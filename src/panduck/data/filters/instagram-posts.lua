-- Convierte el documento en posts de Instagram (typst). Parte el cuerpo en
-- encabezados de nivel 1 (#): cada uno inicia un post (una pagina). Lee las
-- opciones por post desde los atributos del encabezado y resuelve el color de
-- texto por contraste (claro/oscuro) segun el fondo:
--   # {background-image="bg.png"}   imagen de fondo (cubre la pagina)
--   # {pagecolor="1b3b6f"}          color de fondo
--   # {textcolor="ffffff"}          color de texto explicito (si no, se elige solo)
--   # {.top}                        no centrar verticalmente (alinear arriba)
--   # {.left}                       alinear a la izquierda en vez de centrar
--   # {panorama="foto.jpg"}         franja de una foto ancha; los posts seguidos
--                                   que declaren la misma se la reparten, y
--                                   panorama-x / panorama-y fijan el encuadre
--   # {.nofooter}                    ese post va sin pie (marca ni numero)
-- Los mismos valores a nivel documento (head.yaml) son los defaults de cada post.
-- Ademas traduce columnas (::: columns), filas de imagenes (::: row, con gap
-- negativo para traslaparlas), imagenes (ancho %, .circle) y spans con clases de
-- tamano/estilo. Emite typst envolviendo el contenido entre RawBlocks.

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

-- ImageMagick (nil si no esta disponible). Las respuestas se cachean por comando:
-- varios posts comparten el mismo fondo y las franjas de un panorama comparten la
-- misma foto, asi que sin cache se llamaria a convert una vez por post.
local im_cache = {}

local function im(args)
  local key = table.concat(args, "\1")
  local hit = im_cache[key]
  if hit == nil then
    local ok, out = pcall(pandoc.pipe, "convert", args, "")
    hit = ok and out or false
    im_cache[key] = hit
  end
  return hit or nil
end

-- color dominante de una imagen: {r, g, b} o nil
local function image_dominant(path)
  local out = im({ path, "-resize", "1x1!", "-depth", "8",
    "-format", "%[fx:int(255*p.r)],%[fx:int(255*p.g)],%[fx:int(255*p.b)]", "info:" })
  local r, g, b = (out or ""):match("(%d+),(%d+),(%d+)")
  if not r then return nil end
  return { tonumber(r), tonumber(g), tonumber(b) }
end

-- Color dominante de cada franja de un panorama: {{r,g,b}, ...} de largo n, o nil.
-- Reproduce el encuadre de la plantilla (la foto cubre la tira de n paginas y el
-- sobrante se reparte segun x/y), recorta la parte visible y la reduce a n pixeles
-- de ancho: el pixel i es el color de la franja i. Sin esto el contraste se mide
-- sobre la foto entera y una tira que va de oscura a clara deja alguna franja con
-- el texto ilegible.
local function strip_dominants(path, n, x, y, page_w, page_h)
  local size = im({ path .. "[0]", "-format", "%w %h", "info:" })
  local iw, ih = (size or ""):match("(%d+)%s+(%d+)")
  if not iw then return nil end
  iw, ih = tonumber(iw), tonumber(ih)
  -- lado que sobra tras cubrir la tira: uno de los dos factores queda en 1
  local tira, foto = (n * page_w) / page_h, iw / ih
  local cw = math.max(1, math.floor(iw * math.min(1, tira / foto) + 0.5))
  local ch = math.max(1, math.floor(ih * math.min(1, foto / tira) + 0.5))
  local out = im({ path, "-crop", cw .. "x" .. ch .. "+" ..
    math.floor((iw - cw) * x + 0.5) .. "+" .. math.floor((ih - ch) * y + 0.5),
    "+repage", "-colorspace", "sRGB", "-resize", n .. "x1!", "-depth", "8", "txt:-" })
  local cols = {}
  for r, g, b in (out or ""):gmatch("%d+,0: %((%d+),(%d+),(%d+)") do
    cols[#cols + 1] = { tonumber(r), tonumber(g), tonumber(b) }
  end
  return #cols == n and cols or nil
end

-- prioridad: textcolor explicito > contraste del fondo (imagen o color) > charcoal
local function resolve_textcolor(tc, pagecolor, rgb)
  if tc then return tc end
  if rgb then return contrast_for(rgb[1], rgb[2], rgb[3]) end
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

-- w/h: geometria de la pagina en cm (defaults iguales a los de la plantilla).
-- Solo se usa la proporcion, para saber que parte de la foto cae en cada franja
-- de un panorama.
local meta = { pagecolor = nil, image = nil, textcolor = nil, w = 10, h = 12.5 }

local UNIT = { cm = 1, mm = 0.1, ["in"] = 2.54, pt = 2.54 / 72, px = 2.54 / 96 }

local function to_cm(s)
  local v, u = tostring(s):match("^%s*(%d+%.?%d*)%s*(%a*)%s*$")
  local f = v and UNIT[u == "" and "cm" or u]
  return f and tonumber(v) * f or nil
end

local function pct(s, default)
  local v = s and tostring(s):match("^(%-?%d+%.?%d*)%%$")
  return v and tonumber(v) / 100 or default
end

-- span: (path, n, i) cuando el post es una franja de un panorama (ver Pandoc)
local function post_opts(attr, span)
  local pagecolor = (attr and attr.attributes["pagecolor"]) or meta.pagecolor
  local image = (attr and attr.attributes["background-image"]) or meta.image
  local tc = (attr and attr.attributes["textcolor"]) or meta.textcolor
  -- el contraste se mide contra el fondo que efectivamente cubre la pagina: la
  -- franja visible si es un panorama, y si no la imagen o el color de fondo
  local fondo
  if span then
    local cols = strip_dominants(span.path, span.n, pct(span.x, 0.5), pct(span.y, 0.5),
      meta.w, meta.h)
    fondo = cols and cols[span.i + 1] or image_dominant(span.path)
  elseif image then
    fondo = image_dominant(image)
  end
  local resolved = resolve_textcolor(tc, pagecolor, fondo)
  local o = {}
  if pagecolor then o[#o + 1] = "pagecolor: " .. rgb_lit(pagecolor) end
  if span then
    o[#o + 1] = 'panorama-path: "' .. span.path .. '"'
    o[#o + 1] = "panorama-n: " .. span.n
    o[#o + 1] = "panorama-i: " .. span.i
    -- encuadre comun a toda la tira (viene del primer post de la corrida)
    if span.x then o[#o + 1] = "panorama-x: " .. span.x end
    if span.y then o[#o + 1] = "panorama-y: " .. span.y end
  elseif image then
    o[#o + 1] = 'image-path: "' .. image .. '"'
  end
  o[#o + 1] = "textcolor: " .. rgb_lit(resolved)
  if attr and attr.attributes["fontsize"] then
    o[#o + 1] = "fontsize: " .. attr.attributes["fontsize"]
  end
  if attr and attr.classes:includes("top") then o[#o + 1] = "flush-top: true" end
  if attr and attr.classes:includes("left") then o[#o + 1] = "flush-left: true" end
  -- sin pie: el caso tipico es una franja de panorama, donde la marca y el
  -- numero cortan la foto
  if attr and (attr.classes:includes("nofooter") or attr.classes:includes("sin-pie")) then
    o[#o + 1] = "show-footer: false"
  end
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

-- ---- Filas de imagenes (primera pasada, ver el return del final) ------------

-- ::: row / ::: fila -> #row(...). Las imagenes de adentro se pasan como piezas
-- en vez de emitirse sueltas, asi que este handler corre en una pasada previa,
-- antes de que Image las convierta.
local function row_piece(img)
  -- el % del width/height de la imagen escala esa pieza dentro de la fila
  local pct = (img.attributes["height"] or img.attributes["width"] or "")
    :match("^(%d+%.?%d*)%%$")
  return string.format('(path: "%s", circle: %s, factor: %s)',
    img.src, has_class(img, "circle") and "true" or "false",
    pct and tostring(tonumber(pct) / 100) or "none")
end

local function row_div(el)
  if not (el.classes:includes("row") or el.classes:includes("fila")) then return nil end
  local pieces = {}
  el:walk({ Image = function(img) pieces[#pieces + 1] = row_piece(img) end })
  if #pieces == 0 then return nil end
  local opts = { "gap: " .. (el.attributes["gap"] or "0.4em") }
  -- height iguala las alturas; sin height, las columnas reparten el ancho
  if el.attributes["height"] then opts[#opts + 1] = "height: " .. el.attributes["height"] end
  if el.attributes["width"] then opts[#opts + 1] = "width: " .. el.attributes["width"] end
  return pandoc.RawBlock("typst",
    "#row(" .. table.concat(opts, ", ") .. ", " .. table.concat(pieces, ", ") .. ")")
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

-- Los estilos inline de texto (tamano .small/.large/.LARGE/..., versalitas
-- .sc/.smallcaps, .sff/.sans, pesos, color) los maneja el filtro compartido
-- fonts-and-alignment, y el LaTeX crudo de prosa (\mbox{...} del markdown viejo
-- de trazos, que evita el corte de linea) el filtro compartido typst-raw-latex.
-- Los dos corren antes en el pipeline. Aqui solo queda lo propio de los posts:
-- imagenes, columnas, filas, particion y footer.

-- ---- Particion en posts (corre despues de las traducciones) -----------------

function Pandoc(doc)
  meta.pagecolor = doc.meta.pagecolor and utils.stringify(doc.meta.pagecolor) or nil
  meta.image = doc.meta["background-image"] and utils.stringify(doc.meta["background-image"]) or nil
  meta.textcolor = doc.meta.textcolor and utils.stringify(doc.meta.textcolor) or nil
  meta.w = (doc.meta.width and to_cm(utils.stringify(doc.meta.width))) or meta.w
  meta.h = (doc.meta.height and to_cm(utils.stringify(doc.meta.height))) or meta.h

  -- footer: resuelve shortcodes de iconos a typst crudo
  if doc.meta.footer then
    doc.meta.footer = pandoc.MetaInlines({
      pandoc.RawInline("typst", footer_to_typst(utils.stringify(doc.meta.footer))),
    })
  end

  -- 1) juntar los bloques de cada post
  local posts, buf, cur_attr, have = {}, {}, nil, false

  local function cerrar()
    if have or #buf > 0 then posts[#posts + 1] = { attr = cur_attr, blocks = buf } end
    buf, cur_attr, have = {}, nil, false
  end

  for _, blk in ipairs(doc.blocks) do
    if blk.t == "Header" and blk.level == 1 then
      cerrar()
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
  cerrar()

  -- 2) panorama: los posts seguidos que declaran la misma imagen se reparten sus
  -- franjas (n = largo de la corrida, i = posicion). El encuadre sale del primero
  -- de la corrida: tiene que ser el mismo en todas para que la costura calce.
  local function panorama_de(p) return p.attr and p.attr.attributes["panorama"] end
  local spans, k = {}, 1
  while k <= #posts do
    local path = panorama_de(posts[k])
    if path then
      local fin = k
      while fin < #posts and panorama_de(posts[fin + 1]) == path do fin = fin + 1 end
      local encuadre = posts[k].attr.attributes
      for j = k, fin do
        spans[j] = { path = path, n = fin - k + 1, i = j - k,
          x = encuadre["panorama-x"], y = encuadre["panorama-y"] }
      end
      k = fin + 1
    else
      k = k + 1
    end
  end

  -- 3) emitir
  local out = {}
  for j, p in ipairs(posts) do
    out[#out + 1] = pandoc.RawBlock("typst", "#post(" .. post_opts(p.attr, spans[j]) .. ")[")
    for _, b in ipairs(p.blocks) do out[#out + 1] = b end
    out[#out + 1] = pandoc.RawBlock("typst", "]")
  end
  doc.blocks = out
  return doc
end

-- Dos pasadas. Las filas de imagenes van primero porque necesitan las imagenes
-- sin transformar: en una sola pasada, Image (inline) corre antes que Div y las
-- piezas ya serian typst crudo.
return {
  { Div = row_div },
  { Div = Div, Image = Image, Pandoc = Pandoc },
}
