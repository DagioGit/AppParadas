// Señalamiento por voz: la app dice en voz alta las paradas, cuánto falta para la combi y
// los avisos. Pensado para personas con discapacidad visual, personas mayores y niños.
//
// - Los botones "Escuchar" siempre hablan.
// - Si en Ajustes está prendido "Avisos por voz", también habla sola (avisos, viajes, paradas).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import 'ajustes.dart';
import 'modelo/incidentes.dart';
import 'modelo/planificador.dart';
import 'modelo/ruta.dart';

class Voz {
  static FlutterTts? _tts;
  static bool _listo = false;

  static Future<FlutterTts> _preparar() async {
    final t = _tts ??= FlutterTts();
    if (!_listo) {
      _listo = true;
      try {
        await t.setLanguage('es-MX');
        await t.setSpeechRate(kIsWeb ? 0.9 : 0.45); // un poco más despacio que lo normal
        await t.setVolume(1.0);
      } catch (_) {}
    }
    return t;
  }

  /// Dice [texto] (botón "Escuchar").
  static Future<void> decir(String texto) async {
    try {
      final t = await _preparar();
      await t.stop();
      await t.speak(texto);
    } catch (_) {}
  }

  /// Dice [texto] sólo si "Avisos por voz" está prendido.
  static Future<void> avisar(String texto) async {
    if (ajustes.voz) await decir(texto);
  }

  static Future<void> callar() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

/// "en menos de un minuto", "en un minuto", "en 7 minutos", "a las 6:01".
String cuandoHablado(double llegada, double ahora) {
  final s = llegada - ahora;
  if (s < 60) return 'en menos de un minuto';
  final m = (s / 60).round();
  if (m == 1) return 'en un minuto';
  if (s < 3600) return 'en $m minutos';
  return 'a las ${hora(llegada).replaceFirst('mañana ', '')}${llegada >= segundosDia ? ' de mañana' : ''}';
}

String _retrasoHablado(double seg) {
  final m = (seg / 60).round();
  return m <= 1 ? 'un minuto' : '$m minutos';
}

/// Lo que se dice de una parada: nombre, próxima combi y avisos.
String textoParada(Parada p, double ahora) {
  final r = p.ruta;
  final b = StringBuffer('Parada ${p.nombre}, ${r.nombre}. ');
  if (!enServicio(ahora)) {
    b.write('Por ahora no hay combis. Vuelven a pasar a las 6 de la mañana.');
    return b.toString();
  }
  if (r.combiEnParada(p, ahora)) {
    b.write('La combi está en la parada. Puede subir. ');
  }
  final llega = r.proximaLlegada(p, ahora);
  b.write('La próxima combi llega ${cuandoHablado(llega, ahora)}. ');
  for (final (inc, ret) in r.incidentesAhora(ahora)) {
    b.write('${inc.esAccidente ? 'Hay un accidente' : 'Hay tráfico'} en ${inc.donde}: la combi viene con ${_retrasoHablado(ret)} de retraso. ');
  }
  return b.toString();
}

/// Lo que se dice de una forma de llegar: qué combi tomar, dónde bajarse y a qué hora se llega.
String textoOpcion(Opcion o, double ahora, {bool masRapida = false}) {
  final b = StringBuffer(masRapida ? 'La forma más rápida. ' : '');
  if (o.soloAPie) {
    b.write('Te conviene caminar. Llegas en ${duracion(o.total)}.');
    return b.toString();
  }
  var primera = true;
  for (final t in o.tramos) {
    if (t.tipo == TipoTramo.pie) {
      if (t.segundos >= 60) b.write('Camina ${duracion(t.segundos)} hasta ${t.hastaNombre}. ');
    } else {
      b.write('${primera ? 'Toma' : 'Luego toma'} la ${t.ruta!.nombre} en ${t.sube!.nombre}; pasa ${cuandoHablado(t.inicio, ahora)}. ');
      b.write('Bájate en ${t.baja!.nombre}. ');
      for (final (inc, ret) in t.ruta!.incidentesEnViaje(t.sube!, t.baja!, t.inicio, t.fin).take(2)) {
        b.write('${inc.esAccidente ? 'Hay un accidente' : 'Hay tráfico'} en ${inc.donde}, unos ${_retrasoHablado(ret)} más. ');
      }
      primera = false;
    }
  }
  b.write('Llegas a las ${hora(o.llegada)}.');
  return b.toString();
}
