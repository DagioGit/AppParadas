import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Centro de Lázaro Cárdenas y el área donde funcionan las rutas.
const LatLng centroLzc = LatLng(17.9660, -102.2080);

bool dentroDeLzc(LatLng p) =>
    p.latitude > 17.90 && p.latitude < 18.04 && p.longitude > -102.28 && p.longitude < -102.12;

class ResultadoUbicacion {
  final LatLng? punto;
  final String? problema;
  const ResultadoUbicacion(this.punto, this.problema);
}

/// Pide la ubicación del teléfono. Si no se puede, explica por qué en [problema].
Future<ResultadoUbicacion> obtenerUbicacion() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const ResultadoUbicacion(null, 'La ubicación del teléfono está apagada.');
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      return const ResultadoUbicacion(null, 'No diste permiso de ubicación.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 12));
    final p = LatLng(pos.latitude, pos.longitude);
    if (!dentroDeLzc(p)) {
      return ResultadoUbicacion(p, 'Estás fuera de Lázaro Cárdenas: elige en el mapa de dónde sales.');
    }
    return ResultadoUbicacion(p, null);
  } catch (_) {
    return const ResultadoUbicacion(null, 'No se pudo obtener tu ubicación.');
  }
}
