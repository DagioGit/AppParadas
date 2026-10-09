// Descarga de OpenStreetMap (Overpass) los semáforos de la ciudad de Lázaro Cárdenas y genera
// lib/datos/semaforos_osm.dart. Se corre en GitHub Actions (.github/workflows/osm-semaforos.yml)
// porque necesita internet. Junta los semáforos de un mismo cruce (OSM suele marcar uno por
// cada sentido) y les pone el nombre de las calles que se cruzan.
import fs from "fs";

const CAJA = "17.90,-102.27,18.02,-102.13"; // sur, oeste, norte, este
const SERVIDORES = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter", "https://overpass.private.coffee/api/interpreter"];
const espera = ms => new Promise(r => setTimeout(r, ms));

const q = `[out:json][timeout:120];
node["highway"="traffic_signals"](${CAJA})->.s;
.s out;
way(bn.s)["highway"]["name"];
out body;`;

let datos = null;
for (let intento = 0; intento < 9 && !datos; intento++) {
  const url = SERVIDORES[intento % SERVIDORES.length];
  try {
    const r = await fetch(url, { method: "POST", body: "data=" + encodeURIComponent(q), headers: { "Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json", "User-Agent": "CombiLZC/1.0 (proyecto escolar, github.com/DagioGit/AppParadas)" } });
    if (!r.ok) throw new Error(r.status + " " + (await r.text()).slice(0, 200));
    datos = await r.json();
  } catch (e) {
    console.log("Overpass falló", url, e.message);
    await espera(15000);
  }
}
if (!datos) throw new Error("No se pudo descargar de Overpass");

const nodos = datos.elements.filter(e => e.type === "node");
const vias = datos.elements.filter(e => e.type === "way");
const callesDe = new Map();
for (const v of vias) for (const n of v.nodes) {
  if (!callesDe.has(n)) callesDe.set(n, new Set());
  callesDe.get(n).add(v.tags.name);
}
const dist = (a, b) => Math.hypot((a.lat - b.lat) * 110570, (a.lon - b.lon) * 105900);

// Agrupar los semáforos a menos de 45 m (mismo cruce)
const grupos = [];
for (const n of nodos) {
  const g = grupos.find(g => g.some(m => dist(m, n) < 45));
  if (g) g.push(n); else grupos.push([n]);
}
const corto = s => s.replace(/^Avenida /, "Av. ").replace(/^Boulevard /, "Blvd. ").replace(/^Calle /, "").replace(/^Prolongación /, "Prol. ");
const lista = grupos.map(g => {
  const lat = g.reduce((s, n) => s + n.lat, 0) / g.length;
  const lon = g.reduce((s, n) => s + n.lon, 0) / g.length;
  const calles = new Set();
  g.forEach(n => (callesDe.get(n.id) || []).forEach(c => calles.add(c)));
  const cs = [...calles].sort((a, b) => (/Lázaro Cárdenas/.test(b) ? 1 : 0) - (/Lázaro Cárdenas/.test(a) ? 1 : 0));
  const nombre = cs.length >= 2 ? `Semáforo de ${corto(cs[0])} y ${corto(cs[1])}` : cs.length === 1 ? `Semáforo de ${corto(cs[0])}` : "Semáforo";
  const detalle = cs.length ? cs.map(corto).join(" con ") : "Cruce con semáforo";
  return { nombre, detalle, lat: +lat.toFixed(6), lon: +lon.toFixed(6) };
}).sort((a, b) => b.lat - a.lat);

const esc = s => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
const dart = `// GENERADO por herramientas/osm_semaforos.mjs — © colaboradores de OpenStreetMap (ODbL).
// Semáforos de la ciudad de Lázaro Cárdenas (un punto por cruce).

import 'package:latlong2/latlong.dart';

import 'semaforos.dart';

const List<Semaforo> semaforosOsm = [
${lista.map(s => `  Semaforo('${esc(s.nombre)}', '${esc(s.detalle)}', LatLng(${s.lat}, ${s.lon})),`).join("\n")}
];
`;
fs.writeFileSync("lib/datos/semaforos_osm.dart", dart);
console.log(`${nodos.length} semáforos en OSM → ${lista.length} cruces`);
