-- latex-wide-figures.lua: una figura marcada con la clase `wide` (en la imagen
-- o en la Figure) sale como figure* (ancho completo) en los documentos LaTeX de
-- dos columnas. Dentro de figure* \linewidth es el ancho del texto, asi que los
-- width relativos de pandoc (width=100%) escalan solos y basta renombrar el
-- entorno. Corre despues de crossref (ids y captions ya finales) y antes del
-- writer; en perfiles de una columna la clase no hace dano (figure* existe y
-- se comporta como figure).

local function tiene_wide(fig)
  if fig.classes and fig.classes:includes('wide') then
    return true
  end
  local found = false
  fig:walk({
    Image = function(img)
      if img.classes:includes('wide') then found = true end
    end
  })
  return found
end

function Figure(fig)
  if not tiene_wide(fig) then
    return nil
  end
  local tex = pandoc.write(pandoc.Pandoc({ fig }), 'latex')
  tex = tex:gsub('\\begin{figure}', '\\begin{figure*}')
            :gsub('\\end{figure}', '\\end{figure*}')
  return pandoc.RawBlock('latex', tex)
end
