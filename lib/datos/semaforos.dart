// Semáforos sobre la Av. Lázaro Cárdenas (Ruta 1).
// El del entronque coincide con OpenStreetMap; el del hospital lo marcó el equipo.

import 'package:latlong2/latlong.dart';

class Semaforo {
  final String nombre;
  final String detalle;
  final LatLng punto;
  const Semaforo(this.nombre, this.detalle, this.punto);
}

/// Segundos que, en promedio, una combi se detiene en cada semáforo (simulado).
const double esperaSemaforo = 25;

const List<Semaforo> semaforos = [
  Semaforo(
    'Semáforo del entronque',
    'Av. Lázaro Cárdenas con Prol. Tulipanes, Av. Las Palmas y Blvd. de las Islas',
    LatLng(17.97275, -102.20690),
  ),
  Semaforo(
    'Semáforo del Hospital General',
    'Av. Lázaro Cárdenas, a un lado del Hospital General',
    LatLng(17.967431, -102.202671),
  ),
];
