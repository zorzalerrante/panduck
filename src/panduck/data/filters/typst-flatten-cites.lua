-- Tras citeproc, aplana cada Cite en su contenido ya renderizado. El writer
-- de typst, en vez de emitir el texto de la cita (p. ej. "[1]"), emite
-- #cite(clave), que exigiria una bibliografia nativa de typst y falla. Al
-- devolver el contenido del Cite, el writer escribe el texto formateado.
function Cite(el)
  return el.content
end
