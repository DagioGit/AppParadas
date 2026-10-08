import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../estado.dart';
import '../modelo/ruta.dart';
import '../modelo/ubicacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/hoja_parada.dart';

class MapaPantalla extends StatefulWidget {
  const MapaPantalla({super.key});

  @override
  State<MapaPantalla> createState() => _MapaPantallaState();
}

class _MapaPantallaState extends State<MapaPantalla> {
  final _mapa = MapController();
  // Al abrir se ven las dos rutas del proyecto; las simuladas se encienden con su botón.
  final Set<String> _visibles = {'R1', 'R2'};
  LatLng? _yo;
  String? _aviso;

  Future<void> _ubicarme() async {
    final r = await obtenerUbicacion();
    if (!mounted) return;
    setState(() {
      _yo = r.punto != null && dentroDeLzc(r.punto!) ? r.punto : null;
      _aviso = r.problema;
    });
    if (_yo != null) _mapa.move(_yo!, 16);
  }

  @override
  Widget build(BuildContext context) {
    final visibles = rutas.where((r) => _visibles.contains(r.id)).toList();
    // Se dibujan primero las simuladas para que la 1 y la 2 queden encima.
    visibles.sort((a, b) => (b.simulada ? 1 : 0).compareTo(a.simulada ? 1 : 0));
    final arriba = MediaQuery.of(context).padding.top;
    final abajo = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      child: Stack(children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: const LatLng(17.9625, -102.2060),
            initialZoom: 13.6,
            minZoom: 11,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            capaTeselas(),
            PolylineLayer(polylines: [
              for (final r in visibles)
                lineaRuta(r.trazo.puntos, r.color, ancho: r.simulada ? 4 : 5.5),
            ]),
            MarkerLayer(markers: [
              for (final r in visibles)
                for (final p in r.paradas)
                  if (p.principal) marcadorParada(p, tam: r.simulada ? 13 : 17, onTap: () => mostrarParada(context, p)),
              if (_yo != null) marcadorUbicacion(_yo!),
            ]),
            creditosMapa(),
          ],
        ),
        // Buscador y filtros
        Positioned(
          left: 0,
          right: 0,
          top: arriba + 10,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => irAViaje(),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(16), boxShadow: Tema.sombra),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: Tema.gris),
                    const SizedBox(width: 10),
                    Expanded(child: Text('¿A dónde vas?', style: Tema.texto(size: 18, weight: FontWeight.w600, color: Tema.gris))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: Tema.amarillo, borderRadius: BorderRadius.circular(8)),
                      child: Text('LZC', style: Tema.texto(size: 13, weight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final r in rutas)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: PildoraRuta(
                        r,
                        activa: _visibles.contains(r.id),
                        onTap: () => setState(() {
                          if (!_visibles.remove(r.id)) _visibles.add(r.id);
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
        if (_aviso != null)
          Positioned(
            left: 16,
            right: 80,
            bottom: abajo + 16,
            child: GestureDetector(
              onTap: () => setState(() => _aviso = null),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xEE111111), borderRadius: BorderRadius.circular(14)),
                child: Text(_aviso!, style: Tema.texto(size: 14, color: const Color(0xFFFFFFFF))),
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: abajo + 16,
          child: Column(children: [
            BotonFlotante(icono: Icons.zoom_out_map_rounded, onTap: () => _mapa.move(const LatLng(17.9625, -102.2060), 13.6)),
            const SizedBox(height: 10),
            BotonFlotante(icono: Icons.near_me_rounded, onTap: _ubicarme),
          ]),
        ),
      ]),
    );
  }
}
