-- Diagramas de Graphviz escritos en el documento: un bloque de codigo con clase
-- .dot o .graphviz se rasteriza con `dot` y se inserta como imagen, en vez de
-- mantener el .dot aparte y una regla en el Makefile.
--
--     ```{.dot width="60%"}
--     digraph { a -> b }
--     ```
--
--     ```{#fig:flujo .dot caption="Flujo de datos"}
--     digraph { a -> b }
--     ```
--
-- Con `caption` sale como figura (pandoc-crossref la numera y `[-@fig:flujo]` la
-- referencia); sin pie, como imagen centrada. Atributos: `width` (80% por
-- defecto), `height`, `engine` (dot, neato, circo, fdp, sfdp, twopi, osage) y
-- `caption`.
--
-- El diagrama toma la tipografia y los colores del documento sin declararlos: el
-- filtro inyecta al inicio del grafo los defaults de graph/node/edge (fontname,
-- fondo transparente y el estilo base de nodo). Como en DOT los defaults son
-- posicionales, un `node [...]` escrito despues los sobreescribe.
--
-- Tres estilos de nodo, que se marcan con `class` (atributo valido de graphviz,
-- que solo usa la salida SVG, asi que el fuente sigue siendo DOT compilable a
-- mano; sin el filtro pierde el color, no la validez):
--
--     a                        -- base: papel de fondo, borde y texto de tinta
--     b [class="strong"]       -- tinta de fondo, texto contrastante
--     c [class="accent"]       -- color destacado de fondo, texto contrastante
--
-- Alias en castellano: `base`, `fuerte`, `acento`. El color del texto sale de la
-- luminancia del fondo (misma regla que instagram-posts.lua, duplicada aca
-- porque un filtro resuelto desde el data-dir no puede `require` un modulo); con
-- un nombre de color de graphviz (steelblue) no hay hex que medir y el texto
-- queda oscuro, asi que para un fondo oscuro conviene dar el color en hex.
--
-- El formato de la imagen sale del writer, no se elige a mano: typst y html leen
-- SVG, LaTeX necesita un PDF (un .svg lo mandaria a \includesvg, que exige el
-- paquete svg mas inkscape) y docx un PNG. Por eso el filtro corre en todos los
-- perfiles y no solo en los typst.
--
-- El archivo se llama por el hash del contenido (`_dot_<sha1>.<ext>`), asi que
-- dos compilaciones seguidas no vuelven a llamar a `dot` y el nombre no colisiona
-- entre diagramas. El hash se calcula sobre el DOT ya expandido, de modo que
-- cambiar la paleta o la tipografia en el head regenere la imagen. Si `dot` no
-- esta instalado se avisa y el bloque de codigo se deja tal cual, en vez de
-- romper la compilacion.
--
-- Metadata (todo opcional): `dot-font` (default: `mainfont`), `dot-fg` (tinta),
-- `dot-bg` (papel) y `dot-accent` (destacado). Los perfiles con tema propio
-- seleccionan su paleta con `dot-theme` en su YAML de defaults; ahi no pueden ir
-- los colores, porque el `metadata:` de un defaults gana sobre el front matter y
-- el documento no podria sobreescribirlos (el nombre del tema si sirve, porque
-- los colores sueltos del head tienen prioridad sobre el).

local FORMATO = {
  typst = "svg", html = "svg", html4 = "svg", html5 = "svg", revealjs = "svg",
  latex = "pdf", beamer = "pdf", context = "pdf",
  docx = "png", odt = "png", pptx = "png", rtf = "png",
}

local MOTORES = {
  dot = true, neato = true, circo = true, fdp = true, sfdp = true,
  twopi = true, osage = true, patchwork = true,
}

-- ---- Estilos de nodo --------------------------------------------------------

local TEMAS = {
  papel  = { fg = "#1a1a1a", bg = "#ffffff", accent = "#CF3889" },
  slides = { fg = "#0A0E50", bg = "#ffffff", accent = "#CF3889" },
}

local CLARO, OSCURO = "#ffffff", "#1a1a1a"

-- nombre de clase (con sus alias) -> estilo
local CLASES = {
  base = "base", strong = "strong", accent = "accent",
  fuerte = "strong", acento = "accent",
}

local paleta, fuente = TEMAS.papel, nil

local function hex_to_rgb(h)
  h = h:gsub("#", "")
  if #h ~= 6 then return nil end
  return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

local function luminance(r, g, b)
  local function chan(c)
    c = c / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)
end

-- color de texto legible sobre `fondo`
local function contraste(fondo)
  local r, g, b = hex_to_rgb(fondo)
  if not r then return OSCURO end
  if luminance(r, g, b) > 0.5 then return OSCURO else return CLARO end
end

local function meta_str(meta, clave)
  local v = meta[clave]
  if v == nil then return nil end
  local s = pandoc.utils.stringify(v)
  if s == "" then return nil end
  return s
end

-- `#` abre un comentario en YAML, asi que un color va entre comillas ("#0A0E50")
-- o sin el numeral (0A0E50); los nombres de color de graphviz (steelblue, gray20)
-- pasan tal cual. Un hex de puros digitos sin comillas se pierde antes de llegar
-- aca (YAML lo lee como numero: `004400` queda en `4400`), asi que lo que no
-- parece un color se avisa y cae al tema, en vez de pasarle basura a graphviz.
local function color(clave, v)
  if v == nil then return nil end
  if v:match("^#%x%x%x%x%x%x$") or v:match("^%a[%w]*$") then return v end
  if v:match("^%x%x%x%x%x%x$") then return "#" .. v end
  io.stderr:write("[panduck] aviso: " .. clave .. ": " .. v .. " no parece un color; " ..
    "escribelo entre comillas en el head (\"#004400\"). Se usa el del tema\n")
  return nil
end

local function leer_meta(meta)
  local tema = TEMAS[meta_str(meta, "dot-theme") or ""] or TEMAS.papel
  paleta = {
    fg = color("dot-fg", meta_str(meta, "dot-fg")) or tema.fg,
    bg = color("dot-bg", meta_str(meta, "dot-bg")) or tema.bg,
    accent = color("dot-accent", meta_str(meta, "dot-accent")) or tema.accent,
  }
  fuente = meta_str(meta, "dot-font") or meta_str(meta, "mainfont")
end

local function atributos(estilo)
  local fondo, borde = paleta.bg, paleta.fg
  if estilo == "strong" then fondo, borde = paleta.fg, paleta.fg
  elseif estilo == "accent" then fondo, borde = paleta.accent, paleta.accent end
  local texto = estilo == "base" and paleta.fg or contraste(fondo)
  return string.format('fillcolor="%s", color="%s", fontcolor="%s"', fondo, borde, texto)
end

local function preambulo()
  local fn = fuente and string.format('fontname="%s", ', fuente) or ""
  return string.format(
    '\n  graph [%sbgcolor="transparent"]\n  node [%sstyle="filled", %s]\n  edge [%scolor="%s", fontcolor="%s"]',
    fn, fn, atributos("base"), fn, paleta.fg, paleta.fg)
end

-- expande las clases a atributos concretos e inyecta los defaults del documento
local function expandir(texto)
  local function estilo(nombre)
    local canon = CLASES[nombre:lower()]
    if canon then return atributos(canon) end
    return nil  -- clase ajena: se deja tal cual (sigue siendo `class` de graphviz)
  end
  texto = texto:gsub('class%s*=%s*"%s*([%w_%-]+)%s*"', estilo)
  texto = texto:gsub('class%s*=%s*([%w_%-]+)', estilo)
  local i = texto:find("{", 1, true)
  if not i then return texto end  -- no parece un grafo; que `dot` de el error
  return texto:sub(1, i) .. preambulo() .. texto:sub(i + 1)
end

-- ---- Diagramas --------------------------------------------------------------

local aviso_dado = false

local function existe(ruta)
  local fh = io.open(ruta, "rb")
  if fh then fh:close() end
  return fh ~= nil
end

local function diagrama(el)
  if not (el.classes:includes("dot") or el.classes:includes("graphviz")) then return nil end
  local ext = FORMATO[FORMAT] or "png"
  local motor = el.attributes["engine"] or "dot"
  if not MOTORES[motor] then motor = "dot" end
  local dot = expandir(el.text)
  local nombre = "_dot_" .. pandoc.utils.sha1(motor .. "\1" .. ext .. "\1" .. dot):sub(1, 8)
    .. "." .. ext

  if not existe(nombre) then
    local ok, salida = pcall(pandoc.pipe, motor, { "-T" .. ext }, dot)
    if not ok then
      if not aviso_dado then
        aviso_dado = true
        io.stderr:write("[panduck] aviso: no se pudo ejecutar `" .. motor ..
          "` (graphviz); los bloques .dot quedan como codigo\n")
      end
      return nil
    end
    local fh = io.open(nombre, "wb")
    fh:write(salida)
    fh:close()
  end

  local atr = { width = el.attributes["width"] or "80%" }
  if el.attributes["height"] then atr.height = el.attributes["height"] end
  local img = pandoc.Image({}, nombre, "", pandoc.Attr("", {}, atr))
  local pie = el.attributes["caption"]
  if pie then
    return pandoc.Figure(
      pandoc.Plain({ img }),
      { long = pandoc.Blocks({ pandoc.Plain(pandoc.utils.blocks_to_inlines(
          pandoc.read(pie, "markdown").blocks)) }) },
      pandoc.Attr(el.identifier))
  end
  -- sin pie no hay figura que numerar; se centra con el vocabulario de
  -- fonts-and-alignment, que corre despues y sirve en typst y en latex
  return pandoc.Div({ pandoc.Plain({ img }) },
    pandoc.Attr(el.identifier, { "pfa-align-center" }))
end

-- dos pasadas: en un mismo filtro Meta corre despues de los bloques, y la
-- paleta tiene que estar leida antes de expandir el primer diagrama
return { { Meta = leer_meta }, { CodeBlock = diagrama } }
