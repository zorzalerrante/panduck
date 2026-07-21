-- Arregla nombres de simbolo matematico que el writer typst de pandoc 3.7 emite
-- pero que typst 0.15 ya no reconoce. pandoc traduce ciertos comandos LaTeX a
-- nombres viejos de typst; typst los renombro y falla con "unknown symbol
-- modifier" / "unknown variable". Se detecta el comando LaTeX en el Math, se
-- serializa la expresion a typst y se reemplazan los nombres rotos por los
-- caracteres correctos, devolviendo un RawInline typst.
--
--   \langle \rangle -> angle.l angle.r  ->  ⟨ ⟩
--   \cap            -> sect              ->  inter
--   \lceil \rceil   -> ceil.l ceil.r     ->  ⌈ ⌉
--   \lfloor \rfloor -> floor.l floor.r   ->  ⌊ ⌋
--
-- No se puede arreglar desde el markdown: pandoc normaliza tambien el unicode de
-- vuelta a esos nombres. Corre en todos los perfiles typst (slides, instagram,
-- tufte, tufte-book). El pre-chequeo por el comando LaTeX evita serializar cada
-- ecuacion: solo toca las que traen un simbolo problematico.

local SOSPECHOSOS = {
  "\\langle", "\\rangle", "\\cap", "\\lceil", "\\rceil", "\\lfloor", "\\rfloor",
}

local ARREGLOS = {
  ["angle%.l"] = "⟨", ["angle%.r"] = "⟩",
  ["%f[%w]sect%f[%W]"] = "inter",
  ["ceil%.l"] = "⌈", ["ceil%.r"] = "⌉",
  ["floor%.l"] = "⌊", ["floor%.r"] = "⌋",
}

function Math(el)
  local necesita = false
  for _, s in ipairs(SOSPECHOSOS) do
    if el.text:find(s, 1, true) then necesita = true break end
  end
  if not necesita then return nil end
  local typ = pandoc.write(pandoc.Pandoc({ pandoc.Plain({ el }) }), "typst")
  for patron, reemplazo in pairs(ARREGLOS) do
    typ = typ:gsub(patron, reemplazo)
  end
  return pandoc.RawInline("typst", (typ:gsub("%s+$", "")))
end
