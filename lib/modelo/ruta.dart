import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

import '../datos/rutas_datos.dart';
import '../datos/rutas_modelo_datos.dart';
import '../datos/semaforos.dart';
import 'geo.dart';

/// Servicio de 6:00 a 22:00 (última salida a las 22:00).
const int inicioServicio = 6 * 3600;
const int finServicio = 22 * 3600;
const int segundosDia = 86400;

/// Segundos que la combi se detiene en cada parada.
const double esperaEnParada = 40;

class Parada {
  final Ruta ruta;
  final ParadaDatos datos;
  final int indice;

  Parada(this.ruta, this.datos, this.indice);

  String get id => datos.id;
  String get nombre => datos.nombre;
  String get sentido => datos.sentido;
  String get descripcion => datos.descripcion;
  LatLng get punto => LatLng(datos.lat, datos.lng);
  double get metros => datos.metros.toDouble();

  /// Segundos desde que la combi sale del inicio hasta que llega a esta parada
  /// (cuenta el tiempo detenida en paradas y semáforos anteriores).
  double get desfase => ruta._llegadaParada[indice];

  /// Paradas principales: las de las rutas reales y las de nombre propio en las simuladas.
  bool get principal => !ruta.simulada || sentido == 'Parada principal';
}

/// Una pausa en el recorrido: parada (sube y baja gente) o semáforo.
class Pausa {
  final double metros;
  final double segundos;
  final Parada? parada;
  final Semaforo? semaforo;
  Pausa(this.metros, this.segundos, {this.parada, this.semaforo});
}

/// Una combi en movimiento en este momento.
class CombiEnRuta {
  final Ruta ruta;
  final double salida; // segundo del día en que salió del inicio
  final double metros;
  final LatLng punto;
  final bool detenida;
  final Parada? siguiente;
  CombiEnRuta(this.ruta, this.salida, this.metros, this.punto, this.detenida, this.siguiente);
}

class Ruta {
  final RutaDatos datos;
  late final Trazo trazo;
  late final List<Parada> paradas;
  late final List<Pausa> pausas;
  late final List<Semaforo> semaforosEnRuta;

  // Línea de tiempo de una vuelta: en el segundo _t[i] la combi está en el metro _s[i].
  final List<double> _t = [];
  final List<double> _s = [];
  late final List<double> _llegadaParada;
  late final double duracion;

  Ruta(this.datos) {
    trazo = Trazo([for (final p in datos.trazo) LatLng(p[0], p[1])]);
    final ordenadas = [...datos.paradas]..sort((a, b) => a.metros.compareTo(b.metros));
    paradas = [for (var i = 0; i < ordenadas.length; i++) Parada(this, ordenadas[i], i)];

    final lista = <Pausa>[for (final p in paradas) Pausa(p.metros, esperaEnParada, parada: p)];
    final enRuta = <Semaforo>[];
    for (final sem in semaforos) {
      final pasos = trazo.pasos(sem.punto);
      if (pasos.isNotEmpty) enRuta.add(sem);
      for (final m in pasos) {
        lista.add(Pausa(m, esperaSemaforo, semaforo: sem));
      }
    }
    lista.sort((a, b) => a.metros.compareTo(b.metros));
    pausas = lista;
    semaforosEnRuta = enRuta;

    final v = velocidadMs;
    final llegadas = List<double>.filled(paradas.length, 0);
    var t = 0.0, s = 0.0;
    _t.add(0);
    _s.add(0);
    for (final p in pausas) {
      t += (p.metros - s) / v;
      s = p.metros;
      _t.add(t);
      _s.add(s);
      if (p.parada != null) llegadas[p.parada!.indice] = t;
      t += p.segundos;
      _t.add(t);
      _s.add(s);
    }
    t += (trazo.largo - s) / v;
    _t.add(t);
    _s.add(trazo.largo);
    _llegadaParada = llegadas;
    duracion = t;
  }

  /// Metros recorridos [e] segundos después de salir del inicio.
  double metrosA(double e) {
    if (e <= 0) return 0;
    if (e >= duracion) return trazo.largo;
    var lo = 0, hi = _t.length - 1;
    while (hi - lo > 1) {
      final m = (lo + hi) >> 1;
      if (_t[m] <= e) {
        lo = m;
      } else {
        hi = m;
      }
    }
    final dt = _t[hi] - _t[lo];
    if (dt <= 0) return _s[lo];
    return _s[lo] + (_s[hi] - _s[lo]) * (e - _t[lo]) / dt;
  }

  /// Todas las combis que van en el recorrido en el segundo [t] del día.
  List<CombiEnRuta> combisEn(double t) {
    final r = <CombiEnRuta>[];
    final f = frecuenciaSeg;
    final t0 = t % segundosDia;
    var k = ((t0 - inicioServicio - duracion) / f).floor();
    if (k < 0) k = 0;
    for (;; k++) {
      final salida = inicioServicio + k * f;
      if (salida > t0 || salida > finServicio) break;
      final e = t0 - salida;
      if (e > duracion) continue;
      final m = metrosA(e);
      final detenida = metrosA(e + 1) == m;
      Parada? sig;
      for (final p in paradas) {
        if (p.metros >= m - 1) {
          sig = p;
          break;
        }
      }
      r.add(CombiEnRuta(this, salida, m, trazo.puntoEn(m), detenida, sig));
    }
    return r;
  }

  /// Dónde va la combi que llegará a la parada [p] en el segundo [llegada]
  /// (null si todavía no sale del inicio).
  LatLng? combiQueLlega(Parada p, double llegada, double ahora) {
    final salida = llegada - p.desfase;
    final e = ahora - salida;
    if (e < 0) return null;
    return trazo.puntoEn(metrosA(e));
  }

  /// Hora en que sale del inicio la combi que llega a [p] en el segundo [llegada].
  double salidaDe(Parada p, double llegada) => llegada - p.desfase;

  String get id => datos.id;
  int get numero => datos.numero;
  String get nombre => datos.nombre;
  String get apodo => datos.apodo;
  String get descripcion => datos.descripcion;
  bool get simulada => datos.simulada;
  Color get color => Color(datos.color);
  int get frecuenciaMin => datos.frecuenciaMin;
  double get velocidadMs => datos.velocidadKmh / 3.6;
  double get frecuenciaSeg => datos.frecuenciaMin * 60.0;

  /// Minutos que tarda una vuelta completa.
  double get vueltaMin => duracion / 60;

  /// Segundos de viaje en la misma combi de la parada [a] a la parada [b].
  double viaje(Parada a, Parada b) {
    if (b.indice > a.indice) return b.desfase - a.desfase;
    return (duracion - a.desfase) + b.desfase;
  }

  /// Paradas que la combi pasa entre [a] y [b] (sin contarlas).
  int paradasEntre(Parada a, Parada b) {
    if (b.indice > a.indice) return b.indice - a.indice - 1;
    return paradas.length - a.indice + b.indice - 1;
  }

  List<LatLng> tramoEntre(Parada a, Parada b) => trazo.tramo(a.metros, b.metros);

  /// Próximas [n] llegadas a la parada desde el segundo [t] del día (pueden pasar de 86400 = mañana).
  List<double> proximasLlegadas(Parada p, double t, {int n = 3}) {
    final r = <double>[];
    final f = frecuenciaSeg;
    var dia = 0.0;
    var tt = t;
    while (r.length < n && dia < 3) {
      final base = dia * segundosDia;
      var k = ((tt - base - inicioServicio - p.desfase) / f).ceil();
      if (k < 0) k = 0;
      while (r.length < n) {
        final salida = inicioServicio + k * f;
        if (salida > finServicio) break;
        r.add(base + salida + p.desfase);
        k++;
      }
      dia++;
      tt = dia * segundosDia;
    }
    return r;
  }

  double proximaLlegada(Parada p, double t) => proximasLlegadas(p, t, n: 1).first;
}

final List<Ruta> rutas = [for (final d in rutasDatos) Ruta(d)];

Ruta rutaPorId(String id) => rutas.firstWhere((r) => r.id == id);

/// Segundos transcurridos del día de hoy.
double segundosAhora() {
  final a = DateTime.now();
  return a.hour * 3600.0 + a.minute * 60 + a.second + a.millisecond / 1000;
}

/// "14:05" (si pasa de medianoche, "mañana 6:12").
String hora(double segDia) {
  final dias = (segDia / segundosDia).floor();
  final s = segDia - dias * segundosDia;
  final h = (s ~/ 3600) % 24;
  final m = ((s % 3600) ~/ 60);
  final txt = '$h:${m.toString().padLeft(2, '0')}';
  return dias > 0 ? 'mañana $txt' : txt;
}

/// "Ahora", "1 min", "12 min", "1 h 05 min".
String duracion(double segundos, {bool ahora = false}) {
  final m = (segundos / 60).round();
  if (m <= 0) return ahora ? 'Ahora' : '1 min';
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}
