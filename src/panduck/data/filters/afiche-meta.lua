-- Prepara la metadata del perfil `afiche`: normaliza la lista de presentadores y
-- resuelve el logo de la agencia que panduck trae vendorizado.
--
-- Los presentadores se escriben con `presenters:` (lista de `- name:` con
-- `affiliation:` opcional, string o lista) y, si no estan, se toman del
-- `authors:` de los perfiles de revista, asi el mismo head sirve en los dos
-- lados. Un elemento que sea un string suelto vale como nombre.
--
-- `anid: true` usa el logo MinCiencia + ANID que vive en data/img/: typst
-- resuelve las rutas contra el directorio del documento, asi que el archivo se
-- copia al lado del .typ en vez de apuntar al data-dir de panduck. Con una ruta
-- (`anid: milogo.png`) se usa esa y no se copia nada.

local stringify = pandoc.utils.stringify
local mtype = pandoc.utils.type

local LOGO_LOCAL = "_panduck-anid.png"

local function normaliza(lista)
  local out = pandoc.List()
  for _, item in ipairs(lista) do
    -- un objeto es una tabla; un nombre suelto llega como Inlines
    local persona = mtype(item) == "table" and item or { name = item }
    -- afiliacion como lista: se junta en una linea, que es como cabe en un afiche
    if persona.affiliation and mtype(persona.affiliation) == "List" then
      local partes = {}
      for _, a in ipairs(persona.affiliation) do partes[#partes + 1] = stringify(a) end
      persona.affiliation = table.concat(partes, " · ")
    end
    out:insert(persona)
  end
  return out
end

-- copia un asset de panduck junto al documento; devuelve su nombre local
local function copia_asset(nombre, destino)
  -- PANDOC_SCRIPT_FILE es <data-dir>/filters/afiche-meta.lua
  local dir = PANDOC_SCRIPT_FILE:match("(.*)[/\\]") or "."
  local origen = dir .. "/../img/" .. nombre
  local entrada = io.open(origen, "rb")
  if not entrada then
    io.stderr:write("[panduck] aviso: no encontre el logo " .. origen .. "\n")
    return nil
  end
  local datos = entrada:read("a")
  entrada:close()
  local salida = io.open(destino, "wb")
  if not salida then
    io.stderr:write("[panduck] aviso: no pude escribir " .. destino .. "\n")
    return nil
  end
  salida:write(datos)
  salida:close()
  return destino
end

function Meta(m)
  if m.presenters then
    m.presenters = normaliza(m.presenters)
  elseif m.authors then
    m.presenters = normaliza(m.authors)
  end
  if m.anid == true then
    m.anid = copia_asset("anid.png", LOGO_LOCAL)
  end
  return m
end
