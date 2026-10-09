import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../ajustes.dart';
import '../modelo/ruta.dart';
import '../tema.dart';

/// "8:15 am" a partir de los segundos del día.
String horaAmPm(double seg) {
  final s = seg % segundosDia;
  final h = (s ~/ 3600) % 24;
  final m = (s % 3600) ~/ 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'am' : 'pm'}';
}

/// Hoja para elegir a qué hora funciona la app (para probarla a cualquier hora).
Future<void> mostrarSelectorHora(BuildContext context) {
  var elegido = segundosAhora();
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      final ahora = segundosAhora();
      final inicial = DateTime(2000, 1, 1, ahora ~/ 3600, (ahora % 3600) ~/ 60);
      return Container(
        decoration: BoxDecoration(
          color: Tema.fondo,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(ctx).padding.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Tema.grisClaro, borderRadius: BorderRadius.circular(3))),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.schedule_rounded, color: Tema.tinta, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('¿Qué hora quieres usar?', style: Tema.texto(size: 21, weight: FontWeight.w800))),
          ]),
          const SizedBox(height: 4),
          Text('Las combis pasan de 6:00 am a 9:00 pm.', style: Tema.texto(size: 15, color: Tema.gris)),
          const SizedBox(height: 10),
          Container(
            height: 190,
            decoration: BoxDecoration(color: Tema.tarjeta, borderRadius: BorderRadius.circular(20)),
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Tema.oscuro ? Brightness.dark : Brightness.light,
                textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: Tema.texto(size: 24, weight: FontWeight.w600, fijo: true)),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: inicial,
                minuteInterval: 1,
                onDateTimeChanged: (d) => elegido = d.hour * 3600.0 + d.minute * 60,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            for (final (txt, h) in const [('7:00 am', 7.0), ('2:00 pm', 14.0), ('7:00 pm', 19.0)]) ...[
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.symmetric(vertical: Tema.b(12)),
                  color: Tema.tarjeta,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () {
                    _usar(h * 3600);
                    Navigator.of(ctx).pop();
                  },
                  child: Text(txt, style: Tema.texto(size: 16, weight: FontWeight.w700)),
                ),
              ),
              if (h != 19.0) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 10),
          CupertinoButton(
            padding: EdgeInsets.symmetric(vertical: Tema.b(16)),
            color: Tema.amarillo,
            borderRadius: BorderRadius.circular(16),
            onPressed: () {
              _usar(elegido);
              Navigator.of(ctx).pop();
            },
            child: Text('Usar esta hora', style: Tema.texto(size: 19, weight: FontWeight.w800, color: Tema.negro)),
          ),
          if (ajustes.ajusteHora != 0) ...[
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.symmetric(vertical: Tema.b(14)),
              color: Tema.tarjeta,
              borderRadius: BorderRadius.circular(16),
              onPressed: () {
                ajustes.cambiar((a) => a.ajusteHora = 0);
                Navigator.of(ctx).pop();
              },
              child: Text('Volver a la hora real', style: Tema.texto(size: 17, weight: FontWeight.w700, color: Tema.azul)),
            ),
          ],
        ]),
      );
    },
  );
}

/// Pone el reloj de la app a [segDia] (segundos del día) desde este momento.
void _usar(double segDia) {
  final real = segundosAhora() - ajustes.ajusteHora;
  var ajuste = segDia - real;
  // El ajuste más corto (menos de medio día hacia adelante o hacia atrás)
  if (ajuste > segundosDia / 2) ajuste -= segundosDia;
  if (ajuste < -segundosDia / 2) ajuste += segundosDia;
  ajustes.cambiar((a) => a.ajusteHora = ajuste.abs() < 60 ? 0 : ajuste);
}
