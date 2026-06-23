-- Convierte el documento en slides typst. Parte el cuerpo en encabezados:
--   ##  (nivel 2) -> slide de contenido con barra de titulo
--   #   (nivel 1) -> slide de seccion (pagina de acento)
-- Lee opciones por slide desde los atributos de clase del encabezado:
--   {.center}                contenido centrado
--   {.smaller}               fuente reducida
--   {.image}                 foco en imagen (margen minimo, a sangre)
--   {.quote}                 slide de cita (la atribucion en *cursiva* va en acento)
--   {.end}                   slide de cierre (titulo grande + contacto)
--   {background="#1b3b6f"}   fondo de color (texto en blanco)
--   {background-image="x.png"}  imagen de fondo
-- Ademas transforma columnas (con grosor configurable), callouts y diagramas.
-- Alineacion por bloque o columna: ::: left / ::: right / ::: center (o esas
-- clases sobre una .column) envuelven el contenido en #align(...). Util en
-- slides .image/centradas para sacar de centro un texto o columna puntual.
-- Callouts: ::: warning / ::: theorem / ::: prompt ... (con title= opcional);
-- los tipos son note, tip, warning, alert, important, theorem, definition,
-- prompt y callout. `prompt` muestra el cuerpo en monofont.
-- Emite typst envolviendo el contenido real entre RawBlocks, asi el writer de
-- pandoc renderiza el cuerpo dentro de las llamadas a #slide / #grid / #image.

local utils = pandoc.utils

local function to_typst(inlines)
  local s = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "typst")
  return (s:gsub("%s+$", ""))
end

local function color_lit(v)
  -- "#1b3b6f" -> rgb("#1b3b6f"); un nombre (navy, gray) se deja como literal typst
  if v:sub(1, 1) == "#" then
    return 'rgb("' .. v .. '")'
  end
  return v
end

local function slide_opts(attr, title_inlines)
  local o = {}
  if title_inlines and #title_inlines > 0 then o[#o + 1] = "title: [" .. to_typst(title_inlines) .. "]" end
  if attr then
    if attr.classes:includes("center") then o[#o + 1] = "centered: true" end
    if attr.classes:includes("smaller") then o[#o + 1] = "smaller: true" end
    if attr.classes:includes("image") then o[#o + 1] = "full: true" end
    local bg = attr.attributes["background"]
    if bg then o[#o + 1] = "bg: " .. color_lit(bg) end
    local img = attr.attributes["background-image"]
    if img then o[#o + 1] = 'bg-image: "' .. img .. '"' end
  end
  return table.concat(o, ", ")
end

-- Callouts: ::: warning / ::: theorem / ::: prompt ... -> #callout
local CALLOUTS = {
  note = true, tip = true, warning = true, alert = true, important = true,
  theorem = true, definition = true, prompt = true, callout = true,
}

local function callout_kind(classes)
  for _, c in ipairs(classes) do
    if CALLOUTS[c] then return c end
  end
  return nil
end

-- Los estilos inline de texto (tamano .small/.large/..., versalitas .sc, pesos,
-- familias, color, alineacion) los maneja el filtro compartido fonts-and-alignment
-- (corre antes en el pipeline). Aqui solo queda lo propio de las slides.

-- Alineacion: ::: left / ::: right / ::: center, o sobre una .column.
-- En slides .image y centradas el cuerpo va centrado (align(center)); estas
-- clases envuelven un bloque (o una columna) en #align(...) para decidir caso
-- a caso si el texto se alinea a la izquierda, derecha o centro.
local ALIGN = { left = "left", right = "right", center = "center" }

local function align_of(classes)
  for _, c in ipairs(classes) do
    if ALIGN[c] then return ALIGN[c] end
  end
  return nil
end

-- Columnas: ::: columns con ::: {.column width="60%"} -> #grid
function Div(el)
  local kind = callout_kind(el.classes)
  if kind then
    local opts = 'kind: "' .. kind .. '"'
    local title = el.attributes["title"]
    if title then opts = opts .. ', title: [' .. to_typst({ pandoc.Str(title) }) .. ']' end
    local out = { pandoc.RawBlock("typst", "#callout(" .. opts .. ")[") }
    for _, b in ipairs(el.content) do out[#out + 1] = b end
    out[#out + 1] = pandoc.RawBlock("typst", "]")
    return out
  end
  -- Bloque con alineacion explicita (::: left / ::: right / ::: center).
  -- Las columnas (.column) las alinea el grid padre, no aqui.
  local a = align_of(el.classes)
  if a and not el.classes:includes("columns") and not el.classes:includes("column") then
    local out = { pandoc.RawBlock("typst", "#align(" .. a .. ")[") }
    for _, b in ipairs(el.content) do out[#out + 1] = b end
    out[#out + 1] = pandoc.RawBlock("typst", "]")
    return out
  end
  if not el.classes:includes("columns") then return nil end
  local widths, cells = {}, {}
  for _, child in ipairs(el.content) do
    if child.t == "Div" and child.classes:includes("column") then
      widths[#widths + 1] = child.attributes["width"] or "1fr"
      cells[#cells + 1] = child
    end
  end
  local out = { pandoc.RawBlock("typst",
    "#grid(columns: (" .. table.concat(widths, ", ") .. "), gutter: 1.2em,") }
  for i, cell in ipairs(cells) do
    local ca = align_of(cell.classes)
    out[#out + 1] = pandoc.RawBlock("typst", "[")
    if ca then out[#out + 1] = pandoc.RawBlock("typst", "#align(" .. ca .. ")[") end
    for _, b in ipairs(cell.content) do out[#out + 1] = b end
    if ca then out[#out + 1] = pandoc.RawBlock("typst", "]") end
    out[#out + 1] = pandoc.RawBlock("typst", i < #cells and "]," or "]")
  end
  out[#out + 1] = pandoc.RawBlock("typst", ")")
  return out
end

-- Graphviz: ```{.dot} o ```{.graphviz} -> dot -Tsvg -> #image
function CodeBlock(el)
  if not (el.classes:includes("dot") or el.classes:includes("graphviz")) then return nil end
  local svg = pandoc.pipe("dot", { "-Tsvg" }, el.text)
  local name = "_dot_" .. utils.sha1(el.text):sub(1, 8) .. ".svg"
  local fh = io.open(name, "wb")
  fh:write(svg)
  fh:close()
  local w = el.attributes["width"] or "80%"
  return pandoc.RawBlock("typst", '#align(center)[#image("' .. name .. '", width: ' .. w .. ')]')
end

-- Particion en slides (corre despues de transformar columnas y diagramas)
function Pandoc(doc)
  local out, buf = {}, {}
  local cur_attr, cur_title, have_slide = nil, nil, false

  local function flush()
    if have_slide or #buf > 0 then
      local cls = cur_attr and cur_attr.classes
      if cls and cls:includes("quote") then
        out[#out + 1] = pandoc.RawBlock("typst", "#quote-slide[")
        for _, b in ipairs(buf) do out[#out + 1] = b end
        out[#out + 1] = pandoc.RawBlock("typst", "]")
      elseif cls and cls:includes("statement") then
        out[#out + 1] = pandoc.RawBlock("typst", "#statement-slide[")
        for _, b in ipairs(buf) do out[#out + 1] = b end
        out[#out + 1] = pandoc.RawBlock("typst", "]")
      elseif cls and cls:includes("end") then
        local parts = {}
        if cur_title then parts[#parts + 1] = "title: [" .. to_typst(cur_title) .. "]" end
        local img = cur_attr.attributes["image"]
        if img then parts[#parts + 1] = 'image: "' .. img .. '"' end
        out[#out + 1] = pandoc.RawBlock("typst", "#end-slide(" .. table.concat(parts, ", ") .. ")[")
        for _, b in ipairs(buf) do out[#out + 1] = b end
        out[#out + 1] = pandoc.RawBlock("typst", "]")
      else
        out[#out + 1] = pandoc.RawBlock("typst", "#slide(" .. slide_opts(cur_attr, cur_title) .. ")[")
        for _, b in ipairs(buf) do out[#out + 1] = b end
        out[#out + 1] = pandoc.RawBlock("typst", "]")
      end
    end
    buf, cur_attr, cur_title, have_slide = {}, nil, nil, false
  end

  for _, blk in ipairs(doc.blocks) do
    if blk.t == "Header" and blk.level == 1 then
      flush()
      out[#out + 1] = pandoc.RawBlock("typst", "#section-slide[" .. to_typst(blk.content) .. "]")
    elseif blk.t == "Header" and blk.level == 2 then
      flush()
      cur_title, cur_attr, have_slide = blk.content, blk.attr, true
    else
      buf[#buf + 1] = blk
    end
  end
  flush()
  doc.blocks = out
  return doc
end
