import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

FlutterTts? _tts;
Future<FlutterTts>? _listo;

Future<FlutterTts> _preparar() => _listo ??= () async {
      final t = _tts = FlutterTts();
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // Que se oiga aunque el iPhone esté en silencio y por audífonos Bluetooth
          await t.setSharedInstance(true);
          await t.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
              IosTextToSpeechAudioCategoryOptions.duckOthers,
            ],
            IosTextToSpeechAudioMode.voicePrompt,
          );
        }
        await t.setLanguage('es-MX');
        await t.setSpeechRate(0.45); // un poco más despacio que lo normal
        await t.setVolume(1.0);
      } catch (_) {}
      return t;
    }();

void hablar(String texto) {
  _preparar().then((t) async {
    try {
      await t.stop();
      await t.speak(texto);
    } catch (_) {}
  });
}

void callar() {
  try {
    _tts?.stop();
  } catch (_) {}
}

void desbloquear() {
  _preparar();
}
