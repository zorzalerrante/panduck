#import "@local/drafting:0.2.2": *

#let sans-fonts = (
  "IBM Plex Sans",
  "Atkinson Hyperlegible",
  "Noto Sans",
  "Helvetica",
  "Verdana",
  "Geneva",
  "sans-serif",
)

#let fullwidth = state("fullwidth", false)

// panduck: bandera que lee la plantilla tufte-book para decidir si el pie de
// figura va al margen. tufte.lua la apaga dentro de `::: margin` y de `::: wide`,
// donde no queda margen libre en que ponerlo.
#let pie-al-margen = state("pie-al-margen", true)

// panduck: cuanto puede subir una figura de margen si el margen esta libre a esa
// altura, y donde empieza el area de texto (para no treparse al encabezado). Las
// fija la plantilla; en 0pt la figura se queda donde se declaro, que es el
// comportamiento original.
#let subida-maxima = state("subida-maxima", 0pt)
#let tope-texto = state("tope-texto", 1in)

#let template(
  title: none,
  authors: none,
  // panduck: la fuente era fija (sans-fonts). Como el `set text` de mas abajo
  // corre dentro de la funcion, un `set` externo no lo puede sobreescribir; con
  // el parametro la plantilla de panduck pasa el `mainfont` del head.yaml y
  // alcanza tambien al titulo y al encabezado, no solo al cuerpo.
  font: sans-fonts,
  date: datetime.today().display("[day] [month repr:long] [year]"),
  abstract: none,
  toc: false,
  full: false,
  header: true,
  footer: true,
  header-content: none,
  footer-content: none,
  bib: none,
  doc,
) = {
  // Full width or with right margin
  let right-margin = {
    if full { 0.7in } else { 3in }
  }
  let left-margin = 0.7in
  let margin-diff = right-margin - left-margin
  let wideblock(content) = block(width: 100% + margin-diff, content)

  // Update full width state used by note and notecite functions
  fullwidth.update(full)

  // Functions
  let titleblock(title, authors, date, abstract) = {
    wideblock([
      #set align(center)
      // panduck: titulo sin silabacion (un titulo largo no debe partirse con
      // guion). Solo el titulo; el abstract mas abajo si se silabea.
      #if title != none { [#text(14pt, hyphenate: false, [*#title*]) \ \ ] }
      #if authors != none {
        if type(authors) == array and authors.len() == 2 {
          [#authors.join(", ", last: " and ") \ ]
        } else if type(authors) == array {
          [#authors.join(", ", last: ", and ") \ ]
        } else if type(authors) == str {
          [#authors \ ]
        }
      }
      #if date != none { [#date \ ] }
      #if abstract != none { [\ #abstract \ ] }
      #if toc { [\ #outline(indent: 1em, title: none, depth: 2) ] }
    ])
  }

  let headerblock(title, authors, date, header-content) = if header and header-content != none {
    header-content
  } else if header {
    set text(size: 8pt)
    wideblock({
      if counter(page).get().first() > 1 [
        #emph[#title]
        #h(1fr)
        #emph[#date]
        \
        #emph[#authors]
      ]
    })
  } else { none }

  let footerblock(footer-content) = if footer and footer-content != none {
    footer-content
  } else if footer {
    set text(size: 8pt)
    wideblock({
      set align(right)
      emph(counter(page).display("1/1", both: true))
    })
  } else { none }

  // Metadata
  if authors != none {
    set document(title: title, author: authors)
  } else {
    set document(title: title)
  }

  set text(font: font, fill: luma(15%))  // panduck: era sans-fonts fijo
  show ref: set text(blue)
  show link: set text(blue)

  set par(justify: true, spacing: 1.5em)

  set cite(style: "american-physics-society")
  show bibliography: set par(spacing: 1em)

  set enum(indent: 1em)
  set list(indent: 1em)
  show enum: set par(spacing: 1.25em)
  show list: set par(spacing: 1.25em)

  set math.equation(numbering: "(1)", supplement: none, number-align: bottom)

  show raw.where(block: false): box.with(
    fill: luma(95%),
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
  )
  show raw.where(block: true): block.with(
    fill: luma(95%),
    inset: 5pt,
    radius: 4pt,
    width: 100%,
  )

  // Equation reference to (1)
  show ref: it => {
    if it.element != none and it.element.func() == math.equation {
      link(it.target)[(#it)]
    } else {
      it
    }
  }

  // Figure reference without supplement
  show ref.where(
    form: "normal",
  ): set ref(supplement: it => {
    if it.func() == figure { none }
  })

  // Section headings
  set heading(numbering: "1.1.1.", supplement: none)
  show heading.where(level: 1): it => {
    v(1.2em, weak: true)
    text(size: 13pt, weight: "bold", it)
    v(1em, weak: true)
  }
  show heading.where(level: 2): it => {
    v(1.2em, weak: true)
    text(size: 12pt, weight: "bold", it)
    v(1em, weak: true)
  }
  show heading.where(level: 3): it => {
    v(1.2em, weak: true)
    text(size: 11pt, weight: "bold", it)
    v(1em, weak: true)
  }

  set page(
    paper: "a4",
    margin: (
      left: left-margin,
      right: right-margin,
      top: 1in,
      bottom: 0.75in,
    ),
    header: context { headerblock(title, authors, date, header-content) },
    footer: context { footerblock(footer-content) },
    footer-descent: 55%,
  )

  // Title block
  titleblock(title, authors, date, abstract)
  v(1.5em)

  // Using drafting package
  set-page-properties(
    margin-right: right-margin - left-margin,
    margin-left: left-margin * 1.2,
  )
  set-margin-note-defaults(
    stroke: none,
    side: right,
  )

  doc

  if bib != none { wideblock(bib) }
}

#let notecounter = counter("notecounter")
/// A sidenote.
///
/// Places a sidenote at the right margin.
/// If `full` template option is set to `true`, becomes a footnote instead.
///
/// - `dy: auto | length = auto` Vertical offset.
/// - `numbered: bool = true` Insert a superscript number.
/// - `body: content` Required. The content of the sidenote.
#let sidenote(dy: auto, numbered: true, body) = context {
  if fullwidth.get() and not numbered {
    footnote(body, numbering: _ => [])
    counter(footnote).update(n => n - 1)
  } else if fullwidth.get() {
    footnote(body)
  } else {
    if numbered {
      notecounter.step()
      context super(notecounter.display())
    }
    // panduck: los tamanos eran fijos (8pt y 11pt), pensados para un cuerpo de
    // 10pt. Al subir `fontsize` en el head.yaml las notas quedaban diminutas, asi
    // que van en em: mantienen la proporcion del diseno original.
    text(size: 0.8em, margin-note(
      if numbered {
        text(size: 1.375em, {
          context super(notecounter.display())
        })
        body
      } else {
        body
      },
      dy: dy,
    ))
  }
}

/// panduck: figura de margen que sube si hay espacio libre sobre ella.
///
/// Una figura declarada a media altura de un parrafo empieza, por omision, en la
/// linea exacta del `:::  margin`, que suele dejar un hueco arriba. Esta version
/// la sube hasta el pie de la nota anterior de la pagina y como maximo
/// `subida-maxima`; si hay una nota justo encima no sube nada, y nunca pasa del
/// inicio del area de texto.
///
/// - `body: content` Required. El contenido de la figura.
#let sidenote-flotante(body) = context {
  // `to-absolute` resuelve un limite escrito en em (depende del cuerpo): sin eso
  // no se puede comparar ni operar con las posiciones, que vienen en pt
  let limite = subida-maxima.get().to-absolute()
  if fullwidth.get() or limite == 0pt {
    return sidenote(numbered: false, body)
  }
  let y = here().position().y
  // margen disponible arriba: el que pida el limite, sin salirse del area de texto
  let espacio = calc.min(limite, calc.max(0pt, y - tope-texto.get().to-absolute()))

  // Una figura que sube hasta quedar al lado de la seccion anterior confunde mas
  // de lo que ayuda. Si la subida completa cruzaria el ultimo encabezado, sube
  // solo esta fraccion de lo que queda hasta el: se acerca al parrafo sin salirse
  // de su seccion.
  // El tope es una cota, no un caso aparte: si fuera `si cruza, usa la fraccion`,
  // subir el limite podria reducir la subida (justo al pasar el umbral), que es
  // al reves de lo que uno espera al configurarlo.
  let fraccion-en-el-borde = 0.5
  let previos = query(selector(heading).before(here()))
  if previos.len() > 0 {
    let h = previos.last().location()
    if h.page() == here().page() {
      let hasta-el-encabezado = y - h.position().y
      espacio = calc.min(espacio, calc.max(0pt, hasta-el-encabezado * fraccion-en-el-borde))
    }
  }

  let pagina = str(here().page())
  let descenso = note-descent.get().at(pagina, default: (left: 0pt, right: 0pt)).right
  // dy negativo sube. El maximo con `descenso - y` es lo que impide pisar la nota
  // anterior: si esa nota termina bajo el ancla, la figura incluso baja.
  sidenote(numbered: false, dy: calc.max(-espacio, descenso - y), body)
}

/// A sidenote citation.
///
/// Places a sidenote at the right margin.
/// If `full` template option is set to `true`, becomes a footnote instead.
/// Only display when `bibliography` is defined.
///
/// - `dy: auto | length = auto` Vertical offset.
/// - `form: none | str = "normal"` Form of in-text citation.
/// - `style: [csl] | auto | bytes | str = auto` Citation style.
/// - `supplement: content | none = none` Citation supplement.
/// - `key: cite-label` Required. The citation key.
#let sidecite(dy: auto, form: "normal", style: auto, supplement: none, key) = context {
  show cite: it => {
    show regex("\[\d\]"): set text(blue)
    it
  }
  let elems = query(bibliography)
  if elems.len() > 0 {
    cite(key, form: form, style: style, supplement: supplement)
    sidenote(
      cite(key, form: "full"),
      dy: dy,
      numbered: false,
    )
  }
}

/// Wideblock
///
/// Wrapped content will span the full width of the page.
///
/// - `content: content | none` Required. The content to span the full width.
#let wideblock(content) = context {
  if fullwidth.get() {
    block(width: 100%, content)
  } else {
    block(width: 100% + 2.3in, content)
  }
}
