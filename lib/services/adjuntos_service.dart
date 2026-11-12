import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';
import 'secure_storage.dart';

const _msj = '/api/v1/mensajeria';

/// Fotos y audios del chat.
///
///  - Con internet suben al servidor (Cloudinary) y llegan al otro usuario por Socket.IO.
///  - Sin conexión se guardan en el celular («pendiente») y suben solos al volver la red.
///  - Por SMS NO viajan: un SMS no puede llevar una foto ni un audio. El chat solo ofrece
///    avisar por SMS de que hay un adjunto esperando conexión.
class AdjuntosService {
  final _cambios = StreamController<int>.broadcast();

  /// idhilo cuyos adjuntos pendientes cambiaron (subió uno, falló, se descartó…).
  Stream<int> get cambios => _cambios.stream;

  bool _subiendo = false;

  String _kLista(String scope, int idhilo) => 'adj:$scope:$idhilo';
  String _kHilos(String scope) => 'adj:$scope:hilos';

  /// Sube un archivo ya existente y devuelve el mensaje creado por el servidor.
  Future<Map<String, dynamic>> subir(
    int idhilo, {
    required String path,
    required String tipo, // IMAGEN | AUDIO
    int? duracionSeg,
    String? texto,
    CancelToken? cancel,
  }) async {
    final form = FormData.fromMap({
      'tipo': tipo,
      if (duracionSeg != null) 'duracionSeg': duracionSeg.toString(),
      if (texto != null && texto.trim().isNotEmpty) 'contenido': texto.trim(),
      'archivo': await MultipartFile.fromFile(path,
          filename: path.split(RegExp(r'[\\/]')).last),
    });
    final r = await Api.i.dio.post(
      '$_msj/hilos/$idhilo/adjuntos',
      data: form,
      cancelToken: cancel,
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
        extra: {
          'noQueue': true
        }, // los archivos no se encolan en la cola genérica
      ),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  // ── Pendientes (sin conexión) ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _leer(String k) async {
    final raw = await secureStorage.read(key: k);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adjuntos de este chat que aún no suben (con el formato de un mensaje del chat).
  Future<List<Map<String, dynamic>>> pendientes(int idhilo) async {
    return _leer(_kLista(Api.i.cacheScope, idhilo));
  }

  /// Guarda el archivo en el celular para enviarlo cuando vuelva la conexión.
  Future<Map<String, dynamic>> encolar(int idhilo,
      {required String path, required String tipo, int? duracionSeg}) async {
    final dir = await getApplicationDocumentsDirectory();
    final carpeta = Directory('${dir.path}/adjuntos_pendientes');
    if (!await carpeta.exists()) await carpeta.create(recursive: true);
    final punto = path.lastIndexOf('.');
    final ext = punto > path.lastIndexOf(RegExp(r'[\\/]'))
        ? path.substring(punto)
        : (tipo == 'AUDIO' ? '.m4a' : '.jpg');
    final id = DateTime.now().microsecondsSinceEpoch;
    final destino = '${carpeta.path}/$id$ext';
    await File(path).copy(
        destino); // el archivo original puede estar en una carpeta temporal

    final item = <String, dynamic>{
      'idmensaje': null,
      'mio': true,
      'tipo': tipo,
      'path': destino,
      if (duracionSeg != null) 'duracionSeg': duracionSeg,
      'createdAt': DateTime.now().toIso8601String(),
      'adjPend': true,
      'adjId': 'adj-$id',
    };
    final scope = Api.i.cacheScope;
    final l = await _leer(_kLista(scope, idhilo))
      ..add(item);
    await secureStorage.write(
        key: _kLista(scope, idhilo), value: jsonEncode(l));
    final rawIds = await secureStorage.read(key: _kHilos(scope));
    final ids = rawIds == null
        ? <String>[]
        : (jsonDecode(rawIds) as List).cast<String>();
    if (!ids.contains('$idhilo')) {
      await secureStorage.write(
          key: _kHilos(scope), value: jsonEncode([...ids, '$idhilo']));
    }
    return item;
  }

  Future<void> descartar(int idhilo, String adjId) async {
    final k = _kLista(Api.i.cacheScope, idhilo);
    final l = await _leer(k);
    for (final m in l.where((m) => m['adjId'] == adjId)) {
      try {
        await File('${m['path']}').delete();
      } catch (_) {}
    }
    l.removeWhere((m) => m['adjId'] == adjId);
    await secureStorage.write(key: k, value: jsonEncode(l));
    _cambios.add(idhilo);
  }

  /// Vuelve a intentar uno que el servidor rechazó.
  Future<void> reintentar(int idhilo, String adjId) async {
    final k = _kLista(Api.i.cacheScope, idhilo);
    final l = await _leer(k);
    for (final m in l.where((m) => m['adjId'] == adjId)) {
      m['fallo'] = false;
      m.remove('error');
    }
    await secureStorage.write(key: k, value: jsonEncode(l));
    _cambios.add(idhilo);
    await flush(idhilo: idhilo);
  }

  /// Sube lo pendiente. Se llama al volver la red y al abrir un chat con internet.
  /// Devuelve cuántos adjuntos subieron.
  Future<int> flush({int? idhilo}) async {
    if (_subiendo) return 0;
    _subiendo = true;
    var subidos = 0;
    try {
      final scope = Api.i.cacheScope;
      final rawIds = await secureStorage.read(key: _kHilos(scope));
      final storedIds = rawIds == null
          ? <String>[]
          : (jsonDecode(rawIds) as List).cast<String>();
      final ids = idhilo != null
          ? [idhilo]
          : storedIds.map(int.tryParse).whereType<int>().toList();
      for (final id in ids) {
        final k = _kLista(scope, id);
        final l = await _leer(k);
        var cambio = false;
        for (final m in l.toList()) {
          if (m['fallo'] == true) {
            continue; // espera que el usuario lo reintente o descarte
          }
          final path = '${m['path']}';
          if (!await File(path).exists()) {
            l.remove(m);
            cambio = true;
            continue;
          }
          try {
            await subir(id,
                path: path,
                tipo: '${m['tipo']}',
                duracionSeg: (m['duracionSeg'] as num?)?.toInt());
            try {
              await File(path).delete();
            } catch (_) {}
            l.remove(m);
            subidos++;
            cambio = true;
          } on DioException catch (e) {
            if (e.response == null) {
              // Sigue sin conexión con el servidor: se guarda lo avanzado y se corta.
              await secureStorage.write(key: k, value: jsonEncode(l));
              if (cambio) _cambios.add(id);
              return subidos;
            }
            m['fallo'] = true; // el servidor lo rechazó (formato, tamaño…)
            m['error'] = Api.errorMsg(e);
            cambio = true;
          }
        }
        await secureStorage.write(key: k, value: jsonEncode(l));
        if (cambio) _cambios.add(id);
      }
    } finally {
      _subiendo = false;
    }
    return subidos;
  }
}
