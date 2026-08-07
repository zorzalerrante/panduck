#!/usr/bin/env python3
"""Montaje con la primera pagina de cada perfil de panduck.

Compila el ejemplo de cada perfil (`panduck init`), rasteriza su primera pagina y
arma una grilla etiquetada con ImageMagick. Sirve para ver de una sola vez que
todos los perfiles compilan y como se ven, y para la imagen del README.

    python scripts/montaje-perfiles.py -o docs/perfiles.png

Dos perfiles no tienen ejemplo propio y reusan uno ajeno, que es la forma de
comprobar que las fuentes son portables entre perfiles: `default` compila el
ejemplo de `documento` y `elsevier` el de `springer` (mismo contrato de autores).

Requiere `panduck`, `pdftoppm` (poppler), `montage` y `convert` (ImageMagick), y
`dot` para los ejemplos que traen diagramas.
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

# perfil -> ejemplo de `panduck init` que se compila con el
PERFILES = {
    "default": "documento",
    "documento": "documento",
    "paper": "paper",
    "elsevier": "springer",
    "springer": "springer",
    "lapreprint": "lapreprint",
    "dcc-informe": "dcc-informe",
    "tufte": "tufte",
    "tufte-book": "tufte-book",
    "slides": "slides",
    "instagram": "instagram",
}


def run(cmd, cwd, paso):
    """Ejecuta un comando y devuelve True si funciono."""
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        cola = (r.stderr or r.stdout).strip().splitlines()[-3:]
        print(f"    {paso} fallo: " + " / ".join(cola))
    return r.returncode == 0


def prepara(perfil, ejemplo, dir_trabajo):
    """Copia el ejemplo, genera sus figuras y compila el PDF. Devuelve su ruta."""
    d = dir_trabajo / perfil
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)

    if not run(["panduck", "init", ejemplo, "-y"], d, "init"):
        return None
    # Los ejemplos con figuras traen el .dot y un Makefile que solo las genera;
    # aca se hace directo, porque el Makefile compila con el perfil del ejemplo y
    # no siempre es el que estamos montando.
    for dot in sorted(d.glob("*.dot")):
        run(["dot", "-Tpng", "-Gdpi=200", dot.name, "-o", dot.stem + ".png"], d, "dot")
    # --no-png: los perfiles typst que exportan PNG por pagina (instagram) no lo
    # necesitan aca, la pagina se rasteriza igual desde el PDF
    if not run(["panduck", "build", "-p", perfil, "--no-png"], d, "build"):
        return None
    pdf = d / "main.pdf"
    return pdf if pdf.exists() else None


def rasteriza(pdf, destino, dpi, pagina):
    ok = run(["pdftoppm", "-png", "-r", str(dpi), "-f", str(pagina), "-l", str(pagina),
              "-singlefile", pdf.name, destino.stem], pdf.parent, "pdftoppm")
    generado = pdf.parent / (destino.stem + ".png")
    if not ok or not generado.exists():
        return None
    shutil.move(generado, destino)
    return destino


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("-o", "--output", default="perfiles.png", help="imagen de salida")
    p.add_argument("-w", "--work-dir", default=".montaje",
                   help="donde compilar (default: .montaje en el directorio actual). "
                        "typst es snap y no ve el /tmp del sistema, asi que tiene que "
                        "estar bajo $HOME")
    p.add_argument("--dpi", type=int, default=110, help="resolucion al rasterizar")
    # Ancho y alto acotan la celda y cada pagina entra respetando su proporcion.
    # Con solo el alto, una lamina apaisada (slides, 16:9) sale tres veces mas
    # ancha que una carta y descuadra la grilla.
    p.add_argument("--alto", type=int, default=520, help="alto maximo de cada pagina")
    p.add_argument("--ancho", type=int, default=420, help="ancho maximo de cada pagina")
    p.add_argument("--columnas", type=int, default=4, help="paginas por fila")
    p.add_argument("--pagina", type=int, default=1, help="que pagina de cada PDF se muestra")
    p.add_argument("--perfiles", nargs="*", metavar="PERFIL",
                   help="subconjunto a montar (default: todos)")
    p.add_argument("--keep", action="store_true",
                   help="conserva el directorio de trabajo con los PDF compilados")
    args = p.parse_args()

    for prog in ("panduck", "pdftoppm", "montage"):
        if shutil.which(prog) is None:
            sys.exit(f"falta {prog} en el PATH")

    perfiles = args.perfiles or list(PERFILES)
    desconocidos = [x for x in perfiles if x not in PERFILES]
    if desconocidos:
        sys.exit(f"perfiles desconocidos: {', '.join(desconocidos)}")

    trabajo = Path(args.work_dir).expanduser().resolve()
    trabajo.mkdir(parents=True, exist_ok=True)
    print(f"[montaje] directorio de trabajo: {trabajo}")

    paginas, fallidos = [], []
    for i, perfil in enumerate(perfiles, 1):
        print(f"[montaje] ({i}/{len(perfiles)}) {perfil} <- ejemplo {PERFILES[perfil]}")
        pdf = prepara(perfil, PERFILES[perfil], trabajo)
        png = rasteriza(pdf, trabajo / f"{perfil}.png", args.dpi, args.pagina) if pdf else None
        if png is None:
            fallidos.append(perfil)
            continue
        paginas.append((perfil, png))

    if not paginas:
        sys.exit("[montaje] no se pudo compilar ningun perfil")

    salida = Path(args.output).expanduser()
    if salida.parent != Path(""):
        salida.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["montage"]
    for perfil, png in paginas:
        cmd += ["-label", perfil, str(png)]
    cmd += [
        "-background", "white", "-fill", "#333333", "-pointsize", "26",
        "-border", "1", "-bordercolor", "#cccccc",
        "-geometry", f"{args.ancho}x{args.alto}+14+14",
        "-tile", f"{args.columnas}x", str(salida),
    ]
    if not run(cmd, Path.cwd(), "montage"):
        sys.exit("[montaje] montage fallo")
    # montage escribe PNG de 16 bits: a 8 bits pesa la mitad y la imagen es la
    # misma (paginas de documento, sin degrade que necesite esa profundidad)
    run(["convert", str(salida), "-depth", "8", "-strip", str(salida)], Path.cwd(), "convert")

    print(f"[montaje] listo: {salida} ({len(paginas)} perfiles)")
    if fallidos:
        print(f"[montaje] no compilaron: {', '.join(fallidos)}")
    if not args.keep:
        shutil.rmtree(trabajo)
    else:
        print(f"[montaje] se conserva {trabajo}")


if __name__ == "__main__":
    main()
