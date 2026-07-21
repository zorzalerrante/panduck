-- Traduce el vocabulario Tufte del markdown a las funciones de toffee-tufte
-- (perfil tufte). El margen derecho ancho de la plantilla es donde vive todo:
--   ^[...] o [^1]        nota al pie -> nota al margen numerada (#sidenote)
--   ::: margin           bloque (texto o figura) al margen, sin numerar
--   ::: wide             bloque a ancho completo, invade el margen (#wideblock)
--   ## Titulo {-}        encabezado sin numerar (el writer de typst ignora la clase)
-- Con `full: true` en el head.yaml, toffee-tufte devuelve las notas al pie de la
-- pagina y el ancho completo; este filtro no cambia, lo resuelve el paquete.
--
-- Emite typst envolviendo el contenido real entre RawBlocks, asi el writer lo
-- sigue procesando (y ve lo que ya dejaron citeproc y fonts-and-alignment).

local function inlines_to_typst(inlines)
  local s = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "typst")
  return (s:gsub("%s+$", ""))
end

local function blocks_to_typst(blocks)
  local s = pandoc.write(pandoc.Pandoc(blocks), "typst")
  return (s:gsub("%s+$", ""))
end

local function wrap(el, open)
  local out = { pandoc.RawBlock("typst", open) }
  for _, blk in ipairs(el.content) do out[#out + 1] = blk end
  out[#out + 1] = pandoc.RawBlock("typst", "]")
  return out
end

-- El writer de typst emite #footnote; en un documento Tufte la nota va al margen.
-- Se serializa a texto porque Note es un Inline y no admite bloques envolventes.
function Note(el)
  return pandoc.RawInline("typst", "#sidenote[" .. blocks_to_typst(el.content) .. "]")
end

function Div(el)
  if el.classes:includes("margin") then
    -- cap-margin-image (def. en la plantilla) acota la altura de las imagenes de
    -- margen: drafting apila las notas hacia abajo sin pasar a la pagina
    -- siguiente, asi que una figura de margen alta (o varias seguidas) se
    -- desborda por el pie. El tope solo achica las altas, no las anchas ni bajas.
    -- El `show figure` reduce el espacio de la figura dentro del margen: el aire
    -- grande que la plantilla da a las figuras del cuerpo aca sumaria al desborde.
    return wrap(el, "#sidenote(numbered: false)[#show image: cap-margin-image;"
      .. "#show figure: set block(above: 0.5em, below: 0.5em);\n")
  end
  if el.classes:includes("wide") then
    return wrap(el, "#wideblock[")
  end
end

-- pandoc marca los encabezados sin numerar con la clase unnumbered ({-} o
-- {.unnumbered}), pero el writer de typst la descarta y el paquete numera igual.
function Header(el)
  if not el.classes:includes("unnumbered") then return nil end
  local label = el.identifier ~= "" and (" <" .. el.identifier .. ">") or ""
  return pandoc.RawBlock("typst",
    "#heading(level: " .. el.level .. ", numbering: none, outlined: false)["
    .. inlines_to_typst(el.content) .. "]" .. label)
end
