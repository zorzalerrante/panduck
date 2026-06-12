-- Removes header-includes from metadata so custom templates
-- are not polluted with working-paper-specific packages.
function Meta(m)
  m['header-includes'] = nil
  return m
end
