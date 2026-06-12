-- Injects a \section*{Funding} block before the References section.
-- Runs after citeproc, so the refs div is already present in the AST.
-- Clears doc.meta.funding so the template's own $if(funding)$ block does not
-- produce a duplicate entry.

local stringify = pandoc.utils.stringify

function Pandoc(doc)
  if doc.meta.anonymous then
    doc.meta.funding = nil
    return doc
  end
  local funding = doc.meta.funding
  if not funding then return doc end

  -- Build funding text from the list items
  local parts = {}
  for _, item in ipairs(funding) do
    table.insert(parts, stringify(item))
  end
  local funding_text = table.concat(parts, "; "):gsub("#", "\\#")

  local raw = pandoc.RawBlock(
    "latex",
    "\\section*{Funding}\nThis work was supported by " .. funding_text .. "."
  )

  -- Find insertion point: the References header or the refs div added by citeproc
  local blocks = doc.blocks
  local insert_pos = nil

  for i = 1, #blocks do
    local b = blocks[i]
    if b.t == "Div" and b.attr and b.attr.identifier == "refs" then
      -- If the preceding block is the References header, insert before it
      if i > 1 and blocks[i - 1].t == "Header" then
        insert_pos = i - 1
      else
        insert_pos = i
      end
      break
    end
    if b.t == "Header" then
      local text = stringify(b.content):lower()
      if text == "references" or text == "bibliography" then
        insert_pos = i
        break
      end
    end
  end

  if insert_pos then
    table.insert(blocks, insert_pos, raw)
  else
    blocks:insert(raw)
  end

  -- Clear funding from metadata so the template block does not duplicate it
  doc.meta.funding = nil

  return pandoc.Pandoc(blocks, doc.meta)
end
