import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../datos/lugares.dart';
import '../estado.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../modelo/ubicacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
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
  double _calculadoA = 0;
  String? _avisoUbicacion;

  @override
  void initState() {
    super.initState();
    destinoPedido.addListener(_alPedirDestino);
    pedirBusqueda.addListener(_alPedirBusqueda);
    _desde = desdeInicial;
    _hasta = hastaInicial;
    desdeInicial = null;
    hastaInicial = null;
    if (_desde == null) _ubicacionInicial();
    if (_desde != null && _hasta != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _calcular());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (destinoPedido.value != null) _alPedirDestino();
      if (busquedaPendiente) _alPedirBusqueda();
    });
  }

  @override
  void dispose() {
    destinoPedido.removeListener(_alPedirDestino);
    pedirBusqueda.removeListener(_alPedirBusqueda);
    super.dispose();
  }

  Future<void> _ubicacionInicial() async {
    final r = await obtenerUbicacion();
    if (!mounted) return;
    if (r.punto != null && r.problema == null) {
      setState(() => _desde ??= Lugar('Mi ubicación', 'Donde estás ahora', TipoLugar.ubicacion, r.punto!));
      _calcular();
    } else {
      setState(() => _avisoUbicacion = r.problema);
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
      _calculadoA = ahora;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Viaje')),
        SliverList(
          delegate: SliverChildListDelegate([
            _formulario(),
            if (_avisoUbicacion != null && _desde == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 2, 32, 0),
                child: Text('$_avisoUbicacion Elige de dónde sales.', style: Tema.chico),
              ),
            ..._resultados(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ]),
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

  List<Widget> _resultados() {
    final ops = _opciones;
    if (ops == null) {
      return [
        const SizedBox(height: 30),
        const Icon(Icons.directions_bus_rounded, size: 54, color: Tema.grisClaro),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Escribe a dónde vas y te mostramos qué combis te llevan y cuál llega primero.',
            textAlign: TextAlign.center,
            style: Tema.subtitulo,
          ),
        ),
      ];
    }
    if (ops.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No hay combis que te acerquen a ese lugar. Prueba con un punto más cerca de una ruta.',
              textAlign: TextAlign.center, style: Tema.subtitulo),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 18, 20, 6),
        child: Row(children: [
          Expanded(child: Text('${ops.length} OPCIONES · SALIENDO A LAS ${hora(_calculadoA)}', style: Tema.etiqueta)),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 24,
            onPressed: _calcular,
            child: Text('Actualizar', style: Tema.texto(size: 13, weight: FontWeight.w600, color: Tema.azul)),
          ),
        ]),
      ),
      for (final o in ops)
        TarjetaOpcion(
          opcion: o,
          onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(
            title: 'Viaje',
            builder: (_) => OpcionDetalle(opcion: o, origen: _desde!, destino: _hasta!),
          )),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
        child: Text(
          'Tiempos estimados con el horario de cada ruta. Las rutas 3, 4 y 5 son simuladas.',
          style: Tema.chico,
        ),
      ),
    ];
  }
}

/// Tarjeta de una opción: tiempo total, hora de llegada y la secuencia caminar → combi → caminar.
class TarjetaOpcion extends StatelessWidget {
  final Opcion opcion;
  final VoidCallback onTap;
  const TarjetaOpcion({super.key, required this.opcion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = opcion;
    final primera = o.enCombi.isEmpty ? null : o.enCombi.first;
    String resumen;
    if (o.soloAPie) {
      resumen = 'Caminando ${(o.metrosAPie / 1000).toStringAsFixed(1)} km';
    } else {
      final partes = <String>[
        'Sale ${hora(primera!.inicio)} de ${primera.desdeNombre}',
        if (o.transbordos > 0) '${o.transbordos} transbordo',
        '${duracion(o.aPie)} a pie',
      ];
      resumen = partes.join(' · ');
    }

    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      color: o.masRapida ? const Color(0xFFFFFFFF) : Tema.tarjeta,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (o.masRapida)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: Tema.verdeClaro, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt_rounded, size: 16, color: Tema.verde),
              const SizedBox(width: 3),
              Text('La más rápida', style: Tema.texto(size: 13, weight: FontWeight.w700, color: Tema.verde)),
            ]),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(duracion(o.total), style: Tema.texto(size: 28, weight: FontWeight.w800)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('llegas ${hora(o.llegada)}', style: Tema.subtitulo),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Icon(CupertinoIcons.chevron_right, color: Tema.grisClaro, size: 20),
          ),
        ]),
        const SizedBox(height: 10),
        SecuenciaTramos(opcion: o),
        const SizedBox(height: 10),
        Text(resumen, style: Tema.chico),
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
