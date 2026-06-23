-- Convierte el documento en posts de Instagram (typst). Parte el cuerpo en
-- encabezados de nivel 1 (#): cada uno inicia un post (una pagina). Lee las
-- opciones por post desde los atributos del encabezado y resuelve el color de
-- texto por contraste (claro/oscuro) segun el fondo:
--   # {background-image="bg.png"}   imagen de fondo (cubre la pagina)
--   # {pagecolor="1b3b6f"}          color de fondo
--   # {textcolor="ffffff"}          color de texto explicito (si no, se elige solo)
--   # {.top}                        no centrar verticalmente (alinear arriba)
--   # {.left}                       alinear a la izquierda en vez de centrar
-- Los mismos valores a nivel documento (head.yaml) son los defaults de cada post.
-- Ademas traduce columnas (::: columns), imagenes (ancho %, .circle) y spans con
-- clases de tamano/estilo. Emite typst envolviendo el contenido entre RawBlocks.

local utils = pandoc.utils

local DARK = "#2d2d2d"   -- charcoal suave: texto sobre fondo claro
local LIGHT = "#f8f6f0"  -- crema: texto sobre fondo oscuro

local function to_typst(inlines)
  local s = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "typst")
  return (s:gsub("%s+$", ""))
end

local function rgb_lit(h)
  if not h then return nil end
  if h:sub(1, 1) ~= "#" then h = "#" .. h end
  return 'rgb("' .. h .. '")'
end

-- ---- Color de texto por contraste -------------------------------------------

local function hex_to_rgb(h)
  h = h:gsub("#", "")
  if #h ~= 6 then return nil end
  return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

local function luminance(r, g, b)
  local function chan(c)
    c = c / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)
end

local function contrast_for(r, g, b)
  if luminance(r, g, b) > 0.5 then return DARK else return LIGHT end
end

-- color dominante de una imagen via ImageMagick (nil si no esta disponible)
local function image_dominant(path)
  local ok, out = pcall(pandoc.pipe, "convert",
    { path, "-resize", "1x1!", "-depth", "8",
      "-format", "%[fx:int(255*p.r)],%[fx:int(255*p.g)],%[fx:int(255*p.b)]", "info:" }, "")
  if not ok then return nil end
  local r, g, b = out:match("(%d+),(%d+),(%d+)")
  if not r then return nil end
  return tonumber(r), tonumber(g), tonumber(b)
end

-- prioridad: textcolor explicito > contraste de la imagen > contraste del color
-- de fondo > charcoal por defecto
local function resolve_textcolor(tc, pagecolor, image)
  if tc then return tc end
  if image then
    local r, g, b = image_dominant(image)
    if r then return contrast_for(r, g, b) end
  end
  if pagecolor then
    local r, g, b = hex_to_rgb(pagecolor)
    if r then return contrast_for(r, g, b) end
  end
  return DARK
end

-- ---- Footer con iconos FontAwesome ------------------------------------------

-- codepoints de FontAwesome 4 (la fuente "FontAwesome" instalada); el footer usa
-- shortcodes :nombre: que se reemplazan por el glifo
local FA = {
  instagram = "f16d", globe = "f0ac", envelope = "f0e0", mail = "f0e0",
  twitter = "f099", facebook = "f09a", youtube = "f167", whatsapp = "f232",
  telegram = "f2c6", linkedin = "f0e1", github = "f09b", link = "f0c1",
  heart = "f004", star = "f005", location = "f041", ["map-marker"] = "f041",
  phone = "f095", at = "f1fa",
}

local function typ_escape(t)
  return (t:gsub("([\\#%[%]%*_@`<$~])", "\\%1"))
end

-- texto del footer (con shortcodes) -> typst crudo: iconos como #text(font:..) y
-- el resto escapado para que @, #, *, etc. no se interpreten como markup
local function footer_to_typst(s)
  local out, i = {}, 1
  while true do
    local a, b, name = s:find(":([%w%-]+):", i)
    if not a then
      out[#out + 1] = typ_escape(s:sub(i))
      break
    end
    if a > i then out[#out + 1] = typ_escape(s:sub(i, a - 1)) end
    local code = FA[name]
    out[#out + 1] = code
      and ('#text(font: "FontAwesome")[\\u{' .. code .. '}]#h(0.3em)')
      or typ_escape(s:sub(a, b))
    i = b + 1
  end
  return table.concat(out)
end

-- ---- Opciones por post ------------------------------------------------------

local meta = { pagecolor = nil, image = nil, textcolor = nil }

local function post_opts(attr)
  local pagecolor = (attr and attr.attributes["pagecolor"]) or meta.pagecolor
  local image = (attr and attr.attributes["background-image"]) or meta.image
  local tc = (attr and attr.attributes["textcolor"]) or meta.textcolor
  local resolved = resolve_textcolor(tc, pagecolor, image)
  local o = {}
  if pagecolor then o[#o + 1] = "pagecolor: " .. rgb_lit(pagecolor) end
  if image then o[#o + 1] = 'image-path: "' .. image .. '"' end
  o[#o + 1] = "textcolor: " .. rgb_lit(resolved)
  if attr and attr.attributes["fontsize"] then
    o[#o + 1] = "fontsize: " .. attr.attributes["fontsize"]
  end
  if attr and attr.classes:includes("top") then o[#o + 1] = "flush-top: true" end
  if attr and attr.classes:includes("left") then o[#o + 1] = "flush-left: true" end
  return table.concat(o, ", ")
end

-- ---- Traducciones de contenido (corren antes de la particion) ---------------

-- Columnas: ::: columns con ::: {.column width="50%"} -> #grid
function Div(el)
  if not el.classes:includes("columns") then return nil end
  local widths, cells = {}, {}
  for _, child in ipairs(el.content) do
    if child.t == "Div" and child.classes:includes("column") then
      widths[#widths + 1] = child.attributes["width"] or "1fr"
      cells[#cells + 1] = child
    end
  end
  local out = { pandoc.RawBlock("typst",
    "#grid(columns: (" .. table.concat(widths, ", ") .. "), gutter: 1em,") }
  for i, cell in ipairs(cells) do
    out[#out + 1] = pandoc.RawBlock("typst", "[")
    for _, b in ipairs(cell.content) do out[#out + 1] = b end
    out[#out + 1] = pandoc.RawBlock("typst", i < #cells and "]," or "]")
  end
  out[#out + 1] = pandoc.RawBlock("typst", ")")
  return out
end

-- soporta tanto .circle (clase pandoc) como class="circle" (atributo, sintaxis
-- del markdown viejo de trazos)
local function has_class(el, name)
  if el.classes:includes(name) then return true end
  local a = el.attributes["class"]
  return a ~= nil and a:find(name, 1, true) ~= nil
end

-- Imagenes: ancho/alto en % y recorte circular con .circle
function Image(el)
  local src = el.src
  if has_class(el, "circle") then
    local size = el.attributes["width"] or "50%"
    local pct = size:match("^(%d+%.?%d*)%%$")
    if pct then
      local f = tonumber(pct) / 100
      return pandoc.RawInline("typst",
        '#align(center)[#layout(s => box(clip: true, radius: 50%, width: s.width * ' .. f ..
        ', height: s.width * ' .. f .. ', image("' .. src .. '", width: 100%, height: 100%, fit: "cover")))]')
    end
    return pandoc.RawInline("typst",
      '#align(center)[#box(clip: true, radius: 50%, width: ' .. size .. ', height: ' .. size ..
      ', image("' .. src .. '", width: 100%, height: 100%, fit: "cover"))]')
  end
  local opts = {}
  if el.attributes["width"] then opts[#opts + 1] = "width: " .. el.attributes["width"] end
  if el.attributes["height"] then opts[#opts + 1] = "height: " .. el.attributes["height"] end
  local optstr = #opts > 0 and (", " .. table.concat(opts, ", ")) or ""
  return pandoc.RawInline("typst", '#align(center)[#image("' .. src .. '"' .. optstr .. ')]')
end

-- \mbox{...} de LaTeX (evita el corte de linea) -> #box[...] de typst, asi el
-- markdown de trazos se reusa sin reescribir. Otro LaTeX crudo lo descarta el
-- writer typst.
function RawInline(el)
  if el.format ~= "tex" and el.format ~= "latex" then return nil end
  local inner = el.text:match("^\\mbox%s*{(.*)}$")
  if inner then return pandoc.RawInline("typst", "#box[" .. inner .. "]") end
  return nil
end

-- Los estilos inline de texto (tamano .small/.large/.LARGE/..., versalitas
-- .sc/.smallcaps, .sff/.sans, pesos, color) los maneja el filtro compartido
-- fonts-and-alignment (corre antes en el pipeline). Aqui solo queda lo propio de
-- los posts: imagenes, columnas, \mbox, particion y footer.

-- ---- Particion en posts (corre despues de las traducciones) -----------------

function Pandoc(doc)
  meta.pagecolor = doc.meta.pagecolor and utils.stringify(doc.meta.pagecolor) or nil
  meta.image = doc.meta["background-image"] and utils.stringify(doc.meta["background-image"]) or nil
  meta.textcolor = doc.meta.textcolor and utils.stringify(doc.meta.textcolor) or nil

  -- footer: resuelve shortcodes de iconos a typst crudo
  if doc.meta.footer then
    doc.meta.footer = pandoc.MetaInlines({
      pandoc.RawInline("typst", footer_to_typst(utils.stringify(doc.meta.footer))),
    })
  end

  local out, buf, cur_attr, have = {}, {}, nil, false

  local function flush()
    if have or #buf > 0 then
      out[#out + 1] = pandoc.RawBlock("typst", "#post(" .. post_opts(cur_attr) .. ")[")
      for _, b in ipairs(buf) do out[#out + 1] = b end
      out[#out + 1] = pandoc.RawBlock("typst", "]")
    end
    buf, cur_attr, have = {}, nil, false
  end

  for _, blk in ipairs(doc.blocks) do
    if blk.t == "Header" and blk.level == 1 then
      flush()
      cur_attr, have = blk.attr, true
      -- si el encabezado lleva texto, se emite como titulo destacado del post
      if #blk.content > 0 then
        buf[#buf + 1] = pandoc.RawBlock("typst",
          '#text(1.5em, weight: "bold")[' .. to_typst(blk.content) .. "]")
      end
    else
      buf[#buf + 1] = blk
    end
  end
  flush()
  doc.blocks = out
  return doc
end
