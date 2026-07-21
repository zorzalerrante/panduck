-- Bibliografia por capitulo en un libro, en vez de una sola al final.
--
-- pandoc/citeproc produce UNA bibliografia para todo el documento (la pone en el
-- ultimo `::: {#refs}` o al final), asi que en un libro las referencias de cada
-- unidad no salen bajo la unidad: se acumulan al final. Este filtro parte el
-- cuerpo en capitulos (encabezados de nivel 1) y corre citeproc por separado en
-- cada uno con `pandoc.utils.citeproc`, de modo que cada capitulo recibe solo sus
-- referencias, numeradas desde 1. La bibliografia queda donde el capitulo tenga
-- `::: {#refs}` y, si no, al final del capitulo (tras un encabezado "Referencias"
-- si lo hay).
--
-- REEMPLAZA al filtro `citeproc` global (no deben correr los dos: el global
-- consumiria las citas antes). Va donde iba citeproc en el perfil (post-crossref,
-- antes de typst-flatten-cites). Para documentos de una sola pieza (perfil
-- `tufte`) NO se usa: ahi citeproc normal ya deja una bibliografia al final.
--
-- Corte de capitulo: un Header de nivel 1, o una pagina de parte (que a esta
-- altura tufte-book.lua ya convirtio en un RawBlock `#part-page[...]`). El
-- contenido antes del primer capitulo (portada, indice, primera parte) pasa sin
-- tocar: no lleva citas.

function Pandoc(doc)
  local meta = doc.meta
  local out = pandoc.List()
  local chapter = nil  -- bloques del capitulo en curso (nil = fuera de capitulo)

  local function flush()
    if chapter == nil then return end
    out:extend(pandoc.utils.citeproc(pandoc.Pandoc(chapter, meta)).blocks)
    chapter = nil
  end

  for _, blk in ipairs(doc.blocks) do
    local es_parte = blk.t == "RawBlock" and blk.text:find("#part%-page")
    if blk.t == "Header" and blk.level == 1 then
      flush()
      chapter = pandoc.List({ blk })
    elseif es_parte then
      flush()
      out:insert(blk)  -- la pagina de parte no pertenece a ningun capitulo
    elseif chapter == nil then
      out:insert(blk)
    else
      chapter:insert(blk)
    end
  end
  flush()
  return pandoc.Pandoc(out, meta)
end
