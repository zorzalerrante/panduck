# Introducción

## ¿De qué trata esto? {.smaller}

- Cada `##` es una slide nueva, con barra de título.
- Cada `#` genera una slide de sección (página de color).
- El texto se escribe en Markdown y se compila a PDF con typst.
- Las opciones de cada slide se ponen como atributos de clase en el título.

## Dos columnas

::: columns
:::: {.column width="58%"}
La columna izquierda lleva el texto principal. El grosor de cada columna se
define con `width` en el atributo de la columna.

Las citas funcionan igual que en los papers [@minto2009pyramid].
::::
:::: {.column width="42%"}
- Lista a la derecha
- Segundo punto
- Tercer punto
::::
:::

## Un diagrama Graphviz

```{.dot width="55%"}
digraph G {
  rankdir=LR;
  node [shape=box, style=rounded];
  Datos -> Modelo -> Resultado;
}
```

## Cita destacada {.center background="#222831"}

"Lo que se mide, se gestiona."

# Resultados

## Hallazgo principal

- Resultado A
- Resultado B
- Resultado C

## Referencias {.smaller}

<div id="refs"></div>
