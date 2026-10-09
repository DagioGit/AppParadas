import 'package:web/web.dart' as web;
import 'dart:js_interop';

bool _desbloqueado = false;

web.SpeechSynthesisVoice? _vozEspanol() {
  final voces = web.window.speechSynthesis.getVoices().toDart;
  web.SpeechSynthesisVoice? es;
  for (final v in voces) {
    final l = v.lang.toLowerCase().replaceAll('_', '-');
    if (l == 'es-mx') return v;
    if (es == null && l.startsWith('es')) es = v;
  }
  return es;
}

/// Habla [texto] de inmediato (sin esperas, para que cuente como parte del toque).
void hablar(String texto) {
  try {
    final s = web.window.speechSynthesis;
    if (s.speaking || s.pending) s.cancel();
    final u = web.SpeechSynthesisUtterance(texto);
    u.lang = 'es-MX';
    u.rate = 0.95;
    u.volume = 1;
    final v = _vozEspanol();
    if (v != null) u.voice = v;
    s.speak(u);
    _desbloqueado = true;
  } catch (_) {}
}

void callar() {
  try {
    web.window.speechSynthesis.cancel();
  } catch (_) {}
}

/// En iPhone (Safari) la voz sólo funciona si la primera vez se habla dentro de un toque.
/// Se llama al principio de cada botón de voz.
void desbloquear() {
  if (_desbloqueado) return;
  try {
    final u = web.SpeechSynthesisUtterance(' ');
    u.volume = 0;
    web.window.speechSynthesis.speak(u);
    _desbloqueado = true;
  } catch (_) {}
}
