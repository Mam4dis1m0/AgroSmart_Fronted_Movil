import 'api_client.dart';

/// Planes y suscripción de la finca.
class PlanService {
  Future<List<Map<String, dynamic>>> planes() async {
    final rows = await Api.i.getList('/api/v1/planes');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<Map<String, dynamic>?> suscripcion() async {
    try {
      final r = await Api.i.dio.get('/api/v1/suscripcion');
      if (r.data is Map) return (r.data as Map).cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  Future<void> contratar() async {
    await Api.i.dio.post('/api/v1/suscripcion/contratar');
  }

  Future<void> cancelar() async {
    await Api.i.dio.post('/api/v1/suscripcion/cancelar');
  }
}
