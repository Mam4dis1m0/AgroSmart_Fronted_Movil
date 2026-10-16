import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/demo/demo_data.dart';

/// Instancia global de sesión (login → selección de finca → app).
final session = Session();

/// ¿El usuario activo es administrador de la finca?
bool get esAdmin => session.rol == 'admin';

/// Estado de sesión (login → selección de finca → app).
class Session extends ChangeNotifier {
  Session() {
    Api.i.onUnauthorized = () {
      if (!logged || kDemoMode) return;
      aviso = 'Tu sesión expiró. Vuelve a iniciar sesión.';
      logout();
    };
  }

  Map<String, dynamic>? usuario;
  int? idfinca;
  List<Map<String, dynamic>> fincas = [];
  bool requiereSeleccionFinca = false;
  bool ready = false;

  /// Finca que estaba activa antes de abrir el selector (permite volver sin elegir).
  int? _fincaAnterior;

  /// Mensaje para mostrar en el login (p. ej. sesión expirada).
  String? aviso;

  bool get logged => Api.i.token != null;
  String get rol => (usuario?['role'] ?? '').toString();
  bool get esComprador => rol == 'comprador';
  bool get esEmpleado => rol == 'empleado';
  bool get necesitaFinca => logged && !esComprador && idfinca == null;
  bool get puedeVolverAFinca => _fincaAnterior != null;
  String get nombre => (usuario?['nombre'] ?? '').toString();
  String get nombreCompleto => '${usuario?['nombre'] ?? ''} ${usuario?['apellido'] ?? ''}'.trim();
  String? get foto {
    final f = usuario?['fotoperfil']?.toString();
    return f == null || f.isEmpty ? null : f;
  }

  Map<String, dynamic> get fincaActiva {
    for (final f in fincas) {
      if (f['idfinca'] == idfinca) return f;
    }
    return const {};
  }

  Future<void> restore() async {
    await Api.i.loadBaseUrl();
    // Modo demo: entra directo con el usuario/finca del prototipo (Carlos Mendoza).
    if (kDemoMode) {
      Api.i.token = 'demo-token';
      usuario = (demoLoginResponse()['usuario'] as Map).cast<String, dynamic>();
      idfinca = 1;
      fincas = demoFincas();
      Api.i.cacheScope = 'demo_1';
      ready = true;
      notifyListeners();
      return;
    }
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('session');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        Api.i.token = m['token'] as String?;
        usuario = (m['usuario'] as Map?)?.cast<String, dynamic>();
        idfinca = m['idfinca'] as int?;
        fincas = ((m['fincas'] as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
        Api.i.cacheScope = '${usuario?['id']}_$idfinca';
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    Api.i.cacheScope = '${usuario?['id']}_$idfinca';
    if (kDemoMode) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('session', jsonEncode({
      'token': Api.i.token, 'usuario': usuario, 'idfinca': idfinca, 'fincas': fincas,
    }));
  }

  Future<void> login(String email, String pass) async {
    final r = await Api.i.dio.post('/usuarios/login', data: {'email': email, 'contrasena': pass});
    await _aplicar(r.data as Map<String, dynamic>);
  }

  /// Login con Google: `credential` es el idToken (el backend lo valida con GOOGLE_CLIENT_ID).
  Future<void> loginGoogle(String credential) async {
    final r = await Api.i.dio.post('/usuarios/login-google', data: {'credential': credential});
    await _aplicar(r.data as Map<String, dynamic>);
  }

  Future<void> _aplicar(Map<String, dynamic> d) async {
    aviso = null;
    Api.i.token = d['token'] as String?;
    usuario = (d['usuario'] as Map).cast<String, dynamic>();
    idfinca = d['idfinca'] as int?;
    fincas = ((d['fincas'] as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    requiereSeleccionFinca = d['requiereSeleccionFinca'] == true;
    _fincaAnterior = null;
    // Con una sola finca el rol efectivo es el de esa finca.
    final activa = fincaActiva;
    if (activa['rol'] != null) usuario!['role'] = activa['rol'];
    await _save();
    notifyListeners();
  }

  /// CU-36: el backend devuelve un JWT nuevo ligado a la finca elegida.
  Future<void> seleccionarFinca(int id) async {
    final r = await Api.i.dio.post('/api/v1/fincas/$id/seleccionar');
    final d = r.data as Map<String, dynamic>;
    Api.i.token = d['token'] as String?;
    idfinca = id;
    _fincaAnterior = null;
    // El rol puede cambiar según la finca elegida (admin en una, empleado en otra).
    for (final f in fincas) {
      if (f['idfinca'] == id && usuario != null) usuario!['role'] = f['rol'];
    }
    await _save();
    notifyListeners();
  }

  /// CU-35: registra una finca; el backend la deja activa en el token devuelto.
  Future<void> crearFinca(Map<String, dynamic> data) async {
    final r = await Api.i.dio.post('/api/v1/fincas', data: data);
    final d = r.data is Map ? (r.data as Map).cast<String, dynamic>() : <String, dynamic>{};
    if (d['token'] != null) Api.i.token = d['token'] as String?;
    final f = d['finca'] is Map ? (d['finca'] as Map).cast<String, dynamic>() : null;
    final nuevo = (f?['idfinca'] ?? d['idfinca']) as int?;
    if (nuevo != null) {
      fincas = [...fincas, {'rol': 'admin', 'plan': 'FREEMIUM', ...?f, 'idfinca': nuevo, 'nombre': f?['nombre'] ?? data['nombre']}];
      idfinca = nuevo;
      _fincaAnterior = null;
      usuario?['role'] = 'admin';
      await _save();
      notifyListeners();
    } else {
      await logout(); // sin datos suficientes: que vuelva a entrar y elija finca
    }
  }

  /// Actualiza los datos de la finca activa en memoria (tras editarla).
  Future<void> actualizarFincaActiva(Map<String, dynamic> cambios) async {
    fincas = [
      for (final f in fincas) f['idfinca'] == idfinca ? {...f, ...cambios} : f,
    ];
    await _save();
    notifyListeners();
  }

  /// Actualiza datos del usuario en memoria y los persiste (perfil, foto).
  Future<void> actualizarUsuario(Map<String, dynamic> cambios) async {
    if (usuario == null) return;
    usuario = {...usuario!, ...cambios};
    await _save();
    notifyListeners();
  }

  /// Abre el selector de finca sin cerrar sesión.
  void cambiarFinca() {
    _fincaAnterior = idfinca;
    idfinca = null;
    notifyListeners();
  }

  /// Cierra el selector y vuelve a la finca que estaba activa (el token sigue siendo válido).
  void volverAFinca() {
    if (_fincaAnterior == null) return;
    idfinca = _fincaAnterior;
    _fincaAnterior = null;
    notifyListeners();
  }

  Future<void> logout() async {
    Api.i.token = null;
    usuario = null;
    idfinca = null;
    _fincaAnterior = null;
    fincas = [];
    final p = await SharedPreferences.getInstance();
    await p.remove('session');
    await Api.i.clearCache();
    notifyListeners();
  }
}
