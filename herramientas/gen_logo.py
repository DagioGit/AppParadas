"""Logo de CombiLZC (combi de frente sobre gris de la Ruta 1) y todos los íconos de la app.

Uso: python3 herramientas/gen_logo.py
"""
import pathlib
from PIL import Image, ImageDraw

RAIZ = pathlib.Path(__file__).resolve().parent.parent
GRIS, BLANCO, GRAFITO, AMARILLO = (110, 110, 115), (255, 255, 255), (43, 50, 55), (242, 194, 0)


def logo(tam=1024, redondo=True, margen=0.0):
    """Dibuja el logo en un lienzo de 170 unidades (como el boceto) escalado a `tam` px."""
    s = tam / 170 * (1 - 2 * margen)
    o = tam * margen
    im = Image.new("RGBA", (tam, tam), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    R = lambda x0, y0, x1, y1: [o + x0 * s, o + y0 * s, o + x1 * s, o + y1 * s]
    if redondo:
        d.rounded_rectangle([0, 0, tam - 1, tam - 1], radius=tam * 0.225, fill=GRIS)
    else:
        d.rectangle([0, 0, tam, tam], fill=GRIS)
    d.rounded_rectangle(R(35, 28, 135, 132), radius=22 * s, fill=BLANCO)          # carrocería
    d.rounded_rectangle(R(48, 41, 122, 79), radius=8 * s, fill=GRAFITO)            # parabrisas
    d.ellipse(R(48, 100, 64, 116), fill=AMARILLO)                                  # faros
    d.ellipse(R(106, 100, 122, 116), fill=AMARILLO)
    d.rounded_rectangle(R(72, 102, 98, 114), radius=3 * s, fill=GRAFITO)          # parrilla
    d.rounded_rectangle(R(45, 130, 63, 146), radius=4 * s, fill=GRAFITO)          # llantas
    d.rounded_rectangle(R(107, 130, 125, 146), radius=4 * s, fill=GRAFITO)
    return im


def guardar(im, ruta, tam, fondo=False):
    ruta = RAIZ / ruta
    ruta.parent.mkdir(parents=True, exist_ok=True)
    x = im.resize((tam, tam), Image.LANCZOS)
    if fondo:  # iOS no acepta transparencia
        f = Image.new("RGB", x.size, GRIS)
        f.paste(x, mask=x.split()[3])
        x = f
    x.save(ruta)


redondo = logo(1024, redondo=True)
cuadrado = logo(1024, redondo=False)
seguro = logo(1024, redondo=False, margen=0.12)  # para íconos "maskable" (Android recorta en círculo)

guardar(redondo, "assets/logo.png", 1024)
for carpeta, t in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    guardar(redondo, f"android/app/src/main/res/mipmap-{carpeta}/ic_launcher.png", t)
ios = RAIZ / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
for f in ios.glob("Icon-App-*.png"):
    medida, escala = f.stem.replace("Icon-App-", "").split("@")
    t = round(float(medida.split("x")[0]) * int(escala.replace("x", "")))
    guardar(cuadrado, f.relative_to(RAIZ), t, fondo=True)
guardar(redondo, "web/icons/Icon-192.png", 192)
guardar(redondo, "web/icons/Icon-512.png", 512)
guardar(seguro, "web/icons/Icon-maskable-192.png", 192)
guardar(seguro, "web/icons/Icon-maskable-512.png", 512)
guardar(redondo, "web/favicon.png", 64)
print("íconos listos")
