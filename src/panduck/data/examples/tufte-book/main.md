# Preliminares {.part}

# Cómo se arma un libro

Un encabezado de nivel 1 es un capítulo: abre página, con el número grande sobre el título. Un encabezado con la clase `{.part}` es una página de parte, que agrupa los capítulos que vienen después.

La numeración es por capítulo, así que la primera figura de este capítulo es la Figura [-@fig:flujo] y la primera del siguiente vuelve a empezar en 1.

## Notas y bloques al margen

Las notas al pie de markdown salen al margen, numeradas y a la altura de la línea que las llama.^[Esta nota se escribió con la sintaxis `^[...]`.] Un bloque `::: margin` va al margen sin número.

::: margin
Sirve para comentarios sueltos, definiciones breves y figuras marginales.
:::

Una figura de margen sube hasta el pie de la nota anterior cuando el margen está libre sobre ella, hasta el límite de `margin-float-up`.

::: margin
![Una figura dentro de `::: margin`.](figura.png)
:::

## Figuras y tablas

El pie de una figura de la columna de texto va al margen, a la altura de su borde superior.

![Etapas del procesamiento.](figura.png){#fig:flujo width=100%}

Una tabla angosta cabe en la columna: la Tabla [-@tbl:coeficientes] resume los coeficientes.

Table: Coeficientes del modelo. {#tbl:coeficientes}

| Variable | Coeficiente | IC 95%         |
| -------- | ----------- | -------------- |
| $x_1$    | 0.42        | [0.31, 0.53]   |
| $x_2$    | -0.18       | [-0.27, -0.09] |

Cuando una tabla no cabe, `::: wide` la extiende sobre el margen y su pie vuelve abajo.

::: wide
Table: Comparación de los tres modelos ajustados. {#tbl:modelos}

| Especificación del modelo   | Predictores | $R^2$ ajustado | RMSE | AIC   | Observaciones |
| --------------------------- | ----------- | -------------- | ---- | ----- | ------------- |
| Base, sin controles         | 2           | 0.31           | 1.42 | 812.4 | 1200          |
| Con controles demográficos  | 6           | 0.48           | 1.18 | 764.1 | 1200          |
| Completo, con interacciones | 11          | 0.52           | 1.11 | 759.8 | 1200          |
:::

## Referencias

Cada capítulo lleva su propia bibliografía, numerada desde el principio [@tufte2001visual]. El capítulo tiene que terminar con un encabezado "Referencias"; si no, las entradas salen sin título.

# Un segundo capítulo

Las referencias de este capítulo no se mezclan con las del anterior: `per-chapter-refs.lua` corre citeproc por separado en cada uno [@knuth1984texbook].

La numeración de figuras y tablas también reinicia, así que esta es la Ecuación [-@eq:ols] del capítulo 2.

$$\hat{\beta} = (X^\top X)^{-1} X^\top y$$ {#eq:ols}

## Referencias
