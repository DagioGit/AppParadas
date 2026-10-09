import 'package:flutter/cupertino.dart';

import 'datos/lugares.dart';

/// Pestañas: 0 Viaje, 1 Paradas, 2 Rutas.
final CupertinoTabController pestanas = CupertinoTabController();

/// Cuando otra pantalla quiere planear un viaje hacia un lugar (por ejemplo, "Ir aquí" en una parada).
final ValueNotifier<Lugar?> destinoPedido = ValueNotifier<Lugar?>(null);

/// Sube de número cada vez que el buscador del mapa pide abrir "¿A dónde vas?".
final ValueNotifier<int> pedirBusqueda = ValueNotifier<int>(0);

/// true mientras la pestaña Viaje no haya abierto la búsqueda que se le pidió.
bool busquedaPendiente = false;

void irAViaje({Lugar? destino}) {
  pestanas.index = 0;
  if (destino != null) {
    destinoPedido.value = destino;
  } else {
    busquedaPendiente = true;
    pedirBusqueda.value++;
  }
}

/// Viaje que se abre al iniciar (en la versión web: ?tab=viaje&desde=gomez&hasta=lazaro).
Lugar? desdeInicial;
Lugar? hastaInicial;

/// Abrir el detalle de la opción más rápida al iniciar (?detalle=1).
bool detalleInicial = false;
