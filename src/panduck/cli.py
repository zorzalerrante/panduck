"""panduck: compila documentos markdown academicos con pandoc.

Centraliza templates, perfiles (defaults de pandoc), CSL y filtros Lua
que antes estaban copiados en cada repositorio. Los perfiles viven en
data/defaults/, los assets en data/templates|csl|filters|texmf.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tomllib
from importlib.resources import files
from pathlib import Path

DATA = Path(str(files("panduck").joinpath("data")))

OUTPUT_EXT = {"pdf": "pdf", "docx": "docx", "tex": "tex", "html": "html"}


def pandoc_bin():
    return os.environ.get("PANDUCK_PANDOC", "pandoc")


def typst_bin():
    return os.environ.get("PANDUCK_TYPST", "typst")


def typst_font_args():
    """`--font-path` para que typst encuentre fuentes de usuario.

    typst (a diferencia de fontconfig) no escanea `~/.fonts` ni
    `~/.local/share/fonts`, asi que las fuentes instaladas por el usuario no
    aparecen salvo que se le pasen explicitamente. `PANDUCK_FONT_PATH` (o
    `TYPST_FONT_PATHS`) agrega rutas extra, y un directorio `fonts/` junto al
    documento sirve para las fuentes propias de ese documento (mismo espiritu que
    `panduck-pre.lua`: lo especifico vive con las fuentes, no en panduck).
    `data/fonts/` son las fuentes que panduck trae vendorizadas (p. ej. Fira Math,
    el default de matematica de las slides), siempre disponibles sin instalar
    nada. Nota: el nombre de familia que usa typst es el typographic family de la
    fuente (p. ej. "Recursive Sn Lnr St", no "Recursive Sans Linear Static");
    verificar con `typst fonts`.
    """
    paths = []
    extra = os.environ.get("PANDUCK_FONT_PATH") or os.environ.get("TYPST_FONT_PATHS")
    if extra:
        paths += extra.split(os.pathsep)
    paths += [Path("fonts"), DATA / "fonts",
              Path.home() / ".fonts", Path.home() / ".local" / "share" / "fonts"]
    args = []
    for p in paths:
        if Path(p).is_dir():
            args += ["--font-path", str(p)]
    return args


def typst_package_args():
    """`--package-path` con los paquetes typst vendorizados (toffee-tufte, drafting).

    Es el analogo de TEXINPUTS con data/texmf: los paquetes viven en el repo, se
    importan como `@local/<nombre>:<version>` y compilan sin red. No afecta a los
    `@preview` que importe el documento: esos siguen resolviendose desde la cache
    normal de typst.
    """
    packages = DATA / "typst-packages"
    return ["--package-path", str(packages)] if packages.is_dir() else []


def profile_format(profile):
    """Lee el writer (`to:`) declarado en el perfil; None si no lo fija."""
    f = DATA / "defaults" / f"{profile}.yaml"
    if f.exists():
        m = re.search(r"^to:\s*(\S+)", f.read_text(), re.M)
        if m:
            return m.group(1)
    return None


def profile_png_dpi(profile):
    """DPI de exportacion PNG declarado por el perfil (comentario `# panduck-png: N`).

    None si el perfil no pide PNG. Se lee de un comentario porque pandoc valida
    las claves de los defaults y rechazaria una clave propia.
    """
    f = DATA / "defaults" / f"{profile}.yaml"
    if f.exists():
        m = re.search(r"^#\s*panduck-png:\s*(\d+)", f.read_text(), re.M)
        if m:
            return int(m.group(1))
    return None


def pandoc_env():
    """PATH con pandoc-crossref y TEXINPUTS con las clases de texmf (elsarticle, sn-jnl)."""
    env = os.environ.copy()
    cabal = Path.home() / ".cabal" / "bin"
    if shutil.which("pandoc-crossref") is None and (cabal / "pandoc-crossref").exists():
        env["PATH"] = f"{cabal}{os.pathsep}{env.get('PATH', '')}"
    # el // hace la busqueda recursiva; el : final preserva el path por defecto de TeX
    env["TEXINPUTS"] = f"{DATA / 'texmf'}//:" + env.get("TEXINPUTS", "")
    return env


def run(cmd, **kwargs):
    print("[panduck]", " ".join(str(c) for c in cmd))
    result = subprocess.run([str(c) for c in cmd], env=pandoc_env(), **kwargs)
    if result.returncode != 0:
        sys.exit(result.returncode)
    return result


def discover_sources(given):
    """Si no se pasan fuentes, busca head.yaml + main.md en el directorio actual."""
    if given:
        return [Path(s) for s in given]
    sources = [Path(p) for p in ("head.yaml", "main.md") if Path(p).exists()]
    if not any(s.suffix == ".md" for s in sources):
        sys.exit("panduck: no encontre main.md; indica las fuentes explicitamente")
    return sources


def base_command(args, extra):
    sources = discover_sources(args.sources)
    cmd = [pandoc_bin(), "--data-dir", DATA, "--defaults", args.profile]
    # defaults local apilado: si hay un panduck.yaml en el directorio, se agrega
    # despues del perfil. Pandoc concatena las listas (filters) entre --defaults,
    # asi que sus filtros corren DESPUES de crossref+citeproc, y sus escalares
    # (pdf-engine, variables, ...) sobreescriben los del perfil.
    local = Path("panduck.yaml")
    if local.exists():
        cmd += ["--defaults", "./panduck.yaml"]
        print(f"[panduck] defaults local: {local}")
    cmd += sources
    if args.anonymous:
        cmd += ["--metadata", "anonymous=true"]
    cmd += extra
    return cmd, sources


def output_name(sources, ext):
    stem = next(s.stem for s in sources if s.suffix == ".md")
    return f"{stem}.{ext}"


def cmd_build(args, extra):
    cmd, sources = base_command(args, extra)
    # perfiles que escriben typst (p. ej. slides) se compilan en dos pasos:
    # pandoc genera el .typ y typst lo convierte a PDF (rapido, sin LaTeX)
    if profile_format(args.profile) == "typst" and args.to == "pdf":
        stem = next(s.stem for s in sources if s.suffix == ".md")
        typ = f"{stem}.typ"
        run(cmd + ["-o", typ])
        typst_args = typst_font_args() + typst_package_args()
        out = args.output or f"{stem}.pdf"
        run([typst_bin(), "compile", *typst_args, typ, out])
        print(f"[panduck] listo: {out}")
        # exportacion a PNG (una imagen por pagina). Algunos perfiles (instagram)
        # la piden por defecto via `# panduck-png: N`; --png/--no-png la fuerzan.
        default_dpi = profile_png_dpi(args.profile)
        want_png = args.png or (default_dpi is not None and not args.no_png)
        if want_png:
            dpi = args.dpi or default_dpi or 144
            base = out[:-4] if out.endswith(".pdf") else stem
            run([typst_bin(), "compile", *typst_args, typ, f"{base}-{{0p}}.png", "--ppi", str(dpi)])
            print(f"[panduck] PNG: {base}-NN.png ({dpi} ppi)")
        return
    # cada perfil puede traer un reference-doc de Word en reference/<perfil>-reference.docx;
    # pandoc solo lo usa para docx (lo resuelve por ruta, no desde el data-dir)
    if args.to == "docx":
        ref = DATA / "reference" / f"{args.profile}-reference.docx"
        if ref.exists():
            cmd += ["--reference-doc", str(ref)]
    out = args.output or output_name(sources, OUTPUT_EXT[args.to])
    run(cmd + ["-o", out])
    print(f"[panduck] listo: {out}")


def cmd_dist(args, extra):
    """Empaqueta el .tex y sus imagenes en un directorio para submission."""
    cmd, sources = base_command(args, extra)
    dist = Path(args.dir)
    dist.mkdir(parents=True, exist_ok=True)
    out = dist / output_name(sources, "tex")
    run(cmd + ["--to", "latex", "-o", out])

    tex = out.read_text()
    images = sorted(set(re.findall(r"[^{}\s]+\.(?:pdf|png|jpe?g|eps)", tex)))
    for img in images:
        src = Path(img)
        if not src.exists() or src.resolve() == out.resolve():
            continue
        shutil.copy(src, dist / src.name)
        tex = tex.replace(img, src.name)
        print(f"[panduck] imagen: {img} -> {dist / src.name}")
    out.write_text(tex)
    print(f"[panduck] listo: {out}")


def cmd_from_template(name, args):
    """Genera titlepage o cover-letter en docx a partir de head.yaml.

    Usa el template local ({name}-template.md) si existe; si no, el de panduck.
    """
    local = Path(f"{name}-template.md")
    template = local if local.exists() else DATA / "templates" / f"{name}.md"
    meta = Path(args.metadata)
    if not meta.exists():
        sys.exit(f"panduck: no encontre {meta}")
    out = args.output or f"{name}.docx"
    print(f"[panduck] template: {template}")
    filled = run(
        [pandoc_bin(), "--wrap=none", "--template", template, meta],
        capture_output=True, text=True,
    ).stdout
    run([pandoc_bin(), "-f", "markdown", "-o", out], input=filled, text=True)
    print(f"[panduck] listo: {out}")


TEXT_SUFFIXES = {".md", ".yaml", ".yml", ".bib", ".tex", ".txt"}


def ask_values(prompts, use_defaults):
    """Pregunta cada campo del manifiesto (o usa los defaults con --yes)."""
    values = {}
    for p in prompts:
        key = p["key"]
        default = str(p.get("default", ""))
        if use_defaults:
            values[key] = default
        else:
            answer = input(f"{p.get('question', key)} [{default}]: ").strip()
            values[key] = answer or default
    return values


def substitute(text, values):
    for key, val in values.items():
        text = text.replace("{{" + key + "}}", val)
    return text


def cmd_init(args):
    """Copia un ejemplo inicial al directorio actual, sin sobreescribir.

    Si el ejemplo trae prompts.toml, pregunta los valores iniciales y los
    sustituye en los marcadores {{clave}} de los archivos de texto.
    """
    example = DATA / "examples" / args.example
    if not example.is_dir():
        names = ", ".join(p.name for p in sorted((DATA / "examples").iterdir()))
        sys.exit(f"panduck: no existe el ejemplo {args.example}; disponibles: {names}")

    manifest = example / "prompts.toml"
    values = {}
    if manifest.exists():
        with manifest.open("rb") as f:
            prompts = tomllib.load(f).get("prompts", [])
        values = ask_values(prompts, args.yes)

    for src in sorted(example.iterdir()):
        if src.name == "prompts.toml":
            continue
        dest = Path(src.name)
        if dest.exists():
            print(f"[panduck] ya existe, no se toca: {dest}")
            continue
        if values and src.suffix in TEXT_SUFFIXES:
            dest.write_text(substitute(src.read_text(), values))
        else:
            shutil.copy(src, dest)
        print(f"[panduck] creado: {dest}")


def cmd_profiles(args):
    print(f"directorio de datos: {DATA}\n")
    print("perfiles (--profile):")
    for p in sorted((DATA / "defaults").glob("*.yaml")):
        print(f"  {p.stem}")
    print("\nestilos CSL (csl: <nombre> en head.yaml):")
    for p in sorted((DATA / "csl").glob("*.csl")):
        print(f"  {p.name}")


def add_common(parser):
    parser.add_argument("sources", nargs="*", help="fuentes (default: head.yaml main.md)")
    parser.add_argument("-p", "--profile", default="default", help="perfil de defaults")
    parser.add_argument("--anonymous", action="store_true", help="anonimiza autores (blind review)")


def main():
    parser = argparse.ArgumentParser(prog="panduck", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_build = sub.add_parser("build", help="compila el documento")
    add_common(p_build)
    p_build.add_argument("-t", "--to", choices=OUTPUT_EXT, default="pdf")
    p_build.add_argument("-o", "--output")
    p_build.add_argument("--png", action="store_true",
                         help="exporta tambien una PNG por pagina (perfiles typst)")
    p_build.add_argument("--no-png", action="store_true",
                         help="desactiva la exportacion PNG por defecto del perfil")
    p_build.add_argument("--dpi", type=int, help="DPI de la exportacion PNG (default del perfil o 144)")

    p_dist = sub.add_parser("dist", help="empaqueta tex + imagenes para submission")
    add_common(p_dist)
    p_dist.add_argument("--dir", default="dist", help="directorio de salida")

    for name in ("titlepage", "cover-letter", "highlights"):
        p = sub.add_parser(name, help=f"genera {name}.docx desde head.yaml")
        p.add_argument("-m", "--metadata", default="head.yaml")
        p.add_argument("-o", "--output")

    p_init = sub.add_parser("init", help="copia un ejemplo inicial al directorio actual")
    p_init.add_argument("example", help="nombre del ejemplo (por ejemplo dcc-informe)")
    p_init.add_argument("-y", "--yes", action="store_true",
                        help="usa los valores por defecto sin preguntar")

    sub.add_parser("profiles", help="lista perfiles y estilos disponibles")

    args, extra = parser.parse_known_args()
    if args.command == "build":
        cmd_build(args, extra)
    elif args.command == "dist":
        cmd_dist(args, extra)
    elif args.command == "init":
        cmd_init(args)
    elif args.command == "profiles":
        cmd_profiles(args)
    else:
        cmd_from_template(args.command, args)


if __name__ == "__main__":
    main()
