-- Diagramas de Graphviz escritos en el documento: un bloque de codigo con clase
-- .dot o .graphviz se rasteriza con `dot` y se inserta como imagen, en vez de
-- mantener el .dot aparte y una regla en el Makefile.
--
--     ```{.dot width="60%"}
--     digraph { a -> b }
--     ```
--
--     ```{#fig:flujo .dot caption="Flujo de datos"}
--     digraph { a -> b }
--     ```
--
-- Con `caption` sale como figura (pandoc-crossref la numera y `[-@fig:flujo]` la
-- referencia); sin pie, como imagen centrada. Atributos: `width` (80% por
-- defecto), `height`, `engine` (dot, neato, circo, fdp, sfdp, twopi, osage) y
-- `caption`.
--
-- El diagrama toma la tipografia y los colores del documento sin declararlos: el
-- filtro inyecta al inicio del grafo los defaults de graph/node/edge (fontname,
-- fondo transparente y el estilo base de nodo). Como en DOT los defaults son
-- posicionales, un `node [...]` escrito despues los sobreescribe.
--
-- Tres estilos de nodo, que se marcan con `class` (atributo valido de graphviz,
-- que solo usa la salida SVG, asi que el fuente sigue siendo DOT compilable a
-- mano; sin el filtro pierde el color, no la validez):
--
--     a                        -- base: papel de fondo, borde y texto de tinta
--     b [class="strong"]       -- tinta de fondo, texto contrastante
--     c [class="accent"]       -- color destacado de fondo, texto contrastante
--
-- Alias en castellano: `base`, `fuerte`, `acento`. El color del texto sale de la
-- luminancia del fondo (misma regla que instagram-posts.lua, duplicada aca
-- porque un filtro resuelto desde el data-dir no puede `require` un modulo); con
-- un nombre de color de graphviz (steelblue) no hay hex que medir y el texto
-- queda oscuro, asi que para un fondo oscuro conviene dar el color en hex.
--
-- El formato de la imagen sale del writer, no se elige a mano: typst y html leen
-- SVG, LaTeX necesita un PDF (un .svg lo mandaria a \includesvg, que exige el
-- paquete svg mas inkscape) y docx un PNG. Por eso el filtro corre en todos los
-- perfiles y no solo en los typst.
--
-- El archivo se llama por el hash del contenido (`_dot_<sha1>.<ext>`), asi que
-- dos compilaciones seguidas no vuelven a llamar a `dot` y el nombre no colisiona
-- entre diagramas. El hash se calcula sobre el DOT ya expandido, de modo que
-- cambiar la paleta o la tipografia en el head regenere la imagen. Si `dot` no
-- esta instalado se avisa y el bloque de codigo se deja tal cual, en vez de
-- romper la compilacion.
--
-- Metadata (todo opcional): `dot-font` (default: `mainfont`), `dot-fg` (tinta),
-- `dot-bg` (papel) y `dot-accent` (destacado). Los perfiles con tema propio
-- seleccionan su paleta con `dot-theme` en su YAML de defaults; ahi no pueden ir
-- los colores, porque el `metadata:` de un defaults gana sobre el front matter y
-- el documento no podria sobreescribirlos (el nombre del tema si sirve, porque
-- los colores sueltos del head tienen prioridad sobre el).

local FORMATO = {
  typst = "svg", html = "svg", html4 = "svg", html5 = "svg", revealjs = "svg",
  -- los writers de markdown (el perfil `hugo` usa gfm) terminan en una pagina
  -- web, asi que svg como en html
  gfm = "svg", markdown = "svg", commonmark = "svg", commonmark_x = "svg",
  markdown_strict = "svg", markdown_mmd = "svg", markdown_phpextra = "svg",
  latex = "pdf", beamer = "pdf", context = "pdf",
  docx = "png", odt = "png", pptx = "png", rtf = "png",
}

local MOTORES = {
  dot = true, neato = true, circo = true, fdp = true, sfdp = true,
  twopi = true, osage = true, patchwork = true,
}

-- ---- Estilos de nodo --------------------------------------------------------

local TEMAS = {
  papel  = { fg = "#1a1a1a", bg = "#ffffff", accent = "#CF3889" },
  slides = { fg = "#0A0E50", bg = "#ffffff", accent = "#CF3889" },
}

local CLARO, OSCURO = "#ffffff", "#1a1a1a"

-- Fondo del lienzo cuando el diagrama va como png a una pagina web: un blanco
-- calido que no deslumbra en modo oscuro ni corta contra un papel crema.
local CANVAS_WEB = "#faf8f5"

-- nombre de clase (con sus alias) -> estilo
local CLASES = {
  base = "base", strong = "strong", accent = "accent",
  fuerte = "strong", acento = "accent",
}

local paleta, fuente = TEMAS.papel, nil
local formato_meta, dpi_meta, canvas = nil, nil, nil

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

-- color de texto legible sobre `fondo`
local function contraste(fondo)
  local r, g, b = hex_to_rgb(fondo)
  if not r then return OSCURO end
  if luminance(r, g, b) > 0.5 then return OSCURO else return CLARO end
end

local function meta_str(meta, clave)
  local v = meta[clave]
  if v == nil then return nil end
  local s = pandoc.utils.stringify(v)
  if s == "" then return nil end
  return s
end

-- `#` abre un comentario en YAML, asi que un color va entre comillas ("#0A0E50")
-- o sin el numeral (0A0E50); los nombres de color de graphviz (steelblue, gray20)
-- pasan tal cual. Un hex de puros digitos sin comillas se pierde antes de llegar
-- aca (YAML lo lee como numero: `004400` queda en `4400`), asi que lo que no
-- parece un color se avisa y cae al tema, en vez de pasarle basura a graphviz.
local function color(clave, v)
  if v == nil then return nil end
  if v:match("^#%x%x%x%x%x%x$") or v:match("^%a[%w]*$") then return v end
  if v:match("^%x%x%x%x%x%x$") then return "#" .. v end
  io.stderr:write("[panduck] aviso: " .. clave .. ": " .. v .. " no parece un color; " ..
    "escribelo entre comillas en el head (\"#004400\"). Se usa el del tema\n")
  return nil
end

local function leer_meta(meta)
  local tema = TEMAS[meta_str(meta, "dot-theme") or ""] or TEMAS.papel
  paleta = {
    fg = color("dot-fg", meta_str(meta, "dot-fg")) or tema.fg,
    bg = color("dot-bg", meta_str(meta, "dot-bg")) or tema.bg,
    accent = color("dot-accent", meta_str(meta, "dot-accent")) or tema.accent,
  }
  fuente = meta_str(meta, "dot-font") or meta_str(meta, "mainfont")
  formato_meta = meta_str(meta, "dot-format")
  dpi_meta = meta_str(meta, "dot-dpi")
  canvas = color("dot-canvas", meta_str(meta, "dot-canvas"))
end

local function atributos(estilo)
  local fondo, borde = paleta.bg, paleta.fg
  if estilo == "strong" then fondo, borde = paleta.fg, paleta.fg
  elseif estilo == "accent" then fondo, borde = paleta.accent, paleta.accent end
  local texto = estilo == "base" and paleta.fg or contraste(fondo)
  return string.format('fillcolor="%s", color="%s", fontcolor="%s"', fondo, borde, texto)
end

-- El lienzo va transparente, para que el diagrama se apoye en el papel del
-- documento. `dot-canvas` le pone un fondo propio, que es lo que hace falta
-- cuando la imagen tiene que leerse sobre cualquier fondo (una pagina con modo
-- oscuro, donde un diagrama de tinta oscura y fondo transparente desaparece).
-- Con fondo hay que separar el dibujo del borde, si no queda pegado.
local function preambulo(canvas_usado)
  local fn = fuente and string.format('fontname="%s", ', fuente) or ""
  -- el aire alrededor del dibujo va con `pad` y no con `margin`: el margen de
  -- graphviz queda FUERA del area que pinta bgcolor, asi que la imagen sale con
  -- un halo transparente y se pierde el fondo justo en el borde
  local fondo = canvas_usado
    and string.format('bgcolor="%s", pad="0.2"', canvas_usado)
    or 'bgcolor="transparent"'
  return string.format(
    '\n  graph [%s%s]\n  node [%sstyle="filled", %s]\n  edge [%scolor="%s", fontcolor="%s"]',
    fn, fondo, fn, atributos("base"), fn, paleta.fg, paleta.fg)
end

-- expande las clases a atributos concretos e inyecta los defaults del documento
local function expandir(texto, canvas_usado)
  local function estilo(nombre)
    local canon = CLASES[nombre:lower()]
    if canon then return atributos(canon) end
    return nil  -- clase ajena: se deja tal cual (sigue siendo `class` de graphviz)
  end
  texto = texto:gsub('class%s*=%s*"%s*([%w_%-]+)%s*"', estilo)
  texto = texto:gsub('class%s*=%s*([%w_%-]+)', estilo)
  local i = texto:find("{", 1, true)
  if not i then return texto end  -- no parece un grafo; que `dot` de el error
  return texto:sub(1, i) .. preambulo(canvas_usado) .. texto:sub(i + 1)
end

-- ---- Conversion a mermaid ---------------------------------------------------

-- En un sitio estatico conviene mermaid en vez de una imagen: lo dibuja el
-- navegador, asi que el diagrama hereda la tipografia y el modo claro/oscuro del
-- sitio, el texto queda seleccionable y no hay archivo que copiar al bundle.
--
-- La traduccion cubre el subconjunto de DOT que documenta este filtro (grafo
-- dirigido o no, `rankdir`, nodos con `label` y `class`, cadenas de aristas) y
-- **cae a la imagen** en cuanto aparece algo que mermaid no expresa igual
-- (subgrafos, defaults posicionales de node/edge, formas, atributos de arista).
-- Se prefirio esto a una herramienta externa (las varias `dot2mermaid` que
-- circulan son paquetes npm que traducen solo la topologia): habria que sumar
-- node como dependencia y de todas formas escribir el `classDef`, que es lo que
-- mantiene al diagrama en la paleta del documento.
--
-- Solo los nodos con `class` reciben `classDef`: el resto queda con el tema de
-- mermaid, que en un sitio con modo oscuro es justamente lo que se busca.

local DIRECCION = { TB = "TB", BT = "BT", LR = "LR", RL = "RL" }
local ATRIBUTOS_OK = { label = true, class = true }

-- palabras del lenguaje: un nodo llamado `end` o `class` no rompe la
-- compilacion, rompe el dibujo en el navegador, asi que va con id numerado
local RESERVADAS = {
  ["end"] = true, graph = true, subgraph = true, class = true, classdef = true,
  click = true, style = true, linkstyle = true, flowchart = true, direction = true,
}

-- ids de mermaid: los que ya sirven se conservan (el fuente se lee mejor) y el
-- resto se numera, manteniendo el nombre original como etiqueta
local function id_mermaid(nombre, ids, n, renombrados)
  if ids[nombre] then return ids[nombre], n end
  if nombre:match("^[%a_][%w_]*$") and not RESERVADAS[nombre:lower()] then
    ids[nombre] = nombre
  else
    n = n + 1
    ids[nombre] = "n" .. n
    -- sin etiqueta propia el nodo se dibujaria con el id inventado
    renombrados[ids[nombre]] = nombre
  end
  return ids[nombre], n
end

local function etiqueta(texto)
  return (texto:gsub('\\n', "<br>"):gsub('"', "#quot;"))
end

-- lista de pares clave=valor; devuelve nil si hay alguna clave que no traducimos
local function atributos_de(s)
  local out = {}
  for clave, valor in s:gmatch('([%w_]+)%s*=%s*"([^"]*)"') do
    if not ATRIBUTOS_OK[clave] then return nil, clave end
    out[clave] = valor
  end
  for clave, valor in s:gmatch('([%w_]+)%s*=%s*([%w_%-%.]+)') do
    if out[clave] == nil then
      if not ATRIBUTOS_OK[clave] then return nil, clave end
      out[clave] = valor
    end
  end
  return out
end

local function a_mermaid(texto)
  texto = texto:gsub("/%*.-%*/", " "):gsub("//[^\n]*", ""):gsub("\n%s*#[^\n]*", "")
  local tipo, cuerpo = texto:match("^%s*(%a+)%s*[%w_\"]*%s*{(.*)}%s*$")
  if not tipo then return nil, "no parece un grafo" end
  tipo = tipo:lower()
  if tipo ~= "digraph" and tipo ~= "graph" then return nil, tipo end
  local flecha = tipo == "digraph" and "-->" or "---"

  local dir, nodos, aristas, clases, ids, n = "TB", {}, {}, {}, {}, 0
  local renombrados, con_label = {}, {}
  for sentencia in (cuerpo .. ";"):gmatch("([^;\n]+)") do
    local s = sentencia:gsub("^%s+", ""):gsub("%s+$", "")
    if s ~= "" then
      local clave, valor = s:match('^([%w_]+)%s*=%s*"?([%w_]+)"?$')
      if clave and clave:lower() == "rankdir" then
        dir = DIRECCION[valor:upper()] or "TB"
      elseif clave then
        return nil, clave  -- otro atributo de grafo (bgcolor, splines, ...)
      elseif s:match("^%s*subgraph") or s:match("^%s*[Nn]ode%s*%[")
          or s:match("^%s*[Ee]dge%s*%[") or s:match("^%s*[Gg]raph%s*%[") then
        return nil, s:match("^%s*(%a+)")  -- subgrafos y defaults posicionales
      elseif s:find("%-[->]") then
        local cadena, attrs = s:match("^([^%[]+)(.*)$")
        if attrs ~= "" then
          local _, sobra = atributos_de(attrs)
          if sobra then return nil, sobra end
        end
        local previo
        for parte in cadena:gmatch("[^%-<>]+") do
          local nombre = parte:gsub('"', ""):gsub("^%s+", ""):gsub("%s+$", "")
          if nombre ~= "" then
            local id; id, n = id_mermaid(nombre, ids, n, renombrados)
            if previo then aristas[#aristas + 1] = previo .. " " .. flecha .. " " .. id end
            previo = id
          end
        end
      else
        local nombre, attrs = s:match('^([%w_"][%w_%s%-%."]*)%s*%[(.*)%]%s*$')
        if not nombre then
          nombre = s:match('^([%w_"][%w_%-%."]*)$')
          if not nombre then return nil, s:sub(1, 20) end
          attrs = ""
        end
        nombre = nombre:gsub('"', ""):gsub("%s+$", "")
        local at, sobra = atributos_de(attrs)
        if not at then return nil, sobra end
        local id; id, n = id_mermaid(nombre, ids, n, renombrados)
        if at.label then
          nodos[#nodos + 1] = id .. '["' .. etiqueta(at.label) .. '"]'
          con_label[id] = true
        end
        if at.class then
          local canon = CLASES[at.class:lower()]
          if canon and canon ~= "base" then clases[#clases + 1] = "class " .. id .. " " .. canon end
        end
      end
    end
  end
  if #aristas == 0 and #nodos == 0 then return nil, "grafo vacio" end
  for id, nombre in pairs(renombrados) do
    if not con_label[id] then
      table.insert(nodos, 1, id .. '["' .. etiqueta(nombre) .. '"]')
    end
  end

  local out = { "flowchart " .. dir }
  for _, l in ipairs(nodos) do out[#out + 1] = "  " .. l end
  for _, l in ipairs(aristas) do out[#out + 1] = "  " .. l end
  if #clases > 0 then
    for _, estilo in ipairs({ "strong", "accent" }) do
      local fondo = estilo == "strong" and paleta.fg or paleta.accent
      out[#out + 1] = string.format("  classDef %s fill:%s,stroke:%s,color:%s",
        estilo, fondo, fondo, contraste(fondo))
    end
    for _, l in ipairs(clases) do out[#out + 1] = "  " .. l end
  end
  return table.concat(out, "\n")
end

-- ---- Diagramas --------------------------------------------------------------

local aviso_dado = false

local function existe(ruta)
  local fh = io.open(ruta, "rb")
  if fh then fh:close() end
  return fh ~= nil
end

-- Formato de salida del diagrama. `auto` (el default) es la imagen que pida el
-- writer, salvo en los writers de markdown, donde va un PNG a 200 dpi con fondo:
-- el destino es una pagina que puede tener modo oscuro, y ahi un diagrama de
-- tinta oscura sobre fondo transparente desaparece. Se fija con `dot-format` en
-- el head o `format=` en el bloque; `mermaid` lo traduce para que lo dibuje el
-- navegador (ver "Conversion a mermaid": hereda el tema del sitio, pero solo
-- cubre el subconjunto traducible).
local VALIDOS = { auto = true, mermaid = true, svg = true, png = true, pdf = true }

local function es_web()
  return FORMAT == "gfm" or FORMAT:find("markdown") ~= nil or FORMAT:find("html") ~= nil
end

-- devuelve el formato y si lo pidio el documento (para el fondo por defecto)
local function formato_de(el)
  local pedido = el.attributes["format"] or formato_meta or "auto"
  if not VALIDOS[pedido] then
    io.stderr:write("[panduck] aviso: formato de diagrama desconocido: " .. pedido ..
      " (mermaid, svg, png, pdf); se usa el del writer\n")
    pedido = "auto"
  end
  local del_writer = FORMATO[FORMAT] or "png"
  if pedido == "auto" then
    if FORMAT == "gfm" or FORMAT:find("markdown") then return "png", false end
    return del_writer, false
  end
  -- LaTeX no incluye SVG sin el paquete `svg` mas inkscape, y typst no lee PDF:
  -- pedir un formato que el writer no puede usar romperia la compilacion
  if pedido ~= "mermaid" and pedido ~= del_writer
      and (del_writer == "pdf" or pedido == "pdf") and pedido ~= "png" then
    io.stderr:write("[panduck] aviso: " .. FORMAT .. " no puede usar " .. pedido ..
      "; el diagrama va como " .. del_writer .. "\n")
    return del_writer, true
  end
  return pedido, true
end

local function diagrama(el)
  if not (el.classes:includes("dot") or el.classes:includes("graphviz")) then return nil end
  local formato, explicito = formato_de(el)
  if formato == "mermaid" then
    local mmd, motivo = a_mermaid(el.text)
    if mmd then
      local bloque = pandoc.CodeBlock(mmd, pandoc.Attr("", { "mermaid" }))
      local pie = el.attributes["caption"]
      if not pie then return bloque end
      -- mermaid no lleva pie propio; va como figura para que crossref la numere
      return pandoc.Figure(bloque,
        { long = pandoc.Blocks({ pandoc.Plain(pandoc.utils.blocks_to_inlines(
            pandoc.read(pie, "markdown").blocks)) }) },
        pandoc.Attr(el.identifier))
    end
    io.stderr:write("[panduck] aviso: el diagrama usa `" .. tostring(motivo) ..
      "`, que no se traduce a mermaid; va como imagen\n")
  end
  local ext = formato == "mermaid" and (FORMATO[FORMAT] or "png") or formato
  local motor = el.attributes["engine"] or "dot"
  if not MOTORES[motor] then motor = "dot" end
  -- el fondo por defecto es para el png que termina en una pagina (o el que se
  -- pidio a mano): ahi la imagen tiene que leerse sobre cualquier tema. En el
  -- resto (svg de un PDF, png de un docx) el lienzo sigue transparente, apoyado
  -- en el papel del documento.
  local fondo = canvas
  if not fondo and ext == "png" and (explicito or es_web()) then fondo = CANVAS_WEB end
  local dot = expandir(el.text, fondo)
  -- graphviz rasteriza a la resolucion que le den; el default de png (96 dpi) se
  -- ve borroso en pantallas densas, asi que aca sube a 200
  local dpi = ext == "png" and (el.attributes["dpi"] or dpi_meta or "200") or nil
  local args = { "-T" .. ext }
  if dpi then args[#args + 1] = "-Gdpi=" .. dpi end
  local nombre = "_dot_" .. pandoc.utils.sha1(
    motor .. "\1" .. ext .. "\1" .. tostring(dpi) .. "\1" .. dot):sub(1, 8) .. "." .. ext

  if not existe(nombre) then
    local ok, salida = pcall(pandoc.pipe, motor, args, dot)
    if not ok then
      if not aviso_dado then
        aviso_dado = true
        io.stderr:write("[panduck] aviso: no se pudo ejecutar `" .. motor ..
          "` (graphviz); los bloques .dot quedan como codigo\n")
      end
      return nil
    end
    local fh = io.open(nombre, "wb")
    fh:write(salida)
    fh:close()
  end

  local atr = { width = el.attributes["width"] or "80%" }
  if el.attributes["height"] then atr.height = el.attributes["height"] end
  local img = pandoc.Image({}, nombre, "", pandoc.Attr("", {}, atr))
  local pie = el.attributes["caption"]
  if pie then
    return pandoc.Figure(
      pandoc.Plain({ img }),
      { long = pandoc.Blocks({ pandoc.Plain(pandoc.utils.blocks_to_inlines(
          pandoc.read(pie, "markdown").blocks)) }) },
      pandoc.Attr(el.identifier))
  end
  -- sin pie no hay figura que numerar; se centra con el vocabulario de
  -- fonts-and-alignment, que corre despues y sirve en typst y en latex
  return pandoc.Div({ pandoc.Plain({ img }) },
    pandoc.Attr(el.identifier, { "pfa-align-center" }))
end

-- dos pasadas: en un mismo filtro Meta corre despues de los bloques, y la
-- paleta tiene que estar leida antes de expandir el primer diagrama
return { { Meta = leer_meta }, { CodeBlock = diagrama } }
