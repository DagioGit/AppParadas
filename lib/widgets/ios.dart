import 'package:flutter/cupertino.dart';

import '../tema.dart';

/// Grupo de filas como en Ajustes del iPhone: tarjeta redondeada con separadores
/// que empiezan después del ícono.
class GrupoIOS extends StatelessWidget {
  final String? titulo;
  final String? pie;
  final List<Widget> filas;
  const GrupoIOS({super.key, this.titulo, this.pie, required this.filas});

  @override
  Widget build(BuildContext context) {
    final hijos = <Widget>[];
    for (var i = 0; i < filas.length; i++) {
      if (i > 0) {
        final conIcono = filas[i - 1] is FilaIOS && (filas[i - 1] as FilaIOS).tieneIcono;
        hijos.add(Container(
          height: 0.6,
          margin: EdgeInsets.only(left: conIcono ? 16 + _tamIcono() + 14 : 16),
          color: Tema.linea,
        ));
      }
      hijos.add(filas[i]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (titulo != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 22, 36, 7),
          child: Text(titulo!, style: Tema.texto(size: 15, weight: FontWeight.w600, color: Tema.gris)),
        ),
      if (titulo == null) const SizedBox(height: 18),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(22)),
        child: Column(children: hijos),
      ),
      if (pie != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 7, 36, 0),
          child: Text(pie!, style: Tema.texto(size: 14, color: Tema.gris)),
        ),
    ]);
  }
}

double _tamIcono() => 30 * Tema.b(1.0).clamp(1.0, 1.25);

/// Cuadrito de color con un ícono blanco (como los de Ajustes).
class IconoIOS extends StatelessWidget {
  final IconData icono;
  final Color color;
  const IconoIOS(this.icono, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = _tamIcono();
    return Container(
      width: t,
      height: t,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(t * 0.24)),
      child: Icon(icono, size: t * 0.66, color: const Color(0xFFFFFFFF)),
    );
  }
}

/// Fila de un [GrupoIOS]: ícono, título, valor gris y flecha (o un interruptor).
class FilaIOS extends StatelessWidget {
  final Widget? icono;
  final String titulo;
  final String? subtitulo;
  final String? valor;
  final Widget? derecha;
  final VoidCallback? onTap;
  final bool flecha;
  final Color? colorTitulo;
  const FilaIOS({
    super.key,
    this.icono,
    required this.titulo,
    this.subtitulo,
    this.valor,
    this.derecha,
    this.onTap,
    this.flecha = true,
    this.colorTitulo,
  });

  /// Fila con interruptor.
  factory FilaIOS.interruptor({
    Key? key,
    Widget? icono,
    required String titulo,
    String? subtitulo,
    required bool valor,
    required ValueChanged<bool> alCambiar,
  }) =>
      FilaIOS(
        key: key,
        icono: icono,
        titulo: titulo,
        subtitulo: subtitulo,
        flecha: false,
        onTap: () => alCambiar(!valor),
        derecha: CupertinoSwitch(value: valor, activeTrackColor: const Color(0xFF34C759), onChanged: alCambiar),
      );

  bool get tieneIcono => icono != null;

  @override
  Widget build(BuildContext context) {
    final fila = ConstrainedBox(
      constraints: BoxConstraints(minHeight: Tema.b(56)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, Tema.b(9), 14, Tema.b(9)),
        child: Row(children: [
          if (icono != null) ...[icono!, const SizedBox(width: 14)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(titulo, style: Tema.texto(size: 18, color: colorTitulo ?? Tema.tinta)),
              if (subtitulo != null) Text(subtitulo!, style: Tema.texto(size: 14, color: Tema.gris)),
            ]),
          ),
          if (valor != null) ...[
            const SizedBox(width: 8),
            Text(valor!, style: Tema.texto(size: 17, color: Tema.gris)),
          ],
          if (derecha != null) ...[const SizedBox(width: 8), derecha!],
          if (flecha && onTap != null) ...[
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_right, size: 18, color: Tema.grisClaro),
          ],
        ]),
      ),
    );
    if (onTap == null) return fila;
    return _Presionable(onTap: onTap!, child: fila);
  }
}

/// Se oscurece un poco al tocarla, como las filas de iOS.
class _Presionable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Presionable({required this.onTap, required this.child});

  @override
  State<_Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<_Presionable> {
  bool _abajo = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _abajo = true),
      onTapCancel: () => setState(() => _abajo = false),
      onTapUp: (_) => setState(() => _abajo = false),
      onTap: widget.onTap,
      child: ColoredBox(
        color: _abajo ? Tema.relleno : const Color(0x00000000),
        child: widget.child,
      ),
    );
  }
}
