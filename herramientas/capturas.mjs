// Toma capturas de la versión web (tamaño iPhone) para revisar el diseño sin un teléfono.
// Uso: node herramientas/capturas.mjs <carpeta build/web> <carpeta de salida>
import { chromium } from "playwright";
import http from "http";
import fs from "fs";
import path from "path";

const [web, salida] = process.argv.slice(2);
fs.mkdirSync(salida, { recursive: true });
const BASE = "/AppParadas/";
const tipos = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".wasm": "application/wasm", ".png": "image/png", ".otf": "font/otf", ".ttf": "font/ttf", ".css": "text/css" };

const servidor = http.createServer((req, res) => {
  let u = decodeURIComponent(req.url.split("?")[0]);
  if (!u.toLowerCase().startsWith(BASE.toLowerCase())) { res.writeHead(404); return res.end(); }
  let f = path.join(web, u.slice(BASE.length) || "index.html");
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(web, "index.html");
  res.writeHead(200, { "Content-Type": tipos[path.extname(f)] || "application/octet-stream" });
  fs.createReadStream(f).pipe(res);
});
await new Promise(r => servidor.listen(8099, r));

const navegador = await chromium.launch();
const ctx = await navegador.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: "es-MX", timezoneId: "America/Mexico_City" });
const pagina = await ctx.newPage();
pagina.on("console", m => { if (m.type() === "error") console.log("consola:", m.text()); });

const tomas = [
  ["1-inicio", ""],
  ["2-viaje", "?tab=viaje&desde=malecon%20de%20la%20cultura&hasta=gomez%20sada"],
  ["2c-parada3d", "?parada3d=R1-4i"],
  ["3-rutas", "?tab=rutas"],
  ["4-viaje-tec-malecon", "?tab=viaje&desde=instituto%20tecnologico&hasta=malecon%20de%20la%20cultura"],
  ["5-opcion", "?desde=gomez%20sada&hasta=av%20lazaro%20cardenas&detalle=1"],
  ["8-paradas", "?tab=paradas"],
  ["10-ajustes", "?tab=ajustes"],
  ["11-ajustes-oscuro", "?tab=ajustes&tema=oscuro"],
  ["12-paradas-oscuro", "?tab=paradas&tema=oscuro&letra=1.3"],
  ["13-rutas-oscuro", "?tab=rutas&tema=oscuro"],
  ["15-paradas-noche", "?tab=paradas&hora=22.5"],
  ["16-viaje-noche", "?tab=viaje&hora=22.5&desde=malecon%20de%20la%20cultura&hasta=gomez%20sada"],
  ["17-paradas-noche-oscuro", "?tab=paradas&hora=23&tema=oscuro"],
  ["14-viaje-oscuro", "?tab=viaje&tema=oscuro&desde=malecon%20de%20la%20cultura&hasta=gomez%20sada"],
];
for (const [nombre, q] of tomas) {
  await pagina.goto("http://localhost:8099" + BASE + q, { waitUntil: "load" });
  await pagina.waitForTimeout(q === "" || q.startsWith("?hacia") || q.includes("tab=viaje") || q.includes("parada3d") ? 30000 : 12000);
  await pagina.screenshot({ path: path.join(salida, nombre + ".png") });
  console.log("captura", nombre);
}

// Caseta de cerca (dentro del visor de la página): pantalla colgada, banca y botes
try {
  await pagina.goto("http://localhost:8099" + BASE + "?parada3d=R1-4i&hora=10", { waitUntil: "load" });
  await pagina.waitForTimeout(30000);
  const visor = pagina.frames().find(f => f.url().includes("visor.html"));
  if (visor) {
    const tomas3d = [["2f-caseta-frente", [-0.9, -6.5, 2.3], [-0.9, 0, 1.6]], ["2g-caseta-banca", [-7.5, -4.5, 2.6], [-2.5, 0.2, 0.8]], ["2h-caseta-botes", [0.6, -2.6, 1.7], [-2.0, 0.4, 0.6]], ["2i-caseta-rampa", [7.2, -4.2, 2.4], [3.2, -0.5, 0.2]]];
    for (const [nombre, cam, obj] of tomas3d) {
      await visor.evaluate(([cam, obj]) => {
        const C = window.VisorZona.capturas;
        const c = C.caseta();
        if (!c) return;
        const [x, y, z, r] = c;
        const w = ([lx, ly, lz]) => [x + lx * Math.cos(r) - ly * Math.sin(r), y + lx * Math.sin(r) + ly * Math.cos(r), z + lz];
        C.pausar(true);
        C.camara(w(cam), w(obj));
        C.cuadro(0.016);
      }, [cam, obj]);
      await pagina.waitForTimeout(2500);
      await pagina.screenshot({ path: path.join(salida, nombre + ".png") });
      console.log("captura", nombre);
    }
  }
} catch (e) { console.log("caseta de cerca:", e.message); }

// Viaje marcando con clics: primero dónde estás y luego a dónde vas
await pagina.goto("http://localhost:8099" + BASE + "?tab=viaje", { waitUntil: "load" });
await pagina.waitForTimeout(16000);
await pagina.screenshot({ path: path.join(salida, "2d-viaje-vacio.png") });
await pagina.mouse.click(170, 430);
await pagina.waitForTimeout(2500);
await pagina.mouse.click(250, 330);
await pagina.waitForTimeout(9000);
await pagina.screenshot({ path: path.join(salida, "2e-viaje-clics.png") });

// Viaje unos segundos después (la combi avanzó)
await pagina.goto("http://localhost:8099" + BASE + "?tab=viaje&desde=gomez%20sada&hasta=av%20lazaro%20cardenas", { waitUntil: "load" });
await pagina.waitForTimeout(25000);
await pagina.screenshot({ path: path.join(salida, "2b-viaje-despues.png") });

// Ajustes más abajo (apariencia)
await pagina.goto("http://localhost:8099" + BASE + "?tab=ajustes&tema=oscuro", { waitUntil: "load" });
await pagina.waitForTimeout(9000);
await pagina.mouse.move(195, 600);
await pagina.mouse.wheel(0, 700);
await pagina.waitForTimeout(2000);
await pagina.screenshot({ path: path.join(salida, "11b-ajustes-abajo.png") });

// Lista de paradas (más abajo en la pestaña Paradas)
await pagina.goto("http://localhost:8099" + BASE + "?tab=paradas", { waitUntil: "load" });
await pagina.waitForTimeout(9000);
await pagina.mouse.move(195, 700);
await pagina.mouse.wheel(0, 520);
await pagina.waitForTimeout(2000);
await pagina.screenshot({ path: path.join(salida, "9-paradas-lista.png") });

// Hoja de una parada: abrir Rutas → Ruta 1 y tocar la primera parada de la lista
await pagina.goto("http://localhost:8099" + BASE + "?tab=rutas", { waitUntil: "load" });
await pagina.waitForTimeout(9000);
await pagina.mouse.click(195, 175);
await pagina.waitForTimeout(6000);
await pagina.screenshot({ path: path.join(salida, "6-ruta1.png") });
await pagina.mouse.wheel(0, 500);
await pagina.waitForTimeout(1500);
await pagina.screenshot({ path: path.join(salida, "7-ruta1-paradas.png") });

await navegador.close();
servidor.close();
