"""Ajusta las carpetas que genera `flutter create`: nombre visible, internet y permiso de ubicación.

Se corre una sola vez, justo después de crear android/, ios/ y web/.
"""
import json
import pathlib
import re

RAIZ = pathlib.Path(__file__).resolve().parent.parent
NOMBRE = "AppParadas"
MOTIVO = "AppParadas usa tu ubicación para buscar las combis y paradas más cercanas."

# ---------- Android ----------
manifiesto = RAIZ / "android/app/src/main/AndroidManifest.xml"
if manifiesto.exists():
    m = manifiesto.read_text()
    permisos = [
        "android.permission.INTERNET",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
    ]
    nuevos = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in permisos if p not in m)
    m = m.replace("    <application", nuevos + "    <application", 1)
    m = re.sub(r'android:label="[^"]*"', f'android:label="{NOMBRE}"', m, count=1)
    manifiesto.write_text(m)

# ---------- iOS ----------
plist = RAIZ / "ios/Runner/Info.plist"
if plist.exists():
    p = plist.read_text()
    p = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", rf"\g<1>{NOMBRE}\g<2>", p)
    if "NSLocationWhenInUseUsageDescription" not in p:
        extra = f"\t<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>{MOTIVO}</string>\n"
        i = p.rfind("</dict>")
        p = p[:i] + extra + p[i:]
    plist.write_text(p)

# ---------- Web ----------
index = RAIZ / "web/index.html"
if index.exists():
    h = index.read_text()
    h = re.sub(r"<title>[^<]*</title>", f"<title>{NOMBRE}</title>", h)
    h = h.replace('content="app_paradas"', f'content="{NOMBRE}"')
    h = h.replace('content="A new Flutter project."', 'content="Rutas de combi de Lázaro Cárdenas y la ruta más rápida."')
    if "maplibre-gl" not in h:
        h = h.replace(f"<title>{NOMBRE}</title>", f"<title>{NOMBRE}</title>\n  <script src=\"https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js\"></script>\n  <link href=\"https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css\" rel=\"stylesheet\" />")
    index.write_text(h)

manifest = RAIZ / "web/manifest.json"
if manifest.exists():
    d = json.loads(manifest.read_text())
    d["name"] = NOMBRE
    d["short_name"] = NOMBRE
    d["description"] = "Rutas de combi de Lázaro Cárdenas y la ruta más rápida."
    d["background_color"] = "#F2F2F7"
    d["theme_color"] = "#111111"
    manifest.write_text(json.dumps(d, ensure_ascii=False, indent=4) + "\n")

print("Plataformas configuradas para", NOMBRE)
