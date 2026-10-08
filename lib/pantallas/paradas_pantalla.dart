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
  Ruta _ruta = rutaPorId('R1');
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                r.id == 'R1' ? 'Av. Lázaro Cárdenas · Ruta 1, de la Glorieta Las Palmas al malecón' : '${r.nombre} · ${r.apodo}',
                style: Tema.subtitulo,
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final otra in rutas)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: PildoraRuta(
                        otra,
                        activa: identical(otra, r),
                        onTap: () => setState(() {
                          _ruta = otra;
                          _sentido = 0;
                        }),
                      ),
                    ),
                ],
              ),
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
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(sentidos[i], style: Tema.texto(size: 14, weight: FontWeight.w600)),
                      ),
                  },
                ),
              ),
            Encabezado('${paradas.length} paradas · próxima combi'),
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
            if (r.semaforosEnRuta.isNotEmpty) ...[
              const Encabezado('Semáforos en el recorrido'),
              Tarjeta(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < r.semaforosEnRuta.length; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => mostrarSemaforo(context, r.semaforosEnRuta[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          border: i == 0 ? null : const Border(top: BorderSide(color: Tema.linea, width: 0.5)),
                        ),
                        child: Row(children: [
                          SizedBox(width: 34, child: Center(child: iconoSemaforo(alto: 26))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.semaforosEnRuta[i].nombre, style: Tema.texto(size: 16, weight: FontWeight.w600)),
                              Text(r.semaforosEnRuta[i].detalle, style: Tema.chico),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
              child: Text(
                'Horario estimado: una combi cada ${r.frecuenciaMin} min de 6:00 a 22:00; '
                'cuenta ${esperaEnParada.round()} s en cada parada y el tiempo en los semáforos.',
                style: Tema.chico,
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
    final llegando = falta < 45;
    final claro = r.color.computeLuminance() > 0.5;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => mostrarParada(context, parada),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: primera ? null : const Border(top: BorderSide(color: Tema.linea, width: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
            child: Text('$numero', style: Tema.texto(size: 14, weight: FontWeight.w800, color: claro ? Tema.tinta : const Color(0xFFFFFFFF))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(parada.nombre, style: Tema.texto(size: 16, weight: FontWeight.w600)),
              if (parada.descripcion.isNotEmpty)
                Text(parada.descripcion, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tema.chico),
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
                llegando ? 'En parada' : falta < 3600 ? '${(falta / 60).floor()}:${(falta % 60).floor().toString().padLeft(2, '0')}' : hora(llegada),
                style: Tema.texto(size: 16, weight: FontWeight.w800, color: llegando ? Tema.verde : Tema.tinta),
              ),
              Text(hora(llegada), style: Tema.chico),
            ]),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => Parada3D(parada: parada))),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: Tema.amarillo, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.view_in_ar_rounded, size: 20, color: Tema.tinta),
            ),
          ),
        ]),
      ),
    );
  }
}
