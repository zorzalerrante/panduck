main.pdf: main.md references.bib diagram.png sandwich.png
	panduck build -p dcc-informe main.md

diagram.png: diagram.dot
	dot -Tpng diagram.dot > diagram.png

sandwich.png: sandwich.dot
	dot -Tpng sandwich.dot > sandwich.png
