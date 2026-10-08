// Genera lib/datos/rutas_datos.dart a partir de geo.json (OSM/OSRM) y ruta2.json (página web).
import fs from "fs";
const dir = new URL(".", import.meta.url).pathname;
const geo = JSON.parse(fs.readFileSync(dir + "geo.json", "utf8"));
const r2 = JSON.parse(fs.readFileSync(dir + "ruta2.json", "utf8"));
const salida = process.argv[2];

const rad = Math.PI / 180;
const dist = (a, b) => {
  const x = (b[1] - a[1]) * rad * Math.cos(((a[0] + b[0]) / 2) * rad);
  const y = (b[0] - a[0]) * rad;
  return Math.hypot(x, y) * 6371000;
};

function sinEspolones(pts) {
  let p = pts.slice();
  let cambio = true;
  while (cambio) {
    cambio = false;
    for (let i = 1; i < p.length - 1; i++) {
      if (dist(p[i - 1], p[i + 1]) < 6) { p.splice(i, 2); cambio = true; break; }
      if (dist(p[i - 1], p[i]) < 0.5) { p.splice(i, 1); cambio = true; break; }
    }
  }
  return p;
}

function dp(pts, tol) {
  const k = 111320, c = Math.cos(17.96 * rad);
  const P = pts.map(p => [p[1] * k * c, p[0] * 110574]);
  const keep = new Array(pts.length).fill(false);
  keep[0] = keep[pts.length - 1] = true;
  const st = [[0, pts.length - 1]];
  while (st.length) {
    const [a, b] = st.pop();
    if (b - a < 2) continue;
    let md = 0, mi = -1;
    const [ax, ay] = P[a], [bx, by] = P[b];
    const L = Math.hypot(bx - ax, by - ay);
    for (let i = a + 1; i < b; i++) {
      const d = L < 0.01 ? Math.hypot(P[i][0] - ax, P[i][1] - ay)
        : Math.abs((bx - ax) * (ay - P[i][1]) - (ax - P[i][0]) * (by - ay)) / L;
      if (d > md) { md = d; mi = i; }
    }
    if (md > tol) { keep[mi] = true; st.push([a, mi], [mi, b]); }
  }
  return pts.filter((_, i) => keep[i]);
}

function acumulado(t) {
  const a = [0];
  for (let i = 1; i < t.length; i++) a.push(a[i - 1] + dist(t[i - 1], t[i]));
  return a;
}

// Proyecta un punto sobre el trazo, buscando sólo entre las distancias [desde, hasta].
function proyectar(t, ac, q, desde = 0, hasta = Infinity) {
  let mejor = null;
  const c = Math.cos(q[0] * rad);
  for (let i = 0; i < t.length - 1; i++) {
    if (ac[i + 1] < desde || ac[i] > hasta) continue;
    const ax = t[i][1] * c, ay = t[i][0], bx = t[i + 1][1] * c, by = t[i + 1][0];
    const qx = q[1] * c, qy = q[0];
    const dx = bx - ax, dy = by - ay;
    const L2 = dx * dx + dy * dy || 1e-18;
    let u = ((qx - ax) * dx + (qy - ay) * dy) / L2;
    u = Math.max(0, Math.min(1, u));
    const p = [t[i][0] + (t[i + 1][0] - t[i][0]) * u, t[i][1] + (t[i + 1][1] - t[i][1]) * u];
    const s = ac[i] + (ac[i + 1] - ac[i]) * u;
    if (s < desde || s > hasta) continue;
    const d = dist(p, q);
    if (!mejor || d < mejor.d) mejor = { d, s, p };
  }
  return mejor;
}

function puntoEn(t, ac, s) {
  for (let i = 0; i < t.length - 1; i++) {
    if (ac[i + 1] >= s) {
      const u = (s - ac[i]) / (ac[i + 1] - ac[i] || 1);
      return [t[i][0] + (t[i + 1][0] - t[i][0]) * u, t[i][1] + (t[i + 1][1] - t[i][1]) * u];
    }
  }
  return t[t.length - 1];
}

const corta = n => n.replace(/^Avenida /, "Av. ").replace(/^Prolongación /, "Prol. ").replace(/^Calle /, "Calle ");

// ---------------- Ruta 1 ----------------
const r1t = sinEspolones(geo.R1);
const r1a = acumulado(r1t);
const mitad = r1a[r1t.findIndex(p => p[0] < 17.937)] ;
const R1_PARADAS = [
  ["Glorieta Las Palmas", [17.97170, -102.20610], "Merza Mayoreo, City Express y la gasolinera; conecta con Prol. Tulipanes y Blvd. de las Islas"],
  ["Hospital General", [17.96720, -102.20250], "Hospital General y talleres de la avenida"],
  ["Monumento al Minero", [17.96480, -102.20090], "Hospital IMSS a dos cuadras y Chevrolet"],
  ["Palacio Municipal", [17.96240, -102.19880], "Palacio Municipal, INE, Plaza Tabachines y Centro Cultural Flamingos"],
  ["Plaza Zirahuén", [17.95975, -102.19650], "Monumento a Lázaro Cárdenas, Correos, bancos y la Secundaria Técnica 12"],
  ["Monumento a Melchor Ocampo", [17.95540, -102.19330], "El corazón del centro: tiendas, farmacias, bancos y la Primaria Melchor Ocampo"],
  ["Plaza Voluntad de Acero", [17.95130, -102.19020], "Porto Hotel, la Heroica Escuela Naval Militar y la Primaria 1 de Mayo"],
  ["Malecón de la Cultura", [17.94640, -102.18860], "El malecón: camellón con andadores, bancas y vista al mar"],
  ["Teatro APILAC", [17.94110, -102.18800], "Teatro del puerto; la combi da vuelta en el retorno y regresa"],
];
const r1Paradas = [];
R1_PARADAS.forEach(([n, q, d], i) => {
  const ida = proyectar(r1t, r1a, q, 0, mitad);
  r1Paradas.push({ id: "R1-" + (i + 1) + "i", nombre: n, sentido: "Hacia el malecón", desc: d, s: ida.s, p: ida.p });
});
R1_PARADAS.slice().reverse().forEach(([n, q, d], k) => {
  const i = R1_PARADAS.length - 1 - k;
  const vu = proyectar(r1t, r1a, q, mitad, r1a[r1a.length - 1]);
  r1Paradas.push({ id: "R1-" + (i + 1) + "v", nombre: n, sentido: "Hacia Las Palmas", desc: d, s: vu.s, p: vu.p });
});

// ---------------- Ruta 2 ----------------
const r2tRaw = r2.trazo.map(([lng, lat]) => [lat, lng]);
const r2t = dp(r2tRaw, 2.5).map(p => [+p[0].toFixed(5), +p[1].toFixed(5)]);
const r2a = acumulado(r2t);
const r2Paradas = r2.paradas.map(p => {
  const pista = p.km * 1000 * (r2a[r2a.length - 1] / acumulado(r2tRaw).at(-1));
  const pr = proyectar(r2t, r2a, [p.lat, p.lng], pista - 500, pista + 500) || proyectar(r2t, r2a, [p.lat, p.lng]);
  return { id: "R2-" + p.id, nombre: p.apodo, sentido: p.calle, desc: p.referencia, s: pr.s, p: [p.lat, p.lng] };
});

// ---------------- Rutas simuladas ----------------
const SIM = {
  R3: { wps: ["Gómez Sada", "IMSS UMF 78", "Glorieta Las Palmas", "Hospital IMSS", "Palacio Municipal", "Mercado Hidalgo", "Parque Tierra Caliente", "Hospital General", "Plaza Las Américas", "Gómez Sada"],
    coords: [[17.98176,-102.22711],[17.97363,-102.22459],[17.9726,-102.2068],[17.96406,-102.2005],[17.96228,-102.1985],[17.96301,-102.19484],[17.9645,-102.1963],[17.9672,-102.2027],[17.97805,-102.2135],[17.98176,-102.22711]],
    d: 13423, legs: [0,1495,4625,5782,6757,7310,7739,8661,11479],
    steps: [[351,"Avenida Narciso Bassols"],[581,"Artémio del Valle Arizpe"],[1043,"Calle D"],[1169,"Calle Río Mezcala"],[1306,"Calle Río Concepción"],[1403,"Avenida Melchor Ocampo"],[3249,"Avenida Tulipanes"],[3892,"Prolongación Tulipanes"],[4611,"Avenida Lázaro Cárdenas"],[6801,"Avenida Heroica Escuela Naval Militar"],[7273,"Calle Ignacio Aldama"],[7346,"Calle Vicente Guerrero"],[7423,"Calle Ignacio Allende"],[7579,"Avenida Heroica Escuela Naval Militar"],[7665,"Andador Sinaloa"],[7810,"Avenida Río Balsas"],[8329,"Avenida Lázaro Cárdenas"],[8846,"Avenida Autonomía Universitaria"],[9973,"Avenida Juan Francisco Noyola"],[10609,"Avenida Belisario Domínguez"],[10866,"Calle Canal de Riego"],[11221,"Calle 4"],[12055,"Calle Guanábana"],[12168,"Calle Mandarinas"],[12249,"Avenida Juan Francisco Noyola"],[13158,"Calle Sicartsa"],[13252,"Buenavista"],[13316,"Napoleón Gómez Sada"]] },
  R4: { wps: ["1o de Mayo","Santa Rosa","Plaza Las Américas","Hospital Naval","Soriana","Las Torres","Tec de Monterrey","ISSSTE","Las Torres","Hospital Naval","Plaza Las Américas","Santa Rosa","1o de Mayo"],
    coords: [[17.99179,-102.22812],[17.98532,-102.21772],[17.97805,-102.2133],[17.97244,-102.2122],[17.97005,-102.2110],[17.96562,-102.2136],[17.96125,-102.2040],[17.96002,-102.2045],[17.96562,-102.2136],[17.97244,-102.2122],[17.97805,-102.2133],[17.98532,-102.21772],[17.99179,-102.22812]],
    d: 17428, legs: [0,1753,3129,4251,4658,5610,7879,8441,10786,12125,13202,15031],
    steps: [[0,"Calle Roble"],[20,"Calle Ignacio Zaragoza"],[83,"Calle Tulipanes"],[282,"Calle Mango"],[662,"Avenida Las Palmas"],[2893,"Calle 4"],[3365,"Avenida Las Palmas"],[3561,"Avenida Belisario Domínguez"],[3667,"Avenida Norte"],[3712,"Calle Paseo de la Solidaridad"],[4494,"Prolongación Tulipanes"],[4760,"Avenida Autonomía Universitaria"],[4894,"Avenida Tulipanes"],[5937,"Avenida Melchor Ocampo"],[7626,"Avenida Rector Hidalgo"],[7686,"Calle G. Zamora"],[7835,"Calle Plan de Ayala"],[7900,"Avenida Melchor Ocampo"],[8257,"Avenida Morelos"],[8861,"Avenida Melchor Ocampo"],[10322,"Avenida Tulipanes"],[11325,"Prolongación Tulipanes"],[11908,"Calle Paseo de la Solidaridad"],[12987,"Calle 4"],[13353,"Calle Jurel"],[13633,"Calle Paseo de Los Cocoteros"],[14280,"Calle Primero de Mayo"],[14791,"Avenida Las Palmas"],[15669,"Calle Reforma"],[15822,"Calle Guillermo Prieto"],[15911,"Guillermo Prieto"],[16218,"Calle 5 de Mayo"],[16294,"Calle Bugambilias"],[17252,"Calle Mango"],[17309,"Calle Los Habillos"],[17345,"Calle Ignacio Zaragoza"],[17408,"Calle Roble"]] },
  R5: { wps: ["Benito Juárez","Tecnológico","Independencia","Lotes y Servicios","Unidad Deportiva","Central Estrella de Oro","Kiosko del Centro","Malecón de la Cultura","Monumento a Melchor Ocampo","Lotes y Servicios","Independencia","Tecnológico","Benito Juárez"],
    coords: [[17.97710,-102.23714],[17.97396,-102.2327],[17.96027,-102.22092],[17.95896,-102.2160],[17.95620,-102.19958],[17.95607,-102.19778],[17.95522,-102.1918],[17.9465,-102.18866],[17.9555,-102.1935],[17.95896,-102.2160],[17.96027,-102.22092],[17.97396,-102.2327],[17.97710,-102.23714]],
    d: 18819, legs: [0,832,3505,4434,6398,7425,8248,9336,10599,13751,14538,17724],
    steps: [[0,"Calle Nanche"],[126,"Calle Papaya"],[164,"Calle Tamarindo"],[327,"Libramiento a Sicartsa"],[552,"Avenida Melchor Ocampo"],[1140,"Avenida Narciso Bassols"],[2227,"Libramiento a Sicartsa"],[3319,"Calle Primero de Mayo"],[3529,"Calle 16 de Septiembre"],[3576,"Avenida Primero de Junio"],[3786,"Libramiento a Sicartsa"],[4718,"Calle F. Mata"],[4837,"Avenida Ejército Mexicano"],[5862,"Calle Sindicalismo"],[6747,"Avenida Francisco I. Madero"],[6969,"Francisco J. Múgica"],[7132,"Avenida Rector Hidalgo"],[7366,"Calle Corregidora"],[7752,"Avenida Lázaro Cárdenas"],[8082,"Calle Guillermo Prieto"],[8265,"Avenida Reforma"],[8415,"Avenida Constitución de 1917"],[8430,"Avenida Lázaro Cárdenas"],[10840,"Avenida Constitución de 1917"],[11313,"Avenida Francisco I. Madero"],[12151,"Libramiento a Sicartsa"],[14351,"Calle Primero de Mayo"],[14561,"Calle 16 de Septiembre"],[14608,"Avenida Primero de Junio"],[14818,"Libramiento a Sicartsa"],[17465,"Avenida Melchor Ocampo"],[18266,"Libramiento a Sicartsa"],[18491,"Calle Tamarindo"],[18654,"Calle Papaya"],[18693,"Calle Nanche"]] },
};

function simulada(k) {
  const S = SIM[k];
  const t = sinEspolones(geo[k]);
  const a = acumulado(t);
  const L = a[a.length - 1];
  const escala = L / S.d;
  const calleEn = s => {
    let n = "";
    for (const [d, nombre] of S.steps) if (d * escala <= s) n = nombre;
    return corta(n || "la ruta");
  };
  const fijas = [];
  let desde = 0;
  const vistos = {};
  S.wps.slice(0, -1).forEach((n, i) => {
    const pista = S.legs[i] * escala;
    const pr = i === 0 ? { s: 0, p: t[0] } : (proyectar(t, a, S.coords[i], Math.max(desde + 30, pista - 400), pista + 400) || { s: pista, p: puntoEn(t, a, pista) });
    desde = pr.s;
    vistos[n] = (vistos[n] || 0) + 1;
    fijas.push({ nombre: n, regreso: vistos[n] > 1, s: pr.s, p: pr.p });
  });
  const todas = [];
  for (let i = 0; i < fijas.length; i++) {
    todas.push(fijas[i]);
    const s0 = fijas[i].s, s1 = i + 1 < fijas.length ? fijas[i + 1].s : L;
    const n = Math.floor((s1 - s0) / 750);
    for (let j = 1; j <= n; j++) {
      const s = s0 + ((s1 - s0) * j) / (n + 1);
      todas.push({ nombre: calleEn(s), regreso: false, s, p: puntoEn(t, a, s), intermedia: true });
    }
  }
  return {
    t, paradas: todas.map((p, i) => ({
      id: k + "-" + (i + 1), nombre: p.nombre + (p.regreso ? " (regreso)" : ""),
      sentido: p.intermedia ? "Sobre " + p.nombre : "Parada principal", desc: "", s: p.s, p: p.p,
    })),
  };
}

const r3 = simulada("R3"), r4 = simulada("R4"), r5 = simulada("R5");

const rutas = [
  { id: "R1", numero: 1, nombre: "Ruta 1", apodo: "Malecón", color: "0xFF6E6E73", simulada: false,
    descripcion: "Recorre la Av. Lázaro Cárdenas de ida y vuelta, de la Glorieta Las Palmas al Malecón de la Cultura y las Artes.",
    frecuencia: 8, velocidad: 16, t: r1t, paradas: r1Paradas },
  { id: "R2", numero: 2, nombre: "Ruta 2", apodo: "Pollo", color: "0xFFF2C200", simulada: false,
    descripcion: "La ruta piloto: Tecnológico, Melchor Ocampo, Autonomía Universitaria, Centro y Plaza Las Américas.",
    frecuencia: 15, velocidad: 18, t: r2t, paradas: r2Paradas },
  { id: "R3", numero: 3, nombre: "Ruta 3", apodo: "Gómez Sada – Centro", color: "0xFF34C759", simulada: true,
    descripcion: "Simulada. De la Gómez Sada al centro por Melchor Ocampo y la Av. Lázaro Cárdenas; regresa por Plaza Las Américas.",
    frecuencia: 12, velocidad: 18, t: r3.t, paradas: r3.paradas },
  { id: "R4", numero: 4, nombre: "Ruta 4", apodo: "1o de Mayo – ISSSTE", color: "0xFF0A84FF", simulada: true,
    descripcion: "Simulada. Del norte (1o de Mayo, Santa Rosa) a Las Américas, Soriana, Las Torres y el Tec de Monterrey.",
    frecuencia: 15, velocidad: 18, t: r4.t, paradas: r4.paradas },
  { id: "R5", numero: 5, nombre: "Ruta 5", apodo: "Benito Juárez – Malecón", color: "0xFFAF52DE", simulada: true,
    descripcion: "Simulada. Del Tecnológico a Independencia, la Unidad Deportiva, la Central y el malecón.",
    frecuencia: 20, velocidad: 18, t: r5.t, paradas: r5.paradas },
];

const f = x => (+x).toFixed(5).replace(/0+$/, "").replace(/\.$/, "");
const esc = s => s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$");
let dart = `// GENERADO por herramientas/gen_rutas.mjs — no editar a mano.
// Trazos: OpenStreetMap (© colaboradores de OSM, ODbL) y OSRM para las rutas simuladas.
// Ruta 2: mismo recorrido y paradas que la página web (rutas-lzc).

import 'rutas_modelo_datos.dart';

const List<RutaDatos> rutasDatos = [
`;
for (const r of rutas) {
  dart += `  RutaDatos(
    id: '${r.id}',
    numero: ${r.numero},
    nombre: '${esc(r.nombre)}',
    apodo: '${esc(r.apodo)}',
    color: ${r.color},
    simulada: ${r.simulada},
    descripcion: '${esc(r.descripcion)}',
    frecuenciaMin: ${r.frecuencia},
    velocidadKmh: ${r.velocidad},
    trazo: [${r.t.map(p => `[${f(p[0])}, ${f(p[1])}]`).join(", ")}],
    paradas: [
${r.paradas.map(p => `      ParadaDatos(id: '${p.id}', nombre: '${esc(p.nombre)}', sentido: '${esc(p.sentido || "")}', descripcion: '${esc(p.desc || "")}', lat: ${f(p.p[0])}, lng: ${f(p.p[1])}, metros: ${Math.round(p.s)}),`).join("\n")}
    ],
  ),
`;
}
dart += "];\n";
fs.writeFileSync(salida, dart);
for (const r of rutas) {
  const L = acumulado(r.t).at(-1);
  console.log(r.id, Math.round(L) + " m", r.t.length + " pts", r.paradas.length + " paradas");
  console.log("   " + r.paradas.map(p => Math.round(p.s) + ":" + p.nombre).join(" | "));
}
