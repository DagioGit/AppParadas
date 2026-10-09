import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../datos/lugares.dart';
import '../estado.dart';
import '../modelo/geo.dart';
import '../modelo/ruta.dart';
import '../pantallas/parada_3d.dart';
import '../pantallas/ruta_detalle.dart';
import '../tema.dart';
import 'comunes.dart';

/// Abre la hoja de una parada: próximas combis con cuenta regresiva y rutas que pasan cerca.
Future<void> mostrarParada(BuildContext context, Parada parada) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => HojaParada(parada: parada),
  );
}

class HojaParada extends StatefulWidget {
  final Parada parada;
  const HojaParada({super.key, required this.parada});

  @override
  State<HojaParada> createState() => _HojaParadaState();
}

class _HojaParadaState extends State<HojaParada> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parada;
    final r = p.ruta;
    final ahora = segundosAhora();
    final llegadas = r.proximasLlegadas(p, ahora, n: 3);

    // Otras rutas con parada a menos de 300 m
    final cerca = <Ruta, Parada>{};
    for (final otra in rutas) {
      if (identical(otra, r)) continue;
      for (final q in otra.paradas) {
        final d = distanciaM(q.punto, p.punto);
        if (d < 300 && (cerca[otra] == null || d < distanciaM(cerca[otra]!.punto, p.punto))) cerca[otra] = q;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Tema.fondo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(0, 8, 0, MediaQuery.of(context).padding.bottom + 12),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 38, height: 5, decoration: BoxDecoration(color: Tema.grisClaro, borderRadius: BorderRadius.circular(3))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InsigniaRuta(r, tam: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nombre, style: Tema.texto(size: 24, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${r.nombre} · ${r.apodo}', style: Tema.subtitulo),
                ]),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, color: Tema.gris, size: 30),
              ),
            ]),
          ),
          const Encabezado('Próxima combi'),
          Tarjeta(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (var i = 0; i < llegadas.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : const Border(top: BorderSide(color: Tema.linea, width: 0.5)),
                  ),
                  child: Row(children: [
                    Icon(Icons.directions_bus_rounded, color: r.color, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _cuenta(llegadas[i], ahora),
                        style: Tema.texto(size: i == 0 ? 26 : 18, weight: i == 0 ? FontWeight.w800 : FontWeight.w500),
                      ),
                    ),
                    Text(hora(llegadas[i]), style: Tema.subtitulo),
                  ]),
                ),
            ]),
          ),
          if (cerca.isNotEmpty) ...[
            const Encabezado('También pasan cerca'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final e in cerca.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PildoraRuta(e.key, onTap: () {
                        Navigator.of(context).pop();
                        mostrarParada(context, e.value);
                      }),
                    ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CupertinoButton(
              color: Tema.amarillo,
              padding: const EdgeInsets.symmetric(vertical: 18),
              borderRadius: BorderRadius.circular(14),
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(CupertinoPageRoute<void>(builder: (_) => Parada3D(parada: p)));
              },
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.view_in_ar_rounded, color: Tema.tinta, size: 28),
                const SizedBox(width: 8),
                Text('Ver en 3D', style: Tema.texto(size: 20, weight: FontWeight.w800)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              Expanded(
                child: CupertinoButton(
                  color: Tema.tarjeta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(CupertinoPageRoute<void>(builder: (_) => RutaDetalle(ruta: r)));
                  },
                  child: Text('Ver ruta', style: Tema.texto(size: 19, weight: FontWeight.w700, color: Tema.azul)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  color: Tema.tinta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () {
                    Navigator.of(context).pop();
                    irAViaje(destino: Lugar(p.nombre, 'Parada de la ${r.nombre}', TipoLugar.parada, p.punto));
                  },
                  child: Text('Ir aquí', style: Tema.texto(size: 19, weight: FontWeight.w700, color: const Color(0xFFFFFFFF))),
                ),
              ),
            ]),
          ),
        ],
      ),
      ),
    );
  }

  String _cuenta(double llegada, double ahora) {
    final s = llegada - ahora;
    if (s < 45) return 'Llegando';
    if (s < 3600) return 'en ${(s / 60).ceil()} min';
    return 'a las ${hora(llegada)}';
  }
}
