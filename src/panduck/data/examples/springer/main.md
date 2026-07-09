# Introducción

Sigue el modelo de embudo (CARS, Swales): primero el fenómeno general y por qué importa, luego la brecha metodológica o empírica en la literatura, después el enfoque propuesto, el caso de estudio como justificación, la fuente de datos y el método, y al final las preguntas de investigación explícitas. Cita con la sintaxis `[@clave]`, donde `clave` es la entrada en `references.bib` [@minto2009pyramid].

# Métodos

Describe qué hiciste, con qué datos y para qué. Las ecuaciones inline llevan un espacio antes y otro después, por ejemplo $y = \beta_0 + \beta_1 x + \varepsilon$ . Las ecuaciones destacadas van en su propio bloque:

$$\hat{\beta} = (X^\top X)^{-1} X^\top y.$$

# Resultados

Referencia las tablas con prefijo suprimido, porque la palabra "Tabla" ya va escrita a mano: la Tabla [-@tbl:ejemplo] resume los valores principales.

Table: Resultados del modelo. {#tbl:ejemplo}

| Variable | Coeficiente | IC 95%        |
| -------- | ----------- | ------------- |
| $x_1$    | 0.42        | [0.31, 0.53]  |
| $x_2$    | -0.18       | [-0.27, -0.09]|

# Discusión

Interpreta los hallazgos y conéctalos con la brecha que planteaste en la introducción. Indica los límites del estudio.

# Conclusión

Cierra con una afirmación directa. Si el resultado lo sostiene, afírmalo sin atenuar.

# Agradecimientos {.unnumbered}

Agradece la colaboración aquí. El financiamiento se declara con la clave `funding` en `head.yaml`.

# Referencias {.unnumbered}

<div id="refs"></div>
