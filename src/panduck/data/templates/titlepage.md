# $title$

$for(authors)$
**$it.name$**$if(it.corresponding)$ (corresponding author)$endif$  
$for(it.affiliation)$$it$$sep$; $endfor$  
$it.email$
$if(it.bio)$

$it.bio$
$endif$

$endfor$

$if(acknowledgements)$
## Acknowledgements

$acknowledgements$

$endif$
$if(funding)$
## Funding

This work was supported by $for(funding)$$it$$sep$; $endfor$.

$endif$
$if(interests)$
## Declaration of interest

$interests$

$endif$
$if(data)$
## Data availability

$data$
$endif$
$if(ai_declaration)$

## Declaration of generative AI and AI-assisted technologies in the writing process

$ai_declaration$
$endif$
