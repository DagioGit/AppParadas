import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Muestra [url] dentro de la app (Android/iOS).
Widget vistaWeb(String url) => _VistaWeb(url: url);

class _VistaWeb extends StatefulWidget {
  final String url;
  const _VistaWeb({required this.url});

  @override
  State<_VistaWeb> createState() => _VistaWebState();
}

class _VistaWebState extends State<_VistaWeb> {
  late final WebViewController _c = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0xFFE6EEF3))
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _c);
}
