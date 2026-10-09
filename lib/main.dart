import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ajustes.dart';
import 'datos/lugares.dart';
import 'estado.dart';
import 'modelo/ruta.dart';
import 'pantallas/ajustes_pantalla.dart';
import 'pantallas/buscar_lugar.dart';
import 'pantallas/parada_3d.dart';
import 'pantallas/paradas_pantalla.dart';
import 'pantallas/rutas_pantalla.dart';
import 'pantallas/viaje_pantalla.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ajustes.cargar();
  // Para revisar el diseño desde la web: ?tema=oscuro, ?letra=1.45, ?botones=grandes
  final q = Uri.base.queryParameters;
  if (q['tema'] == 'oscuro') ajustes.apariencia = 2;
  if (q['tema'] == 'claro') ajustes.apariencia = 1;
  final letra = double.tryParse(q['letra'] ?? '');
  if (letra != null) ajustes.letra = letra;
  if (q['botones'] == 'grandes') ajustes.botonesGrandes = true;
  if (q['modovoz'] == '1') ajustes.modoVoz = true;
  // ?hora=22.5 simula que son las 22:30 (para ver cómo se ve la app de noche)
  final h = double.tryParse(q['hora'] ?? '');
  if (h != null) ajustes.ajusteHora = h * 3600 - segundosAhora();
  runApp(const CombiLZC());
}

class CombiLZC extends StatefulWidget {
  const CombiLZC({super.key});

  @override
  State<CombiLZC> createState() => _CombiLZCState();
}

class _CombiLZCState extends State<CombiLZC> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ajustes.addListener(_alCambiar);
    _aplicar();
  }

  @override
  void dispose() {
    ajustes.removeListener(_alCambiar);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _alCambiar();

  /// Decide si va en modo oscuro y ajusta la barra de estado del teléfono.
  void _aplicar() {
    final sistema = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    Tema.oscuro = ajustes.apariencia == 2 || (ajustes.apariencia == 0 && sistema == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(Tema.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
  }

  /// Los colores y letras se leen al dibujar, así que se vuelve a dibujar todo.
  void _alCambiar() {
    if (!mounted) return;
    setState(_aplicar);
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    (context as Element).visitChildren(marcar);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'CombiLZC',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _ArrastreConMouse(),
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
  guiaInicial = q['guia'] == '1';
  hastaInicial ??= buscar(q['hacia']);
  final tab = q['tab'];
  if (tab == 'paradas') pestanas.index = 1;
  if (tab == 'rutas') pestanas.index = 2;
  if (tab == 'ajustes') pestanas.index = 3;
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
    // ?parada3d=R1-4i abre directo la vista 3D de esa parada
    final id = Uri.base.queryParameters['parada3d'];
    if (id != null) {
      for (final r in rutas) {
        for (final p in r.paradas) {
          if (p.id == id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => Parada3D(parada: p)));
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: pestanas,
      tabBar: CupertinoTabBar(
        activeColor: Tema.azul,
        inactiveColor: Tema.gris,
        backgroundColor: Tema.oscuro ? const Color(0xF0161618) : const Color(0xF0F9F9F9),
        iconSize: Tema.b(30).clamp(30.0, 38.0),
        height: Tema.b(50).clamp(50.0, 60.0),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.near_me_rounded), label: 'Viaje'),
          BottomNavigationBarItem(icon: Icon(Icons.place_rounded), label: 'Paradas'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'Rutas'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear_alt_fill), label: 'Ajustes'),
        ],
      ),
      tabBuilder: (context, i) {
        return CupertinoTabView(builder: (context) {
          switch (i) {
            case 0:
              return const ViajePantalla();
            case 1:
              return const ParadasPantalla();
            case 2:
              return const RutasPantalla();
            default:
              return const AjustesPantalla();
          }
        });
      },
    );
  }
}

/// En la computadora también se puede arrastrar con el mouse o el trackpad (listas y paneles).
class _ArrastreConMouse extends CupertinoScrollBehavior {
  const _ArrastreConMouse();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
