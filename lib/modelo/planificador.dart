// Buscador de viajes: combina caminar + combi (+ transbordo) y ordena por hora de llegada.
//
// Para cada ruta busca las paradas cercanas al origen y al destino, calcula
//   caminar a la parada + esperar la próxima combi (según su horario) + viaje + caminar al destino
// y se queda con la mejor forma de usar cada ruta o par de rutas (con un transbordo).

import 'package:latlong2/latlong.dart';

import 'geo.dart';
import 'ruta.dart';

/// 4.5 km/h, y las calles no van en línea recta: se camina un 25 % más que la distancia directa.
const double velocidadPie = 1.25;
const double rodeo = 1.25;

double segundosAPie(LatLng a, LatLng b) => distanciaM(a, b) * rodeo / velocidadPie;
double metrosAPie(LatLng a, LatLng b) => distanciaM(a, b) * rodeo;

enum TipoTramo { pie, combi }

class Tramo {
  final TipoTramo tipo;
  final double inicio; // segundo del día en que empieza
  final double fin;
  final LatLng desde;
  final LatLng hasta;
  final String desdeNombre;
  final String hastaNombre;
  final double metros;

  // Sólo para tramos en combi
  final Ruta? ruta;
  final Parada? sube;
  final Parada? baja;
  final double espera; // segundos esperando en la parada antes de este tramo
  final List<LatLng> puntos;

  Tramo({
    required this.tipo,
    required this.inicio,
    required this.fin,
    required this.desde,
    required this.hasta,
    required this.desdeNombre,
    required this.hastaNombre,
    required this.metros,
    this.ruta,
    this.sube,
    this.baja,
    this.espera = 0,
    required this.puntos,
  });

  double get segundos => fin - inicio;
  int get paradas => (ruta != null && sube != null && baja != null) ? ruta!.paradasEntre(sube!, baja!) + 1 : 0;
}

class Opcion {
  final List<Tramo> tramos;
  final double salida;
  bool masRapida = false;

  Opcion(this.tramos, this.salida);

  double get llegada => tramos.isEmpty ? salida : tramos.last.fin;
  double get total => llegada - salida;
  Iterable<Tramo> get enCombi => tramos.where((t) => t.tipo == TipoTramo.combi);
  int get transbordos => enCombi.length > 1 ? enCombi.length - 1 : 0;
  double get espera => enCombi.fold(0.0, (s, t) => s + t.espera);
  double get aPie => tramos.where((t) => t.tipo == TipoTramo.pie).fold(0.0, (s, t) => s + t.segundos);
  double get metrosAPie => tramos.where((t) => t.tipo == TipoTramo.pie).fold(0.0, (s, t) => s + t.metros);
  bool get soloAPie => enCombi.isEmpty;

  /// Rutas usadas, p. ej. "R3>R1"; sirve para no repetir la misma combinación.
  String get firma => soloAPie ? 'pie' : enCombi.map((t) => t.ruta!.id).join('>');
}

class _Cercana {
  final Parada parada;
  final double segundos;
  _Cercana(this.parada, this.segundos);
}

class Planificador {
  final List<Ruta> todas;
  Planificador([List<Ruta>? r]) : todas = r ?? rutas;

  List<_Cercana> _cercanas(Ruta r, LatLng p, double radio, {int max = 4}) {
    final l = <_Cercana>[];
    for (final par in r.paradas) {
      final d = distanciaM(p, par.punto);
      if (d <= radio) l.add(_Cercana(par, segundosAPie(p, par.punto)));
    }
    l.sort((a, b) => a.segundos.compareTo(b.segundos));
    return l.length > max ? l.sublist(0, max) : l;
  }

  Tramo _pie(LatLng a, LatLng b, String na, String nb, double t) {
    return Tramo(
      tipo: TipoTramo.pie,
      inicio: t,
      fin: t + segundosAPie(a, b),
      desde: a,
      hasta: b,
      desdeNombre: na,
      hastaNombre: nb,
      metros: metrosAPie(a, b),
      puntos: [a, b],
    );
  }

  Tramo _combi(Ruta r, Parada sube, Parada baja, double listo) {
    final llega = r.proximaLlegada(sube, listo);
    return Tramo(
      tipo: TipoTramo.combi,
      inicio: llega,
      fin: llega + r.viaje(sube, baja),
      desde: sube.punto,
      hasta: baja.punto,
      desdeNombre: sube.nombre,
      hastaNombre: baja.nombre,
      metros: (baja.metros - sube.metros) % r.trazo.largo,
      ruta: r,
      sube: sube,
      baja: baja,
      espera: llega - listo,
      puntos: r.tramoEntre(sube, baja),
    );
  }

  /// Opciones ordenadas de la que llega primero a la que llega al último.
  /// Siempre intenta dar al menos [minimo] combinaciones de combis distintas.
  List<Opcion> planear(
    LatLng origen,
    LatLng destino, {
    required double ahora,
    String origenNombre = 'Origen',
    String destinoNombre = 'Destino',
    int minimo = 3,
    int maximo = 3,
  }) {
    var radio = 900.0;
    var radioTransbordo = 450.0;
    Map<String, Opcion> mejores = {};
    for (var intento = 0; intento < 3; intento++) {
      mejores = _buscar(origen, destino, ahora, origenNombre, destinoNombre, radio, radioTransbordo);
      if (mejores.length >= minimo) break;
      radio += 500;
      radioTransbordo += 250;
    }

    // Un transbordo que no gana tiempo frente a ir directo en una de sus dos combis sobra.
    final directos = {for (final o in mejores.values) if (o.transbordos == 0) o.firma: o.llegada};
    final sobran = mejores.values.where((o) {
      if (o.transbordos == 0) return false;
      return o.firma.split('>').any((id) => directos[id] != null && directos[id]! <= o.llegada + 60);
    }).toList()
      ..sort((a, b) => b.llegada.compareTo(a.llegada));
    for (final o in sobran) {
      if (mejores.length <= minimo) break;
      mejores.remove(o.firma);
    }

    final lista = mejores.values.toList()..sort((a, b) => a.llegada.compareTo(b.llegada));
    final combis = lista.take(maximo).toList();

    // Caminar también es opción si está cerca.
    final directo = distanciaM(origen, destino);
    if (directo <= 2500) {
      final pie = Opcion([_pie(origen, destino, origenNombre, destinoNombre, ahora)], ahora);
      combis.add(pie);
      combis.sort((a, b) => a.llegada.compareTo(b.llegada));
    }
    if (combis.isNotEmpty) combis.first.masRapida = true;
    return combis;
  }

  Map<String, Opcion> _buscar(LatLng o, LatLng d, double ahora, String on, String dn, double radio, double radioT) {
    final mejores = <String, Opcion>{};
    void guardar(Opcion op) {
      final actual = mejores[op.firma];
      if (actual == null || op.llegada < actual.llegada) mejores[op.firma] = op;
    }

    // Directo: una sola combi
    for (final r in todas) {
      final suben = _cercanas(r, o, radio);
      final bajan = _cercanas(r, d, radio);
      for (final s in suben) {
        for (final b in bajan) {
          if (s.parada == b.parada) continue;
          final caminar1 = _pie(o, s.parada.punto, on, s.parada.nombre, ahora);
          final combi = _combi(r, s.parada, b.parada, caminar1.fin);
          final caminar2 = _pie(b.parada.punto, d, b.parada.nombre, dn, combi.fin);
          guardar(Opcion([caminar1, combi, caminar2], ahora));
        }
      }
    }

    // Con un transbordo
    for (final r1 in todas) {
      final suben = _cercanas(r1, o, radio, max: 3);
      if (suben.isEmpty) continue;
      for (final r2 in todas) {
        if (identical(r1, r2)) continue;
        final bajan = _cercanas(r2, d, radio, max: 3);
        if (bajan.isEmpty) continue;
        for (final x in r1.paradas) {
          for (final y in r2.paradas) {
            if (distanciaM(x.punto, y.punto) > radioT) continue;
            for (final s in suben) {
              if (s.parada == x) continue;
              for (final b in bajan) {
                if (b.parada == y) continue;
                final caminar1 = _pie(o, s.parada.punto, on, s.parada.nombre, ahora);
                final combi1 = _combi(r1, s.parada, x, caminar1.fin);
                final cambio = _pie(x.punto, y.punto, x.nombre, y.nombre, combi1.fin);
                final combi2 = _combi(r2, y, b.parada, cambio.fin);
                final caminar2 = _pie(b.parada.punto, d, b.parada.nombre, dn, combi2.fin);
                guardar(Opcion([caminar1, combi1, cambio, combi2, caminar2], ahora));
              }
            }
          }
        }
      }
    }
    return mejores;
  }
}
