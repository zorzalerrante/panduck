main.pdf: main.md head.yaml references.bib
	panduck build -p paper

docx: main.md head.yaml references.bib
	panduck build -p paper -t docx
