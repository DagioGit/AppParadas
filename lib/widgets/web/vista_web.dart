// Página web incrustada: en la versión web es un <iframe>; en Android/iOS, un WebView.
export 'vista_web_movil.dart' if (dart.library.js_interop) 'vista_web_iframe.dart';
