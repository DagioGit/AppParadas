// Tráfico y accidentes simulados del día. Cada día salen distintos (dependen de la fecha),
// pero en un mismo día siempre son los mismos. Aparecen en los cruces con semáforo de la
// ciudad, más seguido en hora pico. Las combis los toman en cuenta: con tráfico avanzan
// más lento por ese tramo y en un accidente se quedan detenidas unos minutos.

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../datos/semaforos.dart';
import 'ruta.dart' show horaPico, rutas;

/// Se apaga en las pruebas automáticas para que los resultados no cambien con la fecha.
bool simularIncidentes = true;

enum TipoIncidente { trafico, accidente }

class Incidente {
  final int id;
  final TipoIncidente tipo;

  /// Dónde: "Av. Lázaro Cárdenas y Av. Río Balsas".
  final String donde;
  final LatLng punto;

  /// Segundos del día en que empieza y termina.
  final double inicio, fin;

  /// Tráfico: metros de calle afectados a cada lado del punto y cuántas veces más lento se avanza.
  final double radio, factor;

  /// Accidente: segundos que se detiene la combi.
  final double espera;

  const Incidente({
    required this.id,
    required this.tipo,
    required this.donde,
    required this.punto,
    required this.inicio,
    required this.fin,
    this.radio = 0,
    this.factor = 1,
    this.espera = 0,
  });

  bool activo(double t) => t >= inicio && t < fin;
  bool get esAccidente => tipo == TipoIncidente.accidente;

  /// "Tráfico" / "Accidente".
  String get titulo => esAccidente ? 'Accidente' : 'Tráfico';
}

double _azar(int semilla, int a, int b) {
  var x = (semilla * 73856093) ^ (a * 19349663) ^ (b * 83492791);
  x &= 0x7FFFFFFF;
  x ^= x >> 13;
  x = (x * 0x5BD1E995) & 0x7FFFFFFF;
  x ^= x >> 15;
  return (x & 0xFFFFFF) / 0x1000000;
}

/// "Semáforo de Av. X y Av. Y" -> "Av. X y Av. Y"; "Semáforo del Palacio Municipal" -> "Palacio Municipal".
String _lugarDe(Semaforo s) => s.nombre.replaceFirst(RegExp(r'^Semáforo (de la |del |de )?'), '');

List<Incidente> _generar(DateTime dia) {
  if (!simularIncidentes || semaforos.isEmpty) return const [];
  final semilla = dia.year * 1000 + dia.difference(DateTime(dia.year)).inDays;
  final r = <Incidente>[];
  var id = 0;
  // Cada media hora de servicio puede empezar un tráfico; de vez en cuando, un accidente.
  for (var slot = 0; slot < 30; slot++) {
    final t0 = (6 + slot * 0.5) * 3600;
    final pico = horaPico(t0);
    if (_azar(semilla, slot, 1) < 0.32 + 0.5 * pico) {
      final s = semaforos[(_azar(semilla, slot, 2) * semaforos.length).floor() % semaforos.length];
      final inicio = t0 + _azar(semilla, slot, 3) * 1200;
      r.add(Incidente(
        id: id++,
        tipo: TipoIncidente.trafico,
        donde: _lugarDe(s),
        punto: s.punto,
        inicio: inicio,
        fin: inicio + (25 + 35 * _azar(semilla, slot, 4)) * 60,
        radio: 200 + 220 * _azar(semilla, slot, 5),
        factor: 1.8 + 1.6 * (0.5 * _azar(semilla, slot, 6) + 0.5 * pico),
      ));
    }
    if (_azar(semilla, slot, 7) < 0.09) {
      final s = semaforos[(_azar(semilla, slot, 8) * semaforos.length).floor() % semaforos.length];
      final inicio = t0 + _azar(semilla, slot, 9) * 1500;
      r.add(Incidente(
        id: id++,
        tipo: TipoIncidente.accidente,
        donde: _lugarDe(s),
        punto: s.punto,
        inicio: inicio,
        fin: inicio + (30 + 45 * _azar(semilla, slot, 10)) * 60,
        espera: (4 + 8 * _azar(semilla, slot, 11)) * 60,
      ));
    }
  }
  return r;
}

/// Tráfico y accidentes de hoy.
final List<Incidente> incidentesHoy = _generar(DateTime.now());

/// Los que están pasando en el segundo [t] del día.
List<Incidente> incidentesEn(double t) => [for (final i in incidentesHoy) if (i.activo(t)) i];

/// "+3 min" / "+45 s".
String textoRetraso(double seg) => seg < 60 ? '+${seg.round()} s' : '+${(seg / 60).round()} min';
final Map<int, List<List<LatLng>>> _lineasInc = {};

/// Pedazos de calle con tráfico (sobre los recorridos de las rutas que pasan por ahí).
List<List<LatLng>> lineasIncidente(Incidente inc) => _lineasInc[inc.id] ??= [
      for (final r in rutas)
        for (final (i, m) in r.zonasIncidente)
          if (i.id == inc.id) r.trazo.tramo(math.max(0.0, m - inc.radio), math.min(r.trazo.largo, m + inc.radio)),
    ];

