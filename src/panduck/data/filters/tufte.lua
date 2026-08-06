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

-- `pie-al-margen` (definida en toffee-tufte) le dice a la plantilla tufte-book si
-- el pie de figura va al margen. Dentro de un bloque de margen o de ancho
-- completo no hay margen libre donde ponerlo, asi que se apaga alrededor.
local PIE_ABAJO = "#pie-al-margen.update(false)"
local PIE_AL_MARGEN = "#pie-al-margen.update(true)"

-- cap-margin-image (def. en la plantilla) acota la altura de las imagenes de
-- margen: drafting apila las notas hacia abajo sin pasar a la pagina siguiente,
-- asi que una figura de margen alta (o varias seguidas) se desborda por el pie.
-- El tope solo achica las altas, no las anchas ni bajas. El `show figure` reduce
-- el espacio de la figura dentro del margen: el aire grande que la plantilla da a
-- las figuras del cuerpo aca sumaria al desborde. `sidenote-flotante` deja que la
-- figura suba si el margen esta libre sobre ella, hasta el limite de la plantilla.
-- `set image(width: 100%)`: en el margen una imagen sin ancho declarado sale a su
-- tamano natural, que rara vez calza con la columna. Un `set` es default, asi que
-- el ancho que el autor escriba sigue mandando.
local ABRE_MARGEN = "#sidenote-flotante[#show image: cap-margin-image;"
  .. "#set image(width: 100%);"
  .. "#show figure: set block(above: 0.5em, below: 0.5em);\n"

local function wrap(el, open)
  local out = {
    pandoc.RawBlock("typst", PIE_ABAJO),
    pandoc.RawBlock("typst", open),
  }
  for _, blk in ipairs(el.content) do out[#out + 1] = blk end
  out[#out + 1] = pandoc.RawBlock("typst", "]")
  -- El `parbreak` separa el bloque del parrafo que sigue. Sin el quedan pegados,
  -- typst los une en un mismo parrafo y el salto de linea sale como un espacio
  -- al inicio, que se lee como una sangria. Una linea en blanco no sirve: el
  -- writer normaliza la separacion entre bloques a un solo salto.
  out[#out + 1] = pandoc.RawBlock("typst", PIE_AL_MARGEN .. "#parbreak()")
  return out
end

-- El writer de typst emite #footnote; en un documento Tufte la nota va al margen.
-- Se serializa a texto porque Note es un Inline y no admite bloques envolventes.
local function nota_al_margen(el)
  return pandoc.RawInline("typst", "#sidenote[" .. blocks_to_typst(el.content) .. "]")
end

-- Un `::: margin` se emite como su propio parrafo, que es la unica forma en que
-- drafting lo coloca bien. Se probaron las otras tres y todas descolocan la
-- figura: pegado al final del parrafo anterior, pegado al inicio del siguiente, y
-- dentro de un `#block`. En los tres casos la x que drafting lee para el ancla no
-- es la del borde izquierdo de la columna y la figura sale corrida a la derecha,
-- a veces fuera de la hoja.
--
-- El costo de ir en parrafo propio es que ese parrafo, aunque invisible, trae su
-- espaciado: entre los dos parrafos vecinos quedan DOS separaciones en vez de una
-- (36,65pt contra 22,25pt en el apunte, 14 casos contra 81). Un
-- `#context v(-par.spacing)` al final las deja en una, pero mover asi el texto
-- basta para volver a descolocar una figura cerca de un salto de pagina, medido.
-- Se prefiere el espacio de mas: es cosmetico y afecta a pocos pares, mientras
-- que la figura descolocada sale impresa fuera de la hoja.
local function divs(el)
  if el.classes:includes("margin") then return wrap(el, ABRE_MARGEN) end
  if el.classes:includes("wide") then return wrap(el, "#wideblock[") end
end

-- pandoc marca los encabezados sin numerar con la clase unnumbered ({-} o
-- {.unnumbered}), pero el writer de typst la descarta y el paquete numera igual.
local function encabezado_sin_numero(el)
  if not el.classes:includes("unnumbered") then return nil end
  local label = el.identifier ~= "" and (" <" .. el.identifier .. ">") or ""
  return pandoc.RawBlock("typst",
    "#heading(level: " .. el.level .. ", numbering: none, outlined: false)["
    .. inlines_to_typst(el.content) .. "]" .. label)
end

return {
  Note = nota_al_margen,
  Header = encabezado_sin_numero,
  Div = divs,
}
