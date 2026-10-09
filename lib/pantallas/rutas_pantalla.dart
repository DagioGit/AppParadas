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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/logo.png', width: 76, height: 76),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AppParadas', style: Tema.texto(size: 24, weight: FontWeight.w800)),
                    Text('Combis de Lázaro Cárdenas', style: Tema.subtitulo),
                  ]),
                ),
              ]),
            ),
            for (final r in reales) _FilaRuta(r),
            const Encabezado('De prueba'),
            for (final r in simuladas) _FilaRuta(r),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 14, 32, 0),
              child: Text('Mapa: © OpenStreetMap', style: Tema.chico),
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
    return Tarjeta(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(
        title: 'Rutas',
        builder: (_) => RutaDetalle(ruta: ruta),
      )),
      child: Row(children: [
        InsigniaRuta(ruta, tam: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ruta.nombre} · ${ruta.apodo}', style: Tema.texto(size: 19, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Pasa cada ${ruta.frecuenciaMin} min', style: Tema.subtitulo),
          ]),
        ),
        const Icon(CupertinoIcons.chevron_right, color: Tema.grisClaro, size: 20),
      ]),
    );
  }
}
