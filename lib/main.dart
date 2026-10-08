import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'estado.dart';
import 'pantallas/mapa_pantalla.dart';
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

class Inicio extends StatelessWidget {
  const Inicio({super.key});

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
            default:
              return const RutasPantalla();
          }
        });
      },
    );
  }
}
