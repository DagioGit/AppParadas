// Estructuras de los datos fijos de cada ruta (ver rutas_datos.dart).

class ParadaDatos {
  final String id;
  final String nombre;

  /// Calle o sentido en que la combi pasa por la parada.
  final String sentido;
  final String descripcion;
  final double lat;
  final double lng;

  /// Distancia en metros desde el inicio del recorrido.
  final int metros;

  const ParadaDatos({
    required this.id,
    required this.nombre,
    required this.sentido,
    required this.descripcion,
    required this.lat,
    required this.lng,
    required this.metros,
  });
}

class RutaDatos {
  final String id;
  final int numero;
  final String nombre;
  final String apodo;
  final int color;

  /// true si la ruta es inventada para probar el buscador.
  final bool simulada;
  final String descripcion;
  final int frecuenciaMin;
  final int velocidadKmh;

  /// Recorrido cerrado [lat, lng]: el último punto es igual al primero.
  final List<List<double>> trazo;
  final List<ParadaDatos> paradas;

  const RutaDatos({
    required this.id,
    required this.numero,
    required this.nombre,
    required this.apodo,
    required this.color,
    required this.simulada,
    required this.descripcion,
    required this.frecuenciaMin,
    required this.velocidadKmh,
    required this.trazo,
    required this.paradas,
  });
}
