import 'api_client.dart';

/// Planes y suscripción de la finca.
class PlanService {
  Future<List<Map<String, dynamic>>> planes() async {
    final rows = await Api.i.getList('/api/v1/planes');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  /// GET /api/v1/suscripcion -> { suscripcion: {...}|null, planEfectivo: { codigo, maxcultivos, ... } }
  Future<Map<String, dynamic>> suscripcion() async {
    final r = await Api.i.dio.get('/api/v1/suscripcion');
    return r.data is Map ? (r.data as Map).cast<String, dynamic>() : const {};
  }

  /// GET /api/v1/suscripcion/pagos
  Future<List<Map<String, dynamic>>> pagos() async {
    final rows = await Api.i.getList('/api/v1/suscripcion/pagos');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<void> contratar() async {
    await Api.i.dio.post('/api/v1/suscripcion/contratar');
  }

  Future<void> cancelar() async {
    await Api.i.dio.post('/api/v1/suscripcion/cancelar');
  }
}
