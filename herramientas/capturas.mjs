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
  ["1-mapa", ""],
  ["1b-mapa-viaje", "?hacia=malecon%20de%20la%20cultura"],
  ["2-viaje", "?tab=viaje&desde=gomez%20sada&hasta=av%20lazaro%20cardenas"],
  ["3-rutas", "?tab=rutas"],
  ["4-viaje-tec-malecon", "?tab=viaje&desde=instituto%20tecnologico&hasta=malecon%20de%20la%20cultura"],
  ["5-opcion", "?desde=gomez%20sada&hasta=av%20lazaro%20cardenas&detalle=1"],
  ["8-paradas", "?tab=paradas"],
];
for (const [nombre, q] of tomas) {
  await pagina.goto("http://localhost:8099" + BASE + q, { waitUntil: "load" });
  await pagina.waitForTimeout(q === "" || q.startsWith("?hacia") ? 20000 : 12000);
  await pagina.screenshot({ path: path.join(salida, nombre + ".png") });
  console.log("captura", nombre);
}

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
