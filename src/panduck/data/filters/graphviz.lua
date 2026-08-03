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
-- El formato de la imagen sale del writer, no se elige a mano: typst y html leen
-- SVG, LaTeX necesita un PDF (un .svg lo mandaria a \includesvg, que exige el
-- paquete svg mas inkscape) y docx un PNG. Por eso el filtro corre en todos los
-- perfiles y no solo en los typst.
--
-- El archivo se llama por el hash del contenido (`_dot_<sha1>.<ext>`), asi que
-- dos compilaciones seguidas no vuelven a llamar a `dot` y el nombre no colisiona
-- entre diagramas. Si `dot` no esta instalado se avisa y el bloque de codigo se
-- deja tal cual, en vez de romper la compilacion.

local FORMATO = {
  typst = "svg", html = "svg", html4 = "svg", html5 = "svg", revealjs = "svg",
  latex = "pdf", beamer = "pdf", context = "pdf",
  docx = "png", odt = "png", pptx = "png", rtf = "png",
}

local MOTORES = {
  dot = true, neato = true, circo = true, fdp = true, sfdp = true,
  twopi = true, osage = true, patchwork = true,
}

local aviso_dado = false

local function existe(ruta)
  local fh = io.open(ruta, "rb")
  if fh then fh:close() end
  return fh ~= nil
end

function CodeBlock(el)
  if not (el.classes:includes("dot") or el.classes:includes("graphviz")) then return nil end
  local ext = FORMATO[FORMAT] or "png"
  local motor = el.attributes["engine"] or "dot"
  if not MOTORES[motor] then motor = "dot" end
  local nombre = "_dot_" .. pandoc.utils.sha1(motor .. "\1" .. ext .. "\1" .. el.text):sub(1, 8)
    .. "." .. ext

  if not existe(nombre) then
    local ok, salida = pcall(pandoc.pipe, motor, { "-T" .. ext }, el.text)
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
