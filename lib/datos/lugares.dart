// Lugares para buscar origen y destino. Coordenadas de OpenStreetMap.

import 'package:latlong2/latlong.dart';

enum TipoLugar { avenida, colonia, lugar, escuela, salud, compras, parada, ubicacion, mapa }

class Lugar {
  final String nombre;
  final String detalle;
  final TipoLugar tipo;
  final LatLng punto;

  const Lugar(this.nombre, this.detalle, this.tipo, this.punto);
}

const List<Lugar> lugares = [
  // Avenidas: el punto es un tramo céntrico de la avenida.
  Lugar('Av. Lázaro Cárdenas', 'Avenida · Centro', TipoLugar.avenida, LatLng(17.9612, -102.1979)),
  Lugar('Av. Melchor Ocampo', 'Avenida', TipoLugar.avenida, LatLng(17.9718, -102.2245)),
  Lugar('Av. Autonomía Universitaria', 'Avenida', TipoLugar.avenida, LatLng(17.9681, -102.2097)),
  Lugar('Prol. Tulipanes', 'Avenida', TipoLugar.avenida, LatLng(17.9705, -102.2093)),
  Lugar('Av. Las Palmas', 'Avenida', TipoLugar.avenida, LatLng(17.9760, -102.2097)),
  Lugar('Av. Belisario Domínguez', 'Avenida', TipoLugar.avenida, LatLng(17.9768, -102.2155)),
  Lugar('Libramiento a Sicartsa', 'Avenida', TipoLugar.avenida, LatLng(17.9640, -102.2300)),
  Lugar('Av. Río Balsas', 'Avenida', TipoLugar.avenida, LatLng(17.9655, -102.1990)),
  // Lugares importantes
  Lugar('Malecón de la Cultura y las Artes', 'Av. Lázaro Cárdenas', TipoLugar.lugar, LatLng(17.9456, -102.1883)),
  Lugar('Malecón del Río Balsas', 'Andador junto al río', TipoLugar.lugar, LatLng(17.9660, -102.1915)),
  Lugar('Palacio Municipal', 'Centro', TipoLugar.lugar, LatLng(17.9623, -102.1978)),
  Lugar('Monumento a Lázaro Cárdenas', 'Centro', TipoLugar.lugar, LatLng(17.9604, -102.1964)),
  Lugar('Kiosko del Centro', 'Centro', TipoLugar.lugar, LatLng(17.9552, -102.1912)),
  Lugar('Plaza Voluntad de Acero', 'Av. Lázaro Cárdenas', TipoLugar.lugar, LatLng(17.9509, -102.1923)),
  Lugar('Teatro APILAC', 'Av. Lázaro Cárdenas', TipoLugar.lugar, LatLng(17.9411, -102.1878)),
  Lugar('Parque Tierra Caliente', 'Centro', TipoLugar.lugar, LatLng(17.9645, -102.1956)),
  Lugar('Unidad Deportiva Lázaro Cárdenas', 'Deporte', TipoLugar.lugar, LatLng(17.9562, -102.1996)),
  Lugar('Central Estrella de Oro', 'Autobuses foráneos', TipoLugar.lugar, LatLng(17.9561, -102.1978)),
  Lugar('Parque Erandeni', 'Parque', TipoLugar.lugar, LatLng(17.9623, -102.2023)),
  // Escuelas
  Lugar('Instituto Tecnológico de Lázaro Cárdenas', 'Av. Melchor Ocampo', TipoLugar.escuela, LatLng(17.9737, -102.2330)),
  Lugar('Tec de Monterrey', 'Campus Lázaro Cárdenas', TipoLugar.escuela, LatLng(17.9613, -102.2037)),
  Lugar('UMSNH Campus Lázaro Cárdenas', 'Universidad Michoacana', TipoLugar.escuela, LatLng(17.9850, -102.2052)),
  Lugar('UNIDEP', 'Universidad', TipoLugar.escuela, LatLng(17.9912, -102.2211)),
  Lugar('Heroica Escuela Naval Militar', 'Av. Lázaro Cárdenas', TipoLugar.escuela, LatLng(17.9513, -102.1893)),
  Lugar('Secundaria Técnica 12', 'Centro', TipoLugar.escuela, LatLng(17.9599, -102.1977)),
  // Salud
  Lugar('Hospital General', 'Av. Lázaro Cárdenas', TipoLugar.salud, LatLng(17.9676, -102.2015)),
  Lugar('Hospital IMSS', 'Centro', TipoLugar.salud, LatLng(17.9641, -102.1994)),
  Lugar('IMSS UMF 78', 'Av. Melchor Ocampo', TipoLugar.salud, LatLng(17.9736, -102.2246)),
  Lugar('Hospital Naval', 'Prol. Tulipanes', TipoLugar.salud, LatLng(17.9724, -102.2127)),
  Lugar('ISSSTE Ricardo Flores Magón', 'Salud', TipoLugar.salud, LatLng(17.9600, -102.2049)),
  Lugar('Clínica Fátima', 'Av. Melchor Ocampo', TipoLugar.salud, LatLng(17.9719, -102.2235)),
  // Compras
  Lugar('Plaza Las Américas', 'Liverpool · Walmart', TipoLugar.compras, LatLng(17.9781, -102.2130)),
  Lugar('Soriana Mercado', 'Prol. Tulipanes', TipoLugar.compras, LatLng(17.9700, -102.2112)),
  Lugar('Mercado Hidalgo', 'Centro', TipoLugar.compras, LatLng(17.9630, -102.1948)),
  Lugar('Mercado Cuauhtémoc', 'Centro', TipoLugar.compras, LatLng(17.9592, -102.1919)),
  Lugar('Plaza Zirahuén', 'Centro', TipoLugar.compras, LatLng(17.9598, -102.1962)),
  Lugar('Bodega Aurrera', 'Av. Melchor Ocampo', TipoLugar.compras, LatLng(17.9624, -102.2038)),
  Lugar('Plaza Las Torres', 'Fidelac', TipoLugar.compras, LatLng(17.9656, -102.2136)),
  // Colonias
  Lugar('Napoleón Gómez Sada', 'Colonia', TipoLugar.colonia, LatLng(17.9818, -102.2271)),
  Lugar('Centro', 'Colonia', TipoLugar.colonia, LatLng(17.9570, -102.1933)),
  Lugar('1o de Mayo', 'Colonia', TipoLugar.colonia, LatLng(17.9918, -102.2281)),
  Lugar('Benito Juárez', 'Colonia', TipoLugar.colonia, LatLng(17.9771, -102.2371)),
  Lugar('Valle del Tecnológico', 'Colonia', TipoLugar.colonia, LatLng(17.9772, -102.2277)),
  Lugar('Villa del Tecnológico', 'Colonia', TipoLugar.colonia, LatLng(17.9752, -102.2368)),
  Lugar('Las Américas', 'Fraccionamiento', TipoLugar.colonia, LatLng(17.9862, -102.2127)),
  Lugar('Santa Rosa', 'Colonia', TipoLugar.colonia, LatLng(17.9853, -102.2177)),
  Lugar('Lucio Cabañas', 'Colonia', TipoLugar.colonia, LatLng(17.9838, -102.2243)),
  Lugar('Luis Donaldo Colosio', 'Colonia', TipoLugar.colonia, LatLng(17.9847, -102.2270)),
  Lugar('Villa Hermosa', 'Colonia', TipoLugar.colonia, LatLng(17.9865, -102.2306)),
  Lugar('FOVISSSTE', 'Colonia', TipoLugar.colonia, LatLng(17.9760, -102.2192)),
  Lugar('Las Palmas', 'Colonia', TipoLugar.colonia, LatLng(17.9706, -102.2208)),
  Lugar('Jarene', 'Colonia', TipoLugar.colonia, LatLng(17.9673, -102.2218)),
  Lugar('Independencia', 'Colonia', TipoLugar.colonia, LatLng(17.9603, -102.2209)),
  Lugar('Fidelac', 'Colonia (2do Sector)', TipoLugar.colonia, LatLng(17.9638, -102.2080)),
  Lugar('INFONAVIT Las Colinas', 'Colonia', TipoLugar.colonia, LatLng(17.9696, -102.2140)),
  Lugar('Lotes y Servicios', 'Colonia', TipoLugar.colonia, LatLng(17.9586, -102.2119)),
  Lugar('Ejidal', 'Colonia', TipoLugar.colonia, LatLng(17.9591, -102.2030)),
  Lugar('La Corregidora', 'Colonia', TipoLugar.colonia, LatLng(17.9541, -102.2095)),
  Lugar('Sector Pesquero', 'Colonia', TipoLugar.colonia, LatLng(17.9560, -102.1882)),
  Lugar('Río Balsas', 'Colonia', TipoLugar.colonia, LatLng(17.9718, -102.2005)),
];
