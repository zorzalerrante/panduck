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

## Perfiles

| Perfil | Descripción |
|---|---|
| `default` | Template default de pandoc, xelatex, crossref + citeproc. La apariencia se controla desde `head.yaml` (geometry, fonts, etc.). |
| `elsevier` | Clase elsarticle con filtros Lua: limpieza de header-includes, afiliaciones agrupadas (`aff1`, `aff2`, ...) y sección de Funding insertada antes de las referencias. |
| `slides` (`typst`)| Slides académicas en PDF vía typst (rápido, sin LaTeX), con tema azul marino + magenta sobre blanco (inspirado en Metropolis). `##` = slide, `#` = slide de sección. Opciones por slide como atributos de clase: `{.center}`, `{.smaller}`, `{.image}` (foco en imagen, a sangre), `{.quote}` (cita: texto grande con barra de acento a la izquierda; sin cursiva automática, se elige qué va en `*cursiva*`), `{.statement}` (declaración: fondo navy, texto grande centrado en blanco, frase clave en `**negrita**` resaltada en acento), `{.end image="x.png"}` (slide de cierre con imagen opcional), `{background="#1b3b6f"}`, dos columnas con grosor (`width=`), alineación por bloque o columna (`::: left` / `::: right` / `::: center`, o esas clases sobre una `.column`) y diagramas Graphviz (` ```{.dot} `). Citas con `>` estilizadas como cita (barra de acento, tipografía de citas y cursiva). Texto inline a otro tamaño o estilo con las clases compartidas (ver "Estilos de texto": `.small`, `.large`, `.sc`, etc.; las versalitas son sintéticas, sirven aunque la fuente no traiga la feature smcp). Callouts con divs `::: warning` / `::: theorem` / `::: prompt` ... (tipos `note`, `tip`, `warning`, `alert`/`important`, `theorem`, `definition`, `prompt`, `callout`; `title=` sobreescribe la etiqueta; `prompt` usa monofont). Notas al pie para referencias (legibles también sobre slides de fondo oscuro). Tablas con encabezado estilizado (primera fila con fondo tenue y negrita). Footer `x / total`. Portada con `title-image` (y `title-image-credit`, crédito vertical a un costado de la imagen), `logos` (lista), `affiliation` (una o varias) y `venue`. Tipografía configurable en `head.yaml`: `mainfont`, `quotefont` (citas), `monofont` (código y prompts, default Fira Code a 0.9em); tamaños `logo-height`, `end-image-height`. Requiere `typst` (`sudo snap install typst`). |
| `paper` | Paper académico genérico (working paper). Compila a PDF (clase `article` con line numbers y pie de página vía `header-includes`) y a docx con un reference-doc de Word estilizado (cuerpo Times New Roman, interlineado 1.5). |
| `dcc-informe` | Informe E o memoria del DCC (U. de Chile), clase `umemoria` con portada institucional, capítulos como nivel 1 de Markdown y bibliografía ACM. |
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
