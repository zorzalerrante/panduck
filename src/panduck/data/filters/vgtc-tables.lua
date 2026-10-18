-- vgtc-tables.lua: convierte cada Table del AST en un float table/table* con
-- tabular clasico, porque la salida de tablas de pandoc (longtable) no compila
-- en el modo dos columnas de vgtc.cls ("longtable not in 1-column mode").
-- Corre al final del pipeline (tras crossref, citeproc y fonts-and-alignment),
-- asi las celdas ya traen citas resueltas y estilos aplicados, y el \label
-- sale del identifier que dejo crossref (la numeracion es nativa de LaTeX).
-- Convenciones del template vgtc: caption arriba, \small, reglas booktabs.
-- Con 4 o mas columnas la tabla sale como table* (ancho completo), que es la
-- unica forma razonable de tabla ancha en dos columnas.

local ALIGN = { AlignLeft = 'l', AlignRight = 'r', AlignCenter = 'c', AlignDefault = 'l' }

local function tex(blocks)
  local s = pandoc.write(pandoc.Pandoc(blocks), 'latex')
  return (s:gsub('%s+$', ''))
end

function Table(t)
  local st = pandoc.utils.to_simple_table(t)
  local ncol = #st.aligns
  if ncol == 0 then return nil end
  local wide = ncol >= 4
  local env = wide and 'table*' or 'table'

  -- pandoc asigna anchos relativos cuando las celdas son largas; en ese caso
  -- emitimos columnas p{} proporcionales, si no, letras l/c/r simples
  local haswidths = false
  for _, w in ipairs(st.widths) do
    if w and w > 0 then haswidths = true end
  end
  local colspec = {}
  for i = 1, ncol do
    if haswidths then
      local w = st.widths[i]
      if not w or w == 0 then w = 1 / ncol end
      table.insert(colspec, string.format(
        '>{\\raggedright\\arraybackslash}p{\\dimexpr%.4f\\linewidth-2\\tabcolsep}', w))
    else
      table.insert(colspec, ALIGN[st.aligns[i]] or 'l')
    end
  end

  local function row_tex(cells)
    local rendered = {}
    for _, cell in ipairs(cells) do
      table.insert(rendered, tex(cell))
    end
    return table.concat(rendered, ' & ') .. ' \\\\'
  end

  local out = {}
  table.insert(out, '\\begin{' .. env .. '}[tb]')
  local cap = (st.caption and #st.caption > 0) and tex({ pandoc.Plain(st.caption) }) or ''
  local label = (t.identifier and t.identifier ~= '') and ('\\label{' .. t.identifier .. '}') or ''
  if cap ~= '' or label ~= '' then
    table.insert(out, '\\caption{' .. cap .. '}' .. label)
  end
  table.insert(out, '\\small\\centering')
  table.insert(out, '\\begin{tabular}{' .. table.concat(colspec) .. '}')
  table.insert(out, '\\toprule')
  if st.header and #st.header > 0 then
    local vacio = true
    for _, cell in ipairs(st.header) do
      if #cell > 0 then vacio = false end
    end
    if not vacio then
      table.insert(out, row_tex(st.header))
      table.insert(out, '\\midrule')
    end
  end
  for _, r in ipairs(st.rows) do
    table.insert(out, row_tex(r))
  end
  table.insert(out, '\\bottomrule')
  table.insert(out, '\\end{tabular}')
  table.insert(out, '\\end{' .. env .. '}')
  return pandoc.RawBlock('latex', table.concat(out, '\n'))
end
