// Recorridos a pie calle por calle (sin internet): grafo de las calles de Lázaro Cárdenas
// (assets/grafo_calles.json, de OpenStreetMap) y búsqueda del camino más corto (A*).
// Además del trazo, arma las indicaciones: "Camina 120 m por Calle Mina; luego gira a la
// derecha en Av. Lázaro Cárdenas".

import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// Un tramo de calle a seguir: "por [calle], [metros] m"; [giro] es cómo se entra a ella.
class Indicacion {
  final String calle; // '' si no tiene nombre
  final double metros;
  final String giro; // 'derecha', 'izquierda', 'derecho' o '' (el primero)
  final int desde; // índice del primer punto de esta indicación en el trazo
  const Indicacion(this.calle, this.metros, this.giro, this.desde);

  /// "por Calle Mina" / "por la calle".
  String get porDonde => calle.isEmpty ? 'por la calle' : 'por $calle';
}

class Camino {
  final List<LatLng> puntos;
  final double metros;
  final List<Indicacion> indicaciones;
  const Camino(this.puntos, this.metros, this.indicaciones);
}

class _Arista {
  final int a, b;
  final double largo;
  final int nombre;
  final List<LatLng> medio; // puntos intermedios de a hacia b
  _Arista(this.a, this.b, this.largo, this.nombre, this.medio);
}

class GrafoCalles {
  static GrafoCalles? instancia;

  final List<LatLng> _v;
  final List<_Arista> _e;
  final List<List<int>> _ady;
  final List<String> _nombres;
  final Map<int, List<int>> _celdas = {}; // rejilla de ~250 m para buscar el cruce más cercano

  GrafoCalles._(this._v, this._e, this._ady, this._nombres) {
    for (var i = 0; i < _v.length; i++) {
      _celdas.putIfAbsent(_celda(_v[i]), () => []).add(i);
    }
  }

  static int _celda(LatLng p) => ((p.latitude * 400).floor() * 100000) + (p.longitude * 400).floor();

  /// Lee el grafo del archivo de la app. Si no está o falla, los recorridos a pie quedan en línea recta.
  static Future<void> cargar() async {
    try {
      final d = jsonDecode(await rootBundle.loadString('assets/grafo_calles.json')) as Map<String, dynamic>;
      final vs = (d['v'] as List).cast<num>();
      final v = <LatLng>[for (var i = 0; i + 1 < vs.length; i += 2) LatLng(vs[i] / 1e5, vs[i + 1] / 1e5)];
      final e = <_Arista>[];
      final ady = List<List<int>>.generate(v.length, (_) => []);
      for (final x in d['e'] as List) {
        final l = x as List;
        final m = (l[4] as List).cast<num>();
        final arista = _Arista(l[0] as int, l[1] as int, (l[2] as num).toDouble(), l[3] as int,
            [for (var i = 0; i + 1 < m.length; i += 2) LatLng(m[i] / 1e5, m[i + 1] / 1e5)]);
        ady[arista.a].add(e.length);
        ady[arista.b].add(e.length);
        e.add(arista);
      }
      instancia = GrafoCalles._(v, e, ady, (d['n'] as List).cast<String>());
    } catch (_) {
      instancia = null;
    }
  }

  int? _cercano(LatLng p, {double maximo = 400}) {
    final c = _celda(p);
    int? mejor;
    var dMin = maximo;
    for (final dy in const [-100000, 0, 100000]) {
      for (final dx in const [-1, 0, 1]) {
        for (final i in _celdas[c + dy + dx] ?? const <int>[]) {
          final d = distanciaM(_v[i], p);
          if (d < dMin) {
            dMin = d;
            mejor = i;
          }
        }
      }
    }
    return mejor;
  }

  /// Camino a pie de [a] a [b] por las calles; null si alguno queda lejos de las calles.
  Camino? ruta(LatLng a, LatLng b) {
    final s = _cercano(a), t = _cercano(b);
    if (s == null || t == null) return null;
    if (s == t) return Camino([a, _v[s], b], distanciaM(a, _v[s]) + distanciaM(_v[s], b), const []);

    // A* con la distancia en línea recta como estimación
    final g = <int, double>{s: 0};
    final previo = <int, int>{}; // vértice -> arista por la que se llegó
    final cola = SplayTreeSet<(double, int)>((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2));
    cola.add((distanciaM(_v[s], _v[t]), s));
    final cerrado = <int>{};
    var pasos = 0;
    while (cola.isNotEmpty && pasos++ < 60000) {
      final (_, x) = cola.first;
      cola.remove(cola.first);
      if (x == t) break;
      if (!cerrado.add(x)) continue;
      for (final ei in _ady[x]) {
        final e = _e[ei];
        final y = e.a == x ? e.b : e.a;
        final ng = g[x]! + e.largo;
        if (ng < (g[y] ?? double.infinity)) {
          g[y] = ng;
          previo[y] = ei;
          cola.add((ng + distanciaM(_v[y], _v[t]), y));
        }
      }
    }
    if (!previo.containsKey(t)) return null;

    // Reconstruir: lista de (arista, sentido)
    final camino = <(int, bool)>[];
    var x = t;
    while (x != s) {
      final ei = previo[x]!;
      final e = _e[ei];
      final haciaB = e.b == x;
      camino.add((ei, haciaB));
      x = haciaB ? e.a : e.b;
    }
    final orden = camino.reversed.toList();

    final puntos = <LatLng>[a, _v[s]];
    final grupos = <(int, double, int)>[]; // (nombre, metros, índice del primer punto)
    for (final (ei, haciaB) in orden) {
      final e = _e[ei];
      final medio = haciaB ? e.medio : e.medio.reversed.toList();
      final inicio = puntos.length - 1;
      puntos.addAll(medio);
      puntos.add(_v[haciaB ? e.b : e.a]);
      if (grupos.isNotEmpty && grupos.last.$1 == e.nombre) {
        final u = grupos.removeLast();
        grupos.add((u.$1, u.$2 + e.largo, u.$3));
      } else {
        grupos.add((e.nombre, e.largo, inicio));
      }
    }
    puntos.add(b);

    // Indicaciones con el giro en cada cambio de calle
    final ind = <Indicacion>[];
    for (var k = 0; k < grupos.length; k++) {
      final (nom, m, desde) = grupos[k];
      if (m < 8 && k > 0 && k < grupos.length - 1) continue; // pedacitos que no vale la pena decir
      var giro = '';
      if (ind.isNotEmpty && desde > 0 && desde + 1 < puntos.length) {
        final antes = _rumbo(puntos[math.max(0, desde - 1)], puntos[desde]);
        final despues = _rumbo(puntos[desde], puntos[desde + 1]);
        var dif = despues - antes;
        while (dif > 180) {
          dif -= 360;
        }
        while (dif < -180) {
          dif += 360;
        }
        giro = dif > 35 ? 'derecha' : (dif < -35 ? 'izquierda' : 'derecho');
      }
      ind.add(Indicacion(_nombres[nom], m, giro, desde));
    }
    final total = distanciaM(a, _v[s]) + g[t]! + distanciaM(_v[t], b);
    return Camino(puntos, total, ind);
  }

  static double _rumbo(LatLng a, LatLng b) {
    final dx = (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180);
    final dy = b.latitude - a.latitude;
    var ang = math.atan2(dx, dy) * 180 / math.pi;
    if (ang < 0) ang += 360;
    return ang;
  }
}

/// Punto del [trazo] más cercano a [p]: (índice del segmento, metros que faltan hasta el final).
(int, double) avanceEnTrazo(List<LatLng> trazo, LatLng p) {
  var mejor = 0;
  var dMin = double.infinity;
  for (var i = 0; i < trazo.length; i++) {
    final d = distanciaM(trazo[i], p);
    if (d < dMin) {
      dMin = d;
      mejor = i;
    }
  }
  var resto = distanciaM(p, trazo[mejor]);
  for (var i = mejor; i + 1 < trazo.length; i++) {
    resto += distanciaM(trazo[i], trazo[i + 1]);
  }
  return (mejor, resto);
}

/// Punto a [metros] del inicio del [trazo].
LatLng puntoEnTrazo(List<LatLng> trazo, double metros) {
  var m = metros;
  for (var i = 0; i + 1 < trazo.length; i++) {
    final d = distanciaM(trazo[i], trazo[i + 1]);
    if (m <= d && d > 0) {
      final u = m / d;
      return LatLng(trazo[i].latitude + (trazo[i + 1].latitude - trazo[i].latitude) * u,
          trazo[i].longitude + (trazo[i + 1].longitude - trazo[i].longitude) * u);
    }
    m -= d;
  }
  return trazo.last;
}
