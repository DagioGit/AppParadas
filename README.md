# AppParadas

App de combis de **Lázaro Cárdenas, Michoacán** hecha con Flutter (iOS y Android), con diseño tipo iPhone.

- **Mapa** con la **Ruta 1** (gris, Av. Lázaro Cárdenas ↔ Malecón de la Cultura y las Artes) y la **Ruta 2 «Pollo»** (amarilla, la de la página web), más tres rutas simuladas.
- Toca una parada para ver la **cuenta regresiva** de las próximas combis.
- **Viaje**: eliges de dónde sales y a dónde vas y la app compara al menos **3 formas de llegar** (una combi, o dos con transbordo) y marca **la más rápida**.
- En **Viaje** también hay un mapa con el recorrido de cada opción: dónde pasa la combi (con cuenta regresiva), la combi acercándose, dónde bajarte y la mención de la ruta más rápida. Al tocar un recorrido se abren sus detalles.
- **Paradas**: las paradas de la Ruta 1 sobre la Av. Lázaro Cárdenas por sentido (hacia el malecón / hacia Las Palmas), con cuenta regresiva y las combis moviéndose en el mapa.
- **Semáforos** marcados en el entronque (Prol. Tulipanes / Blvd. de las Islas) y junto al Hospital General; en el horario simulado la combi se detiene ahí unos segundos.
- **Rutas**: cada ruta con su mapa, paradas y la próxima combi en cada una.

Los horarios son estimados: cada ruta sale de su inicio cada cierto tiempo (Ruta 1 cada 8 min, Ruta 2 cada 15) de 6:00 a 22:00. Las rutas 3, 4 y 5 son inventadas sobre calles reales para probar el buscador.

## Probarla

- **Enlace de demostración**: `?desde=gomez sada&hasta=av lazaro cardenas` abre el viaje directo (agrega `&detalle=1` para ver el paso a paso; `?tab=paradas` abre las paradas).
- **En el navegador**: la versión web se publica sola en GitHub Pages (`https://dagiogit.github.io/AppParadas/`) cada vez que se sube un cambio.
- **En Android**: en *Releases → ultima* está `AppParadas.apk`; se descarga en el teléfono y se instala (hay que permitir apps de origen desconocido).
- **En iPhone**: hace falta una Mac con Xcode: `flutter run` con el iPhone conectado.

## Correrla en tu computadora

```bash
flutter pub get
flutter run            # elige el teléfono o el emulador
flutter test           # pruebas del buscador de rutas
```

## Cómo está hecha

| Carpeta | Qué hay |
|---|---|
| `lib/datos/rutas_datos.dart` | Recorridos y paradas de las 5 rutas (generado) |
| `lib/datos/lugares.dart` | Colonias, avenidas y lugares para buscar |
| `lib/modelo/planificador.dart` | El buscador: caminar + combi (+ transbordo), ordenado por hora de llegada |
| `lib/modelo/ruta.dart` | Horario de cada ruta y próximas llegadas |
| `lib/pantallas/` | Mapa, Viaje, Rutas y detalles |
| `herramientas/gen_rutas.mjs` | Regenera `rutas_datos.dart` con `node herramientas/gen_rutas.mjs lib/datos/rutas_datos.dart` |

Calles y recorridos: © colaboradores de OpenStreetMap (ODbL); rutas simuladas trazadas con OSRM; mapa base de OpenStreetMap en gris.
