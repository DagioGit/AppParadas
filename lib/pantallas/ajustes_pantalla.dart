import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../ajustes.dart';
import '../tema.dart';
import '../widgets/ios.dart';

/// Ajustes de la app, con el mismo diseño que Ajustes del iPhone.
class AjustesPantalla extends StatelessWidget {
  const AjustesPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ajustes,
      builder: (context, _) => CupertinoPageScaffold(
        child: CustomScrollView(slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Ajustes')),
          SliverList(
            delegate: SliverChildListDelegate([
              _tarjetaApp(),
              _letra(),
              GrupoIOS(
                titulo: 'Para ver mejor',
                filas: [
                  FilaIOS.interruptor(
                    icono: const IconoIOS(Icons.format_bold_rounded, Color(0xFF8E8E93)),
                    titulo: 'Letra en negritas',
                    valor: ajustes.negritas,
                    alCambiar: (v) => _cambiar((a) => a.negritas = v),
                  ),
                  FilaIOS.interruptor(
                    icono: const IconoIOS(Icons.touch_app_rounded, Color(0xFFFF9500)),
                    titulo: 'Botones grandes',
                    valor: ajustes.botonesGrandes,
                    alCambiar: (v) => _cambiar((a) => a.botonesGrandes = v),
                  ),
                  FilaIOS.interruptor(
                    icono: const IconoIOS(Icons.contrast_rounded, Color(0xFF0A84FF)),
                    titulo: 'Más contraste',
                    valor: ajustes.contraste,
                    alCambiar: (v) => _cambiar((a) => a.contraste = v),
                  ),
                  FilaIOS.interruptor(
                    icono: const IconoIOS(Icons.vibration_rounded, Color(0xFFFF3B30)),
                    titulo: 'Vibrar con avisos',
                    valor: ajustes.vibrar,
                    alCambiar: (v) => _cambiar((a) => a.vibrar = v),
                  ),
                ],
              ),
              _apariencia(),
              GrupoIOS(filas: [
                FilaIOS(
                  icono: const IconoIOS(Icons.restart_alt_rounded, Color(0xFF8E8E93)),
                  titulo: 'Volver a lo de fábrica',
                  colorTitulo: Tema.rojo,
                  flecha: false,
                  onTap: () => _confirmarRestablecer(context),
                ),
              ]),
              GrupoIOS(
                titulo: 'Acerca de',
                filas: const [
                  FilaIOS(
                    icono: IconoIOS(Icons.directions_bus_rounded, Color(0xFF6E6E73)),
                    titulo: 'Versión',
                    valor: '1.0',
                  ),
                  FilaIOS(
                    icono: IconoIOS(Icons.school_rounded, Color(0xFF5856D6)),
                    titulo: 'Proyecto',
                    valor: 'Tec de Lázaro Cárdenas',
                  ),
                  FilaIOS(
                    icono: IconoIOS(Icons.map_rounded, Color(0xFF34C759)),
                    titulo: 'Mapa',
                    valor: 'OpenStreetMap',
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ]),
          ),
        ]),
      ),
    );
  }

  void _cambiar(void Function(Ajustes a) f) {
    if (ajustes.vibrar) HapticFeedback.selectionClick();
    ajustes.cambiar(f);
  }

  Widget _tarjetaApp() {
    return Container(
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
            Text('Combis de Lázaro Cárdenas', style: Tema.texto(size: 15, color: Tema.gris)),
          ]),
        ),
      ]),
    );
  }

  /// Tamaño de letra: vista previa y barra con "A" chica y "A" grande, como en el iPhone.
  Widget _letra() {
    final nivel = ajustes.nivelLetra;
    return GrupoIOS(
      titulo: 'Tamaño de letra',
      pie: 'Mueve la barra. Toda la app cambia al momento.',
      filas: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('La combi pasa en 3 min', style: Tema.texto(size: 22, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Así se ve la letra', style: Tema.texto(size: 16, color: Tema.gris)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, Tema.b(10)),
          child: Row(children: [
            Text('A', style: Tema.texto(size: 15, weight: FontWeight.w600, fijo: true)),
            Expanded(
              child: CupertinoSlider(
                value: nivel.toDouble(),
                min: 0,
                max: (Ajustes.tamanos.length - 1).toDouble(),
                divisions: Ajustes.tamanos.length - 1,
                onChanged: (v) {
                  final i = v.round();
                  if (i != ajustes.nivelLetra) _cambiar((a) => a.letra = Ajustes.tamanos[i]);
                },
              ),
            ),
            Text('A', style: Tema.texto(size: 28, weight: FontWeight.w600, fijo: true)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Center(
            child: Text(Ajustes.nombresTamano[nivel], style: Tema.texto(size: 15, weight: FontWeight.w600, color: Tema.azul)),
          ),
        ),
      ],
    );
  }

  /// Automática / Clara / Oscura con dibujitos de un teléfono, como en Pantalla y brillo.
  Widget _apariencia() {
    Widget opcion(int i, String nombre) {
      final elegida = ajustes.apariencia == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _cambiar((a) => a.apariencia = i),
          child: Column(children: [
            _MiniTelefono(modo: i),
            const SizedBox(height: 8),
            Text(nombre, style: Tema.texto(size: 15, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: elegida ? Tema.azul : const Color(0x00000000),
                border: Border.all(color: elegida ? Tema.azul : Tema.grisClaro, width: 1.6),
              ),
              child: elegida ? const Icon(Icons.check_rounded, size: 17, color: Color(0xFFFFFFFF)) : null,
            ),
          ]),
        ),
      );
    }

    return GrupoIOS(
      titulo: 'Apariencia',
      filas: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
          child: Row(children: [
            opcion(0, 'Automática'),
            opcion(1, 'Clara'),
            opcion(2, 'Oscura'),
          ]),
        ),
      ],
    );
  }

  Future<void> _confirmarRestablecer(BuildContext context) async {
    final si = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¿Volver a lo de fábrica?'),
        content: const Text('La letra, los botones y la apariencia regresan como al principio.'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('Sí'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (si == true) ajustes.restablecer();
  }
}

/// Teléfono chiquito claro, oscuro o mitad y mitad.
class _MiniTelefono extends StatelessWidget {
  final int modo;
  const _MiniTelefono({required this.modo});

  @override
  Widget build(BuildContext context) {
    Widget pantalla(bool oscura) {
      final f = oscura ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
      final t = oscura ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);
      final b = oscura ? const Color(0xFF636366) : const Color(0xFFC7C7CC);
      return Container(
        color: f,
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
        child: Column(children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 13,
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: t, borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: [const Color(0xFF6E6E73), Tema.amarillo, const Color(0xFF34C759)][i],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(child: Container(height: 3, color: b)),
              ]),
            ),
        ]),
      );
    }

    return Container(
      width: 62,
      height: 112,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF3A3A3C), width: 3),
      ),
      child: modo == 0
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: ClipRect(child: OverflowBox(alignment: Alignment.centerLeft, maxWidth: 56, minWidth: 56, child: pantalla(false)))),
              Expanded(child: ClipRect(child: OverflowBox(alignment: Alignment.centerRight, maxWidth: 56, minWidth: 56, child: pantalla(true)))),
            ])
          : pantalla(modo == 2),
    );
  }
}
