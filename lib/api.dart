import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// URL del backend. Prioridad: --dart-define=API_URL > la guardada en la app > local por defecto.
const _envUrl = String.fromEnvironment('API_URL');

String defaultBaseUrl() {
  if (_envUrl.isNotEmpty) return _envUrl;
  if (kIsWeb) return 'http://localhost:3000';
  // En el emulador Android, "localhost" es el propio emulador; 10.0.2.2 es tu PC.
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}

/// Cliente HTTP único. La app NUNCA habla con la base de datos: todo pasa por la API.
class Api {
  Api._() {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
      h.next(o);
    }));
  }
  static final Api i = Api._();

  final Dio dio = Dio(BaseOptions(
    baseUrl: defaultBaseUrl(),
    // Render (plan gratis) tarda en "despertar": damos margen.
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  ));

  String? token;

  String get baseUrl => dio.options.baseUrl;

  /// Carga la URL guardada (si el usuario la cambió desde la app).
  Future<void> loadBaseUrl() async {
    if (_envUrl.isNotEmpty) return; // --dart-define manda
    final p = await SharedPreferences.getInstance();
    final u = p.getString('api_url');
    if (u != null && u.isNotEmpty) dio.options.baseUrl = u;
  }

  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    dio.options.baseUrl = u;
    final p = await SharedPreferences.getInstance();
    await p.setString('api_url', u);
  }

  /// true si el servidor responde algo (aunque sea 404): hay conexión.
  Future<bool> ping() async {
    try {
      await dio.get('/api-json',
          options: Options(
            validateStatus: (_) => true,
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ));
      return true;
    } catch (_) {
      return false;
    }
  }

  static String errorMsg(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) {
        final m = d['message'];
        return m is List ? m.join('\n') : m.toString();
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'El servidor tardó en responder. Intenta de nuevo.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Sin conexión con el servidor.';
      }
      return 'Error ${e.response?.statusCode ?? ''}'.trim();
    }
    return e.toString();
  }

  /// true cuando la última lista mostrada vino del caché local (sin conexión).
  final ValueNotifier<bool> offline = ValueNotifier(false);

  /// Separa el caché por usuario y finca.
  String cacheScope = '';

  Future<void> clearCache() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('cache:')).toList()) {
      await p.remove(k);
    }
  }

  /// GET de listas. Si no hay red, devuelve la última copia guardada (solo lectura).
  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async {
    final key = 'cache:$cacheScope:$path:${query ?? ''}';
    try {
      final r = await dio.get(path, queryParameters: query);
      final d = r.data;
      final list = d is List ? d : (d is Map && d['data'] is List ? d['data'] as List : <dynamic>[]);
      offline.value = false;
      SharedPreferences.getInstance().then((p) => p.setString(key, jsonEncode(list)));
      return list;
    } on DioException catch (e) {
      if (e.response == null) {
        final p = await SharedPreferences.getInstance();
        final raw = p.getString(key);
        if (raw != null) {
          offline.value = true;
          return jsonDecode(raw) as List;
        }
      }
      rethrow;
    }
  }
}

/// Estado de sesión (login → selección de finca → app).
class Session extends ChangeNotifier {
  Map<String, dynamic>? usuario;
  int? idfinca;
  List<Map<String, dynamic>> fincas = [];
  bool requiereSeleccionFinca = false;
  bool ready = false;

  bool get logged => Api.i.token != null;
  String get rol => (usuario?['role'] ?? 'admin').toString();
  bool get esComprador => rol == 'comprador';
  bool get necesitaFinca => logged && !esComprador && idfinca == null;
  String get nombre => (usuario?['nombre'] ?? '').toString();

  Future<void> restore() async {
    await Api.i.loadBaseUrl();
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
    Api.i.token = d['token'] as String?;
    usuario = (d['usuario'] as Map).cast<String, dynamic>();
    idfinca = d['idfinca'] as int?;
    fincas = ((d['fincas'] as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    requiereSeleccionFinca = d['requiereSeleccionFinca'] == true;
    await _save();
    notifyListeners();
  }

  /// CU-36: el backend devuelve un JWT nuevo ligado a la finca elegida.
  Future<void> seleccionarFinca(int id) async {
    final r = await Api.i.dio.post('/api/v1/fincas/$id/seleccionar');
    final d = r.data as Map<String, dynamic>;
    Api.i.token = d['token'] as String?;
    idfinca = id;
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
      fincas = [...fincas, f ?? {'idfinca': nuevo, 'nombre': data['nombre'], 'rol': 'admin', 'plan': 'basico'}];
      idfinca = nuevo;
      usuario?['role'] = 'admin';
      await _save();
      notifyListeners();
    } else {
      await logout(); // sin datos suficientes: que vuelva a entrar y elija finca
    }
  }

  /// Vuelve al selector de finca sin cerrar sesión.
  void cambiarFinca() {
    idfinca = null;
    notifyListeners();
  }

  Future<void> logout() async {
    Api.i.token = null;
    usuario = null;
    idfinca = null;
    fincas = [];
    final p = await SharedPreferences.getInstance();
    await p.remove('session');
    await Api.i.clearCache();
    notifyListeners();
  }
}
