-- Rescata el LaTeX crudo que el writer typst de pandoc descarta sin avisar, y
-- avisa por stderr de lo que no pudo traducir.
--
-- El writer typst ignora todo RawBlock/RawInline en formato tex: un \clearpage,
-- un \begin{align*} o un \mbox desaparecen de la salida sin error ni warning.
-- Este filtro:
--   1. traduce los saltos de pagina a #pagebreak(weak: true)
--   2. reparsea los entornos (\begin{...}...\end{...}) con el lector latex de
--      pandoc, asi una ecuacion display escrita en LaTeX vuelve a ser un nodo
--      Math que el writer si sabe emitir
--   3. desenvuelve los comandos de prosa conservando el contenido: \textbf y
--      \emph pasan a nodos nativos, \mbox y \hbox a #box[...] (que es lo que
--      hacen en LaTeX: no partir la linea)
--   4. cuenta lo que igual se va a perder y lo lista al terminar, para que la
--      perdida no sea silenciosa
--
-- Un comando desconocido con contenido (\foo{texto}) NO se desenvuelve: hacerlo
-- volcaria al texto cosas como el argumento de un \label. Se avisa y ya.
--
-- Corre en todos los perfiles typst, justo antes de typst-fix-symbols.lua (que
-- trabaja sobre nodos Math, incluidos los que este filtro recupera).

local SALTOS = { clearpage = true, newpage = true, pagebreak = true,
                 cleardoublepage = true }

local ENVOLTURA = {  -- comando -> nodo pandoc equivalente
  textbf = pandoc.Strong, bf = pandoc.Strong, textmd = pandoc.Strong,
  textit = pandoc.Emph, emph = pandoc.Emph, textsl = pandoc.Emph, it = pandoc.Emph,
  textsc = pandoc.SmallCaps, sc = pandoc.SmallCaps,
  underline = pandoc.Underline,
}
local CAJA = { mbox = true, hbox = true }              -- no parte la linea
local PLANO = { textrm = true, textnormal = true, textup = true }  -- solo el contenido

local descartados = {}

local function anota(texto)
  local cmd = texto:match("^%s*\\(%a+)") or texto:match("^%s*(\\\\)") or "?"
  descartados[cmd] = (descartados[cmd] or 0) + 1
end

local function es_tex(formato)
  return formato == "tex" or formato == "latex"
end

-- Reparsea un trozo de LaTeX a nodos nativos. Devuelve nil si el lector no
-- rescato nada (p. ej. un entorno que no entiende, como tikzpicture) o si lo
-- devolvio tal cual como raw.
local function reparsea(texto)
  local ok, doc = pcall(pandoc.read, texto, "latex")
  if not ok or #doc.blocks == 0 then return nil end
  if #doc.blocks == 1 and doc.blocks[1].t == "RawBlock" and es_tex(doc.blocks[1].format) then
    return nil
  end
  local hay_algo = pandoc.utils.stringify(doc):match("%S") ~= nil
  if not hay_algo then
    doc:walk({ Image = function() hay_algo = true end })
  end
  return hay_algo and doc.blocks or nil
end

function RawBlock(el)
  if not es_tex(el.format) then return nil end
  local solo = el.text:gsub("%s+", "")
  local cmd = solo:match("^\\(%a+)%*?$") or solo:match("^\\(%a+)%[%d%]$")
  if cmd and SALTOS[cmd] then
    return pandoc.RawBlock("typst", "#pagebreak(weak: true)")
  end
  if el.text:match("^%s*\\begin%s*{") then
    local blocks = reparsea(el.text)
    if blocks then return blocks end
  end
  anota(el.text)
  return nil  -- el writer lo descarta; ya quedo anotado
end

function RawInline(el)
  if not es_tex(el.format) then return nil end
  local t = el.text
  if t:match("^%s*\\begin%s*{") then
    local blocks = reparsea(t)
    if blocks then return pandoc.utils.blocks_to_inlines(blocks) end
    anota(t)
    return nil
  end
  if t:match("^%s*\\newline") or t:match("^%s*\\\\%s*$") then return pandoc.LineBreak() end
  local cmd, arg = t:match("^%s*\\(%a+)%s*(%b{})$")
  if cmd and (ENVOLTURA[cmd] or CAJA[cmd] or PLANO[cmd]) then
    local blocks = reparsea(arg:sub(2, -2))
    local dentro = blocks and pandoc.utils.blocks_to_inlines(blocks)
    if dentro then
      if ENVOLTURA[cmd] then return ENVOLTURA[cmd](dentro) end
      if PLANO[cmd] then return dentro end
      local out = pandoc.List({ pandoc.RawInline("typst", "#box[") })
      out:extend(dentro)
      out:insert(pandoc.RawInline("typst", "]"))
      return out
    end
  end
  anota(t)
  return nil
end

function Pandoc(doc)
  local items, total = {}, 0
  for cmd, n in pairs(descartados) do
    items[#items + 1] = { cmd = cmd, n = n }
    total = total + n
  end
  if total == 0 then return nil end
  table.sort(items, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.cmd < b.cmd
  end)
  local lista = {}
  for _, it in ipairs(items) do
    lista[#lista + 1] = "\\" .. it.cmd .. " (" .. it.n .. ")"
  end
  io.stderr:write("[panduck] aviso: " .. total .. " trozo(s) de LaTeX crudo sin " ..
    "traduccion a typst; no apareceran en la salida: " .. table.concat(lista, ", ") .. "\n")
  return nil
end
