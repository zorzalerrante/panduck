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

## Cita {.quote}

"Lo que se mide, se gestiona."

*Peter Drucker*

## {.statement}

**Una idea importante** se resalta con una slide de declaración.

El texto va grande y centrado sobre fondo navy.

## Callouts

::: definition
Un *callout* es una caja con etiqueta y color para destacar contenido.
:::

::: warning
Los tipos disponibles son note, tip, warning, alert, theorem, definition y prompt.
:::

::: {.theorem title="Regla práctica"}
Un buen prompt necesita vocabulario, estructura y contexto.
:::

## Un prompt {.smaller}

Los prompts se muestran con tipografía de código:

::: prompt
Resume el siguiente texto en tres puntos **(tarea)**, en tono formal **(requisito)**, para una audiencia técnica **(contexto)**.
:::

## Código

El código usa Fira Code a 0.9em:

```python
def saludar(nombre):
    return f"Hola, {nombre}"
```

# Resultados

## Hallazgo principal

- Resultado A
- Resultado B
- Resultado C

## Referencias {.smaller}

<div id="refs"></div>

## ¡Gracias! {.end}

correo@ejemplo.cl
