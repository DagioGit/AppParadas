import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final Set<String> _registradas = {};

/// Muestra [url] dentro de la app (versión web).
Widget vistaWeb(String url) {
  final id = 'vista-web-${url.hashCode}';
  if (_registradas.add(id)) {
    ui_web.platformViewRegistry.registerViewFactory(id, (int _) {
      final f = web.HTMLIFrameElement()
        ..src = url
        ..allow = 'fullscreen; accelerometer; gyroscope';
      f.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%';
      return f;
    });
  }
  return HtmlElementView(viewType: id);
}
