import 'dart:convert';
import 'dart:io' show Directory, File;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'almacen_local.dart';

/// Cola de cambios hechos sin internet (crear / editar / borrar).
/// Se guarda en el celular y se envía sola cuando vuelve la red.
/// Cada cambio queda atado al usuario+finca que lo hizo, para no mezclar cuentas.
/// Se guarda en Hive (caja `cola_offline`), un registro por cambio, en orden de creación.
class ColaOffline {

  /// Cambios pendientes del usuario actual.
  final ValueNotifier<int> pendientes = ValueNotifier(0);

  /// Cambios que el servidor rechazó al sincronizar (se muestran una vez).
  final ValueNotifier<int> rechazadas = ValueNotifier(0);

  bool _enviando = false;

  /// Todos los cambios guardados, en orden (las claves son ids de igual longitud).
  List<Map<String, dynamic>> _leer() {
    final box = AlmacenLocal.cola;
    final keys = box.keys.map((k) => k.toString()).toList()..sort();
    final out = <Map<String, dynamic>>[];
    for (final k in keys) {
      try {
        out.add((jsonDecode(box.get(k)!) as Map).cast<String, dynamic>());
      } catch (_) {
        box.delete(k); // registro dañado
      }
    }
    return out;
  }

  int _contar(String scope) => _leer().where((i) => i['scope'] == scope).length;

  Future<void> _guardar(Map<String, dynamic> it) =>
      AlmacenLocal.cola.put(it['id'].toString(), jsonEncode(it));

  Future<void> _quitar(Map<String, dynamic> it) => AlmacenLocal.cola.delete(it['id'].toString());

  Future<void> cargar(String scope) async {
    pendientes.value = _contar(scope);
  }

  Future<void> agregar({
    required String scope,
    required String method,
    required String path,
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    await _guardar({
      'id': DateTime.now().microsecondsSinceEpoch,
      'scope': scope,
      'method': method,
      'path': path,
      'data': data,
      'query': query,
    });
    pendientes.value = _contar(scope);
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
    await _guardar({
      'id': id,
      'scope': scope,
      'method': 'POST',
      'path': path,
      'tipo': 'subida',
      'campos': campos,
      'archivo': archivo,
    });
    pendientes.value = _contar(scope);
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
      for (final it in _leer().where((i) => i['scope'] == scope)) {
        try {
          await dio.request(
            it['path'] as String,
            data: it['tipo'] == 'subida' ? await _armarSubida(it) : it['data'],
            queryParameters: (it['query'] as Map?)?.cast<String, dynamic>(),
            options: Options(method: it['method'] as String, extra: const {'noQueue': true}),
          );
          await _borrarArchivo(it);
          await _quitar(it);
          ok++;
        } on DioException catch (e) {
          final c = e.response?.statusCode;
          if (c == null || c == 401 || c >= 500) break; // se reintenta después
          await _borrarArchivo(it);
          await _quitar(it); // el servidor lo rechazó (4xx): no tiene sentido reintentar
          rechazadas.value++;
        } on Object {
          // El archivo guardado ya no existe: no se puede reenviar
          await _borrarArchivo(it);
          await _quitar(it);
          rechazadas.value++;
        }
      }
      pendientes.value = _contar(scope);
    } finally {
      _enviando = false;
    }
    return ok;
  }
}
