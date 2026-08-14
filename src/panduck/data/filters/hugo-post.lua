-- Adapta la salida markdown de pandoc a lo que espera Hugo (Goldmark).
-- Corre despues de citeproc, asi que trabaja sobre las citas ya renderizadas.
--
--   * bibliografia: el div `#refs` de citeproc pasa a una lista, en vez de los
--     divs anidados que emite gfm (que dependen de CSS del tema para el sangrado)
--   * figuras: `![alt](img "pie")` en vez del <figure> HTML de pandoc, porque
--     Hugo tiene un render hook para imagenes que arma figure+figcaption solo
--     cuando la imagen trae title
--   * matematica: gfm escribe la sintaxis de GitHub ($`x`$ y un bloque ```math)
--     que Goldmark no renderiza; se emite con los delimitadores de su extension
--     passthrough (\(...\) inline, $$...$$ en bloque)
--   * spans y divs sin equivalente en markdown se desenvuelven, para no dejar
--     <span class="..."> en el post
--   * front matter: title y tags como escalares planos, listos para YAML

local utils = pandoc.utils

-- ---- Front matter -----------------------------------------------------------

-- El front matter es YAML, no markdown: un valor va como texto plano y con las
-- comillas escapadas, para que un titulo con comillas no rompa el bloque.
local function yaml_escape(s)
  return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

local function plano(v)
  return pandoc.MetaString(yaml_escape(utils.stringify(v)))
end

function Meta(meta)
  if meta.title then meta.title = plano(meta.title) end
  if meta.thumbnail then meta.thumbnail = plano(meta.thumbnail) end
  -- las etiquetas del post salen de `tags:` y, si no esta, de las `keywords:`
  -- del documento academico, que es el mismo campo con otro nombre
  local tags = meta.tags or meta.keywords
  if tags then
    local out = pandoc.MetaList({})
    for _, t in ipairs(tags) do out:insert(plano(t)) end
    meta.tags = out
  end
  -- la fecha puede venir como fecha de YAML o como texto; Hugo quiere ISO
  if meta.date then meta.date = pandoc.MetaString(utils.stringify(meta.date)) end
  return meta
end

-- ---- Bibliografia -----------------------------------------------------------

local function es_refs(el)
  return el.identifier == "refs" or el.classes:includes("csl-bib-body")
end

-- Cada `.csl-entry` es un item de la lista. Se conserva el orden que dio el CSL
-- (alfabetico o de aparicion, segun el estilo).
local function refs_a_lista(el)
  local items = {}
  for _, child in ipairs(el.content) do
    if child.t == "Div" then
      items[#items + 1] = child.content
    else
      items[#items + 1] = pandoc.Blocks({ child })
    end
  end
  if #items == 0 then return {} end
  return { pandoc.BulletList(items) }
end

function Div(el)
  if es_refs(el) then return refs_a_lista(el) end
  -- un div sin significado en markdown se desenvuelve: gfm lo emitiria como
  -- <div class="..."> y en el post no aporta nada
  return el.content
end

function Span(el)
  return el.content
end

-- Con `link-citations: true` citeproc enlaza cada cita a su entrada por el id
-- del div (`#ref-clave`). La bibliografia va como lista y no lleva esos ids, asi
-- que el enlace apuntaria a un ancla inexistente: queda solo el texto de la
-- cita. Los demas enlaces internos del documento no se tocan.
function Link(el)
  if el.target:match("^#ref%-") then return el.content end
end

-- ---- Matematica -------------------------------------------------------------

-- Delimitadores de la extension passthrough de Goldmark. gfm emitiria la
-- sintaxis de GitHub, que Hugo no renderiza.
function Math(el)
  if el.mathtype == "InlineMath" then
    return pandoc.RawInline("html", "\\(" .. el.text .. "\\)")
  end
  return pandoc.RawInline("html", "$$" .. el.text .. "$$")
end

-- ---- Figuras ----------------------------------------------------------------

-- El pie viaja como title de la imagen y puede llevar markdown (el hook del
-- sitio lo pasa por markdownify), asi que se escribe con el writer en vez de
-- aplanarlo a texto. Sin `wrap = "none"` un pie largo sale partido en varias
-- lineas dentro del atributo title, que es una sola cadena entre comillas.
local SIN_CORTES = pandoc.WriterOptions({ wrap_text = "wrap-none" })

local function inlines_a_markdown(inls)
  local ok, md = pcall(function()
    return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inls) }), "gfm", SIN_CORTES)
  end)
  return ok and (md:gsub("%s+$", "")) or utils.stringify(inls)
end

-- Sin atributos: un width/height sale como <img style="..."> y el id como
-- atributo HTML, que en un post no sirven de ancla. El tamano lo decide el CSS.
function Image(el)
  return pandoc.Image(el.caption, el.src, el.title)
end

function Figure(el)
  local pie = el.caption and el.caption.long
  local inls, texto = pandoc.Inlines({}), ""
  if pie and #pie > 0 then
    for _, b in ipairs(pie) do
      if b.content then for _, i in ipairs(b.content) do inls:insert(i) end end
    end
    texto = inlines_a_markdown(inls)
  end
  -- el contenido de una Figure de pandoc es un Plain con la imagen
  local imgs = pandoc.Inlines({})
  pandoc.walk_block(el, { Image = function(img)
    imgs:insert(pandoc.Image(img.caption, img.src, texto ~= "" and texto or img.title))
  end })
  -- una figura sin imagen es un diagrama mermaid (o cualquier bloque con pie):
  -- el pie no cabe en un title, asi que va como parrafo debajo, igual que el de
  -- las tablas
  if #imgs == 0 then
    local out = pandoc.Blocks({})
    for _, b in ipairs(el.content) do out:insert(b) end
    if texto ~= "" then out:insert(pandoc.Para(inls)) end
    return out
  end
  return pandoc.Para(imgs)
end
