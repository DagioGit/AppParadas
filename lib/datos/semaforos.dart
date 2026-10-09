// Semáforos sobre la Av. Lázaro Cárdenas (Ruta 1).
// El del entronque coincide con OpenStreetMap; los demás los marcó el equipo.

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
  Semaforo(
    'Semáforo de la Av. Río Balsas',
    'Av. Lázaro Cárdenas con Av. Río Balsas, junto al Monumento al Minero',
    LatLng(17.965278, -102.201033),
  ),
  Semaforo(
    'Semáforo del Palacio Municipal',
    'Av. Lázaro Cárdenas con Av. Heroica Escuela Naval Militar',
    LatLng(17.962609, -102.198972),
  ),
  Semaforo(
    'Semáforo de la Calle Mina',
    'Av. Lázaro Cárdenas con Calle General Francisco Javier Mina',
    LatLng(17.958436, -102.195730),
  ),
  Semaforo(
    'Semáforo de la Calle Constitución de 1814',
    'Av. Lázaro Cárdenas con Calle Constitución de 1814, antes del Monumento a Melchor Ocampo',
    LatLng(17.956783, -102.194407),
  ),
  Semaforo(
    'Semáforo de la Av. Constitución de 1917',
    'Av. Lázaro Cárdenas con Av. Constitución de 1917 y Av. Reforma',
    LatLng(17.953756, -102.192092),
  ),
];
