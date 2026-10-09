// Motor de voz: en el navegador usa directamente la voz del navegador (speechSynthesis) para
// poder hablar en el mismo toque (Safari y Chrome no dejan hablar si no fue con un toque);
// en el teléfono usa flutter_tts.
export 'motor_movil.dart' if (dart.library.js_interop) 'motor_web.dart';
