import 'dart:convert';
import 'dart:io' show Directory, File;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cola de cambios hechos sin internet (crear / editar / borrar).
/// Se guarda en el celular y se envía sola cuando vuelve la red.
/// Cada cambio queda atado al usuario+finca que lo hizo, para no mezclar cuentas.
class ColaOffline {
  static const _key = 'cola_offline';

  /// Cambios pendientes del usuario actual.
  final ValueNotifier<int> pendientes = ValueNotifier(0);

  /// Cambios que el servidor rechazó al sincronizar (se muestran una vez).
  final ValueNotifier<int> rechazadas = ValueNotifier(0);

  bool _enviando = false;

  List<Map<String, dynamic>> _leer(SharedPreferences p) {
    final raw = p.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cargar(String scope) async {
    final p = await SharedPreferences.getInstance();
    pendientes.value = _leer(p).where((i) => i['scope'] == scope).length;
  }

  Future<void> agregar({
    required String scope,
    required String method,
    required String path,
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final p = await SharedPreferences.getInstance();
    final l = _leer(p);
    l.add({
      'id': DateTime.now().microsecondsSinceEpoch,
      'scope': scope,
      'method': method,
      'path': path,
      'data': data,
      'query': query,
    });
    await p.setString(_key, jsonEncode(l));
    pendientes.value = l.where((i) => i['scope'] == scope).length;
  }

  /// Guarda una subida con archivos (fotos). En el celular el archivo se copia a una carpeta propia de
  /// la app; en web queda dentro del mismo registro (no hay disco).
  Future<void> agregarSubida({
    required String scope,
    required String path,
    required Map<String, String> campos,
    required String campoArchivo,
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final archivo = <String, dynamic>{'campo': campoArchivo, 'nombre': nombreArchivo};
    if (kIsWeb) {
      archivo['b64'] = base64Encode(bytes);
    } else {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/cola_offline');
      if (!await dir.exists()) await dir.create(recursive: true);
      final f = File('${dir.path}/${id}_$nombreArchivo');
      await f.writeAsBytes(bytes, flush: true);
      archivo['ruta'] = f.path;
    }
    final p = await SharedPreferences.getInstance();
    final l = _leer(p);
    l.add({
      'id': id,
      'scope': scope,
      'method': 'POST',
      'path': path,
      'tipo': 'subida',
      'campos': campos,
      'archivo': archivo,
    });
    await p.setString(_key, jsonEncode(l));
    pendientes.value = l.where((i) => i['scope'] == scope).length;
  }

  Future<FormData> _armarSubida(Map<String, dynamic> it) async {
    final a = (it['archivo'] as Map).cast<String, dynamic>();
    final bytes = a['b64'] != null ? base64Decode(a['b64'] as String) : await File(a['ruta'] as String).readAsBytes();
    return FormData.fromMap({
      ...((it['campos'] as Map?)?.cast<String, dynamic>() ?? const {}),
      a['campo'] as String: MultipartFile.fromBytes(bytes, filename: a['nombre'] as String),
    });
  }

  Future<void> _borrarArchivo(Map<String, dynamic> it) async {
    final ruta = (it['archivo'] as Map?)?['ruta'];
    if (ruta == null) return;
    try {
      final f = File(ruta as String);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Envía en orden los cambios guardados. Se detiene si vuelve a fallar la red.
  Future<int> enviarTodo(Dio dio, String scope) async {
    if (_enviando) return 0;
    _enviando = true;
    var ok = 0;
    try {
      final p = await SharedPreferences.getInstance();
      final items = _leer(p);
      for (final it in items.where((i) => i['scope'] == scope).toList()) {
        try {
          await dio.request(
            it['path'] as String,
            data: it['tipo'] == 'subida' ? await _armarSubida(it) : it['data'],
            queryParameters: (it['query'] as Map?)?.cast<String, dynamic>(),
            options: Options(method: it['method'] as String, extra: const {'noQueue': true}),
          );
          await _borrarArchivo(it);
          items.remove(it);
          ok++;
        } on DioException catch (e) {
          final c = e.response?.statusCode;
          if (c == null || c == 401 || c >= 500) break; // se reintenta después
          await _borrarArchivo(it);
          items.remove(it); // el servidor lo rechazó (4xx): no tiene sentido reintentar
          rechazadas.value++;
        } on Object {
          // El archivo guardado ya no existe: no se puede reenviar
          await _borrarArchivo(it);
          items.remove(it);
          rechazadas.value++;
        }
        await p.setString(_key, jsonEncode(items));
      }
      pendientes.value = items.where((i) => i['scope'] == scope).length;
    } finally {
      _enviando = false;
    }
    return ok;
  }
}
