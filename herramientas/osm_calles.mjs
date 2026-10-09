// Descarga de OpenStreetMap (Overpass) todas las calles y avenidas con nombre de Lázaro Cárdenas
// (sólo del municipio de Lázaro Cárdenas, Michoacán) y sus colonias, y genera
// lib/datos/calles_osm.dart para el buscador. Se corre en GitHub Actions (osm-semaforos.yml).
import fs from "fs";

const CAJA = "17.90,-102.30,18.03,-102.12"; // sur, oeste, norte, este (la ciudad y sus alrededores)
const SERVIDORES = [
  "https://overpass-api.de/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
  "https://overpass.osm.jp/api/interpreter"
];
const espera = ms => new Promise(r => setTimeout(r, ms));
async function overpass(q, intentos = 10) {
  for (let i = 0; i < intentos; i++) {
    const url = SERVIDORES[i % SERVIDORES.length];
    try {
      const r = await fetch(url + "?data=" + encodeURIComponent(q), {
        headers: { "Accept": "application/json", "User-Agent": "CombiLZC/1.0 (proyecto escolar, github.com/DagioGit/AppParadas)" }
      });
      if (!r.ok) throw new Error(String(r.status));
      return await r.json();
    } catch (e) {
      console.log("Overpass falló", url, e.message);
      await espera(10000);
    }
  }
  return null;
}

const TIPOS_VIA = "motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|pedestrian|trunk_link|primary_link|secondary_link|tertiary_link";
const datos = await overpass(`[out:json][timeout:180];
area["name"="Lázaro Cárdenas"]["boundary"="administrative"]["admin_level"="6"]->.m;
(
  way["highway"~"^(${TIPOS_VIA})$"]["name"](area.m)(${CAJA});
);
out geom;
(
  node["place"~"^(suburb|neighbourhood|quarter|village|hamlet|town|city)$"]["name"](area.m)(${CAJA});
  way["place"~"^(suburb|neighbourhood|quarter)$"]["name"](area.m)(${CAJA});
  relation["place"~"^(suburb|neighbourhood|quarter)$"]["name"](area.m)(${CAJA});
);
out center;`);
if (!datos) throw new Error("No se pudo descargar de Overpass");

const vias = datos.elements.filter(e => e.type === "way" && e.tags && e.tags.highway && e.geometry);
const lugares = datos.elements.filter(e => e.tags && e.tags.place).map(e => ({
  nombre: e.tags.name, tipo: e.tags.place,
  lat: e.lat ?? (e.center && e.center.lat), lon: e.lon ?? (e.center && e.center.lon)
})).filter(l => l.lat != null);

const dist = (a, b) => Math.hypot((a.lat - b.lat) * 110570, (a.lon - b.lon) * 105900);
const rango = { trunk: 0, motorway: 0, primary: 1, trunk_link: 1, primary_link: 1, secondary: 2, secondary_link: 2, tertiary: 3, tertiary_link: 3, unclassified: 4, residential: 5, living_street: 6, pedestrian: 6 };

// Juntar los pedazos de cada calle por nombre
const porNombre = new Map();
for (const v of vias) {
  const n = v.tags.name.trim();
  if (!porNombre.has(n)) porNombre.set(n, { puntos: [], rango: 9, largo: 0 });
  const c = porNombre.get(n);
  c.rango = Math.min(c.rango, rango[v.tags.highway] ?? 9);
  for (let i = 0; i < v.geometry.length; i++) {
    c.puntos.push(v.geometry[i]);
    if (i) c.largo += dist(v.geometry[i - 1], v.geometry[i]);
  }
}

const colonias = lugares.filter(l => /suburb|neighbourhood|quarter/.test(l.tipo));
const coloniaDe = p => {
  let mejor = null, d = 1600;
  for (const l of colonias) { const x = dist(p, l); if (x < d) { d = x; mejor = l; } }
  return mejor ? mejor.nombre : null;
};
const corto = s => s.replace(/^Avenida /, "Av. ").replace(/^Boulevard /, "Blvd. ").replace(/^Bulevar /, "Blvd. ").replace(/^Prolongación /, "Prol. ").replace(/^Calzada /, "Calz. ");
const clase = (n, r) => /^(Avenida|Av\.)/.test(n) ? "Avenida" : /^(Boulevard|Bulevar|Blvd)/.test(n) ? "Bulevar" : /^Libramiento/.test(n) ? "Libramiento"
  : /^Prolongación/.test(n) ? "Prolongación" : /^Calzada/.test(n) ? "Calzada" : /^Andador/.test(n) ? "Andador" : /^(Privada|Cerrada|Retorno|Callejón)/.test(n) ? n.split(" ")[0]
  : r <= 3 ? "Avenida" : "Calle";

const calles = [...porNombre.entries()].map(([nombre, c]) => {
  const cen = { lat: c.puntos.reduce((s, p) => s + p.lat, 0) / c.puntos.length, lon: c.puntos.reduce((s, p) => s + p.lon, 0) / c.puntos.length };
  let rep = c.puntos[0], d = Infinity;
  for (const p of c.puntos) { const x = dist(p, cen); if (x < d) { d = x; rep = p; } }
  const col = coloniaDe(rep);
  const tipo = clase(nombre, c.rango);
  return { nombre: corto(nombre), detalle: `${tipo}${col ? " · " + col : ""} · Lázaro Cárdenas`, lat: +rep.lat.toFixed(6), lon: +rep.lon.toFixed(6), rango: c.rango, largo: c.largo };
}).sort((a, b) => a.rango - b.rango || b.largo - a.largo);

const vistas = new Set();
const cols = lugares.filter(l => !vistas.has(l.nombre) && vistas.add(l.nombre)).map(l => ({
  nombre: l.nombre,
  detalle: (/village|hamlet|town|city/.test(l.tipo) ? "Localidad" : "Colonia") + " · Lázaro Cárdenas",
  lat: +l.lat.toFixed(6), lon: +l.lon.toFixed(6)
}));

const esc = s => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$");
const dart = `// GENERADO por herramientas/osm_calles.mjs — © colaboradores de OpenStreetMap (ODbL).
// Calles y avenidas con nombre del municipio de Lázaro Cárdenas, Michoacán, y sus colonias.
// El punto de cada calle es un punto sobre la calle cerca de su centro.

import 'package:latlong2/latlong.dart';

import 'lugares.dart';

const List<Lugar> callesOsm = [
${calles.map(c => `  Lugar('${esc(c.nombre)}', '${esc(c.detalle)}', TipoLugar.avenida, LatLng(${c.lat}, ${c.lon})),`).join("\n")}
];

const List<Lugar> coloniasOsm = [
${cols.map(c => `  Lugar('${esc(c.nombre)}', '${esc(c.detalle)}', TipoLugar.colonia, LatLng(${c.lat}, ${c.lon})),`).join("\n")}
];
`;
fs.writeFileSync("lib/datos/calles_osm.dart", dart);
console.log(`${vias.length} vías → ${calles.length} calles; ${cols.length} colonias/localidades`);
