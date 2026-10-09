import 'package:app_paradas/modelo/planificador.dart';
import 'package:app_paradas/modelo/ruta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const gomezSada = LatLng(17.9818, -102.2271);
  const avLazaroCardenas = LatLng(17.9612, -102.1979);
  const tec = LatLng(17.9737, -102.2330);
  const malecon = LatLng(17.9456, -102.1883);

  test('Hay cinco rutas y la 1 es gris y la 2 amarilla', () {
    expect(rutas.length, 5);
    expect(rutaPorId('R1').color.toARGB32(), 0xFF6E6E73);
    expect(rutaPorId('R2').color.toARGB32(), 0xFFF2C200);
    for (final r in rutas) {
      expect(r.paradas, isNotEmpty);
      expect(r.trazo.largo, greaterThan(5000));
    }
  });

  test('La próxima combi nunca llega antes de ahora', () {
    final r = rutaPorId('R1');
    for (final t in [0.0, 6 * 3600.0, 14 * 3600.0 + 123, 21.9 * 3600, 23 * 3600.0]) {
      for (final p in r.paradas) {
        final l = r.proximasLlegadas(p, t, n: 3);
        expect(l.length, 3);
        expect(l.first, greaterThanOrEqualTo(t));
        expect(l[1], greaterThan(l[0]));
      }
    }
  });

  test('De la Gómez Sada a la Av. Lázaro Cárdenas hay al menos 3 opciones y la primera es la más rápida', () {
    final ops = Planificador().planear(gomezSada, avLazaroCardenas, ahora: 14 * 3600);
    final combis = ops.where((o) => !o.soloAPie).toList();
    expect(combis.length, greaterThanOrEqualTo(3));
    expect(ops.first.masRapida, isTrue);
    expect(ops.where((o) => o.masRapida).length, 1);
    for (var i = 1; i < ops.length; i++) {
      expect(ops[i].llegada, greaterThanOrEqualTo(ops[i - 1].llegada));
    }
    // Firmas distintas: cada opción usa otra combinación de combis.
    expect(combis.map((o) => o.firma).toSet().length, combis.length);
  });

  test('Del Tecnológico al malecón sale al menos una opción con la Ruta 1 o la 5', () {
    final ops = Planificador().planear(tec, malecon, ahora: 9 * 3600);
    expect(ops.length, greaterThanOrEqualTo(3));
    expect(ops.any((o) => o.firma.contains('R1') || o.firma.contains('R5')), isTrue);
  });

  test('Los tramos van en orden de tiempo', () {
    final ops = Planificador().planear(tec, avLazaroCardenas, ahora: 10 * 3600);
    for (final o in ops) {
      for (var i = 1; i < o.tramos.length; i++) {
        expect(o.tramos[i].inicio, greaterThanOrEqualTo(o.tramos[i - 1].fin - 0.001));
      }
    }
  });

  test('La Ruta 1 pasa dos veces por el semáforo del hospital y una por el del entronque', () {
    final r = rutaPorId('R1');
    expect(r.semaforosEnRuta.length, 2);
    final hospital = r.pausas.where((p) => p.semaforo != null && p.semaforo!.nombre.contains('Hospital')).length;
    expect(hospital, 2);
    expect(r.pausas.where((p) => p.semaforo != null).length, greaterThanOrEqualTo(3));
  });

  test('Las combis avanzan sobre el recorrido y hay combis en servicio a las 14:00', () {
    final r = rutaPorId('R1');
    var antes = -1.0;
    for (var e = 0.0; e <= r.duracion; e += 7) {
      final m = r.metrosA(e);
      expect(m, greaterThanOrEqualTo(antes));
      antes = m;
    }
    expect(r.metrosA(r.duracion), closeTo(r.trazo.largo, 0.5));
    expect(r.combisEn(14 * 3600).length, greaterThan(0));
    expect(r.combisEn(3 * 3600), isEmpty);
  });

  test('En hora pico la vuelta tarda más y las combis pasan más seguido', () {
    final r = rutaPorId('R1');
    final pico = r.vuelta(r.salidas.indexWhere((s) => s >= 7.4 * 3600));
    final calma = r.vuelta(r.salidas.indexWhere((s) => s >= 11 * 3600));
    expect(pico.duracion, greaterThan(calma.duracion));
    expect(r.frecuenciaA(7.6 * 3600), lessThan(r.frecuenciaA(11 * 3600)));
  });

  test('La combi frena en cada parada, espera y vuelve a arrancar', () {
    final r = rutaPorId('R1');
    final v = r.vuelta(20);
    final p = r.paradas[2];
    final e = v.llegadas[p.indice] + 2;
    expect(identical(v.pausaA(e)?.parada, p), isTrue);
    expect(v.metrosA(e), closeTo(p.metros, 0.5));
    expect(v.kmhA(v.llegadas[p.indice] - 1), lessThan(15)); // va frenando
    var antes = -1.0;
    for (var t = 0.0; t <= v.duracion; t += 3) {
      final m = v.metrosA(t);
      expect(m, greaterThanOrEqualTo(antes - 0.001));
      antes = m;
    }
  });

  test('La llegada que se muestra corresponde a una combi real del horario', () {
    final r = rutaPorId('R1');
    final p = r.paradas[4];
    final llega = r.proximaLlegada(p, 15 * 3600);
    final pas = r.pasadaDe(p, llega);
    expect(pas.salida + pas.vuelta.llegadas[p.indice], closeTo(llega, 0.01));
  });
}
