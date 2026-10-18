-- Convierte el documento en posts de Instagram (typst). Parte el cuerpo en
-- encabezados de nivel 1 (#): cada uno inicia un post (una pagina). Lee las
-- opciones por post desde los atributos del encabezado y resuelve el color de
-- texto por contraste (claro/oscuro) segun el fondo:
--   # {background-image="bg.png"}   imagen de fondo (cubre la pagina)
--   # {background-dim="0.35"}       velo negro sobre esa imagen, 0 a 1, para que
--                                   el texto despegue de una foto con detalle
--   # {background-tint="6b0f4e"}    color del velo (default negro); dim sigue
--                                   siendo su opacidad, y si no viene queda en 0.5
--   # {pagecolor="1b3b6f"}          color de fondo
--   # {textcolor="ffffff"}          color de texto explicito (si no, se elige solo)
--   # {.top}                        no centrar verticalmente (alinear arriba)
--   # {.left}                       alinear a la izquierda en vez de centrar
--   # {panorama="foto.jpg"}         franja de una foto ancha; los posts seguidos
--                                   que declaren la misma se la reparten, y
--                                   panorama-x / panorama-y fijan el encuadre
--   # {footer="..."}                pie propio de ese post, en vez del general;
--                                   acepta iconos :nombre: y formulas ($\cdot$)
--   # {.nofooter}                   ese post va sin pie (marca ni numero)
--   # {overlay="sello.png"}         imagen suelta sobre el post, fuera del
--                                   margen (overlay-position elige la esquina,
--                                   overlay-width el porte y overlay-inset,
--                                   overlay-x, overlay-y la corren)
-- Los mismos valores a nivel documento (head.yaml) son los defaults de cada post.
-- La alineacion del encabezado vale para el post entero; para un bloque suelto
-- (titulo centrado y bajada a la izquierda) va ::: {.left} / .center / .right.
-- Ademas traduce columnas (::: columns), filas de imagenes (::: row, con gap
-- negativo para traslaparlas), imagenes (ancho %, .circle, .left/.right y .sombra,
-- que acepta sombra-color/-opacidad/-radio/-dx/-dy) y spans con clases de
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

-- Un shortcode viaja dentro de un Str; se parte el texto para dejar el icono
-- como typst crudo y conservar lo que lo rodea.
local function str_con_iconos(el)
  if not el.text:find(":[%w%-]+:") then return nil end
  local out, i = pandoc.Inlines({}), 1
  while true do
    local a, b, name = el.text:find(":([%w%-]+):", i)
    if not a then
      if i <= #el.text then out:insert(pandoc.Str(el.text:sub(i))) end
      break
    end
    if a > i then out:insert(pandoc.Str(el.text:sub(i, a - 1))) end
    local code = FA[name]
    out:insert(code
      and pandoc.RawInline("typst",
        '#text(font: "FontAwesome")[\\u{' .. code .. '}]#h(0.3em)')
      or pandoc.Str(el.text:sub(a, b))) -- shortcode desconocido: queda tal cual
    i = b + 1
  end
  return out
end

-- inlines del footer -> typst crudo. Los iconos salen del mapa FA por su
-- shortcode y el resto lo escribe el propio pandoc, que ya escapa @, #, * donde
-- corresponde. Asi el pie admite lo mismo que el cuerpo: negrita, cursiva,
-- versalitas y formulas ($\cdot$, el separador de siempre).
local function inlines_to_typst(inls)
  local ok, typ = pcall(function()
    local con_iconos = pandoc.Inlines(inls):walk({ Str = str_con_iconos })
    return pandoc.write(pandoc.Pandoc({ pandoc.Plain(con_iconos) }), "typst")
  end)
  return ok and (typ:gsub("%s+$", "")) or typ_escape(utils.stringify(inls))
end

-- Desde el atributo de un encabezado el footer llega como cadena cruda, asi que
-- se lee como markdown antes de convertir. Sin citations, para que una arroba
-- de red social (@trazos.de.aves) no se lea como cita bibliografica.
local function footer_to_typst(s)
  local ok, inls = pcall(function()
    local doc = pandoc.read(s, "markdown-citations-raw_tex-raw_html")
    return doc.blocks[1] and doc.blocks[1].content or pandoc.Inlines({})
  end)
  return inlines_to_typst(ok and inls or pandoc.Inlines({ pandoc.Str(s) }))
end

-- Desde el meta (head.yaml) pandoc ya parseo el valor, que llega como inlines;
-- una cadena pelada solo aparece si vino por --metadata.
local function meta_to_typst(v)
  if type(v) == "string" then return footer_to_typst(v) end
  return inlines_to_typst(v)
end

-- ---- Opciones por post ------------------------------------------------------

-- w/h: geometria de la pagina en cm (defaults iguales a los de la plantilla).
-- Solo se usa la proporcion, para saber que parte de la foto cae en cada franja
-- de un panorama.
local meta = { pagecolor = nil, image = nil, textcolor = nil, dim = nil, tint = nil, w = 10, h = 12.5 }

-- Velo oscuro sobre la imagen de fondo, 0 a 1, para que el texto despegue de una
-- foto con mucho detalle. Se aplica tambien al color dominante con que se elige
-- el color de texto: si no, un fondo medio seguiria resolviendo a texto oscuro
-- aunque el velo ya lo dejo oscuro.
local function dim_valor(s)
  local v = tonumber(s)
  if not v then return nil end
  return math.max(0, math.min(1, v))
end

local function aplicar_dim(rgb, dim, tint)
  if not rgb or not dim then return rgb end
  -- el velo mezcla el fondo con su color (negro si no hay tint) segun dim
  local tr, tg, tb = 0, 0, 0
  if tint then tr, tg, tb = hex_to_rgb(tint) end
  if not tr then tr, tg, tb = 0, 0, 0 end
  return { rgb[1] * (1 - dim) + tr * dim, rgb[2] * (1 - dim) + tg * dim,
           rgb[3] * (1 - dim) + tb * dim }
end

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

-- Esquina donde se ancla el overlay. La plantilla la lee token a token (cada uno
-- manda sobre su eje), asi que "bottom", "bottom-center" y "center-bottom" son la
-- misma; aqui solo se valida el vocabulario.
local ANCLA = {}
for _, v in ipairs({ "left", "center", "right", "top", "middle", "bottom" }) do
  ANCLA[v] = true
end

local function esquina_valida(pos)
  for t in pos:gmatch("[^-]+") do
    if not ANCLA[t] then return false end
  end
  return true
end

-- Alineacion del contenido del post, dos ejes independientes. Los defaults
-- (centrado horizontal, al medio vertical) no se emiten.
local HALIGN = { "left", "center", "right" }
local VALIGN = { "top", "middle", "bottom" }

local function primera_clase(attr, opciones)
  for _, nombre in ipairs(opciones) do
    if attr and attr.classes:includes(nombre) then return nombre end
  end
end

local function tiene_alguna(attr, nombres)
  return primera_clase(attr, nombres) ~= nil
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
  -- el velo solo tiene sentido sobre una imagen; sobre un pagecolor se cambia el color
  local dim = dim_valor((attr and attr.attributes["background-dim"]) or meta.dim)
  if dim == 0 then dim = nil end
  -- un tint sin dim no se veria: se le da una opacidad media
  local tint = (attr and attr.attributes["background-tint"]) or meta.tint
  if tint and not dim then dim = 0.5 end
  local resolved = resolve_textcolor(tc, pagecolor, aplicar_dim(fondo, dim, tint))
  local o = {}
  if pagecolor then o[#o + 1] = "pagecolor: " .. rgb_lit(pagecolor) end
  if dim and (image or span) then o[#o + 1] = "background-dim: " .. dim end
  if tint and dim and (image or span) then o[#o + 1] = "background-tint: " .. rgb_lit(tint) end
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
  for _, k in ipairs({ "fontsize", "leading", "margin" }) do
    if attr and attr.attributes[k] then o[#o + 1] = k .. ": " .. attr.attributes[k] end
  end
  -- Imagen suelta sobre el post, dibujada fuera del margen (un sello, un logo).
  -- La ruta va como atributo y no por interpolacion de plantilla, asi que no
  -- sufre el escape de _ que hace el writer typst.
  local overlay = (attr and attr.attributes["overlay"]) or meta.overlay
  if tiene_alguna(attr, { "nooverlay", "sin-overlay" }) then overlay = nil end
  if overlay then
    o[#o + 1] = 'overlay-path: "' .. overlay .. '"'
    for _, k in ipairs({ "overlay-width", "overlay-inset", "overlay-x", "overlay-y" }) do
      local v = (attr and attr.attributes[k]) or meta[k]
      if v then o[#o + 1] = k .. ": " .. v end
    end
    local pos = (attr and attr.attributes["overlay-position"]) or meta["overlay-position"]
    -- una esquina mal escrita caeria al centro sin decir nada
    if pos and not esquina_valida(pos) then
      io.stderr:write("[instagram] overlay-position desconocida: " .. pos ..
        " (combinacion de left/center/right con top/middle/bottom)\n")
      pos = nil
    end
    if pos then o[#o + 1] = 'overlay-position: "' .. pos .. '"' end
  end
  -- alineacion en dos ejes; el default (centrado, al medio) no se emite
  local h = primera_clase(attr, HALIGN)
  local v = primera_clase(attr, VALIGN)
  if h then o[#o + 1] = 'halign: "' .. h .. '"' end
  if v then o[#o + 1] = 'valign: "' .. v .. '"' end
  -- cabecera y pie propios de este post (el texto pasa por los shortcodes)
  for _, k in ipairs({ "header", "footer" }) do
    if attr and attr.attributes[k] then
      o[#o + 1] = k .. ": [" .. footer_to_typst(attr.attributes[k]) .. "]"
    end
  end
  -- sin pie: el caso tipico es una franja de panorama, donde la marca y el
  -- numero cortan la foto
  if tiene_alguna(attr, { "noheader", "sin-cabecera" }) then o[#o + 1] = "show-header: false" end
  if tiene_alguna(attr, { "nofooter", "sin-pie" }) then o[#o + 1] = "show-footer: false" end
  if tiene_alguna(attr, { "nonumber", "sin-numero" }) then o[#o + 1] = "show-number: false" end
  return table.concat(o, ", ")
end

-- ---- Traducciones de contenido (corren antes de la particion) ---------------

-- Alineacion de un bloque suelto: ::: {.left} / .center / .right. La del
-- encabezado alinea el post entero, asi que esto es para el caso de un titulo
-- centrado con la bajada a la izquierda, o al reves. Pandoc no deja anotar un
-- parrafo, por eso va como div.
local BLOQUE_ALIGN = { left = "left", center = "center", right = "right",
                       izquierda = "left", centro = "center", derecha = "right" }

local function align_of(classes)
  for _, c in ipairs(classes) do
    if BLOQUE_ALIGN[c] then return BLOQUE_ALIGN[c] end
  end
end

function Div(el)
  -- Las columnas (.column) las alinea el grid padre, no aqui: el filtro corre de
  -- adentro hacia afuera, asi que envolverlas aqui les quitaria la clase y el
  -- padre las dejaria fuera del grid, perdiendo su contenido.
  local al = align_of(el.classes)
  if al and not el.classes:includes("columns") and not el.classes:includes("column") then
    local out = { pandoc.RawBlock("typst", "#align(" .. al .. ")[") }
    for _, b in ipairs(el.content) do out[#out + 1] = b end
    out[#out + 1] = pandoc.RawBlock("typst", "]")
    return out
  end
  -- Columnas: ::: columns con ::: {.column width="50%"} -> #grid
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
    local ca = align_of(cell.classes)
    out[#out + 1] = pandoc.RawBlock("typst", "[")
    if ca then out[#out + 1] = pandoc.RawBlock("typst", "#align(" .. ca .. ")[") end
    for _, b in ipairs(cell.content) do out[#out + 1] = b end
    if ca then out[#out + 1] = pandoc.RawBlock("typst", "]") end
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

-- Sombra difusa de una imagen. Typst no desenfoca, asi que la rasteriza
-- ImageMagick junto al original y typst solo muestra el PNG con alfa. Sobre
-- fondo oscuro una sombra negra no se ve: ahi conviene sombra-color con el
-- color del texto y sin desplazamiento, que funciona como halo.
local sombras = {}

local function existe(ruta)
  local fh = io.open(ruta, "rb")
  if fh then fh:close() end
  return fh ~= nil
end

-- El nombre sale del hash de los parametros mas el contenido del original (como
-- en graphviz.lua), asi la misma sombra reusa el archivo entre compilaciones en
-- vez de dejar una copia nueva, y una imagen que cambia si regenera la suya.
local function hash_corto(spec, color, src)
  local fh = io.open(src, "rb")
  local datos = fh and fh:read("*a") or ""
  if fh then fh:close() end
  return pandoc.utils.sha1(spec .. "\1" .. color .. "\1" .. datos):sub(1, 8)
end

-- src y atributos pueden venir de una imagen suelta o de una pieza de fila, por
-- eso recibe una tabla con esos dos campos y no el elemento pandoc entero.
local function con_sombra(el)
  local at = el.attributes
  local spec = string.format("%sx%s+%s+%s",
    at["sombra-opacidad"] or "70", at["sombra-radio"] or "12",
    at["sombra-dx"] or "0", at["sombra-dy"] or "8")
  -- el hex va con numeral para ImageMagick, que si no lo toma como nombre de
  -- color, no encuentra ninguno y sigue con el suyo por defecto (solo avisa).
  -- En el resto del perfil (pagecolor, textcolor) el numeral es opcional.
  local color = at["sombra-color"] or "black"
  if color:match("^%x%x%x$") or color:match("^%x%x%x%x%x%x$") then color = "#" .. color end

  local clave = el.src .. "\1" .. spec .. "\1" .. color
  if sombras[clave] then return sombras[clave] end

  local salida = el.src:gsub("%.%w+$", "")
    .. "-sombra-" .. hash_corto(spec, color, el.src) .. ".png"
  if not existe(salida) then
    local ok = pcall(pandoc.pipe, "convert", {
      el.src, "(", "+clone", "-background", color, "-shadow", spec, ")",
      "+swap", "-background", "none", "-layers", "merge", "+repage", salida,
    }, "")
    if not ok then
      io.stderr:write("[instagram] no pude generar la sombra de " .. el.src .. "\n")
      return el.src
    end
  end
  sombras[clave] = salida
  return salida
end

-- La sombra se pide en la imagen o en el div que la contiene (una fila entera
-- con .sombra), y los parametros del div valen de default para sus imagenes.
local function pide_sombra(el)
  return has_class(el, "sombra") or has_class(el, "shadow")
end

local function sombra_heredada(img, div)
  local at = {}
  for k, v in pairs(div and div.attributes or {}) do at[k] = v end
  for k, v in pairs(img.attributes) do at[k] = v end
  return con_sombra({ src = img.src, attributes = at })
end

-- ---- Filas de imagenes (primera pasada, ver el return del final) ------------

-- ::: row / ::: fila -> #row(...). Las imagenes de adentro se pasan como piezas
-- en vez de emitirse sueltas, asi que este handler corre en una pasada previa,
-- antes de que Image las convierta.
local function row_piece(img, div)
  -- el % del width/height de la imagen escala esa pieza dentro de la fila
  local pct = (img.attributes["height"] or img.attributes["width"] or "")
    :match("^(%d+%.?%d*)%%$")
  local circulo = has_class(img, "circle")
  local src = img.src
  -- el recorte circular lo hace la plantilla sobre la imagen ya compuesta, asi
  -- que la sombra quedaria cortada adentro del circulo
  if (pide_sombra(img) or (div and pide_sombra(div))) and not circulo then
    src = sombra_heredada(img, div)
  end
  return string.format('(path: "%s", circle: %s, factor: %s)',
    src, circulo and "true" or "false",
    pct and tostring(tonumber(pct) / 100) or "none")
end

local function row_div(el)
  if not (el.classes:includes("row") or el.classes:includes("fila")) then return nil end
  local pieces = {}
  el:walk({ Image = function(img) pieces[#pieces + 1] = row_piece(img, el) end })
  if #pieces == 0 then return nil end
  local opts = { "gap: " .. (el.attributes["gap"] or "0.4em") }
  -- height iguala las alturas; sin height, las columnas reparten el ancho
  if el.attributes["height"] then opts[#opts + 1] = "height: " .. el.attributes["height"] end
  if el.attributes["width"] then opts[#opts + 1] = "width: " .. el.attributes["width"] end
  return pandoc.RawBlock("typst",
    "#row(" .. table.concat(opts, ", ") .. ", " .. table.concat(pieces, ", ") .. ")")
end

-- Alineacion horizontal de una imagen: centrada salvo que traiga .left o
-- .right, para que pueda acompanar a un post con {.left}.
local function img_align(el)
  if has_class(el, "left") then return "left" end
  if has_class(el, "right") then return "right" end
  return "center"
end

-- Imagenes: ancho/alto en % y recorte circular con .circle
function Image(el)
  local src = el.src
  local al = img_align(el)
  if pide_sombra(el) then
    -- el recorte circular lo hace typst sobre la imagen ya compuesta, asi que
    -- la sombra quedaria cortada adentro del circulo
    if has_class(el, "circle") then
      io.stderr:write("[instagram] .sombra no se combina con .circle: " .. src .. "\n")
    else
      src = con_sombra(el)
    end
  end
  if has_class(el, "circle") then
    local size = el.attributes["width"] or "50%"
    local pct = size:match("^(%d+%.?%d*)%%$")
    if pct then
      local f = tonumber(pct) / 100
      return pandoc.RawInline("typst",
        '#align(' .. al .. ')[#layout(s => box(clip: true, radius: 50%, width: s.width * ' .. f ..
        ', height: s.width * ' .. f .. ', image("' .. src .. '", width: 100%, height: 100%, fit: "cover")))]')
    end
    return pandoc.RawInline("typst",
      '#align(' .. al .. ')[#box(clip: true, radius: 50%, width: ' .. size .. ', height: ' .. size ..
      ', image("' .. src .. '", width: 100%, height: 100%, fit: "cover"))]')
  end
  local opts = {}
  if el.attributes["width"] then opts[#opts + 1] = "width: " .. el.attributes["width"] end
  if el.attributes["height"] then opts[#opts + 1] = "height: " .. el.attributes["height"] end
  local optstr = #opts > 0 and (", " .. table.concat(opts, ", ")) or ""
  return pandoc.RawInline("typst", '#align(' .. al .. ')[#image("' .. src .. '"' .. optstr .. ')]')
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
  meta.dim = doc.meta["background-dim"] and utils.stringify(doc.meta["background-dim"]) or nil
  meta.tint = doc.meta["background-tint"] and utils.stringify(doc.meta["background-tint"]) or nil
  meta.w = (doc.meta.width and to_cm(utils.stringify(doc.meta.width))) or meta.w
  meta.h = (doc.meta.height and to_cm(utils.stringify(doc.meta.height))) or meta.h
  -- overlay comun a todos los posts (una marca en la esquina); un post lo saca
  -- con .nooverlay o lo cambia con su propio atributo
  for _, k in ipairs({ "overlay", "overlay-width", "overlay-position",
                       "overlay-inset", "overlay-x", "overlay-y" }) do
    meta[k] = doc.meta[k] and utils.stringify(doc.meta[k]) or nil
  end

  -- cabecera y pie: resuelven shortcodes de iconos a typst crudo
  for _, k in ipairs({ "header", "footer" }) do
    if doc.meta[k] then
      doc.meta[k] = pandoc.MetaInlines({
        pandoc.RawInline("typst", meta_to_typst(doc.meta[k])),
      })
    end
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

  -- 3) emitir. Cada post deja una marca invisible con su numero y la pagina
  -- donde empieza; `panduck build` la lee con `typst query` para avisar de los
  -- posts que no cupieron (typst los parte en dos paginas sin decir nada).
  local out = {}
  for j, p in ipairs(posts) do
    out[#out + 1] = pandoc.RawBlock("typst", "#post(" .. post_opts(p.attr, spans[j]) .. ")[")
    out[#out + 1] = pandoc.RawBlock("typst",
      "#context [#metadata((n: " .. j .. ", p: counter(page).get().first(), " ..
      "t: counter(page).final().first()))<panduck-page>]")
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
