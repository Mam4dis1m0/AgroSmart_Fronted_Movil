import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
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
  String get nombreCompleto =>
      '${usuario?['nombre'] ?? ''} ${usuario?['apellido'] ?? ''}'.trim();
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
    if (raw != null) _cargarGuardada(raw);
    ready = true;
    notifyListeners();
  }

  /// Carga una sesión guardada (token, usuario, finca) en memoria.
  bool _cargarGuardada(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      Api.i.token = m['token'] as String?;
      usuario = (m['usuario'] as Map?)?.cast<String, dynamic>();
      idfinca = m['idfinca'] as int?;
      fincas = ((m['fincas'] as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      Api.i.cacheScope = '${usuario?['id']}_$idfinca';
      return Api.i.token != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save() async {
    Api.i.cacheScope = '${usuario?['id']}_$idfinca';
    if (kDemoMode) return;
    final p = await SharedPreferences.getInstance();
    final json = jsonEncode({
      'token': Api.i.token,
      'usuario': usuario,
      'idfinca': idfinca,
      'fincas': fincas,
    });
    await p.setString('session', json);
    // Copia para poder volver a entrar sin internet después de cerrar sesión.
    await _actualizarSesionLocal(p, json);
  }

  // ---- Inicio de sesión sin internet -------------------------------------
  // Tras un login con contraseña y con internet se guarda, para esa cuenta, un hash salado
  // (5000 vueltas) de correo+contraseña y una copia de su sesión. Se guardan hasta
  // [_maxLocales] cuentas (las 2 más recientes). Sin red, si la contraseña coincide con una
  // de ellas, se reabre su sesión.

  static const _kLocales = 'logins_locales';
  static const _maxLocales = 2;

  String _hash(String email, String pass, String salt) {
    final base = utf8.encode('$salt|${email.trim().toLowerCase()}|$pass');
    var d = sha256.convert(base).bytes;
    for (var i = 0; i < 5000; i++) {
      d = sha256.convert([...d, ...base]).bytes;
    }
    return base64Encode(d);
  }

  List<Map<String, dynamic>> _leerLocales(SharedPreferences p) {
    final raw = p.getString(_kLocales);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _guardarLocales(
          SharedPreferences p, List<Map<String, dynamic>> l) =>
      p.setString(_kLocales, jsonEncode(l));

  Future<void> _guardarLocal(String email, String pass) async {
    final p = await SharedPreferences.getInstance();
    final em = email.trim().toLowerCase();
    final uid = usuario?['id'];
    final l = _leerLocales(p)
      ..removeWhere(
          (e) => e['email'] == em || (uid != null && e['uid'] == uid));
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    l.add({
      'email': em,
      'uid': uid,
      'nombre': nombreCompleto,
      'salt': salt,
      'hash': _hash(email, pass, salt),
      'session': p.getString('session'),
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    // Solo se conservan las 2 cuentas más recientes.
    l.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));
    await _guardarLocales(p, l.take(_maxLocales).toList());
    await p.remove('login_local'); // formato anterior (una sola cuenta)
    await p.remove('session_local');
  }

  /// Mantiene al día la copia de sesión de la cuenta actual (cambio de finca, etc.).
  Future<void> _actualizarSesionLocal(SharedPreferences p, String json) async {
    final uid = usuario?['id'];
    if (uid == null) return;
    final l = _leerLocales(p);
    final e = l.where((x) => x['uid'] == uid).toList();
    if (e.isEmpty) return;
    e.first['session'] = json;
    await _guardarLocales(p, l);
  }

  /// true si abrió la sesión guardada. Lanza un mensaje si la contraseña no coincide
  /// o si esa cuenta no ha iniciado sesión antes en este celular.
  Future<bool> _loginLocal(String email, String pass) async {
    final p = await SharedPreferences.getInstance();
    final l = _leerLocales(p);
    if (l.isEmpty) {
      throw 'Sin conexión a internet. La primera vez que inicias sesión en este celular necesitas conexión.';
    }
    final em = email.trim().toLowerCase();
    final cuentas = l.where((x) => x['email'] == em).toList();
    if (cuentas.isEmpty) {
      throw 'Sin conexión a internet. Sin red solo pueden entrar las cuentas que ya iniciaron sesión en este celular: ${l.map((x) => x['email']).join(' y ')}.';
    }
    final e = cuentas.first;
    if (_hash(email, pass, e['salt'] as String) != e['hash']) {
      throw 'Correo o contraseña incorrectos.';
    }
    final rawS = e['session'] as String?;
    if (rawS == null || !_cargarGuardada(rawS)) {
      throw 'No se pudo abrir la sesión guardada. Conéctate a internet para iniciar sesión.';
    }
    aviso = null;
    requiereSeleccionFinca = false;
    e['ts'] = DateTime.now().millisecondsSinceEpoch;
    await _guardarLocales(p, l);
    await p.setString('session', rawS);
    Api.i.offline.value = true;
    notifyListeners();
    return true;
  }

  Future<void> login(String email, String pass) async {
    // Connectivity no detecta rutas locales como adb reverse; intenta la API y
    // usa la sesión local solo si la conexión al servidor falla.
    try {
      final r = await Api.i.dio
          .post('/usuarios/login', data: {'email': email, 'contrasena': pass});
      await _aplicar(r.data as Map<String, dynamic>);
      if (!kDemoMode) await _guardarLocal(email, pass);
    } on DioException catch (e) {
      // Wi-Fi sin internet o servidor caído: se intenta con la cuenta guardada en el celular.
      final sinServidor =
          e.response == null && e.type != DioExceptionType.cancel;
      if (sinServidor && !kDemoMode && await _loginLocal(email, pass)) return;
      rethrow;
    }
  }

  /// Login con Google: `credential` es el idToken (el backend lo valida con GOOGLE_CLIENT_ID).
  Future<void> loginGoogle(String credential) async {
    final r = await Api.i.dio
        .post('/usuarios/login-google', data: {'credential': credential});
    await _aplicar(r.data as Map<String, dynamic>);
  }

  Future<void> _aplicar(Map<String, dynamic> d) async {
    aviso = null;
    Api.i.token = d['token'] as String?;
    usuario = (d['usuario'] as Map).cast<String, dynamic>();
    idfinca = d['idfinca'] as int?;
    fincas = ((d['fincas'] as List?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
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
    final d = r.data is Map
        ? (r.data as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    if (d['token'] != null) Api.i.token = d['token'] as String?;
    final f =
        d['finca'] is Map ? (d['finca'] as Map).cast<String, dynamic>() : null;
    final nuevo = (f?['idfinca'] ?? d['idfinca']) as int?;
    if (nuevo != null) {
      fincas = [
        ...fincas,
        {
          'rol': 'admin',
          'plan': 'FREEMIUM',
          ...?f,
          'idfinca': nuevo,
          'nombre': f?['nombre'] ?? data['nombre']
        }
      ];
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
    // Con login local guardado se conservan los datos (están separados por usuario y finca)
    // para que, al volver a entrar sin internet, la app no quede vacía.
    if (_leerLocales(p).isEmpty) await Api.i.clearCache();
    notifyListeners();
  }
}
