import 'api_client.dart';
import '../models/aviso.dart';

/// Avisos (notificaciones) y auditoría.
class AvisoService {
  Future<List<Notificacion>> notificaciones() async {
    final rows = await Api.i.getList('/notificaciones');
    return [for (final r in rows) Notificacion.fromJson((r as Map).cast<String, dynamic>())];
  }

  Future<void> marcarLeida(dynamic idnotificacion) async {
    await Api.i.dio.put('/notificaciones/$idnotificacion/leer');
  }

  /// PUT /notificaciones/leer-todas
  Future<void> marcarTodas() async {
    await Api.i.dio.put('/notificaciones/leer-todas');
  }

  /// DELETE /notificaciones/{id} (solo administrador)
  Future<void> eliminar(dynamic idnotificacion) async {
    await Api.i.dio.delete('/notificaciones/$idnotificacion');
  }

  Future<List<EventoAuditoria>> auditoria() async {
    final rows = await Api.i.getList('/auditoria');
    return [for (final r in rows) EventoAuditoria.fromJson((r as Map).cast<String, dynamic>())];
  }
}
