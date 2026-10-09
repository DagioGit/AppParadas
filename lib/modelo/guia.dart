// Motor de la guía paso a paso (lo usan "Guiarme con voz" y el modo de voz para personas ciegas).
// Con la hora y la posición (GPS o estimada) dice qué hacer: caminar a la parada, esperar,
// subirse, cuántas paradas faltan, bajarse y caminar al destino.

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../voz.dart' show cuandoHablado;
import 'geo.dart';
import 'planificador.dart';
import 'ruta.dart';

enum TipoPaso { caminar, esperar, combi, llegaste }

class EstadoGuia {
  final TipoPaso tipo;
  final String titulo;
  final String detalle;

  /// Lo que hay que decir ahora (sólo cuando cambia algo); null si no hay nada nuevo.
  final String? decir;
  const EstadoGuia(this.tipo, this.titulo, this.detalle, this.decir);
}

/// Hacia dónde queda [b] desde [a]: "hacia el norte", "hacia el sureste"…
String haciaDonde(LatLng a, LatLng b) {
  final dx = (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180);
  final dy = b.latitude - a.latitude;
  var ang = math.atan2(dx, dy) * 180 / math.pi;
  if (ang < 0) ang += 360;
  const nombres = ['norte', 'noreste', 'este', 'sureste', 'sur', 'suroeste', 'oeste', 'noroeste'];
  return 'hacia el ${nombres[((ang + 22.5) ~/ 45) % 8]}';
}

String metrosHablados(double m) {
  if (m < 20) return 'unos pasos';
  if (m < 1000) return '${(m / 10).round() * 10} metros';
  return '${(m / 1000).toStringAsFixed(1)} kilómetros';
}

class MotorGuia {
  final Opcion opcion;
  final String destino;
  int i = 0; // tramo actual
  bool fin = false;
  final Set<String> _dichos = {};
  String ultimoDicho = '';
  EstadoGuia? ultimo;

  MotorGuia(this.opcion, this.destino);

  List<Tramo> get tramos => opcion.tramos;

  String? _una(String clave, String texto) {
    if (!_dichos.add(clave)) return null;
    ultimoDicho = texto;
    return texto;
  }

  /// Dónde va la persona según el horario (cuando no hay GPS).
  LatLng posEstimada(double ahora) {
    if (i >= tramos.length) return tramos.last.hasta;
    final t = tramos[i];
    if (t.tipo == TipoTramo.combi) {
      if (ahora < t.inicio) return t.desde;
      final m = t.ruta!.metrosCombi(t.sube!, t.inicio, ahora);
      return m == null ? t.hasta : t.ruta!.trazo.puntoEn(m);
    }
    final u = ((ahora - t.inicio) / math.max(1, t.fin - t.inicio)).clamp(0.0, 1.0);
    return LatLng(t.desde.latitude + (t.hasta.latitude - t.desde.latitude) * u, t.desde.longitude + (t.hasta.longitude - t.desde.longitude) * u);
  }

  /// Paradas que faltan (contando la de bajada) para la combi del tramo [t] en el segundo [ahora].
  int paradasQueFaltan(Tramo t, double ahora) {
    final r = t.ruta!;
    final pas = r.pasadaDe(t.sube!, t.inicio);
    final v = pas.vuelta;
    final e = ahora - pas.salida;
    final n = r.paradas.length;
    var faltan = 0;
    var k = t.sube!.indice;
    var vuelta = 0.0;
    while (k != t.baja!.indice) {
      k = (k + 1) % n;
      if (k == 0) vuelta = v.duracion;
      final llega = vuelta == 0 ? v.llegadas[k] : vuelta + r.tipica.llegadas[k];
      if (llega > e) faltan++;
    }
    return faltan;
  }

  /// Qué hacer ahora. [pos] es la posición del GPS (null si no hay).
  EstadoGuia paso(double ahora, LatLng? pos) {
    for (var vueltas = 0; vueltas < 6; vueltas++) {
      if (fin || i >= tramos.length) {
        fin = true;
        return ultimo = EstadoGuia(TipoPaso.llegaste, '¡Llegaste!', destino, _una('fin', 'Llegaste a $destino. Buen viaje.'));
      }
      final t = tramos[i];
      final esUltimo = i == tramos.length - 1;

      if (t.tipo == TipoTramo.pie) {
        final aqui = pos ?? posEstimada(ahora);
        final dist = pos != null ? distanciaM(pos, t.hasta) : math.max(0.0, t.metros * (t.fin - ahora) / math.max(1, t.fin - t.inicio));
        final llego = dist < 25 || (pos == null && ahora >= t.fin) || t.segundos < 20;
        if (llego) {
          if (esUltimo) {
            i++;
            continue;
          }
          final sig = tramos[i + 1];
          final dicho = _una('llego-$i', 'Llegaste a la parada ${sig.sube!.nombre}. Espera la ${sig.ruta!.nombre}.');
          i++;
          final e = paso(ahora, pos);
          return ultimo = EstadoGuia(e.tipo, e.titulo, e.detalle, _juntar(dicho, e.decir));
        }
        final hacia = haciaDonde(aqui, t.hasta);
        final meta = esUltimo ? destino : 'la parada ${t.hastaNombre}';
        return ultimo = EstadoGuia(
          TipoPaso.caminar,
          'Camina ${metrosHablados(dist)}',
          '$hacia, hasta $meta.',
          _una('pie-$i-${(dist / 100).ceil()}', 'Camina ${metrosHablados(dist)} $hacia, hasta $meta.'),
        );
      }

      final r = t.ruta!;
      final falta = t.inicio - ahora;
      if (falta > 25) {
        final min = (falta / 60).ceil();
        String? dicho;
        if ([5, 3, 2, 1].contains(min)) dicho = _una('espera-$i-$min', 'Tu combi, la ${r.nombre}, llega ${min == 1 ? 'en un minuto' : 'en $min minutos'}.');
        dicho ??= _una('espera-$i', 'Espera la ${r.nombre} en la parada ${t.sube!.nombre}. Llega ${cuandoHablado(t.inicio, ahora)}.');
        return ultimo = EstadoGuia(
          TipoPaso.esperar,
          'Tu combi llega en ${falta < 60 ? '${falta.round()} s' : '$min min'}',
          'Espera la ${r.nombre} (${r.apodo}) en ${t.sube!.nombre}.',
          dicho,
        );
      }
      if (ahora < t.inicio + 20) {
        return ultimo = EstadoGuia(
          TipoPaso.combi,
          '¡Súbete!',
          'Llegó la ${r.nombre} (${r.apodo}). Bájate en ${t.baja!.nombre}.',
          _una('sube-$i', 'Ya llegó tu combi: la ${r.nombre}, ${r.apodo}. Súbete. Te aviso dónde bajarte.'),
        );
      }
      if (ahora < t.fin) {
        final faltan = paradasQueFaltan(t, ahora);
        if (faltan <= 1) {
          return ultimo = EstadoGuia(
            TipoPaso.combi,
            'Bájate en la próxima',
            'Tu parada: ${t.baja!.nombre}. Pide la parada.',
            _una('proxima-$i', 'Prepárate: bájate en la próxima parada, ${t.baja!.nombre}. Pide la parada.'),
          );
        }
        return ultimo = EstadoGuia(
          TipoPaso.combi,
          'Faltan $faltan paradas',
          'Vas en la ${r.nombre}. Te bajas en ${t.baja!.nombre}.',
          _una('bordo-$i-$faltan', 'Vas en la combi. Faltan $faltan paradas para bajarte en ${t.baja!.nombre}.'),
        );
      }
      final dicho = _una('baja-$i', 'Bájate aquí: ${t.baja!.nombre}.');
      i++;
      final e = paso(ahora, pos);
      return ultimo = EstadoGuia(e.tipo, e.titulo, e.detalle, _juntar(dicho, e.decir));
    }
    return ultimo ?? const EstadoGuia(TipoPaso.caminar, '', '', null);
  }

  String? _juntar(String? a, String? b) {
    final t = [a, b].whereType<String>().join(' ').trim();
    return t.isEmpty ? null : t;
  }

  /// Para "¿cuánto falta?": un resumen de lo que sigue y a qué hora se llega.
  String cuantoFalta(double ahora) {
    final e = ultimo;
    final llegada = opcion.llegada;
    final resto = llegada - ahora;
    final base = e == null ? '' : '${e.titulo}. ${e.detalle} ';
    if (fin) return 'Ya llegaste a $destino.';
    return '${base}Llegas a $destino ${resto < 60 ? 'en menos de un minuto' : 'en ${(resto / 60).round()} minutos'}, a las ${hora(llegada)}.';
  }
}
