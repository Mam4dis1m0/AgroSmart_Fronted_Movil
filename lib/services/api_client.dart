import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cola_offline.dart';
import 'demo/demo_data.dart';

/// URL del backend. Prioridad: --dart-define=API_URL > la guardada en la app > local por defecto.
const _envUrl = String.fromEnvironment('API_URL');

String defaultBaseUrl() {
  if (_envUrl.isNotEmpty) return _envUrl;
  if (kIsWeb) return 'http://localhost:3000';
  // En un teléfono físico conectado por USB, adb reverse expone el backend en localhost.
  // El emulador debe usar 10.0.2.2 mediante API_URL.
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://127.0.0.1:3000';
  }
  return 'http://localhost:3000';
}

/// Cliente HTTP único. La app NUNCA habla con la base de datos: todo pasa por la API.
///
/// Funciona sin internet:
///  - Toda lectura (GET) correcta se guarda; si no hay red, se responde con lo guardado.
///  - Crear / editar / borrar sin red se encola y se envía solo al volver la conexión.
class Api {
  Api._() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        if (token != null) o.headers['Authorization'] = 'Bearer $token';
        h.next(o);
      },
      onError: (e, h) {
        final path = e.requestOptions.path;
        final esLogin =
            path.startsWith('/usuarios/login') || path.contains('/password');
        if (e.response?.statusCode == 401 && token != null && !esLogin) {
          onUnauthorized?.call();
        }
        h.next(e);
      },
    ));
    if (!kDemoMode) dio.interceptors.add(_OfflineInterceptor(this));
    // Modo demo: responde TODO desde los datos del prototipo (sin backend).
    if (kDemoMode) dio.interceptors.add(DemoInterceptor());
  }
  static final Api i = Api._();

  final Dio dio = Dio(BaseOptions(
    baseUrl: defaultBaseUrl(),
    // Conectar: corto, para fallar rápido sin red. Render (plan gratis) acepta la conexión
    // enseguida y tarda en responder, por eso la RESPUESTA sí tiene margen.
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

  String? token;

  /// La sesión lo registra para cerrar sesión cuando el backend responde 401.
  void Function()? onUnauthorized;

  String get baseUrl => dio.options.baseUrl;

  /// Cambios hechos sin internet, pendientes de enviar.
  final ColaOffline cola = ColaOffline();

  /// Tareas que se ejecutan al volver la red (por ejemplo, subir SMS al servidor).
  final List<Future<void> Function()> alVolverRed = [];

  StreamSubscription<List<ConnectivityResult>>? _netSub;

  /// true si el celular no tiene ninguna red (modo avión, sin Wi-Fi ni datos).
  Future<bool> sinRed() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.every((x) => x == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Vigila la red: al volver, envía lo pendiente.
  void iniciarMonitor() {
    cola.cargar(cacheScope);
    _netSub ??= Connectivity().onConnectivityChanged.listen((r) async {
      if (r.every((x) => x == ConnectivityResult.none)) {
        offline.value = true;
      } else {
        await sincronizar();
      }
    });
  }

  /// Si hay conexión real con el servidor, envía la cola y las tareas de [alVolverRed].
  Future<void> sincronizar() async {
    if (token == null) return;
    if (!await ping()) return;
    await cola.enviarTodo(dio, cacheScope);
    for (final f in alVolverRed) {
      try {
        await f();
      } catch (_) {}
    }
  }

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
            extra: const {'sinCache': true},
          ));
      offline.value = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// true si la petición falló por falta de conexión (no porque el servidor la rechazara).
  static bool esErrorDeRed(Object e) =>
      e is DioException &&
      e.response == null &&
      const {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.unknown,
      }.contains(e.type);

  /// Modifica la copia guardada de un GET (sin parámetros) para que la pantalla refleje lo hecho
  /// sin red mientras la cola no se envía. Si no hay copia no hace nada.
  Future<void> parchearCache(String path, dynamic Function(dynamic datos) cambiar) async {
    final p = await SharedPreferences.getInstance();
    final k = 'cache:$cacheScope:$path:{}';
    final raw = p.getString(k);
    if (raw == null) return;
    try {
      await p.setString(k, jsonEncode(cambiar(jsonDecode(raw))));
    } catch (_) {}
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
      final code = e.response?.statusCode;
      // 401 con sesión abierta = token vencido. 401 al iniciar sesión = datos incorrectos.
      if (code == 401 && i.token != null) {
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      }
      if (d is Map && d['message'] != null) {
        final m = d['message'];
        return m is List ? m.join('\n') : m.toString();
      }
      if (code == 401) return 'Correo o contraseña incorrectos.';
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return 'No se pudo conectar con el servidor (${i.baseUrl}). Revisa que el celular y el servidor estén en la misma red y que la dirección sea correcta.';
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'El servidor tardó en responder. Intenta de nuevo.';
        case DioExceptionType.connectionError:
          return 'Sin conexión con el servidor (${i.baseUrl}).';
        case DioExceptionType.cancel:
          return 'Sin conexión con el servidor.';
        default:
          return 'Error ${code ?? ''}'.trim();
      }
    }
    return e.toString();
  }

  /// true cuando lo que se muestra viene del caché local (sin conexión).
  final ValueNotifier<bool> offline = ValueNotifier(false);

  /// Separa el caché por usuario y finca.
  String cacheScope = '';

  Future<void> clearCache() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('cache:')).toList()) {
      await p.remove(k);
    }
  }

  /// GET de listas. Sin red, el interceptor devuelve la última copia guardada.
  Future<List<dynamic>> getList(String path,
      {Map<String, dynamic>? query}) async {
    final r = await dio.get(path, queryParameters: query);
    final d = r.data;
    return d is List
        ? d
        : (d is Map && d['data'] is List ? d['data'] as List : <dynamic>[]);
  }
}

/// Caché de lecturas + cola de escrituras para trabajar sin internet.
class _OfflineInterceptor extends Interceptor {
  _OfflineInterceptor(this.api);
  final Api api;

  // Estas rutas nunca se encolan: dependen del servidor en el momento (login, pagos,
  // mensajes, planes, creación de finca) o devuelven datos que la pantalla necesita.
  static const _noEncolar = [
    '/usuarios',
    '/api/v1/mensajeria',
    '/api/v1/suscripcion',
    '/api/v1/marketplace',
    '/api/v1/chat',
    '/api/v1/fincas',
    '/lotes/foto',
  ];

  static const _errRed = {
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.unknown,
  };

  bool _cacheable(RequestOptions o) =>
      o.method == 'GET' &&
      o.responseType == ResponseType.json &&
      o.extra['sinCache'] != true;

  String _key(RequestOptions o) {
    String q;
    try {
      q = jsonEncode(o.queryParameters);
    } catch (_) {
      q = o.queryParameters.toString();
    }
    return 'cache:${api.cacheScope}:${o.path}:$q';
  }

  bool _encolable(RequestOptions o) {
    if (!{'POST', 'PUT', 'PATCH', 'DELETE'}.contains(o.method)) return false;
    if (o.extra['noQueue'] == true || api.token == null) return false;
    if (_noEncolar.any(o.path.startsWith)) return false;
    if (o.path.endsWith('/pagar') || o.path.endsWith('/confirmar')) {
      return false;
    }
    final d = o.data;
    return d == null ||
        d is Map ||
        d is List ||
        d is String; // FormData (fotos) no se encola
  }

  Response _desdeCache(RequestOptions o, String raw) {
    api.offline.value = true;
    return Response(
        requestOptions: o,
        statusCode: 200,
        data: jsonDecode(raw),
        extra: const {'fromCache': true});
  }

  @override
  Future<void> onRequest(RequestOptions o, RequestInterceptorHandler h) async {
    if (_cacheable(o)) {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(o));
      if (raw != null) {
        // Hay copia guardada: no vale la pena esperar mucho al servidor.
        o.connectTimeout = const Duration(seconds: 6);
        o.receiveTimeout = const Duration(seconds: 20);
        if (await api.sinRed()) return h.resolve(_desdeCache(o, raw));
      }
    }
    h.next(o);
  }

  @override
  void onResponse(Response r, ResponseInterceptorHandler h) {
    if (r.extra['fromCache'] != true) {
      api.offline.value = false;
      final o = r.requestOptions;
      final ok = (r.statusCode ?? 0) >= 200 && (r.statusCode ?? 0) < 300;
      if (ok && _cacheable(o) && (r.data is Map || r.data is List)) {
        try {
          final s = jsonEncode(r.data);
          SharedPreferences.getInstance().then((p) => p.setString(_key(o), s));
        } catch (_) {}
      }
    }
    h.next(r);
  }

  @override
  Future<void> onError(DioException e, ErrorInterceptorHandler h) async {
    final o = e.requestOptions;
    if (e.response != null || !_errRed.contains(e.type)) return h.next(e);

    if (_cacheable(o)) {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(o));
      if (raw != null) return h.resolve(_desdeCache(o, raw));
      return h.next(e);
    }

    if (_encolable(o)) {
      await api.cola.agregar(
        scope: api.cacheScope,
        method: o.method,
        path: o.path,
        data: o.data,
        query: o.queryParameters.isEmpty ? null : o.queryParameters,
      );
      api.offline.value = true;
      return h.resolve(Response(
        requestOptions: o,
        statusCode: 202,
        data: const {'offline': true, 'encolado': true},
      ));
    }
    h.next(e);
  }
}
