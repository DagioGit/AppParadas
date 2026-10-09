import 'package:flutter/cupertino.dart';
import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import 'package:latlong2/latlong.dart';

import '../datos/lugares.dart';
import '../estado.dart';
import '../modelo/geo.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../modelo/ubicacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/mapa_viaje.dart';
import '../widgets/mapa_viaje_3d.dart';
import 'buscar_lugar.dart';
import 'opcion_detalle.dart';

class ViajePantalla extends StatefulWidget {
  const ViajePantalla({super.key});

  @override
  State<ViajePantalla> createState() => _ViajePantallaState();
}

class _ViajePantallaState extends State<ViajePantalla> {
  final _planificador = Planificador();
  Lugar? _desde;
  Lugar? _hasta;
  List<Opcion>? _opciones;
  int _sel = 0;
  final _hoja = DraggableScrollableController();

  /// Aviso de "sal ya / tu combi está llegando" para la opción elegida.
  bool _alerta = false;
  final Set<String> _avisados = {};
  String? _banner;
  Timer? _vigia;

  @override
  void initState() {
    super.initState();
    destinoPedido.addListener(_alPedirDestino);
    pedirBusqueda.addListener(_alPedirBusqueda);
    _vigia = Timer.periodic(const Duration(seconds: 1), (_) => _vigilar());
    _desde = desdeInicial;
    _hasta = hastaInicial;
    desdeInicial = null;
    hastaInicial = null;
    if (_desde == null) _ubicacionInicial();
    if (_desde != null && _hasta != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calcular();
        final ops = _opciones;
        if (detalleInicial && ops != null && ops.isNotEmpty) {
          detalleInicial = false;
          Navigator.of(context).push(CupertinoPageRoute<void>(
            builder: (_) => OpcionDetalle(opcion: ops.first, origen: _desde!, destino: _hasta!),
          ));
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (destinoPedido.value != null) _alPedirDestino();
      if (busquedaPendiente) _alPedirBusqueda();
    });
  }

  @override
  void dispose() {
    destinoPedido.removeListener(_alPedirDestino);
    _hoja.dispose();
    _vigia?.cancel();
    pedirBusqueda.removeListener(_alPedirBusqueda);
    super.dispose();
  }

  Future<void> _ubicacionInicial() async {
    final r = await obtenerUbicacion();
    if (!mounted) return;
    if (r.punto != null && r.problema == null) {
      setState(() => _desde ??= Lugar('Mi ubicación', 'Donde estás ahora', TipoLugar.ubicacion, r.punto!));
      _calcular();
    }
  }

  void _alPedirDestino() {
    final l = destinoPedido.value;
    if (l == null) return;
    destinoPedido.value = null;
    setState(() => _hasta = l);
    _calcular();
  }

  void _alPedirBusqueda() {
    if (!mounted || !busquedaPendiente) return;
    busquedaPendiente = false;
    _elegir(destino: true);
  }

  Future<void> _elegir({required bool destino}) async {
    final l = await Navigator.of(context).push<Lugar>(CupertinoPageRoute(
      title: 'Viaje',
      builder: (_) => BuscarLugar(titulo: destino ? '¿A dónde vas?' : '¿De dónde sales?'),
    ));
    if (l == null || !mounted) return;
    setState(() {
      if (destino) {
        _hasta = l;
      } else {
        _desde = l;
      }
    });
    _calcular();
  }

  void _intercambiar() {
    setState(() {
      final t = _desde;
      _desde = _hasta;
      _hasta = t;
    });
    _calcular();
  }

  void _calcular() {
    if (_desde == null || _hasta == null) {
      setState(() => _opciones = null);
      return;
    }
    final ahora = segundosAhora();
    final ops = _planificador.planear(
      _desde!.punto,
      _hasta!.punto,
      ahora: ahora,
      origenNombre: _desde!.nombre,
      destinoNombre: _hasta!.nombre,
    );
    setState(() {
      _opciones = ops;
      _sel = 0;
      _avisados.clear();
    });
  }

  /// Nombre del lugar conocido más cercano (a menos de 350 m) para un punto tocado en el mapa.
  String _nombreCerca(LatLng p, String otro) {
    Lugar? mejor;
    var dMin = 350.0;
    for (final l in todosLosLugares()) {
      final d = distanciaM(l.punto, p);
      if (d < dMin) {
        dMin = d;
        mejor = l;
      }
    }
    return mejor == null ? otro : 'Cerca de ${mejor.nombre}';
  }

  /// Primer toque: dónde estás. Segundo toque: a dónde vas. Un tercero empieza otro viaje.
  void _tocarMapa(LatLng p) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_desde == null) {
        _desde = Lugar(_nombreCerca(p, 'Tu punto'), 'Marcado en el mapa', TipoLugar.mapa, p);
      } else if (_hasta == null) {
        _hasta = Lugar(_nombreCerca(p, 'Destino'), 'Marcado en el mapa', TipoLugar.mapa, p);
      } else {
        _desde = Lugar(_nombreCerca(p, 'Tu punto'), 'Marcado en el mapa', TipoLugar.mapa, p);
        _hasta = null;
      }
    });
    _calcular();
  }

  /// Revisa cada segundo si toca avisar: cuando hay que salir caminando y cuando la combi está por llegar.
  void _vigilar() {
    final ops = _opciones;
    if (!_alerta || ops == null || ops.isEmpty || !mounted) return;
    final o = ops[_sel.clamp(0, ops.length - 1)];
    if (o.enCombi.isEmpty) return;
    final t = o.enCombi.first;
    final ahora = segundosAhora();
    final caminar = o.tramos.first.tipo == TipoTramo.pie ? o.tramos.first.segundos : 0.0;
    final salirA = t.inicio - caminar - 60; // un minuto de margen
    void avisar(String clave, String texto) {
      if (_avisados.contains(clave)) return;
      _avisados.add(clave);
      HapticFeedback.heavyImpact();
      setState(() => _banner = texto);
    }

    if (ahora >= salirA && ahora < t.inicio - 120) {
      avisar('salir', '¡Sal ya! Camina a ${t.sube!.nombre}.');
    }
    if (ahora >= t.inicio - 120 && ahora < t.inicio) {
      avisar('llega', '¡Ya viene tu combi!');
    }
  }

  /// Copia el viaje en texto para mandarlo por WhatsApp o mensaje.
  Future<void> _copiar(Opcion o) async {
    final b = StringBuffer('AppParadas · ${_desde!.nombre} → ${_hasta!.nombre}\n');
    b.writeln('Sales ${hora(o.salida)} y llegas ${hora(o.llegada)} (${duracion(o.total)}).');
    for (final t in o.tramos) {
      if (t.tipo == TipoTramo.pie) {
        if (t.segundos >= 30) b.writeln('• Camina ${duracion(t.segundos)} a ${t.hastaNombre}');
      } else {
        b.writeln('• ${t.ruta!.nombre} (${t.ruta!.apodo}) en ${t.sube!.nombre} a las ${hora(t.inicio)}; bájate en ${t.baja!.nombre}');
      }
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (mounted) setState(() => _banner = 'Copiado. Pégalo en WhatsApp.');
  }

  void _abrir(Opcion o) => Navigator.of(context).push(CupertinoPageRoute<void>(
        title: 'Viaje',
        builder: (_) => OpcionDetalle(opcion: o, origen: _desde!, destino: _hasta!),
      ));

  @override
  Widget build(BuildContext context) {
    // Siempre el mapa 3D: se toca primero dónde estás y luego a dónde vas.
    return _conMapa(_opciones ?? const <Opcion>[]);
  }

  /// Con opciones: mapa 3D a pantalla completa, el formulario arriba y las opciones en un panel que se arrastra.
  Widget _conMapa(List<Opcion> ops) {
    final arriba = MediaQuery.of(context).padding.top;
    return CupertinoPageScaffold(
      child: Stack(children: [
        Positioned.fill(
          child: MapaViaje3D(
            opciones: ops,
            seleccion: _sel,
            origen: _desde,
            destino: _hasta,
            onElegir: (i) => setState(() => _sel = i),
            onDetalle: _abrir,
            onTocarVacio: _tocarMapa,
          ),
        ),
        Positioned(left: 0, right: 0, top: arriba + 4, child: _formulario()),
        Positioned(
          left: 0,
          right: 0,
          top: arriba + 146,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xE6111111), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _desde == null
                      ? '1 · Toca donde estás'
                      : _hasta == null
                          ? '2 · Toca a dónde vas'
                          : 'Toca para otro viaje',
                  style: Tema.texto(size: 17, weight: FontWeight.w700, color: const Color(0xFFFFFFFF)),
                ),
              ),
            ),
          ),
        ),
        if (_banner != null)
          Positioned(
            left: 16,
            right: 16,
            top: arriba + 196,
            child: GestureDetector(
              onTap: () => setState(() => _banner = null),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(color: const Color(0xF0111111), borderRadius: BorderRadius.circular(16), boxShadow: Tema.sombra),
                child: Row(children: [
                  const Icon(Icons.notifications_active_rounded, color: Tema.amarillo),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_banner!, style: Tema.texto(size: 18, weight: FontWeight.w700, color: const Color(0xFFFFFFFF)))),
                  const Icon(Icons.close_rounded, color: Tema.grisClaro, size: 18),
                ]),
              ),
            ),
          ),
        Positioned.fill(
          child: HojaDeslizable(
            controlador: _hoja,
            inicial: 0.32,
            hijos: (ahora) => ops.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Text(
                        _desde != null && _hasta != null ? 'No hay combis ahí' : '¿A dónde vas?',
                        style: Tema.texto(size: 26, weight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Text(
                        _desde != null && _hasta != null
                            ? 'Toca otro lugar del mapa.'
                            : 'Toca el mapa.',
                        style: Tema.texto(size: 19, color: Tema.gris),
                      ),
                    ),
                  ]
                : [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                child: Row(children: [
                  Expanded(
                    child: Text('${ops.length} formas de llegar', style: Tema.texto(size: 24, weight: FontWeight.w800)),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(30, 30),
                    onPressed: _calcular,
                    child: const Icon(CupertinoIcons.arrow_clockwise, size: 26, color: Tema.azul),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: _alerta ? Tema.verde : Tema.tarjeta,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () => setState(() {
                        _alerta = !_alerta;
                        _avisados.clear();
                        _banner = _alerta ? 'Te aviso cuando salir.' : null;
                      }),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(_alerta ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                            size: 22, color: _alerta ? const Color(0xFFFFFFFF) : Tema.tinta),
                        const SizedBox(width: 6),
                        Text(_alerta ? 'Aviso activado' : 'Avísame',
                            style: Tema.texto(size: 17, weight: FontWeight.w700, color: _alerta ? const Color(0xFFFFFFFF) : Tema.tinta)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: Tema.tarjeta,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () => _copiar(ops[_sel.clamp(0, ops.length - 1)]),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.ios_share_rounded, size: 22, color: Tema.tinta),
                        const SizedBox(width: 6),
                        Text('Compartir', style: Tema.texto(size: 17, weight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
              ),
              for (var i = 0; i < ops.length; i++)
                TarjetaOpcion(
                  opcion: ops[i],
                  elegida: i == _sel,
                  onTap: () => i == _sel ? _abrir(ops[i]) : setState(() => _sel = i),
                ),
                  ],
          ),
        ),
      ]),
    );
  }

  Widget _formulario() {
    Widget campo(String etiqueta, Lugar? l, Color punto, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(etiqueta, style: Tema.etiqueta),
                const SizedBox(height: 2),
                Text(
                  l?.nombre ?? (etiqueta == 'DESDE' ? 'Elige de dónde sales' : 'Elige a dónde vas'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tema.texto(size: 17, weight: FontWeight.w600, color: l == null ? Tema.grisClaro : Tema.tinta),
                ),
              ]),
            ),
          ]),
        ),
      );
    }

    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(children: [
        Expanded(
          child: Column(children: [
            campo('DESDE', _desde, Tema.azul, () => _elegir(destino: false)),
            Container(height: 0.5, color: Tema.linea, margin: const EdgeInsets.only(left: 26)),
            campo('HASTA', _hasta, const Color(0xFFFF3B30), () => _elegir(destino: true)),
          ]),
        ),
        CupertinoButton(
          padding: const EdgeInsets.all(10),
          onPressed: _intercambiar,
          child: const Icon(Icons.swap_vert_rounded, color: Tema.azul, size: 28),
        ),
      ]),
    );
  }
}

/// Tarjeta de una opción: tiempo total, hora de llegada y la secuencia caminar → combi → caminar.
class TarjetaOpcion extends StatelessWidget {
  final Opcion opcion;
  final VoidCallback onTap;
  final bool elegida;
  const TarjetaOpcion({super.key, required this.opcion, required this.onTap, this.elegida = false});

  @override
  Widget build(BuildContext context) {
    final o = opcion;
    final primera = o.enCombi.isEmpty ? null : o.enCombi.first;

    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      color: o.masRapida ? const Color(0xFFFFFFFF) : Tema.tarjeta,
      borde: elegida ? Tema.tinta : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (o.masRapida)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: Tema.verdeClaro, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt_rounded, size: 20, color: Tema.verde),
              const SizedBox(width: 3),
              Text('La más rápida', style: Tema.texto(size: 16, weight: FontWeight.w800, color: Tema.verde)),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(duracion(o.total), style: Tema.texto(size: 32, weight: FontWeight.w800)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('llegas ${hora(o.llegada)}', style: Tema.texto(size: 18, color: Tema.gris)),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.chevron_right, color: Tema.grisClaro, size: 20),
          ),
        ]),
        const SizedBox(height: 10),
        SecuenciaTramos(opcion: o),
        const SizedBox(height: 8),
        BarraTiempo(opcion: o),
        if (primera != null) ...[
          const SizedBox(height: 10),
          ConReloj(
            cada: const Duration(seconds: 1),
            builder: (context, ahora) => Row(children: [
              Icon(Icons.directions_bus_rounded, size: 24, color: primera.ruta!.color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Pasa ${faltaTexto(primera.inicio, ahora)}',
                  style: Tema.texto(size: 19, weight: FontWeight.w700),
                ),
              ),
            ]),
          ),
        ],

      ]),
    );
  }
}

/// 🚶 5 › [3] › 🚶 2 › [1] › 🚶 1
class SecuenciaTramos extends StatelessWidget {
  final Opcion opcion;
  const SecuenciaTramos({super.key, required this.opcion});

  @override
  Widget build(BuildContext context) {
    final piezas = <Widget>[];
    for (final t in opcion.tramos) {
      if (t.tipo == TipoTramo.pie && t.segundos < 30 && opcion.tramos.length > 1) continue;
      if (piezas.isNotEmpty) {
        piezas.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(CupertinoIcons.chevron_right, size: 13, color: Tema.grisClaro),
        ));
      }
      if (t.tipo == TipoTramo.pie) {
        piezas.add(Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.directions_walk_rounded, size: 20, color: Tema.gris),
          Text('${(t.segundos / 60).round()}', style: Tema.texto(size: 13, weight: FontWeight.w600, color: Tema.gris)),
        ]));
      } else {
        piezas.add(Container(
          padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
          decoration: BoxDecoration(color: Tema.fondo, borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            InsigniaRuta(t.ruta!, tam: 22),
            const SizedBox(width: 5),
            Text('${(t.segundos / 60).round()} min', style: Tema.texto(size: 13, weight: FontWeight.w600)),
          ]),
        ));
      }
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: piezas);
  }
}


/// Barra con el tiempo del viaje repartido: caminar (gris), esperar (claro) y en combi (color de la ruta).
class BarraTiempo extends StatelessWidget {
  final Opcion opcion;
  const BarraTiempo({super.key, required this.opcion});

  @override
  Widget build(BuildContext context) {
    final partes = <(int, Color)>[];
    for (final t in opcion.tramos) {
      if (t.tipo == TipoTramo.pie) {
        if (t.segundos >= 20) partes.add((t.segundos.round(), Tema.grisClaro));
      } else {
        if (t.espera >= 20) partes.add((t.espera.round(), const Color(0xFFE5E5EA)));
        partes.add((t.segundos.round(), t.ruta!.color));
      }
    }
    if (partes.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(children: [
          for (var i = 0; i < partes.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(flex: partes[i].$1.clamp(1, 100000), child: Container(color: partes[i].$2)),
          ],
        ]),
      ),
    );
  }
}
