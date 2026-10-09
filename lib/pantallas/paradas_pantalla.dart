import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';

import '../modelo/ruta.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/hoja_parada.dart';
import 'parada_3d.dart';

/// Paradas de una ruta (por defecto la Ruta 1 sobre la Av. Lázaro Cárdenas) con su
/// mapa, semáforos, combis en movimiento y cuenta regresiva de cada parada.
class ParadasPantalla extends StatefulWidget {
  const ParadasPantalla({super.key});

  @override
  State<ParadasPantalla> createState() => _ParadasPantallaState();
}

class _ParadasPantallaState extends State<ParadasPantalla> {
  final Ruta _ruta = rutaPorId('R1');
  int _sentido = 0;

  List<String> get _sentidos {
    final vistos = <String>[];
    for (final p in _ruta.paradas.where((p) => p.principal)) {
      if (!vistos.contains(p.sentido)) vistos.add(p.sentido);
    }
    // Sólo la Ruta 1 tiene dos sentidos claros sobre la misma avenida
    return _ruta.id == 'R1' && vistos.length == 2 ? vistos : const [];
  }

  List<Parada> get _paradas {
    final todas = _ruta.paradas.where((p) => p.principal).toList();
    final s = _sentidos;
    if (s.isEmpty) return todas;
    return todas.where((p) => p.sentido == s[_sentido.clamp(0, s.length - 1)]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final r = _ruta;
    final sentidos = _sentidos;
    final paradas = _paradas;

    return CupertinoPageScaffold(
      child: CustomScrollView(slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Paradas')),
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(children: [
                InsigniaRuta(r, tam: 34),
                const SizedBox(width: 10),
                Text('Ruta 1 · Malecón', style: Tema.texto(size: 20, weight: FontWeight.w700)),
              ]),
            ),
            _mapa(r),
            if (sentidos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _sentido,
                  onValueChanged: (v) => setState(() => _sentido = v ?? 0),
                  children: {
                    for (var i = 0; i < sentidos.length; i++)
                      i: Padding(
                        padding: EdgeInsets.symmetric(vertical: Tema.b(12)),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(sentidos[i], maxLines: 1, style: Tema.texto(size: 17, weight: FontWeight.w700))),
                      ),
                  },
                ),
              ),
            const SizedBox(height: 10),
            ConReloj(
              cada: const Duration(seconds: 1),
              builder: (context, ahora) => Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < paradas.length; i++)
                    _FilaLlegada(parada: paradas[i], numero: i + 1, ahora: ahora, primera: i == 0),
                ]),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ]),
        ),
      ]),
    );
  }

  Widget _mapa(Ruta r) {
    final paradas = r.paradas.where((p) => p.principal).toList();
    return Container(
      height: 320,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Tema.fondo),
      child: FlutterMap(
        key: ValueKey(r.id),
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(r.trazo.puntos),
            padding: const EdgeInsets.all(30),
          ),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
        children: [
          capaTeselas(),
          PolylineLayer(polylines: [lineaRuta(r.trazo.puntos, r.color, ancho: 6)]),
          MarkerLayer(markers: [
            for (final p in paradas) marcadorParada(p, tam: 16, onTap: () => mostrarParada(context, p)),
            for (final s in r.semaforosEnRuta) marcadorSemaforo(s, alto: 26, onTap: () => mostrarSemaforo(context, s)),
          ]),
          capaCombis([r], tam: 26, onTap: (c) => mostrarCombi(context, c)),
          creditosMapa(),
        ],
      ),
    );
  }
}

class _FilaLlegada extends StatelessWidget {
  final Parada parada;
  final int numero;
  final double ahora;
  final bool primera;
  const _FilaLlegada({required this.parada, required this.numero, required this.ahora, required this.primera});

  @override
  Widget build(BuildContext context) {
    final r = parada.ruta;
    final llegada = r.proximaLlegada(parada, ahora);
    final falta = llegada - ahora;
    final llegando = r.combiEnParada(parada, ahora);
    final claro = r.color.computeLuminance() > 0.5;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => mostrarParada(context, parada),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Tema.b(14)),
        decoration: BoxDecoration(
          border: primera ? null : Border(top: BorderSide(color: Tema.linea, width: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
            child: Text('$numero', style: Tema.texto(size: 18, weight: FontWeight.w800, color: claro ? Tema.negro : Tema.blanco)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(parada.nombre, style: Tema.texto(size: 19, weight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: llegando ? Tema.verdeClaro : const Color(0x00000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                llegando ? 'Ya está' : falta < 60 ? '${falta.round()} s' : falta < 3600 ? '${(falta / 60).ceil()} min' : hora(llegada).replaceFirst('mañana ', ''),
                style: Tema.texto(size: 24, weight: FontWeight.w800, color: llegando ? Tema.verde : Tema.tinta),
              ),
              Text(falta < 3600 ? hora(llegada) : (llegada >= segundosDia ? 'mañana' : 'hoy'), style: Tema.chico),
            ]),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => Parada3D(parada: parada))),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Tema.amarillo, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.view_in_ar_rounded, size: Tema.b(26), color: Tema.negro),
            ),
          ),
        ]),
      ),
    );
  }
}
