"""Convierte la Caseta LZC de la página web (caras de SketchUp, metros, Z arriba) en piezas
rectangulares que el mapa 3D puede extruir. Genera lib/datos/caseta_lzc.dart.

Uso: python3 herramientas/gen_caseta.py
"""
import json
import pathlib
from collections import OrderedDict, Counter

RAIZ = pathlib.Path(__file__).resolve().parent.parent
COLORES = {
    "LZC_Concreto": "#c8c4bc", "LZC_Tactil": "#f2c200", "LZC_Grafito": "#2b3237", "LZC_Acento": "#f2c200",
    "LZC_Cristal": "#cde2ea", "LZC_Plafon": "#e2e3e0", "LZC_Madera": "#9e683c", "LZC_Panel_Solar": "#1c2f52",
    "LZC_Aluminio": "#bec4c8", "LZC_LED": "#fafcff", "LZC_Mapa": "#f0f0ec", "LZC_Letrero": "#1e262c",
    "LZC_ISA": "#1f5caa", "LZC_Bote_Organico": "#2f7d5b", "LZC_Bote_Inorganico": "#70787e", "LZC_USB": "#14181c",
    "LZC_Disco": "#f2c200",
}
FORZAR = {"Cubierta": "LZC_Grafito", "Panel_1": "LZC_Panel_Solar", "Panel_2": "LZC_Panel_Solar",
          "Letrero_Frontal": "LZC_Acento", "Modulo_USB": "LZC_Acento", "Disco": "LZC_Disco",
          "Bote_Organico": "LZC_Bote_Organico", "Bote_Inorganico": "LZC_Bote_Inorganico"}

caras = json.loads((RAIZ / "herramientas/caseta-lzc-caras.json").read_text())
grupos = OrderedDict()
for c in caras:
    grupos.setdefault(c["g"], []).append(c)

piezas = []
for nombre, fs in grupos.items():
    pts = [p for f in fs for p in f["p"]]
    xs, ys, zs = [p[0] for p in pts], [p[1] for p in pts], [p[2] for p in pts]
    x0, x1, y0, y1, z0, z1 = min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)
    # Las piezas planas (área ISA) se levantan un centímetro para que se vean
    if z1 - z0 < 0.01:
        z1 = z0 + 0.012
    mat = FORZAR.get(nombre) or Counter(f["m"] for f in fs).most_common(1)[0][0]
    piezas.append((nombre, x0, x1, y0, y1, z0, z1, COLORES.get(mat, "#2b3237")))

lineas = [
    "// GENERADO por herramientas/gen_caseta.py a partir de la Caseta LZC de la página web",
    "// (modelo de SketchUp). Medidas en metros: x a lo largo de la calle, y de la guarnición (−)",
    "// al respaldo (+), z hacia arriba.",
    "",
    "class PiezaCaseta {",
    "  final String nombre;",
    "  final double x0, x1, y0, y1, z0, z1;",
    "  final String color;",
    "  const PiezaCaseta(this.nombre, this.x0, this.x1, this.y0, this.y1, this.z0, this.z1, this.color);",
    "}",
    "",
    "const List<PiezaCaseta> piezasCaseta = [",
]
for n, x0, x1, y0, y1, z0, z1, col in piezas:
    lineas.append(f"  PiezaCaseta('{n}', {x0:.3f}, {x1:.3f}, {y0:.3f}, {y1:.3f}, {z0:.3f}, {z1:.3f}, '{col}'),")
lineas.append("];")
(RAIZ / "lib/datos/caseta_lzc.dart").write_text("\n".join(lineas) + "\n")
print(len(piezas), "piezas")
