Este ejemplo muestra qué produce el perfil `hugo`: un documento escrito con las
convenciones de panduck (citas, referencias cruzadas, diagramas) sale como un
post listo para publicar. El mismo archivo compila a PDF con `panduck build`.

Las citas se renderizan con el CSL del documento y la bibliografía queda como
lista al final [@tufte2001visual]. Las notas al pie se conservan.[^nota]

[^nota]: Goldmark, el motor de markdown de Hugo, las renderiza al pie del post.

# Figuras y diagramas

Un diagrama escrito en el documento se dibuja al compilar y viaja al bundle como
PNG de alta resolución, con un fondo claro para que se lea igual en un sitio con
modo oscuro. Con `format=mermaid` sale como bloque mermaid, que dibuja el
navegador heredando el tema del sitio. El pie lo numera pandoc-crossref, así que
el texto puede referenciarlo: el flujo está en la Figura [-@fig:flujo].

```{#fig:flujo .dot caption="Las etapas del diseño"}
digraph {
  rankdir=LR;
  dominio -> abstraccion -> tecnica -> algoritmo;
  abstraccion [class="strong"];
}
```

Una figura con imagen propia se escribe igual que siempre y su archivo se copia
junto al `index.md`.

# Matemática

La matemática inline sale con los delimitadores que espera la extensión
passthrough de Goldmark, por ejemplo $E = mc^2$, y la de bloque va aparte:

$$\int_0^1 x\,dx = \frac{1}{2}$$

# Referencias

::: {#refs}
:::
