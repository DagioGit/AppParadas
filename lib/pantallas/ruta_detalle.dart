import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';

import '../modelo/ruta.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/hoja_parada.dart';

class RutaDetalle extends StatefulWidget {
  final Ruta ruta;
  const RutaDetalle({super.key, required this.ruta});

  @override
  State<RutaDetalle> createState() => _RutaDetalleState();
}

class _RutaDetalleState extends State<RutaDetalle> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ruta;
    final ahora = segundosAhora();
    final paradas = r.paradas.where((p) => p.principal).toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('${r.nombre} · ${r.apodo}'),
      ),
      child: ListView(children: [
        Container(
          height: 300,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(r.trazo.puntos),
                padding: const EdgeInsets.all(28),
              ),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              capaTeselas(),
              PolylineLayer(polylines: [lineaRuta(r.trazo.puntos, r.color, ancho: 5.5)]),
              MarkerLayer(markers: [
                for (final p in paradas) marcadorParada(p, tam: 15, onTap: () => mostrarParada(context, p)),
                for (final sem in r.semaforosEnRuta) marcadorSemaforo(sem, alto: 22, onTap: () => mostrarSemaforo(context, sem)),
              ]),
              capaCombis([r], onTap: (c) => mostrarCombi(context, c)),
              creditosMapa(),
            ],
          ),
        ),
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              InsigniaRuta(r, tam: 34),
              const SizedBox(width: 10),
              if (r.simulada)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Tema.fondo, borderRadius: BorderRadius.circular(8)),
                  child: Text('Simulada', style: Tema.etiqueta),
                ),
            ]),
            const SizedBox(height: 10),
            Text(r.descripcion, style: Tema.texto(size: 15, height: 1.35)),
            const SizedBox(height: 14),
            Row(children: [
              _Dato('Cada', '${r.frecuenciaMin} min'),
              _Dato('Horario', '6 a 22 h'),
              _Dato('Vuelta', '${r.vueltaMin.round()} min'),
              _Dato('Largo', '${(r.trazo.largo / 1000).toStringAsFixed(1)} km'),
            ]),
          ]),
        ),
        const Encabezado('Paradas y próxima combi'),
        Tarjeta(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (var i = 0; i < paradas.length; i++)
              _FilaParada(
                parada: paradas[i],
                primera: i == 0,
                ultima: i == paradas.length - 1,
                llegada: r.proximaLlegada(paradas[i], ahora),
                ahora: ahora,
              ),
          ]),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
      ]),
    );
  }
}

class _Dato extends StatelessWidget {
  final String titulo;
  final String valor;
  const _Dato(this.titulo, this.valor);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo.toUpperCase(), style: Tema.etiqueta),
        const SizedBox(height: 2),
        Text(valor, style: Tema.texto(size: 15, weight: FontWeight.w700)),
      ]),
    );
  }
}

class _FilaParada extends StatelessWidget {
  final Parada parada;
  final bool primera;
  final bool ultima;
  final double llegada;
  final double ahora;
  const _FilaParada({required this.parada, required this.primera, required this.ultima, required this.llegada, required this.ahora});

  @override
  Widget build(BuildContext context) {
    final color = parada.ruta.color;
    final falta = llegada - ahora;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => mostrarParada(context, parada),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 22,
            child: Stack(alignment: Alignment.center, children: [
              Positioned(
                top: primera ? 22 : 0,
                bottom: ultima ? null : 0,
                height: ultima ? 22 : null,
                child: Container(width: 4, color: color),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Tema.tarjeta,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3.5),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(parada.nombre, style: Tema.texto(size: 16, weight: FontWeight.w600)),
                if (parada.sentido.isNotEmpty && parada.sentido != 'Parada principal')
                  Text(parada.sentido, style: Tema.chico, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(falta < 3600 ? '${(falta / 60).ceil()} min' : hora(llegada), style: Tema.texto(size: 15, weight: FontWeight.w700)),
            Text(hora(llegada), style: Tema.chico),
          ]),
        ]),
      ),
    );
  }
}
