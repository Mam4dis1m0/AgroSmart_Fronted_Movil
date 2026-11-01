import 'package:dio/dio.dart';
import 'api_client.dart';

/// Prepara y ejecuta operaciones confirmadas por el usuario.
class AsistenteAccionesService {
  Future<Map<String, dynamic>> planificar(String solicitud) async {
    final r = await Api.i.dio.post('/api/v1/chat/planificar', data: {
      'solicitud': solicitud,
      'contexto': {'fecha_hoy': DateTime.now().toIso8601String().substring(0, 10)},
    });
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<List<String>> ejecutar(List<dynamic> acciones) async {
    dynamic idLote;
    dynamic idCultivo;
    final resultados = <String>[];
    for (final raw in acciones) {
      final a = (raw as Map).cast<String, dynamic>();
      final datos = (a['datos'] as Map).cast<String, dynamic>();
      final tipo = a['tipo'];
      dynamic r;
      if (tipo == 'lote') {
        final payload = Map<String, dynamic>.from(datos)..remove('idlote_ref');
        r = await Api.i.dio.post('/lotes', data: payload);
        idLote = _id(r.data, ['idlote', 'id']);
        resultados.add('Lote creado: ${datos['nombre'] ?? 'sin nombre'}');
      } else if (tipo == 'cultivo') {
        final payload = Map<String, dynamic>.from(datos)..remove('idlote_ref');
        if (datos['idlote_ref'] == 'lote') {
          if (idLote == null) throw Exception('No se obtuvo el ID del lote para asociar el cultivo.');
          payload['idlote'] = idLote;
        }
        r = await Api.i.dio.post('/cultivos', data: payload);
        idCultivo = _id(r.data, ['idcultivo', 'id']);
        resultados.add('Cultivo creado: ${datos['tipo'] ?? 'sin tipo'}');
      } else if (tipo == 'tarea') {
        final payload = Map<String, dynamic>.from(datos)..remove('cultivo_ref');
        if (datos['cultivo_ref'] == 'cultivo') {
          if (idCultivo == null) throw Exception('No se obtuvo el ID del cultivo para asociar la tarea.');
          payload['idcultivo'] = idCultivo;
        }
        await Api.i.dio.post('/api/v1/tareas', data: {'estado': 'Pendiente', ...payload});
        resultados.add('Tarea creada: ${datos['tipoactividad'] ?? 'sin nombre'}');
      }
    }
    return resultados;
  }

  dynamic _id(dynamic data, List<String> keys) {
    if (data is Map) {
      for (final k in keys) { if (data[k] != null) return data[k]; }
    }
    return null;
  }
}
