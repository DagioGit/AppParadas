import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes de la app (pestaña Ajustes): tamaño de letra, botones grandes,
/// apariencia clara u oscura, etc. Se guardan en el teléfono.
class Ajustes extends ChangeNotifier {
  /// Tamaños de letra que se pueden elegir.
  static const tamanos = [0.9, 1.0, 1.15, 1.3, 1.45];
  static const nombresTamano = ['Chica', 'Normal', 'Grande', 'Muy grande', 'Enorme'];

  double letra = 1.15;
  bool negritas = false;
  bool botonesGrandes = false;
  bool contraste = false;
  bool vibrar = true;

  /// 0 = Automática (como el teléfono), 1 = Clara (de fábrica), 2 = Oscura.
  int apariencia = 1;

  int get nivelLetra {
    var mejor = 0;
    for (var i = 0; i < tamanos.length; i++) {
      if ((tamanos[i] - letra).abs() < (tamanos[mejor] - letra).abs()) mejor = i;
    }
    return mejor;
  }

  SharedPreferences? _prefs;

  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      letra = p.getDouble('letra') ?? letra;
      negritas = p.getBool('negritas') ?? negritas;
      botonesGrandes = p.getBool('botonesGrandes') ?? botonesGrandes;
      contraste = p.getBool('contraste') ?? contraste;
      vibrar = p.getBool('vibrar') ?? vibrar;
      apariencia = p.getInt('apariencia') ?? apariencia;
    } catch (_) {
      // Sin almacenamiento (pruebas, navegador privado): se usan los valores de fábrica.
    }
  }

  /// Cambia algo, avisa a la app para redibujarse y lo guarda.
  void cambiar(void Function(Ajustes a) cambio, {bool guardar = true}) {
    cambio(this);
    notifyListeners();
    if (guardar) _guardar();
  }

  void restablecer() => cambiar((a) {
        a.letra = 1.15;
        a.negritas = false;
        a.botonesGrandes = false;
        a.contraste = false;
        a.vibrar = true;
        a.apariencia = 1;
      });

  Future<void> _guardar() async {
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setDouble('letra', letra);
      await p.setBool('negritas', negritas);
      await p.setBool('botonesGrandes', botonesGrandes);
      await p.setBool('contraste', contraste);
      await p.setBool('vibrar', vibrar);
      await p.setInt('apariencia', apariencia);
    } catch (_) {}
  }
}

final ajustes = Ajustes();
