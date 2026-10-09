import 'package:flutter/cupertino.dart';

import '../modelo/ruta.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/ios.dart';
import 'ruta_detalle.dart';

class RutasPantalla extends StatelessWidget {
  const RutasPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final reales = rutas.where((r) => !r.simulada).toList();
    final simuladas = rutas.where((r) => r.simulada).toList();
    FilaIOS fila(Ruta r) => FilaIOS(
          icono: InsigniaRuta(r, tam: 34 * Tema.b(1.0).clamp(1.0, 1.2)),
          titulo: '${r.nombre} · ${r.apodo}',
          subtitulo: 'Pasa cada ${r.frecuenciaMin} min',
          onTap: () => Navigator.of(context).push(CupertinoPageRoute<void>(
            title: 'Rutas',
            builder: (_) => RutaDetalle(ruta: r),
          )),
        );
    return CupertinoPageScaffold(
      child: CustomScrollView(slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Rutas')),
        SliverList(
          delegate: SliverChildListDelegate([
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/logo.png', width: 62, height: 62),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AppParadas', style: Tema.texto(size: 22, weight: FontWeight.w700)),
                    Text('Combis de Lázaro Cárdenas', style: Tema.subtitulo),
                  ]),
                ),
              ]),
            ),
            GrupoIOS(titulo: 'Rutas del proyecto', filas: [for (final r in reales) fila(r)]),
            GrupoIOS(titulo: 'De prueba', filas: [for (final r in simuladas) fila(r)]),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
          ]),
        ),
      ]),
    );
  }
}
