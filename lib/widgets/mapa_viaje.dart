import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../datos/lugares.dart';
import '../datos/semaforos.dart';
import '../modelo/planificador.dart';
import '../modelo/ruta.dart';
import '../tema.dart';
import 'comunes.dart';

/// "llegando", "en 7 min" o "a las 15:40".
String faltaTexto(double llegada, double ahora) {
  final s = llegada - ahora;
  if (s < 15) return 'llegando';
  if (s < 60) return 'en ${s.round()} s';
  if (s < 3600) return 'en ${(s / 60).ceil()} min';
  return 'a las ${hora(llegada)}';
}

/// Mapa con los recorridos de las opciones de viaje.
/// La más rápida va resaltada: dónde pasa la combi (con cuenta regresiva), la combi
/// acercándose y dónde bajarse. Tocar un recorrido abre sus detalles.
class MapaViaje extends StatefulWidget {
  final List<Opcion> opciones;
  final Lugar origen;
  final Lugar destino;
  final void Function(Opcion) onTapOpcion;
  final double alto;

  /// Opción resaltada; si es null, la más rápida.
  final Opcion? resaltada;

  const MapaViaje({
    super.key,
    required this.opciones,
    required this.origen,
    required this.destino,
    required this.onTapOpcion,
    this.alto = 330,
    this.resaltada,
  });

  @override
  State<MapaViaje> createState() => _MapaViajeState();
}

class _MapaViajeState extends State<MapaViaje> {
  final LayerHitNotifier<Opcion> _golpe = ValueNotifier(null);

  @override
  void dispose() {
    _golpe.dispose();
    super.dispose();
  }

  Opcion? get _principal =>
      widget.resaltada ?? (widget.opciones.isEmpty ? null : widget.opciones.firstWhere((o) => o.masRapida, orElse: () => widget.opciones.first));

  @override
  Widget build(BuildContext context) {
    final principal = _principal;
    final otras = widget.opciones.where((o) => !identical(o, principal) && !o.soloAPie).toList();
    final todos = <LatLng>[
      widget.origen.punto,
      widget.destino.punto,
      if (principal != null)
        for (final t in principal.tramos) ...t.puntos,
    ];

    final lineas = <Polyline<Opcion>>[
      // Las demás opciones, delgadas y tenues
      for (final o in otras)
        for (final t in o.enCombi)
          Polyline<Opcion>(
            points: t.puntos,
            color: t.ruta!.color.withValues(alpha: 0.55),
            strokeWidth: 4,
            hitValue: o,
          ),
      // La resaltada: caminata en gris y combi con borde blanco
      if (principal != null)
        for (final t in principal.tramos)
          if (t.tipo == TipoTramo.pie)
            Polyline<Opcion>(points: t.puntos, color: Tema.grisFijo, strokeWidth: 3, hitValue: principal)
          else
            Polyline<Opcion>(
              points: t.puntos,
              color: t.ruta!.color,
              strokeWidth: 7,
              borderColor: const Color(0xFFFFFFFF),
              borderStrokeWidth: 2,
              hitValue: principal,
            ),
    ];

    return Container(
      height: widget.alto,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Tema.fondoFijo),
      child: Stack(children: [
        FlutterMap(
          key: ValueKey(Object.hashAll([widget.origen.punto, widget.destino.punto, widget.opciones.length])),
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(todos),
              padding: const EdgeInsets.fromLTRB(100, 80, 100, 45),
            ),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            capaTeselas(),
            GestureDetector(
              onTap: () {
                final r = _golpe.value;
                if (r != null && r.hitValues.isNotEmpty) widget.onTapOpcion(r.hitValues.first);
              },
              child: PolylineLayer<Opcion>(hitNotifier: _golpe, polylines: lineas),
            ),
            capaTrafico(),
            capaAvisos(context),
            MarkerLayer(markers: [
              for (final sem in semaforos) marcadorSemaforo(sem, alto: 22, onTap: () => mostrarSemaforo(context, sem)),
              // En las otras opciones, sólo el número de la ruta donde se sube
              for (final o in otras)
                if (o.enCombi.isNotEmpty)
                  Marker(
                    point: o.enCombi.first.sube!.punto,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: () => widget.onTapOpcion(o),
                      child: Center(child: InsigniaRuta(o.enCombi.first.ruta!, tam: 22)),
                    ),
                  ),
              if (principal != null)
                for (final t in principal.enCombi) ...[
                  marcadorParada(t.sube!, tam: 18),
                  marcadorParada(t.baja!, tam: 18),
                ],
              marcadorOrigen(widget.origen.punto, tam: 28),
              marcadorDestino(widget.destino.punto, tam: 42),
            ]),
            // Combis acercándose y etiquetas con cuenta regresiva (se actualizan solas)
            if (principal != null)
              ConReloj(builder: (context, ahora) {
                final combis = principal.enCombi.toList();
                return MarkerLayer(markers: [
                  for (var i = 0; i < combis.length; i++) ...[
                    if (combis[i].ruta!.combiQueLlega(combis[i].sube!, combis[i].inicio, ahora) case final LatLng p)
                      Marker(
                        point: p,
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => widget.onTapOpcion(principal),
                          child: Center(child: iconoCombi(combis[i].ruta!, tam: 28, resaltada: true)),
                        ),
                      ),
                    marcadorEtiqueta(
                      combis[i].sube!.punto,
                      i == 0
                          ? 'Pasa aquí · ${faltaTexto(combis[i].inicio, ahora)}'
                          : 'Cambia a la ${combis[i].ruta!.numero} · ${faltaTexto(combis[i].inicio, ahora)}',
                      color: combis[i].ruta!.color,
                      letra: combis[i].ruta!.color.computeLuminance() > 0.5 ? Tema.negro : const Color(0xFFFFFFFF),
                      ancho: 190,
                      onTap: () => widget.onTapOpcion(principal),
                    ),
                  ],
                  if (combis.isNotEmpty)
                    marcadorEtiqueta(
                      combis.last.baja!.punto,
                      'Bájate aquí · ${hora(combis.last.fin)}',
                      color: Tema.negro,
                      ancho: 170,
                      onTap: () => widget.onTapOpcion(principal),
                    ),
                ]);
              }),
          ],
        ),
        // Mención de la más rápida
        if (principal != null)
          Positioned(
            left: 10,
            top: 10,
            right: 10,
            child: IgnorePointer(
              child: Row(children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: principal.masRapida ? Tema.verdeClaroFijo : Tema.blanco,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: Tema.sombra,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(principal.masRapida ? Icons.bolt_rounded : Icons.directions_rounded, size: 17, color: principal.masRapida ? Tema.verdeFijo : Tema.negro),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${principal.masRapida ? 'Ruta más rápida' : 'Opción elegida'} · ${duracion(principal.total)} · '
                          '${principal.soloAPie ? 'a pie' : principal.enCombi.map((t) => 'R${t.ruta!.numero}').join(' + ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Tema.textoFijo(size: 13, weight: FontWeight.w700, color: principal.masRapida ? Tema.verdeFijo : Tema.negro),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
