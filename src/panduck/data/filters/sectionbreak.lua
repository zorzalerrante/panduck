-- Convierte cada HorizontalRule (`* * *`, `---`, `___`) en un asterismo
-- centrado, solo para salida LaTeX. Inyecta el paquete panduck-asterism en el
-- preambulo (resuelto desde el texmf de panduck via TEXINPUTS), asi el documento
-- no necesita boilerplate: ni stackengine, ni adforn, ni definir \asterism.
-- Activar por documento con un panduck.yaml: `filters: [sectionbreak.lua]`.

if FORMAT:match('latex') then
  function HorizontalRule()
    return pandoc.RawBlock('latex', '\\panduckbreak')
  end

  -- agrega \usepackage{panduck-asterism} a header-includes sea cual sea su tipo
  function Meta(meta)
    local use = pandoc.MetaBlocks({ pandoc.RawBlock('latex', '\\usepackage{panduck-asterism}') })
    local hi = meta['header-includes']
    if hi == nil then
      meta['header-includes'] = pandoc.MetaList({ use })
    elseif hi.t == 'MetaList' then
      hi:insert(use)
      meta['header-includes'] = hi
    else
      meta['header-includes'] = pandoc.MetaList({ hi, use })
    end
    return meta
  end
end
