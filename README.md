# `panduck`

Compilación centralizada de documentos markdown académicos a PDF con `pandoc`, `citeproc` y `pandoc-crossref`. 

## Instalación

```bash
uv tool install --editable .
```

Requisitos externos: `pandoc`, `xelatex`, `typst`, `graphviz` y `pandoc-crossref` (se busca en el PATH y en `~/.cabal/bin`). El perfil `instagram` usa además ImageMagick (`convert`) para el contraste automático de texto sobre imágenes.

## Uso

En un directorio con `main.md`, `head.yaml` y `references.bib`:

```bash
panduck build                     # main.pdf con el perfil default
panduck build -p elsevier         # template elsarticle con filtros de afiliaciones y funding
panduck build -p elsevier --anonymous   # blind review
panduck build -t docx             # main.docx
panduck build -t tex              # main.tex standalone
panduck build datos_head.yaml datos.md  # fuentes explicitas (metadata primero)
panduck build documento.md        # archivo unico, con el front matter dentro del md
panduck dist -p elsevier          # empaqueta tex + imagenes en dist/ para submission
panduck titlepage                 # titlepage.docx desde head.yaml
panduck cover-letter              # cover-letter.docx desde head.yaml
panduck build -p instagram        # carrusel de Instagram: PDF + una PNG por post
panduck build -p instagram --no-png      # solo PDF
panduck build -p slides --png --dpi 300  # fuerza PNG por slide a 300 dpi
panduck profiles                  # lista perfiles y estilos CSL disponibles
panduck init dcc-informe          # copia un ejemplo inicial al directorio actual
```

Cualquier argumento no reconocido se pasa directo a pandoc, por ejemplo:

```bash
panduck build --metadata lang=es --toc
```

## Cómo funciona

panduck es una capa delgada sobre dos mecanismos nativos de pandoc:

- **`--defaults`**: cada perfil es un archivo YAML en `src/panduck/data/defaults/` que fija formato de entrada, motor de PDF, template y el orden de los filtros (incluyendo la posición de citeproc).
- **`--data-dir`**: apunta a `src/panduck/data/`, donde pandoc resuelve por nombre los templates (`templates/`), estilos bibliográficos (`csl/`) y filtros Lua (`filters/`).

Además define `TEXINPUTS` para que xelatex encuentre la clase `elsarticle` en `data/texmf/` sin copiarla a cada proyecto.

## Estilos de texto (clases)

Todos los perfiles incluyen el filtro `fonts-and-alignment` (vendorizado de [pandoc-ext](https://github.com/pandoc-ext/fonts-and-alignment) y extendido para typst), que da un vocabulario único de clases CSS-like para spans `[texto]{.clase}` y divs `::: clase`, tanto en PDF LaTeX como typst:

- **Peso y estilo**: `bold`, `italic`, `medium`, `mono`, `sans`, `serif`, `smallcaps`/`sc`, `upright`, `emphasis`.
- **Tamaño**: `tiny`, `smaller`, `small`, `large`, `Large`, `LARGE`, `huge` (canónicos `pfa-text-3xs`..`pfa-text-3xl`).
- **Alineación** (divs): `::: center` con `centering`, `raggedleft`, `raggedright`, o `pfa-block-*`.
- **Color**: atributo `pfa-font-color="crimson"` (nombre CSS, hex o mezcla `rojo!50!negro`).
- **Subrayado/tachado**: `uline`, `sout`, etc. **Mayúsculas/minúsculas**: `pfa-uppercase`, `pfa-lowercase`.

```markdown
Una palabra [destacada]{.large .bold} y otra [en rojo]{pfa-font-color="crimson"}.

::: center
Bloque centrado.
:::
```

Es opt-in por clase (no afecta documentos que no las usan). En typst las familias `sans`/`mono` toman el nombre de `sansfont`/`monofont` del `head.yaml`. En los perfiles con template LaTeX propio (`elsevier`, `dcc-informe`) las clases que requieren paquetes extra (subrayado/tachado, bloques, color) pueden no cargar su paquete; el resto funciona.

## Diagramas de Graphviz

Un bloque de código con clase `.dot` (o `.graphviz`) se dibuja al compilar y se inserta como imagen, en todos los perfiles. Con `caption` sale como figura numerada por crossref y sin pie como imagen centrada. Atributos: `width` (80% por defecto), `height`, `engine` (`dot`, `neato`, `circo`, `fdp`, `sfdp`, `twopi`, `osage`) y `caption`. El formato lo elige el writer: SVG en typst, PDF en LaTeX, PNG en docx.

El diagrama toma la tipografía y los colores del documento sin declararlos, y hay tres estilos de nodo que se marcan con `class`:

````markdown
```{#fig:flujo .dot caption="Las tres etapas"}
digraph {
  rankdir=LR;
  Datos -> Modelo -> Resultado;
  Modelo [class="strong"];      // fondo del color del texto, letra contrastante
  Resultado [class="accent"];   // fondo del color destacado, letra contrastante
}
```
````

`base` es el estilo por defecto (fondo del papel, borde y letra del color del texto) y no hace falta escribirlo. Los alias en castellano son `base`, `fuerte` y `acento`. El color de la letra se calcula por la luminancia del fondo, así que un acento claro lleva letra oscura y uno oscuro letra clara; para eso el color va en hex (con un nombre de graphviz como `steelblue` la letra queda oscura).

La paleta y la tipografía se cambian desde el `head.yaml`: `dot-fg` (texto), `dot-bg` (papel), `dot-accent` (destacado) y `dot-font` (default: `mainfont`). Los colores van entre comillas o sin el numeral (`"#0A0E50"` o `0A0E50`), porque en YAML `#` abre un comentario; un valor que no parece color se avisa por stderr y cae al del tema. El perfil `slides` trae su propia paleta (navy y magenta del tema), y los valores del `head.yaml` la sobreescriben.

Como `class` es un atributo válido de graphviz, el mismo fuente se puede compilar con `dot` a mano: pierde los colores, no la validez. Los defaults que inyecta panduck van al inicio del grafo, así que un `node [...]` escrito después manda sobre ellos.

## Perfiles

| Perfil | Descripción |
|---|---|
| `default` | Template default de pandoc, xelatex, crossref + citeproc. La apariencia se controla desde `head.yaml` (geometry, fonts, etc.). |
| `documento` (`typst`) | Reporte o artículo de una columna compilado con typst: el equivalente de `default` sin necesitar una instalación de TeX y con compilación en menos de un segundo. El mismo markdown compila en los dos perfiles, porque la numeración la pone pandoc-crossref y no el motor. Portada con `title`, `subtitle`, autores, `date`, `abstract` y `keywords`, más `toc`, `numbersections` y la tipografía de `mainfont`/`monofont`/`mathfont`. Los autores se pueden declarar como `author:` (lista de strings) o como `authors:` (lista de `- name:`, el mismo contrato de los perfiles de revista). Solo PDF: para docx hay que usar `default`. |
| `elsevier` | Clase elsarticle con filtros Lua: limpieza de header-includes, afiliaciones agrupadas (`aff1`, `aff2`, ...) y sección de Funding insertada antes de las referencias. |
| `springer` | Clase `sn-jnl` de Springer Nature, una columna, pdflatex. Mismo contrato de autores que `elsevier` (`authors:` con `name`, `email`, `corresponding`, `orcid` y `affiliation`), con superíndices numéricos, `\author*` para el autor de contacto y logo ORCID junto al nombre. Las declaraciones `funding`, `interests` y `data` salen como secciones antes de las referencias. Las referencias van por citeproc y CSL, no por natbib, así que `link-citations: true` sí funciona aquí. `balance-margins: true` iguala el margen inferior con el superior para previsualizar (por defecto respeta la maquetación de la clase, que es lo que espera la revista). Solo PDF; `panduck dist -p springer` empaqueta el `.tex` para la submission. |
| `lapreprint` | Clase [LaPreprint](https://github.com/LaPreprint/LaPreprint), preprint de una columna con un margen izquierdo ancho donde va un sidebar de metadata (correspondencia, keywords, conflictos de interés y funding). Mismo contrato de autores que `elsevier` y `springer`, más `orcid` por autor y `leadauthor`/`shorttitle` por documento (se derivan del primer autor y del título si faltan). El servidor de preprint se elige con `classoption` (`biorxiv`, `arxiv`, `medrxiv`, `chemrxiv`). xelatex, solo PDF. |
| `tufte` (`typst`) | Reporte científico estilo Tufte: columna de texto angosta con un margen derecho ancho para las notas. Las notas al pie del markdown (`^[...]`) salen como notas al margen numeradas, `::: margin` es un bloque al margen sin numerar (texto o figura) y `::: wide` invade el margen. Numeración por pandoc-crossref, así que se escribe con `[-@fig:x]` como en los demás perfiles. `full: true` vuelve a una columna ancha con las notas al pie de la página. Tipografía con `mainfont`/`monofont`/`mathfont` (fuente de matemática con tabla MATH) y `math-scale`. Requiere `typst`. |
| `tufte-book` (`typst`) | El `tufte` para documentos largos: libro con portada, índice (`toc`, con nivel según `toc-depth`), capítulos (encabezado de nivel 1) y páginas de parte (`# Nombre {.part}`). Numeración por capítulo (Figura 8.1) y **bibliografía por capítulo**, con las referencias de cada unidad bajo su propio encabezado "Referencias" y numeradas desde 1. Mismo vocabulario de margen que `tufte` (`::: margin`, `::: wide`, notas al margen), con un tope de altura para las figuras del margen (`margin-image-height`). Requiere `typst`. |
| `slides` (`typst`)| Slides académicas en PDF vía typst (rápido, sin LaTeX), con tema azul marino + magenta sobre blanco (inspirado en Metropolis). `##` = slide, `#` = slide de sección. Opciones por slide como atributos de clase: `{.center}`, `{.smaller}`, `{.image}` (foco en imagen, a sangre), `{.quote}` (cita: texto grande con barra de acento a la izquierda; sin cursiva automática, se elige qué va en `*cursiva*`), `{.statement}` (declaración: fondo navy, texto grande centrado en blanco, frase clave en `**negrita**` resaltada en acento), `{.end image="x.png"}` (slide de cierre con imagen opcional), `{background="#1b3b6f"}`, dos columnas con grosor (`width=`), alineación por bloque o columna (`::: left` / `::: right` / `::: center`, o esas clases sobre una `.column`) y diagramas Graphviz (` ```{.dot} `). Citas con `>` estilizadas como cita (barra de acento, tipografía de citas y cursiva). Texto inline a otro tamaño o estilo con las clases compartidas (ver "Estilos de texto": `.small`, `.large`, `.sc`, etc.; las versalitas son sintéticas, sirven aunque la fuente no traiga la feature smcp). Callouts con divs `::: warning` / `::: theorem` / `::: prompt` ... (tipos `note`, `tip`, `warning`, `alert`/`important`, `theorem`, `definition`, `prompt`, `callout`; `title=` sobreescribe la etiqueta; `prompt` usa monofont). Notas al pie para referencias (legibles también sobre slides de fondo oscuro). Tablas con encabezado estilizado (primera fila con fondo tenue y negrita). Footer `x / total`. Portada con `title-image` (y `title-image-credit`, crédito vertical a un costado de la imagen), `logos` (lista), `affiliation` (una o varias) y `venue`. Tipografía configurable en `head.yaml`: `mainfont`, `quotefont` (citas), `monofont` (código y prompts, default Fira Code a 0.9em); tamaños `logo-height`, `end-image-height`. `fontsize` (default 22pt) escala el deck completo: títulos de slide, texto reducido de `{.smaller}` y `{.image}`, pies de figura y notas al pie se derivan de él. Los pies de figura van del porte del deck y los enlaces salen subrayados en todo el deck (cuerpo, pies y notas al pie). Requiere `typst` (`sudo snap install typst`). |
| `paper` | Paper académico genérico (working paper). Compila a PDF (clase `article` con line numbers y pie de página vía `header-includes`) y a docx con un reference-doc de Word estilizado (cuerpo Times New Roman, interlineado 1.5). |
| `dcc-informe` | Informe E o memoria del DCC (U. de Chile), clase `umemoria` con portada institucional, capítulos como nivel 1 de Markdown y bibliografía ACM. |
| `beamer` | Slides en beamer con el tema por defecto de LaTeX, sin plantilla propia. Queda como salida alternativa: para presentaciones se usa `slides`, que compila mucho más rápido. |
| `instagram` (`typst`) | Carruseles de Instagram en PDF y una PNG por post (256 dpi por defecto). Cada `#` es un post (página vertical 4:5, configurable). Opciones por post como atributos del encabezado: `{background-image="bg.png"}` (imagen cover), `{pagecolor="1b3b6f"}`, `{textcolor="ffffff"}`, `{fontsize="11pt"}`, `{.top}`, `{.left}`. Color de texto por contraste automático (claro/oscuro) si no se fija. Imagen circular (`.circle`), columnas, y los estilos de texto compartidos (`.LARGE`, `.sc`, `.sff`, ...; ver "Estilos de texto"). Pie común con iconos FontAwesome (`:instagram:`, `:globe:`, ...) y número de post. `mainfont`/`sansfont` configurables en `head.yaml`. Requiere `typst` e ImageMagick (`convert`). |

## Configuración por documento

Para variar la compilación de un documento sin crear un perfil nuevo hay tres mecanismos, de menos a más permanente.

**1. Flags sueltos.** Los argumentos que panduck no reconoce pasan directo a `pandoc`. Los filtros Lua se resuelven por nombre desde `data/filters/` (vía `--data-dir`) o desde el directorio actual:

```bash
panduck build doc.md --lua-filter sectionbreak.lua   # filtro local o de data/filters
panduck build doc.md --defaults ./otro.yaml          # apilar otro defaults
```

**2. `panduck.yaml` local.** Si el directorio tiene un `panduck.yaml`, `panduck build` lo agrega como `--defaults` después del perfil. Ahí van filtros extra, `pdf-engine`, variables o `header-includes` propios del documento, y `panduck build` (sin flags) queda como único comando:

```yaml
# panduck.yaml
filters:
  - sectionbreak.lua   # cada `***` sale como asterismo centrado (solo en perfiles LaTeX)
```

Pandoc **concatena** las listas (`filters`) al apilar `--defaults`: los filtros del `panduck.yaml` corren después de `pandoc-crossref` y `citeproc`. Para un filtro post-citeproc basta esa línea. Si necesita correr antes de citeproc, hay que re-declarar la lista completa de filtros en el `panduck.yaml`. 

**3. Perfil nuevo.** Para una configuración que se repite en muchos documentos, conviene crear un perfil en `data/defaults/`.

## Convenciones del proyecto

- `main.md`: cuerpo del documento. `head.yaml`: metadatos (título, autores, abstract, `bibliography`, `csl`). `references.bib`: bibliografía.
- **El `head.yaml` aparte es convención, no requisito**: los mismos metadatos pueden ir como front matter YAML dentro del `.md` y el documento compila igual, con cualquier perfil (`panduck build documento.md -p documento`). Si el archivo se llama `main.md` y no hay `head.yaml`, `panduck build` sin argumentos también lo toma. Al pasar las dos fuentes, un campo definido en ambas se resuelve a favor de la última: como el `.md` va al final, su front matter sobreescribe al `head.yaml`. Los subcomandos `titlepage`, `cover-letter` y `highlights` leen `head.yaml` por defecto, así que con metadatos embebidos hay que indicarlo (`panduck titlepage -m documento.md`).
- El CSL se indica por nombre en `head.yaml` (por ejemplo `csl: elsevier-harvard.csl`); se resuelve desde `data/csl/` sin copiar el archivo al proyecto.
- `titlepage` y `cover-letter` usan los templates de panduck, pero si el proyecto tiene `titlepage-template.md` o `cover-letter-template.md` locales, esos tienen prioridad.
- Las dependencias específicas de cada proyecto (generación de figuras con dot o scripts de Python) se quedan en un Makefile local mínimo que termina llamando a `panduck build`.

## Extender

- **Nuevo perfil**: agregar `data/defaults/<nombre>.yaml`.
- **Nuevo template**: agregar `data/templates/<nombre>.latex` y referenciarlo con `template: <nombre>` en el perfil.
- **Reference-doc para docx**: agregar `data/reference/<perfil>-reference.docx`; `build -t docx` lo aplica automáticamente para ese perfil.
- **Ejemplo de `init` con prompts**: agregar `data/examples/<nombre>/` con un `prompts.toml` (`[[prompts]]` con `key`/`question`/`default`) y usar marcadores `{{key}}` en los archivos de texto.
- **Perfil que compila a PDF vía typst**: declarar `to: typst` en el perfil; `build` lo compila en dos pasos (pandoc → `.typ` → `typst compile`). Para exportar también PNG (una por página), agregar el comentario `# panduck-png: <dpi>` al YAML del perfil (lo activa por defecto), o usar las flags `--png`/`--no-png`/`--dpi N`. typst no escanea `~/.fonts` ni `~/.local/share/fonts`: panduck le pasa esas rutas con `--font-path` (extra con `PANDUCK_FONT_PATH`). El nombre de fuente que espera typst es el typographic family (ver `typst fonts`), que puede diferir del de fontconfig.
- **Nuevo CSL**: copiar a `data/csl/` (disponibles, entre otros: `apa-6th-edition`, `acm-sigchi-proceedings`, `sage-harvard`, `elsevier-harvard`, `ieee`). Se referencian por nombre con `csl:` en el front matter.
- **Nueva clase o paquete LaTeX** (`.sty`/`.cls`): copiar a `data/texmf/` (por convención `tex/latex/<nombre>/`); como `TEXINPUTS` incluye `data/texmf/`, `\usepackage{<nombre>}` resuelve al compilar desde cualquier directorio.
- **Filtro Lua reusable**: copiar a `data/filters/`; se referencia por nombre desde un perfil, un `panduck.yaml` o `--lua-filter <nombre>.lua`.
- **Override puntual**: `PANDUCK_PANDOC=/ruta/a/pandoc` cambia el binario de pandoc; `PANDUCK_TYPST` el de typst; `PANDUCK_FONT_PATH` agrega rutas de fuentes para typst.
