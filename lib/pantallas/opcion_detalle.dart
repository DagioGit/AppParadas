import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../datos/lugares.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/mapa_viaje.dart';
import 'viaje_pantalla.dart';

class OpcionDetalle extends StatelessWidget {
  final Opcion opcion;
  final Lugar origen;
  final Lugar destino;
  const OpcionDetalle({super.key, required this.opcion, required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    final o = opcion;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(duracion(o.total))),
      child: ListView(children: [
        MapaViaje(
          opciones: [o],
          origen: origen,
          destino: destino,
          resaltada: o,
          alto: 340,
          onTapOpcion: (_) {},
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
            if (o.enCombi.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConReloj(
                cada: const Duration(seconds: 1),
                builder: (context, ahora) {
                  final t = o.enCombi.first;
                  final falta = t.inicio - ahora;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Tema.fondo, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      InsigniaRuta(t.ruta!, tam: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Tu combi pasa por ${t.sube!.nombre}', style: Tema.chico),
                          Text(
                            falta < 45 ? 'Llegando' : falta < 3600 ? 'En ${(falta / 60).floor()} min ${(falta % 60).floor().toString().padLeft(2, '0')} s' : 'A las ${hora(t.inicio)}',
                            style: Tema.texto(size: 22, weight: FontWeight.w800),
                          ),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
            ],
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
  final Color? color;
  final Widget? insignia;
  final String titulo;
  final String detalle;
  const _Fila({this.icono, this.color, this.insignia, required this.titulo, required this.detalle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 34,
          child: insignia ?? Icon(icono, color: color ?? Tema.gris, size: 26),
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
