import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'datos/lugares.dart';
import 'estado.dart';
import 'pantallas/buscar_lugar.dart';
import 'pantallas/mapa_pantalla.dart';
import 'pantallas/paradas_pantalla.dart';
import 'pantallas/rutas_pantalla.dart';
import 'pantallas/viaje_pantalla.dart';
import 'tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const AppParadas());
}

class AppParadas extends StatelessWidget {
  const AppParadas({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'AppParadas',
      debugShowCheckedModeBanner: false,
      theme: Tema.cupertino,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Inicio(),
    );
  }
}

/// Lee ?tab=…&desde=…&hasta=… de la dirección (sólo pasa en la versión web).
void leerEnlace() {
  final q = Uri.base.queryParameters;
  Lugar? buscar(String? texto) {
    if (texto == null || texto.trim().isEmpty) return null;
    final t = normalizar(texto);
    for (final l in todosLosLugares()) {
      if (normalizar(l.nombre).contains(t)) return l;
    }
    return null;
  }

  desdeInicial = buscar(q['desde']);
  hastaInicial = buscar(q['hasta']);
  detalleInicial = q['detalle'] == '1';
  final tab = q['tab'];
  if (tab == 'viaje' || hastaInicial != null) pestanas.index = 1;
  if (tab == 'paradas') pestanas.index = 2;
  if (tab == 'rutas') pestanas.index = 3;
}

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  @override
  void initState() {
    super.initState();
    leerEnlace();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: pestanas,
      tabBar: CupertinoTabBar(
        activeColor: Tema.tinta,
        inactiveColor: Tema.grisClaro,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.near_me_rounded), label: 'Viaje'),
          BottomNavigationBarItem(icon: Icon(Icons.place_rounded), label: 'Paradas'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'Rutas'),
        ],
      ),
      tabBuilder: (context, i) {
        return CupertinoTabView(builder: (context) {
          switch (i) {
            case 0:
              return const MapaPantalla();
            case 1:
              return const ViajePantalla();
            case 2:
              return const ParadasPantalla();
            default:
              return const RutasPantalla();
          }
        });
      },
    );
  }
}
