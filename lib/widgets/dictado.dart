// "Di a dónde vas": escucha lo que dice la persona (micrófono) y lo convierte en texto.
// Se usa en Viaje para buscar el destino por voz, pensando en personas con discapacidad visual.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../tema.dart';
import '../voz.dart';

final SpeechToText _stt = SpeechToText();
bool _iniciado = false;
bool _disponible = false;

/// Abre la hoja "Te escucho…" y regresa lo que se dijo (o null si se canceló o no se pudo).
Future<String?> escucharDestino(BuildContext context) async {
  await Voz.callar();
  return showCupertinoModalPopup<String>(context: context, builder: (_) => const _HojaDictado());
}

class _HojaDictado extends StatefulWidget {
  const _HojaDictado();

  @override
  State<_HojaDictado> createState() => _HojaDictadoState();
}

class _HojaDictadoState extends State<_HojaDictado> {
  String _texto = '';
  String? _problema;
  bool _oyendo = false;

  @override
  void initState() {
    super.initState();
    _empezar();
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  Future<void> _empezar() async {
    try {
      if (!_iniciado) {
        _iniciado = true;
        _disponible = await _stt.initialize(
          onStatus: (s) {
            if (!mounted) return;
            if (s == 'done' || s == 'notListening') setState(() => _oyendo = false);
          },
          onError: (e) {
            if (mounted) setState(() => _problema = 'No te escuché bien. Toca el micrófono e inténtalo otra vez.');
          },
        );
      }
      if (!_disponible) {
        setState(() => _problema = 'Este teléfono no deja usar el micrófono para dictar. Escribe el lugar arriba.');
        return;
      }
      // Español de México si el teléfono lo tiene
      String? idioma;
      try {
        final idiomas = await _stt.locales();
        idioma = idiomas.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'es_mx').map((l) => l.localeId).firstOrNull ??
            idiomas.where((l) => l.localeId.toLowerCase().startsWith('es')).map((l) => l.localeId).firstOrNull;
      } catch (_) {}
      setState(() {
        _oyendo = true;
        _problema = null;
        _texto = '';
      });
      await _stt.listen(
        onResult: _resultado,
        localeId: idioma,
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.search, cancelOnError: true),
      );
    } catch (_) {
      if (mounted) setState(() => _problema = 'No se pudo usar el micrófono. Escribe el lugar arriba.');
    }
  }

  void _resultado(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() => _texto = r.recognizedWords);
    if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
      Navigator.of(context).pop(r.recognizedWords.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(color: Tema.fondo, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, abajo + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 5, decoration: BoxDecoration(color: Tema.grisClaro, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 18),
        Text(_oyendo ? 'Te escucho…' : '¿A dónde quieres ir?', style: Tema.texto(size: 24, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Di por ejemplo: "Quiero ir al malecón"', style: Tema.texto(size: 16, color: Tema.gris), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Semantics(
          button: true,
          label: _oyendo ? 'Escuchando' : 'Volver a escuchar',
          child: GestureDetector(
            onTap: _oyendo ? null : _empezar,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _oyendo ? 110 : 96,
              height: _oyendo ? 110 : 96,
              decoration: BoxDecoration(
                color: _oyendo ? const Color(0xFFFF3B30) : Tema.azul,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (_oyendo ? const Color(0xFFFF3B30) : Tema.azul).withValues(alpha: 0.35), blurRadius: 24, spreadRadius: _oyendo ? 8 : 2)],
              ),
              child: const Icon(Icons.mic_rounded, color: Color(0xFFFFFFFF), size: 52),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_texto.isNotEmpty)
          Text('"$_texto"', textAlign: TextAlign.center, style: Tema.texto(size: 22, weight: FontWeight.w700)),
        if (_problema != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_problema!, textAlign: TextAlign.center, style: Tema.texto(size: 16, color: Tema.rojo)),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: CupertinoButton(
              color: Tema.tarjeta,
              borderRadius: BorderRadius.circular(14),
              padding: EdgeInsets.symmetric(vertical: Tema.b(14)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: Tema.texto(size: 17, weight: FontWeight.w700, color: Tema.rojo)),
            ),
          ),
          if (_texto.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                color: Tema.azul,
                borderRadius: BorderRadius.circular(14),
                padding: EdgeInsets.symmetric(vertical: Tema.b(14)),
                onPressed: () => Navigator.of(context).pop(_texto.trim()),
                child: Text('Listo', style: Tema.texto(size: 17, weight: FontWeight.w800, color: const Color(0xFFFFFFFF))),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Lo que se dijo, separado en origen (si lo dijo) y destino.
/// "Quiero ir al malecón" -> (null, "malecón"); "De la Gómez Sada al centro" -> ("Gómez Sada", "centro").
(String?, String) entenderDestino(String dicho) {
  var t = ' ${dicho.toLowerCase().trim()} ';
  t = t.replaceAll(RegExp(r'[¿?¡!.,]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  t = t.replaceAll(RegExp(r' por favor '), ' ');
  // "de/desde X a/al/hasta/para Y"
  final m = RegExp(r'^ ?(?:quiero ir |voy |ir |como llego |cómo llego |llevame |llévame )?(?:de|desde) (?:la |el |los |las )?(.+?) (?:a|al|hasta|hacia|para) (?:la |el |los |las )?(.+?) ?$').firstMatch(t);
  if (m != null) return (m.group(1)!.trim(), m.group(2)!.trim());
  const inicios = [
    'quiero ir a', 'quiero ir al', 'quiero ir', 'quisiera ir a', 'necesito ir a', 'voy a', 'voy al', 'ir a', 'ir al',
    'llevame a', 'llévame a', 'llevame al', 'llévame al', 'como llego a', 'cómo llego a', 'como llego al', 'cómo llego al',
    'como le hago para llegar a', 'cómo le hago para llegar a', 'a donde', 'a', 'al', 'hacia', 'hasta', 'para',
  ];
  var d = t.trim();
  var cambio = true;
  while (cambio) {
    cambio = false;
    for (final i in inicios) {
      if (d.startsWith('$i ')) {
        d = d.substring(i.length).trim();
        cambio = true;
      }
    }
    for (final a in ['la ', 'el ', 'los ', 'las ']) {
      if (d.startsWith(a)) {
        d = d.substring(a.length).trim();
        cambio = true;
      }
    }
  }
  return (null, d);
}
