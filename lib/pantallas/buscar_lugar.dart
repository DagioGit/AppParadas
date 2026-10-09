import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../datos/calles_osm.dart';
import '../datos/lugares.dart';
import '../modelo/ruta.dart';
import '../modelo/ubicacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';

String normalizar(String s) {
  const de = 'áéíóúüñÁÉÍÓÚÜÑ';
  const a = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString().toLowerCase().replaceAll('.', '').trim();
}

/// Clave para comparar nombres: sin acentos, en minúsculas y con las abreviaturas escritas completas
/// ("Av. Lázaro Cárdenas" = "Avenida Lazaro Cardenas").
String clave(String s) {
  var t = ' ${normalizar(s).replaceAll(',', ' ')} ';
  const abrev = {' av ': ' avenida ', ' blvd ': ' boulevard ', ' bulevar ': ' boulevard ', ' prol ': ' prolongacion ',
    ' col ': ' colonia ', ' calz ': ' calzada ', ' fracc ': ' fraccionamiento ', ' gral ': ' general '};
  abrev.forEach((a, b) => t = t.replaceAll(a, b));
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<Lugar>? _cacheLugares;

/// Lugares del catálogo, las paradas con nombre propio de todas las rutas y todas las calles,
/// avenidas y colonias de Lázaro Cárdenas (OpenStreetMap), sin repetir.
List<Lugar> todosLosLugares() => _cacheLugares ??= _juntarLugares();

List<Lugar> _juntarLugares() {
  final l = <Lugar>[...lugares];
  final vistos = <String>{for (final x in lugares) clave(x.nombre)};
  for (final r in rutas) {
    for (final p in r.paradas.where((p) => p.principal)) {
      final nombre = p.nombre.replaceAll(' (regreso)', '');
      final clave = normalizar(nombre);
      if (vistos.add(clave)) {
        l.add(Lugar(nombre, 'Parada · ${r.nombre}', TipoLugar.parada, p.punto));
      }
    }
  }
  for (final x in [...coloniasOsm, ...callesOsm]) {
    if (vistos.add(clave(x.nombre))) l.add(x);
  }
  return l;
}

/// Qué tan bien coincide [l] con lo que se escribió (más chico = mejor; null = no coincide).
/// Como en los mapas: cada palabra escrita tiene que ser el principio de alguna palabra del lugar.
int? puntaje(Lugar l, List<String> palabras, String completo) {
  final n = clave(l.nombre);
  final d = clave(l.detalle);
  final pn = n.split(' ');
  final pd = d.split(' ');
  var enDetalle = 0;
  for (final w in palabras) {
    if (pn.any((x) => x.startsWith(w))) continue;
    if (pd.any((x) => x.startsWith(w))) {
      enDetalle++;
      continue;
    }
    return null;
  }
  var p = 0;
  if (n == completo) {
    p = 0;
  } else if (n.startsWith(completo)) {
    p = 10;
  } else if (n.contains(' $completo')) {
    p = 20;
  } else {
    p = 30;
  }
  p += enDetalle * 15;
  // Lugares importantes y avenidas primero; calles y colonias después
  const orden = {
    TipoLugar.lugar: 0, TipoLugar.parada: 1, TipoLugar.escuela: 1, TipoLugar.salud: 1, TipoLugar.compras: 1,
    TipoLugar.colonia: 3, TipoLugar.avenida: 2, TipoLugar.ubicacion: 0, TipoLugar.mapa: 0,
  };
  p += orden[l.tipo] ?? 2;
  if (l.tipo == TipoLugar.avenida && !l.detalle.startsWith('Avenida') && !l.detalle.startsWith('Bulevar') && l.detalle.contains('·')) p += 2;
  return p;
}

/// Busca como en los mapas: sin acentos, en cualquier orden de palabras y lo más parecido primero.
List<Lugar> buscarLugares(List<Lugar> todos, String texto, {int maximo = 40}) {
  final completo = clave(texto);
  if (completo.isEmpty) return const [];
  final palabras = completo.split(' ').where((w) => w.isNotEmpty).toList();
  final r = <(Lugar, int)>[];
  for (final l in todos) {
    final p = puntaje(l, palabras, completo);
    if (p != null) r.add((l, p));
  }
  r.sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.nombre.length.compareTo(b.$1.nombre.length));
  return [for (final x in r.take(maximo)) x.$1];
}

IconData iconoLugar(TipoLugar t) {
  switch (t) {
    case TipoLugar.avenida:
      return Icons.directions_rounded;
    case TipoLugar.colonia:
      return Icons.home_rounded;
    case TipoLugar.escuela:
      return Icons.school_rounded;
    case TipoLugar.salud:
      return Icons.local_hospital_rounded;
    case TipoLugar.compras:
      return Icons.shopping_bag_rounded;
    case TipoLugar.parada:
      return Icons.directions_bus_rounded;
    case TipoLugar.ubicacion:
      return Icons.near_me_rounded;
    case TipoLugar.mapa:
      return Icons.place_rounded;
    case TipoLugar.lugar:
      return Icons.star_rounded;
  }
}

Color colorLugar(TipoLugar t) {
  switch (t) {
    case TipoLugar.avenida:
      return const Color(0xFF8E8E93);
    case TipoLugar.colonia:
      return const Color(0xFFFF9500);
    case TipoLugar.escuela:
      return const Color(0xFF5856D6);
    case TipoLugar.salud:
      return const Color(0xFFFF3B30);
    case TipoLugar.compras:
      return const Color(0xFFFF2D55);
    case TipoLugar.parada:
      return const Color(0xFFC99F00);
    case TipoLugar.ubicacion:
      return Tema.azul;
    case TipoLugar.mapa:
      return const Color(0xFF34C759);
    case TipoLugar.lugar:
      return const Color(0xFF30B0C7);
  }
}

class IconoLugar extends StatelessWidget {
  final TipoLugar tipo;
  const IconoLugar(this.tipo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: colorLugar(tipo), shape: BoxShape.circle),
      child: Icon(iconoLugar(tipo), color: const Color(0xFFFFFFFF), size: 19),
    );
  }
}

class BuscarLugar extends StatefulWidget {
  final String titulo;
  final bool permitirUbicacion;
  const BuscarLugar({super.key, required this.titulo, this.permitirUbicacion = true});

  @override
  State<BuscarLugar> createState() => _BuscarLugarState();
}

class _BuscarLugarState extends State<BuscarLugar> {
  final _todos = todosLosLugares();
  String _q = '';
  bool _buscandoUbicacion = false;
  String? _problema;

  static const _sugeridos = [
    'Av. Lázaro Cárdenas',
    'Malecón de la Cultura y las Artes',
    'Napoleón Gómez Sada',
    'Centro',
    'Plaza Las Américas',
    'Instituto Tecnológico de Lázaro Cárdenas',
  ];

  Future<void> _miUbicacion() async {
    setState(() {
      _buscandoUbicacion = true;
      _problema = null;
    });
    final r = await obtenerUbicacion();
    if (!mounted) return;
    setState(() => _buscandoUbicacion = false);
    if (r.punto != null && r.problema == null) {
      Navigator.of(context).pop(Lugar('Mi ubicación', 'Donde estás ahora', TipoLugar.ubicacion, r.punto!));
    } else {
      setState(() => _problema = r.problema);
    }
  }

  Future<void> _enMapa() async {
    final lugar = await Navigator.of(context).push<Lugar>(
      CupertinoPageRoute(builder: (_) => const ElegirEnMapa()),
    );
    if (lugar != null && mounted) Navigator.of(context).pop(lugar);
  }

  Widget _fila(Lugar l) {
    return CupertinoListTile(
      leading: IconoLugar(l.tipo),
      leadingSize: 34,
      title: Text(l.nombre, style: Tema.texto(size: 17, weight: FontWeight.w600)),
      subtitle: Text(l.detalle, style: Tema.chico, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.of(context).pop(l),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = normalizar(_q);
    final resultados = q.isEmpty ? <Lugar>[] : buscarLugares(_todos, _q);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.titulo)),
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: CupertinoSearchTextField(
              autofocus: true,
              placeholder: 'Calle, avenida, colonia o lugar',
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView(children: [
              if (q.isEmpty)
                CupertinoListSection.insetGrouped(children: [
                  if (widget.permitirUbicacion)
                    CupertinoListTile(
                      leading: const IconoLugar(TipoLugar.ubicacion),
                      leadingSize: 34,
                      title: Text('Mi ubicación', style: Tema.texto(size: 16, weight: FontWeight.w500)),
                      subtitle: _problema != null ? Text(_problema!, style: Tema.chico) : null,
                      trailing: _buscandoUbicacion ? const CupertinoActivityIndicator() : null,
                      onTap: _miUbicacion,
                    ),
                  CupertinoListTile(
                    leading: const IconoLugar(TipoLugar.mapa),
                    leadingSize: 34,
                    title: Text('Elegir en el mapa', style: Tema.texto(size: 16, weight: FontWeight.w500)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _enMapa,
                  ),
                ]),
              if (q.isEmpty)
                CupertinoListSection.insetGrouped(
                  header: Text('SUGERENCIAS', style: Tema.etiqueta),
                  children: [
                    for (final n in _sugeridos) _fila(_todos.firstWhere((l) => l.nombre == n)),
                  ],
                ),
              if (q.isNotEmpty && resultados.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No encontramos "$_q". Prueba con otra palabra o elige el punto en el mapa.',
                    textAlign: TextAlign.center,
                    style: Tema.subtitulo,
                  ),
                ),
              if (resultados.isNotEmpty)
                CupertinoListSection.insetGrouped(children: [for (final l in resultados) _fila(l)]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Mapa con un alfiler fijo al centro: se mueve el mapa y se toca "Usar este punto".
class ElegirEnMapa extends StatefulWidget {
  const ElegirEnMapa({super.key});

  @override
  State<ElegirEnMapa> createState() => _ElegirEnMapaState();
}

class _ElegirEnMapaState extends State<ElegirEnMapa> {
  final _mapa = MapController();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Elegir en el mapa')),
      child: Stack(children: [
        FlutterMap(
          mapController: _mapa,
          options: MapOptions(
            initialCenter: centroLzc,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            capaTeselas(),
            PolylineLayer(polylines: [
              for (final r in rutas) lineaRuta(r.trazo.puntos, r.color, ancho: 3, tenue: true),
            ]),
          ],
        ),
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on_rounded, size: 48, color: Color(0xFFFF3B30)),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          child: CupertinoButton(
            color: Tema.azul,
            borderRadius: BorderRadius.circular(14),
            onPressed: () {
              final LatLng c = _mapa.camera.center;
              Navigator.of(context).pop(Lugar('Punto en el mapa', '${c.latitude.toStringAsFixed(4)}, ${c.longitude.toStringAsFixed(4)}', TipoLugar.mapa, c));
            },
            child: Text('Usar este punto', style: Tema.texto(weight: FontWeight.w600, color: const Color(0xFFFFFFFF))),
          ),
        ),
      ]),
    );
  }
}
