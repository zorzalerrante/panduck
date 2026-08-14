# $title$

$for(authors)$
**$it.name$**$if(it.corresponding)$ (corresponding author)$endif$  
$for(it.affiliation)$$it$$sep$; $endfor$  
$it.email$
$if(it.bio)$

$it.bio$
$endif$

$endfor$

$if(funding)$
## Funding

This work was supported by $for(funding)$$it$$sep$; $endfor$.

$endif$
$if(data)$
## Data availability

$data$
$endif$
