// Descarga de OpenStreetMap las calles por donde se puede caminar en Lázaro Cárdenas y arma
// assets/grafo_calles.json: un grafo (cruces y tramos de calle con su nombre) para trazar
// los recorridos a pie calle por calle dentro de la app, sin internet.
// Se corre en GitHub Actions (.github/workflows/osm-semaforos.yml).
import fs from "fs";

const CAJA = "17.90,-102.30,18.03,-102.12";
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
      const r = await fetch(url, {
        method: "POST",
        body: "data=" + encodeURIComponent(q),
        headers: { "Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json", "User-Agent": "CombiLZC/1.0 (proyecto escolar, github.com/DagioGit/AppParadas)" }
      });
      if (!r.ok) throw new Error(String(r.status));
      return await r.json();
    } catch (e) {
      console.log("Overpass falló", url, e.message);
      await espera(12000);
    }
  }
  return null;
}

const TIPOS = "trunk|primary|secondary|tertiary|unclassified|residential|living_street|pedestrian|footway|path|steps|service|track|trunk_link|primary_link|secondary_link|tertiary_link|cycleway|road";
const datos = await overpass(`[out:json][timeout:240];
way["highway"~"^(${TIPOS})$"]["foot"!~"^no$"]["access"!~"^(private|no)$"](${CAJA});
out body;
>;
out skel qt;`);
if (!datos) throw new Error("No se pudo descargar de Overpass");

const nodos = new Map();
for (const e of datos.elements) if (e.type === "node") nodos.set(e.id, [e.lat, e.lon]);
const vias = datos.elements.filter(e => e.type === "way" && e.nodes && e.nodes.length > 1);
const usos = new Map();
for (const v of vias) v.nodes.forEach((n, i) => usos.set(n, (usos.get(n) || 0) + (i === 0 || i === v.nodes.length - 1 ? 2 : 1)));

const dist = (a, b) => Math.hypot((a[0] - b[0]) * 110570, (a[1] - b[1]) * 105900);
// Douglas-Peucker (metros) para aligerar las curvas
function simplificar(pts, tol = 2.5) {
  if (pts.length < 3) return pts;
  const [a, b] = [pts[0], pts[pts.length - 1]];
  let iMax = 0, dMax = 0;
  const ax = a[1] * 105900, ay = a[0] * 110570, bx = b[1] * 105900, by = b[0] * 110570;
  const L = Math.hypot(bx - ax, by - ay) || 1;
  for (let i = 1; i < pts.length - 1; i++) {
    const px = pts[i][1] * 105900, py = pts[i][0] * 110570;
    const d = Math.abs((bx - ax) * (ay - py) - (ax - px) * (by - ay)) / L;
    if (d > dMax) { dMax = d; iMax = i; }
  }
  if (dMax <= tol) return [a, b];
  return [...simplificar(pts.slice(0, iMax + 1), tol).slice(0, -1), ...simplificar(pts.slice(iMax), tol)];
}

const corto = s => s.replace(/^Avenida /, "Av. ").replace(/^Boulevard /, "Blvd. ").replace(/^Prolongación /, "Prol. ");
const nombres = [""], idxNombre = new Map([["", 0]]);
const nombreDe = v => {
  const t = v.tags || {};
  let n = t.name ? corto(t.name) : "";
  if (!n && /footway|path|pedestrian|steps/.test(t.highway)) n = t.footway === "crossing" || t.highway === "crossing" ? "el cruce peatonal" : "el andador";
  if (!idxNombre.has(n)) { idxNombre.set(n, nombres.length); nombres.push(n); }
  return idxNombre.get(n);
};

// Vértices: cruces y extremos
const vert = new Map(); // id OSM -> índice
const vLat = [], vLng = [];
const vertice = id => {
  if (!vert.has(id)) { vert.set(id, vLat.length); const p = nodos.get(id); vLat.push(p[0]); vLng.push(p[1]); }
  return vert.get(id);
};
const aristas = [];
for (const v of vias) {
  const nom = nombreDe(v);
  let tramo = [v.nodes[0]];
  for (let i = 1; i < v.nodes.length; i++) {
    tramo.push(v.nodes[i]);
    if ((usos.get(v.nodes[i]) || 0) >= 2 || i === v.nodes.length - 1) {
      const pts = tramo.map(n => nodos.get(n)).filter(Boolean);
      if (pts.length >= 2) {
        let largo = 0;
        for (let k = 1; k < pts.length; k++) largo += dist(pts[k - 1], pts[k]);
        if (largo > 0.5) aristas.push({ a: vertice(tramo[0]), b: vertice(tramo[tramo.length - 1]), largo, nom, pts: simplificar(pts) });
      }
      tramo = [v.nodes[i]];
    }
  }
}

// Quedarse con la parte conectada más grande
const ady = vLat.map(() => []);
aristas.forEach((e, i) => { ady[e.a].push(i); ady[e.b].push(i); });
const comp = new Int32Array(vLat.length).fill(-1);
let mejor = -1, tamMejor = 0, c = 0;
for (let s = 0; s < vLat.length; s++) {
  if (comp[s] >= 0) continue;
  const pila = [s]; comp[s] = c; let tam = 0;
  while (pila.length) { const x = pila.pop(); tam++; for (const ei of ady[x]) { const e = aristas[ei]; const y = e.a === x ? e.b : e.a; if (comp[y] < 0) { comp[y] = c; pila.push(y); } } }
  if (tam > tamMejor) { tamMejor = tam; mejor = c; }
  c++;
}
const nuevo = new Int32Array(vLat.length).fill(-1);
const V = [];
for (let i = 0; i < vLat.length; i++) if (comp[i] === mejor) { nuevo[i] = V.length / 2; V.push(Math.round(vLat[i] * 1e5), Math.round(vLng[i] * 1e5)); }
const E = [];
for (const e of aristas) {
  if (comp[e.a] !== mejor) continue;
  const medio = e.pts.slice(1, -1).flatMap(p => [Math.round(p[0] * 1e5), Math.round(p[1] * 1e5)]);
  E.push([nuevo[e.a], nuevo[e.b], Math.round(e.largo), e.nom, medio]);
}
fs.mkdirSync("assets", { recursive: true });
fs.writeFileSync("assets/grafo_calles.json", JSON.stringify({ v: V, e: E, n: nombres }));
console.log(`${vias.length} vías → ${V.length / 2} cruces, ${E.length} tramos, ${nombres.length} nombres; ${(fs.statSync("assets/grafo_calles.json").size / 1024).toFixed(0)} KB`);
