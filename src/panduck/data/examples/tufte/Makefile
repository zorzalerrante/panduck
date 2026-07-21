main.pdf: main.md head.yaml references.bib figura.png
	panduck build -p tufte

# El Makefile local solo genera figuras; la compilacion la hace panduck.
figura.png: figura.dot
	dot -Tpng -Gdpi=200 $< -o $@

clean:
	rm -f main.typ main.pdf figura.png
