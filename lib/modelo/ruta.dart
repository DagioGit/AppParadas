import 'dart:ui' show Color;

import 'package:latlong2/latlong.dart';

import '../datos/rutas_datos.dart';
import '../datos/rutas_modelo_datos.dart';
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

  /// Segundos desde que la combi sale del inicio hasta que llega a esta parada.
  double get desfase => metros / ruta.velocidadMs + indice * esperaEnParada;

  /// Paradas principales: las de las rutas reales y las de nombre propio en las simuladas.
  bool get principal => !ruta.simulada || sentido == 'Parada principal';
}

class Ruta {
  final RutaDatos datos;
  late final Trazo trazo;
  late final List<Parada> paradas;

  Ruta(this.datos) {
    trazo = Trazo([for (final p in datos.trazo) LatLng(p[0], p[1])]);
    final ordenadas = [...datos.paradas]..sort((a, b) => a.metros.compareTo(b.metros));
    paradas = [for (var i = 0; i < ordenadas.length; i++) Parada(this, ordenadas[i], i)];
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

  /// Minutos que tarda una vuelta completa.
  double get vueltaMin => (trazo.largo / velocidadMs + paradas.length * esperaEnParada) / 60;

  /// Segundos de viaje en la misma combi de la parada [a] a la parada [b].
  double viaje(Parada a, Parada b) {
    if (b.metros > a.metros) {
      return (b.metros - a.metros) / velocidadMs + (b.indice - a.indice) * esperaEnParada;
    }
    return (trazo.largo - a.metros + b.metros) / velocidadMs +
        (paradas.length - a.indice + b.indice) * esperaEnParada;
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
