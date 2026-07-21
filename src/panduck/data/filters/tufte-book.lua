-- Partes del libro para el perfil `tufte-book`. Un encabezado de nivel 1 con
-- clase .part no es un capitulo sino un separador de parte:
--
--   # Modelamiento {.part}
--
-- Se emite como `#part-page[...]` (funcion de templates/tufte-book.typst), que
-- ocupa una pagina entera. El resto de los encabezados de nivel 1 quedan como
-- estan y la plantilla los estiliza como capitulos.
--
-- Corre despues de tufte.lua, que ya resolvio notas al margen, ::: margin y
-- ::: wide. El caso .unnumbered lo maneja tufte.lua, asi que aca no se toca.

local function inlines_to_typst(inlines)
  local s = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "typst")
  return (s:gsub("%s+$", ""))
end

function Header(el)
  if el.level ~= 1 or not el.classes:includes("part") then return nil end
  local label = el.identifier ~= "" and (" <" .. el.identifier .. ">") or ""
  return pandoc.RawBlock("typst",
    "#part-page[" .. inlines_to_typst(el.content) .. "]" .. label)
end

-- Una nota al pie pegada a un encabezado (`## Titulo^[nota]`) sale duplicada: el
-- indice de typst re-renderiza el encabezado completo, asi que la nota se compone
-- tambien ahi, encima del indice. Ocultar la marca con un `show` no basta, porque
-- el cuerpo de la nota igual se emite. Se saca del encabezado y se pega al final
-- del primer parrafo que lo sigue, donde se lee igual.
--
-- Va en este filtro y no en tufte.lua porque tufte.lua ya convirtio las notas en
-- typst crudo cuando le toca (los handlers de elemento corren de adentro hacia
-- afuera), y aca las notas todavia son nodos Note.
function Blocks(blocks)
  local salida = pandoc.List()
  local pendientes = pandoc.List()
  for _, blk in ipairs(blocks) do
    if blk.t == "Header" then
      blk = blk:walk({ Note = function(n) pendientes:insert(n); return {} end })
      salida:insert(blk)
    elseif #pendientes > 0 and (blk.t == "Para" or blk.t == "Plain") then
      for _, nota in ipairs(pendientes) do blk.content:insert(nota) end
      pendientes = pandoc.List()
      salida:insert(blk)
    else
      salida:insert(blk)
    end
  end
  -- Sin parrafo despues del encabezado, la nota va en uno propio para no perderla.
  if #pendientes > 0 then salida:insert(pandoc.Para(pendientes)) end
  return salida
end
