import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

import '../datos/rutas_datos.dart';
import '../datos/rutas_modelo_datos.dart';
import '../datos/semaforos.dart';
import 'geo.dart';

/// Las combis pasan de 6:00 a 21:00: la última sale a tiempo para terminar su vuelta a las 21:00.
const int inicioServicio = 6 * 3600;
const int finServicio = 21 * 3600;

/// ¿Hay combis pasando a la hora [t] (segundos del día)?
bool enServicio(double t) {
  final s = t % segundosDia;
  return s >= inicioServicio && s < finServicio;
}

/// "6:00 am" (texto de cuándo vuelven a pasar las combis).
String get horaInicioServicio => '${inicioServicio ~/ 3600}:00 am';
const int segundosDia = 86400;

/// Segundos típicos que la combi se detiene en una parada principal (hora normal).
const double esperaEnParada = 30;

/// Arranque y frenado de la combi (m/s²): no se teletransporta de 0 a 30 km/h.
const double _acelera = 0.9;
const double _frena = 1.3;

// ---------------- Simulación del día ----------------

double _campana(double h, double centro, double ancho) {
  final z = (h - centro) / ancho;
  return math.exp(-0.5 * z * z);
}

/// Qué tan cargada está la hora [seg] del día: 0 = tranquila, ~1 = hora pico
/// (entrada a escuelas y trabajo ~7:30, comida ~14:00, salida ~19:00).
double horaPico(double seg) {
  final h = (seg % segundosDia) / 3600;
  return math.min(1.0, _campana(h, 7.6, 0.8) + 0.65 * _campana(h, 14.0, 0.9) + 0.9 * _campana(h, 19.0, 1.0));
}

/// Cuánto más lento va el tráfico: 1 = normal, 1.4 = 40 % más lento. De noche, un poco más rápido.
double factorTrafico(double seg) {
  final h = (seg % segundosDia) / 3600;
  final noche = h >= 20 ? 0.06 : 0.0;
  return 1 + 0.4 * horaPico(seg) - noche;
}

/// Número pseudoaleatorio fijo entre 0 y 1 (la misma combi se comporta igual cada vez que se calcula).
double _azar(String semilla, int a, [int b = 0]) {
  var x = 0x811C9DC5;
  for (final c in '$semilla|$a|$b'.codeUnits) {
    x = ((x ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  x ^= x >> 13;
  x = (x * 0x5BD1E995) & 0xFFFFFFFF;
  x ^= x >> 15;
  return (x & 0xFFFFFF) / 0x1000000;
}

/// El semáforo cambia cada [cicloSemaforo] segundos y está [rojoSemaforo] en rojo
/// para la avenida. Cada cruce tiene su propio desfase.
const double cicloSemaforo = 90;
const double rojoSemaforo = 38;

double _faseSemaforo(Semaforo s, double metros, double seg) {
  final desfase = _azar(s.nombre, metros.round()) * cicloSemaforo;
  return (seg + desfase) % cicloSemaforo;
}

/// ¿Está en rojo el semáforo [s] (en el paso del metro [metros]) en el segundo [seg]?
bool semaforoEnRojo(Semaforo s, double metros, double seg) => _faseSemaforo(s, metros, seg) < rojoSemaforo;

/// Segundos para que se ponga en verde (0 si ya está en verde).
double faltaVerde(Semaforo s, double metros, double seg) {
  final f = _faseSemaforo(s, metros, seg);
  return f < rojoSemaforo ? rojoSemaforo - f : 0;
}

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

  /// Segundos típicos (a media mañana) desde que la combi sale del inicio hasta que llega aquí.
  double get desfase => ruta.tipica.llegadas[indice];

  /// Paradas principales: las de las rutas reales y las de nombre propio en las simuladas.
  bool get principal => !ruta.simulada || sentido == 'Parada principal';
}

/// Un punto del recorrido donde la combi se puede detener: parada o semáforo.
class Pausa {
  final double metros;
  final double segundos; // espera típica
  final Parada? parada;
  final Semaforo? semaforo;
  Pausa(this.metros, this.segundos, {this.parada, this.semaforo});
}

/// Pedazo de la vuelta: la combi avanza (arranca, va y frena) o está detenida.
class _Pedazo {
  final double t0, t1, s0, s1;
  final double v; // velocidad máxima del pedazo (0 si está detenida)
  final Pausa? pausa;
  _Pedazo(this.t0, this.t1, this.s0, this.s1, this.v, [this.pausa]);
  bool get detenida => v == 0;
}

/// Tiempo para recorrer [d] metros arrancando desde cero y frenando hasta cero.
double _tiempoTramo(double d, double v) {
  final dA = v * v / (2 * _acelera), dF = v * v / (2 * _frena);
  if (d >= dA + dF) return v / _acelera + v / _frena + (d - dA - dF) / v;
  final vp = math.sqrt(2 * d / (1 / _acelera + 1 / _frena));
  return vp / _acelera + vp / _frena;
}

/// Tiempo para llegar a [d] metros arrancando desde cero, sin frenar.
double _tiempoSinFrenar(double d, double v) {
  final dA = v * v / (2 * _acelera);
  if (d >= dA) return v / _acelera + (d - dA) / v;
  return math.sqrt(2 * d / _acelera);
}

/// Metros avanzados [tau] segundos después de arrancar en un tramo de [d] metros
/// que dura [T] segundos con velocidad máxima [v].
double _posicion(double tau, double d, double T, double v) {
  if (tau <= 0) return 0;
  if (tau >= T) return d;
  final dA = v * v / (2 * _acelera), dF = v * v / (2 * _frena);
  var vp = v;
  if (d < dA + dF) vp = math.sqrt(2 * d / (1 / _acelera + 1 / _frena));
  final tA = vp / _acelera, tF = vp / _frena;
  if (tau < tA) return 0.5 * _acelera * tau * tau;
  final quedan = T - tau;
  if (quedan < tF) return d - 0.5 * _frena * quedan * quedan;
  return 0.5 * _acelera * tA * tA + vp * (tau - tA);
}

/// Una vuelta completa de una combi que sale del inicio a la hora [salida]:
/// arranca y frena en cada parada, espera más o menos gente según la hora,
/// se para sólo si le toca rojo y va más lenta en hora pico. Cada chofer maneja un poco distinto.
class Vuelta {
  final Ruta ruta;
  final int numero;
  final double salida;
  final List<_Pedazo> _pedazos = [];
  late final List<double> llegadas;
  late final double duracion;

  Vuelta(this.ruta, this.numero, this.salida, {bool tipica = false}) {
    final chofer = tipica ? 1.0 : 0.97 + 0.06 * _azar(ruta.id, numero, 1);
    final llegadasP = List<double>.filled(ruta.paradas.length, 0);
    var t = 0.0, s = 0.0;

    void avanzar(double hasta) {
      final d = hasta - s;
      if (d < 0.5) return;
      final v = ruta.velocidadMs * chofer / factorTrafico(salida + t);
      final T = _tiempoTramo(d, v);
      _pedazos.add(_Pedazo(t, t + T, s, hasta, v));
      t += T;
      s = hasta;
    }

    void detener(double seg, Pausa p) {
      if (seg <= 0) return;
      _pedazos.add(_Pedazo(t, t + seg, s, s, 0, p));
      t += seg;
    }

    for (final p in ruta.pausas) {
      if (p.semaforo != null) {
        final sem = p.semaforo!;
        final v = ruta.velocidadMs * chofer / factorTrafico(salida + t);
        final llegaria = salida + t + _tiempoSinFrenar(p.metros - s, v);
        if (!semaforoEnRojo(sem, p.metros, llegaria)) continue; // verde: pasa de largo
        avanzar(p.metros);
        detener(math.max(3, faltaVerde(sem, p.metros, salida + t)), p);
      } else {
        avanzar(p.metros);
        llegadasP[p.parada!.indice] = t;
        final gente = 1 + 0.7 * horaPico(salida + t);
        final base = p.parada!.principal ? esperaEnParada : 16.0;
        final azar = tipica ? 1.0 : 0.7 + 0.6 * _azar(ruta.id, numero, 100 + p.parada!.indice);
        detener(base * gente * azar, p);
      }
    }
    avanzar(ruta.trazo.largo);
    llegadas = llegadasP;
    duracion = t;
  }

  _Pedazo? _pedazoEn(double e) {
    if (_pedazos.isEmpty || e < 0 || e > duracion) return null;
    var lo = 0, hi = _pedazos.length - 1;
    while (lo < hi) {
      final m = (lo + hi + 1) >> 1;
      if (_pedazos[m].t0 <= e) {
        lo = m;
      } else {
        hi = m - 1;
      }
    }
    return _pedazos[lo];
  }

  /// Metros recorridos [e] segundos después de salir del inicio.
  double metrosA(double e) {
    if (e <= 0) return 0;
    if (e >= duracion) return ruta.trazo.largo;
    final p = _pedazoEn(e)!;
    if (p.detenida) return p.s0;
    return p.s0 + _posicion(e - p.t0, p.s1 - p.s0, p.t1 - p.t0, p.v);
  }

  /// Dónde está detenida (parada o semáforo) [e] segundos después de salir, o null si va avanzando.
  Pausa? pausaA(double e) {
    final p = _pedazoEn(e);
    return p != null && p.detenida ? p.pausa : null;
  }

  /// Velocidad en km/h [e] segundos después de salir.
  double kmhA(double e) => ((metrosA(e + 0.5) - metrosA(e - 0.5)) * 3.6).clamp(0, 80).toDouble();
}

/// Una combi en movimiento en este momento.
class CombiEnRuta {
  final Ruta ruta;
  final Vuelta vuelta;
  final double salida; // segundo del día en que salió del inicio
  final double metros;
  final LatLng punto;
  final Pausa? pausa; // dónde está detenida, si lo está
  final Parada? siguiente;
  final double kmh;
  CombiEnRuta(this.ruta, this.vuelta, this.salida, this.metros, this.punto, this.pausa, this.siguiente, this.kmh);
  bool get detenida => pausa != null;

  /// Segundos para llegar a la siguiente parada.
  double? faltaSiguiente(double ahora) => siguiente == null ? null : vuelta.llegadas[siguiente!.indice] - (ahora - salida);
}

/// La vuelta (y el día) de la combi que pasa por una parada a cierta hora.
class Pasada {
  final Vuelta vuelta;
  final double base; // 0 hoy, 86400 mañana...
  Pasada(this.vuelta, this.base);
  double get salida => base + vuelta.salida;
}

class Ruta {
  final RutaDatos datos;
  late final Trazo trazo;
  late final List<Parada> paradas;
  late final List<Pausa> pausas;
  late final List<Semaforo> semaforosEnRuta;

  /// Horas de salida del día: más seguidas en hora pico y más espaciadas en la noche.
  late final List<double> salidas;
  late final Vuelta tipica;
  final Map<int, Vuelta> _vueltas = {};
  late final double _duracionMax;

  Ruta(this.datos) {
    trazo = Trazo([for (final p in datos.trazo) LatLng(p[0], p[1])]);
    final ordenadas = [...datos.paradas]..sort((a, b) => a.metros.compareTo(b.metros));
    paradas = [for (var i = 0; i < ordenadas.length; i++) Parada(this, ordenadas[i], i)];

    final lista = <Pausa>[for (final p in paradas) Pausa(p.metros, p.principal ? esperaEnParada : 16, parada: p)];
    final enRuta = <Semaforo>[];
    for (final sem in semaforos) {
      final pasos = trazo.pasos(sem.punto);
      if (pasos.isNotEmpty) enRuta.add(sem);
      for (final m in pasos) {
        lista.add(Pausa(m, rojoSemaforo / 2, semaforo: sem));
      }
    }
    lista.sort((a, b) => a.metros.compareTo(b.metros));
    pausas = lista;
    semaforosEnRuta = enRuta;

    // Salidas: más seguidas en hora pico, más espaciadas al final del día, y la última
    // sale a tiempo para terminar su vuelta antes de las 21:00.
    final sal = <double>[];
    var t = inicioServicio.toDouble();
    while (true) {
      final v = Vuelta(this, sal.length, t);
      if (t + v.duracion > finServicio) break;
      _vueltas[sal.length] = v;
      sal.add(t);
      var hueco = frecuenciaSeg / (1 + 0.35 * horaPico(t));
      if (t >= 19.75 * 3600) hueco *= 1.3;
      t += (hueco / 30).round() * 30.0;
    }
    salidas = sal;
    tipica = Vuelta(this, -1, 11 * 3600, tipica: true);
    _duracionMax = tipica.duracion * 1.8;
  }

  Vuelta vuelta(int k) => _vueltas[k] ??= Vuelta(this, k, salidas[k]);

  /// Minutos típicos de una vuelta completa (segundos).
  double get duracion => tipica.duracion;

  /// Metros recorridos en una vuelta típica [e] segundos después de salir.
  double metrosA(double e) => tipica.metrosA(e);

  /// Primer índice de salida >= [t] (en segundos del día).
  int _desde(double t) {
    var lo = 0, hi = salidas.length;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (salidas[m] < t) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    return lo;
  }

  /// La pausa (parada o semáforo) que está en el metro [m], si hay.
  Pausa? pausaEn(double m) {
    for (final p in pausas) {
      if ((p.metros - m).abs() < 0.6) return p;
    }
    return null;
  }

  /// Todas las combis que van en el recorrido en el segundo [t] del día.
  List<CombiEnRuta> combisEn(double t) {
    final r = <CombiEnRuta>[];
    final t0 = t % segundosDia;
    for (var k = _desde(t0 - _duracionMax); k < salidas.length && salidas[k] <= t0; k++) {
      final v = vuelta(k);
      final e = t0 - v.salida;
      if (e > v.duracion) continue;
      final m = v.metrosA(e);
      Parada? sig;
      for (final p in paradas) {
        if (v.llegadas[p.indice] >= e - 0.5) {
          sig = p;
          break;
        }
      }
      r.add(CombiEnRuta(this, v, v.salida, m, trazo.puntoEn(m), v.pausaA(e), sig, v.kmhA(e)));
    }
    return r;
  }

  /// Próximas [n] llegadas a la parada desde el segundo [t] del día (pueden pasar de 86400 = mañana).
  List<double> proximasLlegadas(Parada p, double t, {int n = 3}) {
    final r = <double>[];
    for (var dia = 0; dia < 3 && r.length < n; dia++) {
      final base = dia * segundosDia.toDouble();
      final cand = <double>[];
      for (var k = _desde(t - base - _duracionMax); k < salidas.length; k++) {
        final llega = base + salidas[k] + vuelta(k).llegadas[p.indice];
        if (llega >= t) cand.add(llega);
        if (cand.length >= n + 2) break;
      }
      cand.sort();
      r.addAll(cand.take(n - r.length));
    }
    return r;
  }

  double proximaLlegada(Parada p, double t) => proximasLlegadas(p, t, n: 1).first;

  /// La combi (vuelta) que llega a [p] en el segundo [llegada].
  Pasada pasadaDe(Parada p, double llegada) {
    final dia = (llegada / segundosDia).floor();
    final base = dia * segundosDia.toDouble();
    final rel = llegada - base;
    var mejor = 0;
    var dMin = double.infinity;
    for (var k = _desde(rel - _duracionMax); k < salidas.length && salidas[k] <= rel; k++) {
      final d = (salidas[k] + vuelta(k).llegadas[p.indice] - rel).abs();
      if (d < dMin) {
        dMin = d;
        mejor = k;
      }
    }
    return Pasada(vuelta(mejor), base);
  }

  /// Hora en que sale del inicio la combi que llega a [p] en el segundo [llegada].
  double salidaDe(Parada p, double llegada) => pasadaDe(p, llegada).salida;

  /// Metros donde va, en el segundo [ahora], la combi que llega a [p] en [llegada]
  /// (0 si todavía no sale; null si ya terminó su vuelta).
  double? metrosCombi(Parada p, double llegada, double ahora) {
    final pas = pasadaDe(p, llegada);
    var e = ahora - pas.salida;
    if (e <= 0) return 0;
    if (e > pas.vuelta.duracion) e -= pas.vuelta.duracion; // ya dio la vuelta y sigue
    if (e > pas.vuelta.duracion) return null;
    return pas.vuelta.metrosA(e);
  }

  /// Dónde va la combi que llegará a la parada [p] en el segundo [llegada]
  /// (null si todavía no sale del inicio).
  LatLng? combiQueLlega(Parada p, double llegada, double ahora) {
    final pas = pasadaDe(p, llegada);
    final e = ahora - pas.salida;
    if (e < 0) return null;
    return trazo.puntoEn(pas.vuelta.metrosA(e));
  }

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

  /// Minutos que tarda una vuelta completa (típica).
  double get vueltaMin => duracion / 60;

  /// ¿Hay una combi detenida en la parada [p] en el segundo [t]?
  bool combiEnParada(Parada p, double t) => combisEn(t).any((c) => identical(c.pausa?.parada, p));

  /// Minutos entre combis a la hora [t] (en hora pico pasan más seguido).
  int frecuenciaA(double t) {
    final k = _desde(t % segundosDia).clamp(1, salidas.length - 1);
    return ((salidas[k] - salidas[k - 1]) / 60).round();
  }

  /// Segundos de viaje en la misma combi: sube en [a] cuando llega en [llegadaA] y baja en [b].
  double viajeEn(Parada a, double llegadaA, Parada b) {
    final v = pasadaDe(a, llegadaA).vuelta;
    if (b.indice > a.indice) return v.llegadas[b.indice] - v.llegadas[a.indice];
    return (v.duracion - v.llegadas[a.indice]) + tipica.llegadas[b.indice];
  }

  /// Segundos de viaje típicos de la parada [a] a la parada [b].
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
}

final List<Ruta> rutas = [for (final d in rutasDatos) Ruta(d)];

Ruta rutaPorId(String id) => rutas.firstWhere((r) => r.id == id);

/// Para probar a otra hora (versión web: ?hora=22.5): segundos que se suman al reloj.
double ajusteReloj = 0;

/// Segundos transcurridos del día de hoy.
double segundosAhora() {
  final a = DateTime.now();
  final s = a.hour * 3600.0 + a.minute * 60 + a.second + a.millisecond / 1000 + ajusteReloj;
  return ((s % segundosDia) + segundosDia) % segundosDia;
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
