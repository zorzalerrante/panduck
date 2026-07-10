main.pdf: main.md head.yaml references.bib
	panduck build -p lapreprint

# Empaqueta el .tex y sus imagenes en dist/ para el servidor de preprints.
dist: main.md head.yaml references.bib
	panduck dist -p lapreprint
