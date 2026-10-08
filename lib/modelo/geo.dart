import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double _radioTierra = 6371000;
const double _rad = math.pi / 180;

/// Distancia en metros entre dos puntos (aproximación plana, suficiente para una ciudad).
double distanciaM(LatLng a, LatLng b) {
  final x = (b.longitude - a.longitude) * _rad * math.cos((a.latitude + b.latitude) / 2 * _rad);
  final y = (b.latitude - a.latitude) * _rad;
  return math.sqrt(x * x + y * y) * _radioTierra;
}

/// Una línea con sus distancias acumuladas, para ubicar cosas "a tantos metros del inicio".
class Trazo {
  final List<LatLng> puntos;
  final List<double> acumulado;

  Trazo._(this.puntos, this.acumulado);

  factory Trazo(List<LatLng> puntos) {
    final acum = <double>[0];
    for (var i = 1; i < puntos.length; i++) {
      acum.add(acum[i - 1] + distanciaM(puntos[i - 1], puntos[i]));
    }
    return Trazo._(puntos, acum);
  }

  double get largo => acumulado.last;

  LatLng puntoEn(double s) {
    s = s.clamp(0, largo).toDouble();
    for (var i = 0; i < puntos.length - 1; i++) {
      if (acumulado[i + 1] >= s) {
        final tramo = acumulado[i + 1] - acumulado[i];
        final u = tramo <= 0 ? 0.0 : (s - acumulado[i]) / tramo;
        return LatLng(
          puntos[i].latitude + (puntos[i + 1].latitude - puntos[i].latitude) * u,
          puntos[i].longitude + (puntos[i + 1].longitude - puntos[i].longitude) * u,
        );
      }
    }
    return puntos.last;
  }

  /// Distancias (desde el inicio) de cada vez que el recorrido pasa a menos de [radio] metros de [q].
  /// Una ruta de ida y vuelta por la misma avenida pasa dos veces por el mismo semáforo.
  List<double> pasos(LatLng q, {double radio = 35}) {
    final cerca = <List<double>>[]; // [s, distancia]
    final c = math.cos(q.latitude * _rad);
    for (var i = 0; i < puntos.length - 1; i++) {
      final a = puntos[i], b = puntos[i + 1];
      final ax = a.longitude * c, ay = a.latitude, bx = b.longitude * c, by = b.latitude;
      final dx = bx - ax, dy = by - ay;
      final l2 = dx * dx + dy * dy;
      var u = l2 == 0 ? 0.0 : ((q.longitude * c - ax) * dx + (q.latitude - ay) * dy) / l2;
      u = u.clamp(0.0, 1.0).toDouble();
      final p = LatLng(a.latitude + (b.latitude - a.latitude) * u, a.longitude + (b.longitude - a.longitude) * u);
      final d = distanciaM(p, q);
      if (d <= radio) cerca.add([acumulado[i] + (acumulado[i + 1] - acumulado[i]) * u, d]);
    }
    cerca.sort((x, y) => x[0].compareTo(y[0]));
    final r = <double>[];
    double? ultimo;
    double mejorD = double.infinity;
    for (final x in cerca) {
      if (ultimo == null || x[0] - ultimo > 80) {
        r.add(x[0]);
        mejorD = x[1];
      } else if (x[1] < mejorD) {
        r[r.length - 1] = x[0];
        mejorD = x[1];
      }
      ultimo = x[0];
    }
    return r;
  }

  /// Puntos entre s0 y s1 avanzando en el sentido del recorrido (da la vuelta si s1 < s0).
  List<LatLng> tramo(double s0, double s1) {
    if (s1 < s0) {
      return [..._tramoDirecto(s0, largo), ..._tramoDirecto(0, s1)];
    }
    return _tramoDirecto(s0, s1);
  }

  List<LatLng> _tramoDirecto(double s0, double s1) {
    final r = <LatLng>[puntoEn(s0)];
    for (var i = 0; i < puntos.length; i++) {
      if (acumulado[i] > s0 && acumulado[i] < s1) r.add(puntos[i]);
    }
    r.add(puntoEn(s1));
    return r;
  }
}
