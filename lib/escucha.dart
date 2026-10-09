// Escuchar la voz de la persona (micrófono → texto). Lo usan "Di a dónde vas" y el modo de voz.

import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class Escucha {
  static final SpeechToText _stt = SpeechToText();
  static bool? _ok;
  static String? _idioma;
  static Future<bool>? _preparando;
  static void Function(String estado)? _alEstado;
  static void Function()? _alError;

  /// Pide el micrófono y busca el español (es-MX si está). Conviene llamarlo al abrir la pantalla.
  static Future<bool> preparar() => _preparando ??= () async {
        try {
          _ok = await _stt.initialize(
            onStatus: (s) => _alEstado?.call(s),
            onError: (_) => _alError?.call(),
          );
          if (_ok == true) {
            try {
              final idiomas = await _stt.locales();
              String norm(String s) => s.toLowerCase().replaceAll('-', '_');
              _idioma = idiomas.where((l) => norm(l.localeId) == 'es_mx').map((l) => l.localeId).firstOrNull ??
                  idiomas.where((l) => norm(l.localeId).startsWith('es')).map((l) => l.localeId).firstOrNull;
            } catch (_) {}
          }
        } catch (_) {
          _ok = false;
        }
        return _ok == true;
      }();

  static bool get disponible => _ok == true;
  static bool get escuchando => _stt.isListening;

  /// Escucha una frase. [parcial] recibe lo que va entendiendo. Regresa la frase o null.
  /// Si ya está preparado, empieza a escuchar en el mismo toque (sin esperas).
  static Future<String?> unaVez({void Function(String)? parcial, Duration maximo = const Duration(seconds: 10)}) {
    if (_ok == null) return preparar().then((ok) => ok ? unaVez(parcial: parcial, maximo: maximo) : null);
    if (_ok == false) return Future.value(null);
    final c = Completer<String?>();
    var ultimo = '';
    void terminar() {
      if (!c.isCompleted) c.complete(ultimo.trim().isEmpty ? null : ultimo.trim());
    }

    _alEstado = (s) {
      if (s == 'done' || s == 'notListening') Future.delayed(const Duration(milliseconds: 500), terminar);
    };
    _alError = terminar;
    try {
      _stt.listen(
        onResult: (r) {
          ultimo = r.recognizedWords;
          parcial?.call(ultimo);
          if (r.finalResult) terminar();
        },
        listenOptions: SpeechListenOptions(
          localeId: _idioma,
          listenFor: maximo,
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      terminar();
    }
    return c.future.timeout(maximo + const Duration(seconds: 4), onTimeout: () {
      _stt.stop();
      return ultimo.trim().isEmpty ? null : ultimo.trim();
    });
  }

  static Future<void> parar() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
