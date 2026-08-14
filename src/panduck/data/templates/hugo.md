---
title: "$title$"
$if(date)$
date: $date$
$endif$
$if(tags)$
tags:
$for(tags)$
  - "$tags$"
$endfor$
$endif$
$if(toc)$
toc: true
$endif$
$if(draft)$
draft: true
$endif$
$if(thumbnail)$
thumbnail: "$thumbnail$"
$endif$
$-- claves libres para el front matter: lo que este bajo `hugo:` en el head.yaml
$-- se copia tal cual, para no tener que tocar panduck por cada campo del tema
$for(hugo/pairs)$
$it.key$: $it.value$
$endfor$
---

$body$
