import 'api_client.dart';
import '../models/operacion.dart';

/// Operación diaria: tareas, asignaciones y compras de insumos.
class OperacionService {
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final rows = await Api.i.getList(path);
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  /// GET /api/v1/tareas
  Future<List<Tarea>> tareas() async =>
      [for (final m in await _list('/api/v1/tareas')) Tarea.fromJson(m)];

  /// POST /api/v1/tareas
  Future<void> crearTarea(Map<String, dynamic> data) async {
    await Api.i.dio.post('/api/v1/tareas', data: {'estado': 'Pendiente', ...data});
  }

  /// PATCH /api/v1/tareas/{id}/completar
  Future<void> completarTarea(dynamic id) async {
    await Api.i.dio.patch('/api/v1/tareas/$id/completar');
  }

  /// PUT /api/v1/tareas/{id}
  Future<void> actualizarTarea(dynamic id, Map<String, dynamic> data) async {
    await Api.i.dio.put('/api/v1/tareas/$id', data: data);
  }

  /// PATCH /api/v1/tareas/{id}/asignar
  Future<void> asignarTarea(dynamic id, Map<String, dynamic> data) async {
    await Api.i.dio.patch('/api/v1/tareas/$id/asignar', data: data);
  }

  /// DELETE /api/v1/tareas/{id}
  Future<void> eliminarTarea(dynamic id) async {
    await Api.i.dio.delete('/api/v1/tareas/$id');
  }

  /// POST /api/v1/insumos/{id}/compras
  Future<void> registrarCompra(dynamic idinsumo, Map<String, dynamic> data) async {
    await Api.i.dio.post('/api/v1/insumos/$idinsumo/compras',
        data: {...data, 'actualizarCostoUnitario': true});
  }

  /// Opciones de cultivo para selects.
  Future<List<MapEntry<dynamic, String>>> cultivosOpc() async => [
        for (final c in await _list('/cultivos'))
          MapEntry(c['idcultivo'],
              '${c['tipo'] ?? ''}'.isEmpty ? 'Cultivo #${c['idcultivo']}' : '${c['tipo']}'),
      ];

  /// Opciones de empleados activos para asignar tareas.
  Future<List<MapEntry<dynamic, String>>> empleadosOpciones() async => [
        for (final m in await _list('/api/v1/fincas/activa/miembros'))
          if (m['rol'] == 'empleado' && m['activo'] != false)
            MapEntry(m['idusuario'], '${m['primernombre'] ?? ''} ${m['primerapellido'] ?? ''}'.trim()),
      ];
}
