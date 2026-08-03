# Introduccion

Este es el perfil `documento`: un reporte de una columna compilado con typst en
vez de LaTeX. El mismo markdown compila con el perfil `default` (LaTeX), porque
la numeracion de figuras, tablas y ecuaciones la pone pandoc-crossref y no el
motor.

Las citas van con citeproc y el estilo CSL del `head.yaml` [@tufte2001visual].
Las notas al pie salen abajo de la pagina.^[Como esta.]

# Figuras, tablas y ecuaciones

Referencia las figuras y tablas con el prefijo suprimido, porque la palabra
"Figura" o "Tabla" ya va escrita en el texto.

Los diagramas de Graphviz se escriben en el documento y panduck los convierte al
compilar, sin archivos `.dot` sueltos ni reglas en el Makefile:

```{#fig:flujo .dot caption="Las tres etapas del procesamiento" width="55%"}
digraph {
  rankdir=LR;
  node [shape=box, style=rounded];
  Datos -> Modelo -> Resultado;
}
```

La Figura [-@fig:flujo] resume el flujo. Sin `caption` el diagrama sale centrado
y sin numero, y con `engine="neato"` se cambia el motor de dibujo.

| Modelo                | Predictores | RMSE |
|:----------------------|------------:|-----:|
| Base, sin controles   |           2 | 1.42 |
| Con controles         |           6 | 1.18 |
| Completo              |          11 | 1.11 |

: Comparacion de los tres modelos ajustados {#tbl:modelos}

La Tabla [-@tbl:modelos] compara los ajustes. Una ecuacion numerada:

$$ \hat{y} = \beta_0 + \beta_1 x + \varepsilon $$ {#eq:modelo}

La Ecuacion [-@eq:modelo] es el modelo lineal.

# Codigo y estilos

Los bloques de codigo van en la fuente mono, con fondo tenue:

```python
def ajusta(x, y):
    return (x.T @ x).inverse() @ x.T @ y
```

Las clases de texto son las mismas de todos los perfiles: [versalitas]{.sc},
[mas grande]{.large}, [color]{pfa-font-color="crimson"}, y bloques centrados con
`::: centering`.

# Referencias

::: {#refs}
:::
