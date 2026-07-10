-- Deriva los campos que el header de LaPreprint necesita cuando el head.yaml no
-- los fija. La clase lapreprint usa \@leadauthor y \@shorttitle sin default, asi
-- que sin esto el header falla. leadauthor = apellido (ultima palabra) del primer
-- autor; shorttitle = title. El usuario puede sobreescribir ambos en el head.yaml.

local stringify = pandoc.utils.stringify

function Meta(m)
  if not m.leadauthor and m.authors and m.authors[1] and m.authors[1].name then
    local name = stringify(m.authors[1].name)
    m.leadauthor = pandoc.MetaString(name:match("(%S+)%s*$") or name)
  end
  if not m.shorttitle and m.title then
    m.shorttitle = pandoc.MetaString(stringify(m.title))
  end
  return m
end
