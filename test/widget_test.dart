import 'package:app_paradas/pantallas/buscar_lugar.dart';
import 'package:app_paradas/pantallas/rutas_pantalla.dart';
import 'package:app_paradas/tema.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => CupertinoApp(theme: Tema.cupertino, home: home);

void main() {
  setUp(() => Tema.usarFuenteWeb = false);

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
}
