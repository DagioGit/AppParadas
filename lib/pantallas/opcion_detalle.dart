import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../datos/lugares.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import 'viaje_pantalla.dart';

class OpcionDetalle extends StatelessWidget {
  final Opcion opcion;
  final Lugar origen;
  final Lugar destino;
  const OpcionDetalle({super.key, required this.opcion, required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    final o = opcion;
    final todos = <LatLng>[for (final t in o.tramos) ...t.puntos];

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(duracion(o.total))),
      child: ListView(children: [
        Container(
          height: 320,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(todos),
                padding: const EdgeInsets.all(36),
              ),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              capaTeselas(),
              PolylineLayer(polylines: [
                for (final t in o.tramos)
                  if (t.tipo == TipoTramo.pie) lineaPie(t.puntos) else lineaRuta(t.puntos, t.ruta!.color, ancho: 6),
              ]),
              MarkerLayer(markers: [
                for (final t in o.enCombi) ...[
                  marcadorParada(t.sube!, tam: 16),
                  marcadorParada(t.baja!, tam: 16),
                ],
                marcadorPunto(origen.punto, color: Tema.azul, icono: Icons.circle, tam: 22),
                marcadorPunto(destino.punto, color: const Color(0xFFFF3B30), icono: Icons.flag_rounded, tam: 32),
              ]),
              creditosMapa(),
            ],
          ),
        ),
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${hora(o.salida)} → ${hora(o.llegada)}', style: Tema.texto(size: 22, weight: FontWeight.w800)),
                  Text('${origen.nombre} a ${destino.nombre}', style: Tema.subtitulo),
                ]),
              ),
              if (o.masRapida)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Tema.verdeClaro, borderRadius: BorderRadius.circular(8)),
                  child: Text('La más rápida', style: Tema.texto(size: 13, weight: FontWeight.w700, color: Tema.verde)),
                ),
            ]),
            const SizedBox(height: 12),
            SecuenciaTramos(opcion: o),
          ]),
        ),
        const Encabezado('Paso a paso'),
        Tarjeta(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < o.tramos.length; i++)
              if (!(o.tramos[i].tipo == TipoTramo.pie && o.tramos[i].segundos < 30 && o.tramos.length > 1))
                _Paso(tramo: o.tramos[i], primero: i == 0),
            _Fila(
              icono: Icons.flag_rounded,
              color: const Color(0xFFFF3B30),
              titulo: 'Llegas a ${destino.nombre}',
              detalle: hora(o.llegada),
            ),
          ]),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
      ]),
    );
  }
}

class _Paso extends StatelessWidget {
  final Tramo tramo;
  final bool primero;
  const _Paso({required this.tramo, required this.primero});

  @override
  Widget build(BuildContext context) {
    final t = tramo;
    if (t.tipo == TipoTramo.pie) {
      final destino = t.hastaNombre;
      return _Fila(
        icono: Icons.directions_walk_rounded,
        color: Tema.gris,
        titulo: 'Camina ${duracion(t.segundos)} a $destino',
        detalle: '${t.metros.round()} m · ${hora(t.inicio)}',
      );
    }
    final r = t.ruta!;
    return Column(children: [
      _Fila(
        insignia: InsigniaRuta(r, tam: 30),
        titulo: 'Toma la ${r.nombre} · ${r.apodo}',
        detalle: 'En ${t.sube!.nombre}. Pasa a las ${hora(t.inicio)}'
            '${t.espera >= 60 ? ' (esperas ${duracion(t.espera)})' : ''}',
      ),
      _Fila(
        icono: Icons.directions_bus_rounded,
        color: r.color,
        titulo: 'Bájate en ${t.baja!.nombre}',
        detalle: '${t.paradas} ${t.paradas == 1 ? 'parada' : 'paradas'} · ${duracion(t.segundos)} · ${hora(t.fin)}',
      ),
    ]);
  }
}

class _Fila extends StatelessWidget {
  final IconData? icono;
  final Color color;
  final Widget? insignia;
  final String titulo;
  final String detalle;
  const _Fila({this.icono, this.color = Tema.gris, this.insignia, required this.titulo, required this.detalle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 34,
          child: insignia ?? Icon(icono, color: color, size: 26),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: Tema.texto(size: 16, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(detalle, style: Tema.chico),
          ]),
        ),
      ]),
    );
  }
}
