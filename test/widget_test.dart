import 'package:app_paradas/ajustes.dart';
import 'package:app_paradas/datos/lugares.dart';
import 'package:app_paradas/modelo/calles.dart';
import 'package:app_paradas/modelo/geo.dart';
import 'package:latlong2/latlong.dart';
import 'package:app_paradas/pantallas/ajustes_pantalla.dart';
import 'package:app_paradas/pantallas/buscar_lugar.dart';
import 'package:app_paradas/widgets/dictado.dart';
import 'package:app_paradas/pantallas/rutas_pantalla.dart';
import 'package:app_paradas/tema.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => CupertinoApp(theme: Tema.cupertino, home: home);

void main() {
  setUp(() {
    Tema.usarFuenteWeb = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('La lista de rutas muestra la Ruta 1 y la Ruta 2', (tester) async {
    await tester.pumpWidget(_app(const RutasPantalla()));
    await tester.pump();
    expect(find.text('Ruta 1 · Malecón'), findsOneWidget);
    expect(find.text('Ruta 2 · Pollo'), findsOneWidget);
  });

  testWidgets('El buscador encuentra la Gómez Sada sin acentos', (tester) async {
    await tester.pumpWidget(_app(const BuscarLugar(titulo: '¿A dónde vas?')));
    await tester.pump();
    await tester.enterText(find.byType(CupertinoSearchTextField), 'gomez sada');
    await tester.pump();
    expect(find.text('Napoleón Gómez Sada'), findsOneWidget);
  });

  testWidgets('Ajustes cambia el tamaño de letra y las negritas', (tester) async {
    await tester.pumpWidget(_app(const AjustesPantalla()));
    await tester.pump();
    expect(find.text('Tamaño de letra'), findsOneWidget);
    final antes = Tema.texto().fontSize!;
    ajustes.cambiar((a) => a.letra = Ajustes.tamanos.last);
    expect(Tema.texto().fontSize!, greaterThan(antes));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Letra gruesa'), 200);
    await tester.pump();
    await tester.tap(find.text('Letra gruesa'));
    await tester.pump();
    expect(ajustes.negritas, isTrue);
    ajustes.restablecer();
  });

  test('El buscador encuentra avenidas y calles de Lázaro Cárdenas como en los mapas', () {
    final todos = todosLosLugares();
    expect(buscarLugares(todos, 'av lazaro').first.nombre, 'Av. Lázaro Cárdenas');
    expect(buscarLugares(todos, 'avenida lázaro cárdenas').first.nombre, 'Av. Lázaro Cárdenas');
    expect(buscarLugares(todos, 'mina').any((l) => l.nombre.contains('Mina')), isTrue);
    expect(todos.where((l) => l.tipo == TipoLugar.avenida).length, greaterThan(500));
  });

  test('Entiende a dónde quiere ir la persona cuando lo dice', () {
    expect(entenderDestino('Quiero ir al malecón'), (null, 'malecón'));
    expect(entenderDestino('¿Cómo llego a la Plaza Las Américas, por favor?'), (null, 'plaza las américas'));
    expect(entenderDestino('de la Gómez Sada al centro'), ('gómez sada', 'centro'));
    expect(entenderDestino('Llévame al monumento a Lázaro Cárdenas').$2, 'monumento a lázaro cárdenas');
  });

  test('Los recorridos a pie van por las calles, no en línea recta', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await GrafoCalles.cargar();
    final g = GrafoCalles.instancia;
    expect(g, isNotNull);
    const a = LatLng(17.9727, -102.2163), b = LatLng(17.96237, -102.19884);
    final c = g!.ruta(a, b)!;
    expect(c.puntos.length, greaterThan(10));
    expect(c.metros, greaterThan(distanciaM(a, b)));
    expect(c.indicaciones.any((i) => i.calle.contains('Lázaro Cárdenas')), isTrue);
  });
}
