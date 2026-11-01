import 'package:dio/dio.dart';
import 'api_client.dart';

/// Asistente por voz: manda el texto dictado + lo que ya existe en la finca al backend,
/// que lo interpreta con IA y devuelve un PLAN (lote → cultivo → tareas). No crea nada.
class VozService {
  String _p2(int n) => n.toString().padLeft(2, '0');

  Future<List<dynamic>> _lista(String path) async {
    try {
      return await Api.i.getList(path);
    } catch (_) {
      return const [];
    }
  }

  /// Nombre del lote de un cultivo (el backend puede mandar `idlote` como objeto o como número).
  String _loteDe(Map c) {
    final l = c['idlote'];
    return l is Map ? '${l['nombre'] ?? ''}' : '';
  }

  Future<Map<String, dynamic>> interpretar(String texto) async {
    final lotes = await _lista('/lotes');
    final cultivos = await _lista('/cultivos');
    final miembros = await _lista('/api/v1/fincas/activa/miembros');
    final hoy = DateTime.now();
    final r = await Api.i.dio.post(
      '/api/v1/voz/interpretar',
      data: {
        'texto': texto.trim(),
        'hoy': '${hoy.year}-${_p2(hoy.month)}-${_p2(hoy.day)}',
        'lotes': [
          for (final l in lotes)
            if (l is Map && l['idlote'] != null) {'id': l['idlote'], 'nombre': '${l['nombre'] ?? 'Lote ${l['idlote']}'}'},
        ],
        'cultivos': [
          for (final c in cultivos)
            if (c is Map && c['idcultivo'] != null) {'id': c['idcultivo'], 'tipo': '${c['tipo'] ?? ''}', 'lote': _loteDe(c)},
        ],
        'empleados': [
          for (final m in miembros)
            if (m is Map && m['rol'] == 'empleado' && m['activo'] != false)
              {'id': m['idusuario'], 'nombre': '${m['primernombre'] ?? ''} ${m['primerapellido'] ?? ''}'.trim()},
        ],
      },
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    return (r.data as Map).cast<String, dynamic>();
  }
}

final vozService = VozService();
