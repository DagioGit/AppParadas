import 'package:flutter/cupertino.dart';

import '../modelo/ruta.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import 'ruta_detalle.dart';

class RutasPantalla extends StatelessWidget {
  const RutasPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final reales = rutas.where((r) => !r.simulada).toList();
    final simuladas = rutas.where((r) => r.simulada).toList();
    return CupertinoPageScaffold(
      child: CustomScrollView(slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Rutas')),
        SliverList(
          delegate: SliverChildListDelegate([
            const Encabezado('Rutas del proyecto'),
            for (final r in reales) _FilaRuta(r),
            const Encabezado('Rutas simuladas'),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 6),
              child: Text(
                'Recorridos inventados sobre calles reales para que el buscador pueda comparar varias combis.',
                style: Tema.chico,
              ),
            ),
            for (final r in simuladas) _FilaRuta(r),
            const Encabezado('Acerca de AppParadas'),
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rutas LZC', style: Tema.texto(size: 19, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Proyecto escolar del Instituto Tecnológico de Lázaro Cárdenas: paradas fijas con caseta, '
                  'horario y contador de llegada para las combis de la ciudad. Los horarios son estimados: '
                  'cada ruta sale de su inicio cada cierto tiempo, de 6:00 a 22:00, y avanza a velocidad constante.',
                  style: Tema.texto(size: 15, height: 1.35),
                ),
                const SizedBox(height: 10),
                Text('Mapa y calles: © colaboradores de OpenStreetMap', style: Tema.chico),
              ]),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ]),
        ),
      ]),
    );
  }
}

class _FilaRuta extends StatelessWidget {
  final Ruta ruta;
  const _FilaRuta(this.ruta);

  @override
  Widget build(BuildContext context) {
    final principales = ruta.paradas.where((p) => p.principal).length;
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(
        title: 'Rutas',
        builder: (_) => RutaDetalle(ruta: ruta),
      )),
      child: Row(children: [
        InsigniaRuta(ruta, tam: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ruta.nombre} · ${ruta.apodo}', style: Tema.texto(size: 17, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              '$principales paradas · cada ${ruta.frecuenciaMin} min · ${(ruta.trazo.largo / 1000).toStringAsFixed(1)} km',
              style: Tema.subtitulo,
            ),
          ]),
        ),
        const Icon(CupertinoIcons.chevron_right, color: Tema.grisClaro, size: 20),
      ]),
    );
  }
}
