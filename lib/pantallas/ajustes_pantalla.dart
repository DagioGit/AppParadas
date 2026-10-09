import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';

import '../ajustes.dart';
import '../tema.dart';
import '../widgets/comunes.dart' show ConReloj;
import '../widgets/selector_hora.dart';
import '../voz.dart';

/// Ajustes con el estilo de la app: tarjetas grandes, colores de las rutas
/// y botones fáciles de tocar para personas mayores y niños.
class AjustesPantalla extends StatelessWidget {
  const AjustesPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ajustes,
      builder: (context, _) => CupertinoPageScaffold(
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, MediaQuery.of(context).padding.top + 8, 0, MediaQuery.of(context).padding.bottom + 40),
          children: [
            const _Portada(),
            const _Titulo(Icons.schedule_rounded, 'Hora de la app'),
            _hora(context),
            const _Titulo(Icons.text_fields_rounded, 'Tamaño de letra'),
            _letra(),
            const _Titulo(Icons.visibility_rounded, 'Para ver mejor'),
            _opciones(),
            const _Titulo(Icons.palette_rounded, 'Colores de la app'),
            _apariencia(),
            const SizedBox(height: 22),
            _restablecer(context),
            const _Pie(),
          ],
        ),
      ),
    );
  }

  static void _cambiar(void Function(Ajustes a) f) {
    if (ajustes.vibrar) HapticFeedback.selectionClick();
    ajustes.cambiar(f);
  }

  /// Hora con la que funciona la app: la real o una elegida para probarla (por ejemplo de noche).
  Widget _hora(BuildContext context) {
    final cambiada = ajustes.ajusteHora != 0;
    return _Caja(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: cambiada ? Tema.amarillo : Tema.relleno, shape: BoxShape.circle),
            child: Icon(cambiada ? Icons.edit_calendar_rounded : Icons.schedule_rounded, size: 28, color: cambiada ? Tema.negro : Tema.gris),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ConReloj(
              cada: const Duration(seconds: 1),
              builder: (context, ahora) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(horaAmPm(ahora), style: Tema.texto(size: 30, weight: FontWeight.w800)),
                Text(
                  cambiada ? 'Hora cambiada para probar' : 'Hora real del teléfono',
                  style: Tema.texto(size: 15, weight: FontWeight.w600, color: cambiada ? const Color(0xFFB8860B) : Tema.gris),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: Tema.b(14)),
              color: Tema.amarillo,
              borderRadius: BorderRadius.circular(16),
              onPressed: () => mostrarSelectorHora(context),
              child: Text('Cambiar hora', style: Tema.texto(size: 17, weight: FontWeight.w800, color: Tema.negro)),
            ),
          ),
          if (cambiada) ...[
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.symmetric(vertical: Tema.b(14)),
                color: Tema.fondo,
                borderRadius: BorderRadius.circular(16),
                onPressed: () => _cambiar((a) => a.ajusteHora = 0),
                child: Text('Hora real', style: Tema.texto(size: 17, weight: FontWeight.w700, color: Tema.azul)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  /// Vista previa y cinco botones con una "A" cada vez más grande.
  Widget _letra() {
    final nivel = ajustes.nivelLetra;
    return _Caja(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Tema.fondo, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: const Color(0xFF6E6E73), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.directions_bus_rounded, color: Color(0xFFFFFFFF), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ruta 1 · Malecón', style: Tema.texto(size: 15, color: Tema.gris)),
                Text('Pasa en 3 min', style: Tema.texto(size: 22, weight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < Ajustes.tamanos.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _cambiar((a) => a.letra = Ajustes.tamanos[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: Tema.b(60),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == nivel ? Tema.amarillo : Tema.fondo,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'A',
                    style: Tema.texto(
                      size: 14.0 + i * 5,
                      weight: FontWeight.w800,
                      color: i == nivel ? Tema.negro : Tema.tinta,
                      fijo: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Center(
          child: Text(Ajustes.nombresTamano[nivel], style: Tema.texto(size: 16, weight: FontWeight.w700, color: Tema.gris)),
        ),
      ]),
    );
  }

  /// Cuatro mosaicos grandes que se prenden y apagan con un toque.
  Widget _opciones() {
    final tiles = [
      _Mosaico(
        icono: Icons.format_bold_rounded,
        color: const Color(0xFF5856D6),
        titulo: 'Letra gruesa',
        activo: ajustes.negritas,
        onTap: () => _cambiar((a) => a.negritas = !a.negritas),
      ),
      _Mosaico(
        icono: Icons.touch_app_rounded,
        color: const Color(0xFFFF9500),
        titulo: 'Botones grandes',
        activo: ajustes.botonesGrandes,
        onTap: () => _cambiar((a) => a.botonesGrandes = !a.botonesGrandes),
      ),
      _Mosaico(
        icono: Icons.contrast_rounded,
        color: const Color(0xFF0A84FF),
        titulo: 'Más contraste',
        activo: ajustes.contraste,
        onTap: () => _cambiar((a) => a.contraste = !a.contraste),
      ),
      _Mosaico(
        icono: Icons.vibration_rounded,
        color: const Color(0xFFFF3B30),
        titulo: 'Vibrar al avisar',
        activo: ajustes.vibrar,
        onTap: () => _cambiar((a) => a.vibrar = !a.vibrar),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        // Avisos por voz (para personas con discapacidad visual): mosaico ancho
        _Mosaico(
          icono: Icons.record_voice_over_rounded,
          color: const Color(0xFF34C759),
          titulo: 'Avisos por voz',
          activo: ajustes.voz,
          onTap: () {
            _cambiar((a) => a.voz = !a.voz);
            if (ajustes.voz) {
              Voz.decir('Avisos por voz prendidos. Te voy a decir en voz alta cuánto falta para tu combi.');
            } else {
              Voz.callar();
            }
          },
        ),
        const SizedBox(height: 12),
        for (var f = 0; f < tiles.length; f += 2) ...[
          if (f > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: tiles[f]),
              const SizedBox(width: 12),
              Expanded(child: tiles[f + 1]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _apariencia() {
    Widget opcion(int i, String nombre) {
      final elegida = ajustes.apariencia == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _cambiar((a) => a.apariencia = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(vertical: Tema.b(12)),
            decoration: BoxDecoration(
              color: elegida ? Tema.amarillo.withValues(alpha: 0.18) : const Color(0x00000000),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: elegida ? Tema.amarillo : const Color(0x00000000), width: 3),
            ),
            child: Column(children: [
              _MiniTelefono(modo: i),
              const SizedBox(height: 8),
              Text(nombre, style: Tema.texto(size: 16, weight: FontWeight.w700)),
            ]),
          ),
        ),
      );
    }

    return _Caja(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        opcion(1, 'Clara'),
        const SizedBox(width: 6),
        opcion(2, 'Oscura'),
        const SizedBox(width: 6),
        opcion(0, 'Como mi cel'),
      ]),
    );
  }

  Widget _restablecer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CupertinoButton(
        color: Tema.tarjeta,
        borderRadius: BorderRadius.circular(18),
        padding: EdgeInsets.symmetric(vertical: Tema.b(16)),
        onPressed: () => _confirmarRestablecer(context),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.restart_alt_rounded, color: Tema.rojo, size: 24),
          const SizedBox(width: 8),
          Text('Dejar como al principio', style: Tema.texto(size: 17, weight: FontWeight.w700, color: Tema.rojo)),
        ]),
      ),
    );
  }

  Future<void> _confirmarRestablecer(BuildContext context) async {
    final si = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('¿Dejar como al principio?'),
        content: const Text('La letra, los botones, los colores y la hora regresan como estaban.'),
        actions: [
          CupertinoDialogAction(child: const Text('No'), onPressed: () => Navigator.of(ctx).pop(false)),
          CupertinoDialogAction(isDestructiveAction: true, child: const Text('Sí'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (si == true) ajustes.restablecer();
  }
}

/// Portada: tarjeta gris de la Ruta 1 con el logo y una calle con su combi.
class _Portada extends StatelessWidget {
  const _Portada();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C7C82), Color(0xFF3A3A3C)],
        ),
        boxShadow: Tema.sombra,
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ajustes', style: Tema.texto(size: 34, weight: FontWeight.w800, color: Tema.blanco, fijo: true)),
                const SizedBox(height: 2),
                Text('Hazla a tu medida', style: Tema.texto(size: 17, weight: FontWeight.w600, color: const Color(0xDDFFFFFF))),
              ]),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/logo.png', width: 78, height: 78),
              ),
            ),
          ]),
        ),
        const _Calle(),
      ]),
    );
  }
}

/// Franja de calle con línea amarilla punteada, paradas y la combi.
class _Calle extends StatelessWidget {
  const _Calle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Stack(children: [
        Positioned.fill(child: Container(color: const Color(0xFF2C2C2E))),
        Positioned.fill(child: CustomPaint(painter: _LineaCalle())),
        for (final x in [0.2, 0.55, 0.88])
          Align(
            alignment: Alignment(x * 2 - 1, -0.8),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF6E6E73), width: 2.5),
              ),
            ),
          ),
        Align(
          alignment: const Alignment(-0.25, 0),
          child: Container(
            width: 44,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 8,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(2)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _LineaCalle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Tema.amarillo
      ..strokeWidth = 3;
    final y = size.height / 2;
    for (double x = 8; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, y), Offset(x + 13, y), p);
    }
  }

  @override
  bool shouldRepaint(_LineaCalle old) => false;
}

class _Titulo extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Titulo(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
      child: Row(children: [
        Icon(icono, size: 24, color: Tema.gris),
        const SizedBox(width: 8),
        Text(texto, style: Tema.texto(size: 20, weight: FontWeight.w800)),
      ]),
    );
  }
}

class _Caja extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Caja({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}

/// Mosaico grande: ícono en círculo de color, nombre y "Prendido / Apagado".
class _Mosaico extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final bool activo;
  final VoidCallback onTap;
  const _Mosaico({required this.icono, required this.color, required this.titulo, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(Tema.b(14)),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: Tema.oscuro ? 0.28 : 0.12) : Tema.tarjeta,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: activo ? color : const Color(0x00000000), width: 2.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: activo ? color : Tema.relleno, shape: BoxShape.circle),
              child: Icon(icono, size: 26, color: activo ? const Color(0xFFFFFFFF) : Tema.gris),
            ),
            const Spacer(),
            Icon(
              activo ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 28,
              color: activo ? color : Tema.grisClaro,
            ),
          ]),
          const SizedBox(height: 12),
          Text(titulo, style: Tema.texto(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(activo ? 'Prendido' : 'Apagado',
              style: Tema.texto(size: 15, weight: FontWeight.w600, color: activo ? color : Tema.gris)),
        ]),
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final c in const [Color(0xFF6E6E73), Color(0xFFF2C200), Color(0xFF34C759), Color(0xFF0A84FF), Color(0xFFAF52DE)])
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
        ]),
        const SizedBox(height: 10),
        Text('CombiLZC 1.0', style: Tema.texto(size: 15, weight: FontWeight.w700, color: Tema.gris)),
        Text('Proyecto del Tec de Lázaro Cárdenas', textAlign: TextAlign.center, style: Tema.chico),
        Text('Mapa © OpenStreetMap', style: Tema.chico),
      ]),
    );
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
      width: 58,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF3A3A3C), width: 3),
      ),
      child: modo == 0
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: ClipRect(child: OverflowBox(alignment: Alignment.centerLeft, maxWidth: 52, minWidth: 52, child: pantalla(false)))),
              Expanded(child: ClipRect(child: OverflowBox(alignment: Alignment.centerRight, maxWidth: 52, minWidth: 52, child: pantalla(true)))),
            ])
          : pantalla(modo == 2),
    );
  }
}
