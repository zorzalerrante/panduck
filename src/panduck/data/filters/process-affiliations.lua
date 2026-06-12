-- Processes author affiliations into the elsarticle group system.
-- Collects unique affiliations, assigns sequential IDs (aff1, aff2, ...),
-- and adds to metadata:
--   affiliation_groups: [{id, name}] — for \address[id]{name} in template
--   author.affiliation_ids: "aff1,aff2" — for \author[ids]{name} in template

local stringify = pandoc.utils.stringify

function Meta(m)
  if not m.authors then return m end

  local affil_list = {}  -- ordered: [{id, name}]
  local affil_map  = {}  -- name -> id

  local function get_id(name)
    if not affil_map[name] then
      local id = 'aff' .. (1 + #affil_list)
      affil_map[name] = id
      table.insert(affil_list, { id = id, name = name })
    end
    return affil_map[name]
  end

  for i, author in ipairs(m.authors) do
    if not author.affiliation then goto continue end

    -- Normalize to a list regardless of whether it's MetaList or MetaInlines
    local affil = author.affiliation
    if pandoc.utils.type(affil) ~= 'List' then
      affil = pandoc.List({ affil })
    end

    local ids = {}
    for _, item in ipairs(affil) do
      table.insert(ids, get_id(stringify(item)))
    end
    m.authors[i].affiliation_ids = table.concat(ids, ',')
    ::continue::
  end

  m.affiliation_groups = affil_list
  return m
end
