// Modo de voz para personas ciegas: todo se hace hablando y tocando la pantalla.
//
// 1. Toca la pantalla (en cualquier parte) y di a dónde quieres ir: "quiero ir al malecón".
// 2. La app busca el lugar, toma tu ubicación y te dice qué combi tomar.
// 3. Toca y di "sí" para que te guíe. Te va diciendo qué hacer en todo el camino.
// 4. Durante el viaje: un toque repite la indicación; el botón de abajo (o un toque largo)
//    escucha preguntas: "¿cuánto falta?", "¿dónde estoy?", "repite", "terminar".

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../ajustes.dart';
import '../datos/lugares.dart';
import '../escucha.dart';
import '../modelo/geo.dart';
import '../modelo/guia.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../modelo/ubicacion.dart';
import '../tema.dart';
import '../voz.dart';
import '../widgets/dictado.dart' show entenderDestino;
import 'buscar_lugar.dart';

enum _Fase { inicio, escuchando, pensando, pedirOrigen, confirmar, guiando, llegaste }

class ModoVozPantalla extends StatefulWidget {
  /// true cuando reemplaza a la pestaña Viaje (modo de voz prendido en Ajustes).
  final bool enPestana;
  const ModoVozPantalla({super.key, this.enPestana = false});

  @override
  State<ModoVozPantalla> createState() => _ModoVozPantallaState();
}

class _ModoVozPantallaState extends State<ModoVozPantalla> {
  _Fase _fase = _Fase.inicio;
  _Fase _antes = _Fase.inicio; // qué se estaba esperando al escuchar
  String _titulo = 'Toca la pantalla';
  String _detalle = 'y di a dónde quieres ir';
  String _oido = '';
  String _ultimoDicho = 'Toca la pantalla y di a dónde quieres ir. Por ejemplo: quiero ir al malecón.';

  Lugar? _destino;
  Lugar? _origen;
  Opcion? _opcion;
  MotorGuia? _motor;
  LatLng? _pos;
  StreamSubscription<Position>? _gps;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    Escucha.preparar(); // pide el micrófono desde ya, para que el toque empiece a escuchar al instante
    _ubicar();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decir(_ultimoDicho));
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _gps?.cancel();
    Escucha.parar();
    Voz.callar();
    super.dispose();
  }

  void _decir(String t) {
    _ultimoDicho = t;
    Voz.decir(t);
  }

  Future<void> _ubicar() async {
    final r = await obtenerUbicacion();
    if (!mounted || r.punto == null || r.problema != null) return;
    _pos = r.punto;
    try {
      _gps = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 4),
      ).listen((p) => _pos = LatLng(p.latitude, p.longitude));
    } catch (_) {}
  }

  // ---------------- Toques ----------------

  /// Un toque en cualquier parte de la pantalla.
  void _tocar() {
    Voz.desbloquear();
    switch (_fase) {
      case _Fase.escuchando:
        Escucha.parar();
        return;
      case _Fase.pensando:
        return;
      case _Fase.guiando:
        _repetir();
        return;
      default:
        _escuchar();
    }
  }

  void _repetir() {
    Voz.desbloquear();
    final m = _motor;
    _decir(m != null && !m.fin ? m.cuantoFalta(segundosAhora()) : _ultimoDicho);
  }

  Future<void> _escuchar() async {
    Voz.desbloquear();
    Voz.callar();
    HapticFeedback.mediumImpact();
    _antes = _fase;
    setState(() {
      _fase = _Fase.escuchando;
      _oido = '';
    });
    final dicho = await Escucha.unaVez(parcial: (t) {
      if (mounted) setState(() => _oido = t);
    });
    if (!mounted) return;
    HapticFeedback.lightImpact();
    if (dicho == null || dicho.isEmpty) {
      setState(() => _fase = _antes);
      _decir(Escucha.disponible
          ? 'No te escuché. Toca la pantalla y vuelve a hablar.'
          : 'No puedo usar el micrófono en este teléfono. Pide ayuda para escribir el lugar.');
      return;
    }
    setState(() => _oido = dicho);
    await _entender(dicho);
  }

  // ---------------- Entender lo que dijo ----------------

  String _norm(String s) => normalizar(s).replaceAll(RegExp(r'[¿?¡!,]'), '').trim();

  Future<void> _entender(String dicho) async {
    final t = _norm(dicho);
    bool dice(List<String> palabras) => palabras.any((p) => t == p || t.startsWith('$p ') || t.endsWith(' $p') || t.contains(' $p '));

    // Comandos que sirven siempre
    if (dice(['terminar', 'termina', 'salir', 'cancelar', 'cancela', 'detener', 'alto'])) {
      _reiniciar('Listo, terminé. Toca la pantalla y di a dónde quieres ir.');
      return;
    }
    if (dice(['repite', 'repetir', 'otra vez', 'que dijiste'])) {
      setState(() => _fase = _antes);
      _repetir();
      return;
    }
    if (dice(['donde estoy', 'en donde estoy'])) {
      setState(() => _fase = _antes);
      _dondeEstoy();
      return;
    }
    if (_antes == _Fase.guiando) {
      setState(() => _fase = _Fase.guiando);
      if (dice(['cuanto falta', 'cuando llega', 'a que hora', 'cuanto tarda', 'falta'])) {
        _repetir();
      } else {
        _decir('Puedes decir: cuánto falta, dónde estoy, repite o terminar.');
      }
      return;
    }
    if (_antes == _Fase.confirmar) {
      if (dice(['si', 'sí', 'claro', 'va', 'vamos', 'guiame', 'guíame', 'ok', 'okey', 'dale', 'por favor'])) {
        _empezarGuia();
        return;
      }
      if (dice(['no'])) {
        _reiniciar('Está bien. Toca la pantalla y di otro lugar.');
        return;
      }
    }
    if (_antes == _Fase.pedirOrigen) {
      final o = buscarLugares(todosLosLugares(), entenderDestino(dicho).$2, maximo: 1).firstOrNull;
      if (o == null) {
        setState(() => _fase = _Fase.pedirOrigen);
        _decir('No encontré ese lugar. Toca la pantalla y di de dónde sales, por ejemplo: desde el Palacio Municipal.');
        return;
      }
      _origen = o;
      await _planear();
      return;
    }
    // Un destino (y quizá un origen)
    final (deDonde, aDonde) = entenderDestino(dicho);
    final todos = todosLosLugares();
    final d = buscarLugares(todos, aDonde, maximo: 1).firstOrNull;
    if (d == null) {
      setState(() => _fase = _Fase.inicio);
      _decir('No encontré $aDonde. Toca la pantalla y dilo de otra forma.');
      return;
    }
    _destino = d;
    _origen = deDonde == null ? null : buscarLugares(todos, deDonde, maximo: 1).firstOrNull;
    setState(() {
      _fase = _Fase.pensando;
      _titulo = 'Buscando…';
      _detalle = d.nombre;
    });
    if (_origen == null && _pos == null) await _ubicar();
    if (_origen == null && _pos != null) _origen = Lugar('tu ubicación', 'Donde estás ahora', TipoLugar.ubicacion, _pos!);
    if (_origen == null) {
      setState(() {
        _fase = _Fase.pedirOrigen;
        _titulo = '¿De dónde sales?';
        _detalle = 'Toca la pantalla y dilo';
      });
      _decir('Vas a ${d.nombre}. No sé dónde estás. Toca la pantalla y di de dónde sales.');
      return;
    }
    await _planear();
  }

  Future<void> _planear() async {
    final o = _origen!, d = _destino!;
    final ahora = segundosAhora();
    if (!enServicio(ahora)) {
      _reiniciar('Por ahora no hay combis. Vuelven a pasar a las 6 de la mañana.');
      return;
    }
    final ops = Planificador().planear(o.punto, d.punto, ahora: ahora, origenNombre: o.nombre, destinoNombre: d.nombre);
    if (ops.isEmpty) {
      _reiniciar('No encontré combis para llegar a ${d.nombre}. Toca la pantalla y di otro lugar.');
      return;
    }
    _opcion = ops.first;
    setState(() {
      _fase = _Fase.confirmar;
      _titulo = '¿Te guío?';
      _detalle = 'Toca y di "sí" · ${d.nombre} · ${duracion(ops.first.total)}';
    });
    _decir('Para ir de ${o.nombre} a ${d.nombre}. ${textoOpcion(ops.first, ahora, masRapida: true)} '
        '¿Quieres que te guíe? Toca la pantalla y di sí.');
  }

  void _empezarGuia() {
    final op = _opcion, d = _destino;
    if (op == null || d == null) return;
    _motor = MotorGuia(op, d.nombre);
    setState(() => _fase = _Fase.guiando);
    _decir('Empezamos. Toca la pantalla cuando quieras que repita. Usa el botón de abajo para preguntar cuánto falta.');
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _guiar());
    Future.delayed(const Duration(seconds: 6), _guiar);
  }

  void _guiar() {
    final m = _motor;
    if (!mounted || m == null || _fase == _Fase.escuchando) return;
    final e = m.paso(segundosAhora(), _pos);
    if (e.decir != null) _decir(e.decir!);
    setState(() {
      _titulo = e.titulo;
      _detalle = e.detalle;
      if (m.fin) {
        _fase = _Fase.llegaste;
        _reloj?.cancel();
      }
    });
  }

  void _dondeEstoy() {
    final p = _pos ?? _motor?.posEstimada(segundosAhora());
    if (p == null) {
      _decir('No sé dónde estás: no tengo tu ubicación.');
      return;
    }
    Lugar? mejor;
    var dMin = double.infinity;
    for (final l in todosLosLugares()) {
      final d = distanciaM(l.punto, p);
      if (d < dMin) {
        dMin = d;
        mejor = l;
      }
    }
    _decir(mejor == null ? 'No sé el nombre de este lugar.' : 'Estás cerca de ${mejor.nombre}, a unos ${metrosHablados(dMin)}.');
  }

  void _reiniciar(String texto) {
    _reloj?.cancel();
    _motor = null;
    _opcion = null;
    setState(() {
      _fase = _Fase.inicio;
      _titulo = 'Toca la pantalla';
      _detalle = 'y di a dónde quieres ir';
    });
    _decir(texto);
  }

  // ---------------- Pantalla ----------------

  @override
  Widget build(BuildContext context) {
    final oyendo = _fase == _Fase.escuchando;
    final guiando = _fase == _Fase.guiando;
    final ayuda = switch (_fase) {
      _Fase.escuchando => 'Te escucho… habla ahora',
      _Fase.guiando => 'Un toque: repetir',
      _Fase.pensando => 'Un momento…',
      _ => 'Toca en cualquier parte',
    };
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      child: SafeArea(
        child: Column(children: [
          // Para quien ayuda a la persona: salir del modo de voz
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              const Icon(Icons.record_voice_over_rounded, color: Tema.amarillo, size: 26),
              const SizedBox(width: 8),
              Expanded(child: Text('Modo de voz', style: Tema.texto(size: 18, weight: FontWeight.w800, color: const Color(0xFFFFFFFF), fijo: true))),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () {
                  Voz.callar();
                  if (widget.enPestana) {
                    ajustes.cambiar((a) => a.modoVoz = false);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text('Salir', style: Tema.texto(size: 17, weight: FontWeight.w700, color: const Color(0xFF8E8E93), fijo: true)),
              ),
            ]),
          ),
          // Toda esta parte es un solo botón grande
          Expanded(
            child: Semantics(
              button: true,
              liveRegion: true,
              label: '$_titulo. $_detalle. $ayuda',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tocar,
                onLongPress: guiando ? _escuchar : null,
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: oyendo ? 200 : 170,
                        height: oyendo ? 200 : 170,
                        decoration: BoxDecoration(
                          color: oyendo ? const Color(0xFFFF3B30) : (guiando ? Tema.verde : Tema.azul),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (oyendo ? const Color(0xFFFF3B30) : Tema.azul).withValues(alpha: 0.45),
                              blurRadius: 40,
                              spreadRadius: oyendo ? 18 : 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          oyendo ? Icons.mic_rounded : (guiando ? Icons.navigation_rounded : (_fase == _Fase.llegaste ? Icons.flag_rounded : Icons.mic_none_rounded)),
                          color: const Color(0xFFFFFFFF),
                          size: 92,
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text(_titulo, textAlign: TextAlign.center, style: Tema.texto(size: 34, weight: FontWeight.w800, color: const Color(0xFFFFFFFF))),
                      const SizedBox(height: 8),
                      Text(_detalle, textAlign: TextAlign.center, style: Tema.texto(size: 21, weight: FontWeight.w600, color: const Color(0xCCFFFFFF))),
                      if (_oido.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text('"$_oido"', textAlign: TextAlign.center, style: Tema.texto(size: 20, color: Tema.amarillo)),
                      ],
                      const SizedBox(height: 22),
                      Text(ayuda, style: Tema.texto(size: 17, weight: FontWeight.w700, color: const Color(0xFF8E8E93))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          // Mientras guía: botón grande para preguntar
          if (guiando)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Semantics(
                button: true,
                label: 'Preguntar: cuánto falta, dónde estoy, repite o terminar',
                child: CupertinoButton(
                  color: Tema.azul,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  borderRadius: BorderRadius.circular(22),
                  onPressed: _escuchar,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.mic_rounded, color: Color(0xFFFFFFFF), size: 34),
                    const SizedBox(width: 10),
                    Text('Preguntar', style: Tema.texto(size: 24, weight: FontWeight.w800, color: const Color(0xFFFFFFFF), fijo: true)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
