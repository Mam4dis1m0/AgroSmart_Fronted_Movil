import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'demo/demo_data.dart';

/// URL del backend. Prioridad: --dart-define=API_URL > la guardada en la app > local por defecto.
const _envUrl = String.fromEnvironment('API_URL');

String defaultBaseUrl() {
  if (_envUrl.isNotEmpty) return _envUrl;
  if (kIsWeb) return 'http://localhost:3000';
  // Con adb reverse, el celular físico llega al backend de la PC por loopback.
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://127.0.0.1:3000';
  return 'http://localhost:3000';
}

/// Cliente HTTP único. La app NUNCA habla con la base de datos: todo pasa por la API.
class Api {
  Api._() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        if (token != null) o.headers['Authorization'] = 'Bearer $token';
        h.next(o);
      },
      onError: (e, h) {
        final path = e.requestOptions.path;
        final esLogin = path.startsWith('/usuarios/login') || path.contains('/password');
        if (e.response?.statusCode == 401 && token != null && !esLogin) onUnauthorized?.call();
        h.next(e);
      },
    ));
    // Modo demo: responde TODO desde los datos del prototipo (sin backend).
    if (kDemoMode) dio.interceptors.add(DemoInterceptor());
  }
  static final Api i = Api._();

  final Dio dio = Dio(BaseOptions(
    baseUrl: defaultBaseUrl(),
    // Render (plan gratis) tarda en "despertar": damos margen.
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  ));

  String? token;

  /// La sesión lo registra para cerrar sesión cuando el backend responde 401.
  void Function()? onUnauthorized;

  String get baseUrl => dio.options.baseUrl;

  /// Carga la URL guardada (si el usuario la cambió desde la app).
  Future<void> loadBaseUrl() async {
    if (_envUrl.isNotEmpty) return; // --dart-define manda
    final p = await SharedPreferences.getInstance();
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android local usa adb reverse; no reutilizar una IP antigua guardada.
      await p.remove('api_url');
      dio.options.baseUrl = defaultBaseUrl();
      return;
    }
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
    if (defaultTargetPlatform != TargetPlatform.android) {
      await p.setString('api_url', u);
    }
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
      offline.value = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// true si el backend rechazó la acción porque requiere el plan Premium.
  static bool esPremiumRequerido(Object e) {
    if (e is! DioException) return false;
    final d = e.response?.data;
    return d is Map && d['code'] == 'PLAN_PREMIUM_REQUERIDO';
  }

  static String errorMsg(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (esPremiumRequerido(e)) {
        return 'Esta función requiere el plan Premium. Puedes activarlo en Más › Plan y suscripción.';
      }
      if (e.response?.statusCode == 401) return 'Tu sesión expiró. Vuelve a iniciar sesión.';
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
