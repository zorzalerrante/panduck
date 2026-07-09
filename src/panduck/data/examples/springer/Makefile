main.pdf: main.md head.yaml references.bib
	panduck build -p springer

# Empaqueta el .tex y sus imagenes en dist/ para enviar a la revista.
dist: main.md head.yaml references.bib
	panduck dist -p springer
