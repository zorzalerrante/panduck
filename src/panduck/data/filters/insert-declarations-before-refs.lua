-- Inserts back-matter declaration sections before the References section:
-- Funding, Competing interests and Data availability. Runs after citeproc, so
-- the refs div is already present in the AST; the sections are placed right
-- before the "References" header (or the citeproc #refs div). Clears the
-- corresponding meta fields so a template's own $if(...)$ fallback block does
-- not duplicate them.
--
-- Each statement is emitted as a native pandoc Para so the LaTeX writer escapes
-- special characters and renders links (\href), which a raw string could not.
--
-- Anonymous: funding is stripped (grant numbers can identify the institution).
-- Competing interests and data availability are kept: a generic statement does
-- not identify the authors, and their text is under the author's control.

local ptype = pandoc.utils.type
local stringify = pandoc.utils.stringify

-- Modern pandoc API returns MetaInlines as Inlines and MetaString as a string.
local function as_inlines(v)
  if type(v) == "string" then return pandoc.Inlines({ pandoc.Str(v) }) end
  if ptype(v) == "Inlines" then return v end
  return pandoc.Inlines({ pandoc.Str(stringify(v)) })
end

local function section(title, para_inlines)
  return {
    pandoc.RawBlock("latex", "\\section*{" .. title .. "}"),
    pandoc.Para(para_inlines),
  }
end

function Pandoc(doc)
  local anon = doc.meta.anonymous
  local decls = {}

  -- Funding: "This work was supported by A; B." (hidden when anonymous).
  local funding = doc.meta.funding
  if funding and not anon then
    local inl = pandoc.List({ pandoc.Str("This work was supported by ") })
    for i, item in ipairs(funding) do
      if i > 1 then inl:insert(pandoc.Str("; ")) end
      inl:extend(as_inlines(item))
    end
    inl:insert(pandoc.Str("."))
    for _, b in ipairs(section("Funding", inl)) do decls[#decls + 1] = b end
  end

  -- Competing interests: single statement.
  if doc.meta.interests then
    for _, b in ipairs(section("Competing interests", as_inlines(doc.meta.interests))) do
      decls[#decls + 1] = b
    end
  end

  -- Data availability: single statement.
  if doc.meta.data then
    for _, b in ipairs(section("Data availability", as_inlines(doc.meta.data))) do
      decls[#decls + 1] = b
    end
  end

  -- Clear meta so the template fallback blocks do not duplicate these.
  doc.meta.funding = nil
  doc.meta.interests = nil
  doc.meta.data = nil

  if #decls == 0 then return doc end

  -- Find insertion point: the References header or the citeproc #refs div.
  local blocks = doc.blocks
  local insert_pos = nil
  for i = 1, #blocks do
    local b = blocks[i]
    if b.t == "Div" and b.attr and b.attr.identifier == "refs" then
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
    for j = #decls, 1, -1 do
      table.insert(blocks, insert_pos, decls[j])
    end
  else
    for _, b in ipairs(decls) do blocks:insert(b) end
  end

  return pandoc.Pandoc(blocks, doc.meta)
end
