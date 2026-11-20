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

  /// GET /api/v1/suscripcion/metodos-pago
  /// -> { nequi: { numero, titular } | null, simulado: bool, revisor: bool }
  Future<Map<String, dynamic>> metodosPago() async {
    try {
      final r = await Api.i.dio.get('/api/v1/suscripcion/metodos-pago');
      if (r.data is Map) return (r.data as Map).cast<String, dynamic>();
    } catch (_) {
      // Servidor antiguo o modo demo: solo hay pago de prueba.
    }
    return const {'nequi': null, 'simulado': true, 'revisor': false};
  }

  /// POST /api/v1/suscripcion/contratar -> { pago: { idpago, estado }, mensaje }
  /// Con Nequi queda PENDIENTE hasta que se revisa la transferencia.
  Future<Map<String, dynamic>> contratar(
      {String metodo = 'SIMULADO', String? referencia, String? comprobante}) async {
    final r = await Api.i.dio.post('/api/v1/suscripcion/contratar', data: {
      'metodo': metodo,
      if (referencia != null) 'referencia': referencia,
      if (comprobante != null && comprobante.isNotEmpty) 'comprobante': comprobante,
    });
    final data = r.data is Map ? (r.data as Map).cast<String, dynamic>() : {};
    final pago = data['pago'] is Map
        ? (data['pago'] as Map).cast<String, dynamic>()
        : <String, dynamic>{'estado': 'APROBADO'}; // demo / respuesta antigua
    return {...data, 'pago': pago};
  }

  /// Transferencias esperando revisión (solo revisores).
  Future<List<Map<String, dynamic>>> porRevisar() async {
    final rows = await Api.i.getList('/api/v1/pagos/por-revisar');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<void> revisar(int idpago, {required bool aprobar}) async {
    await Api.i.dio.post('/api/v1/pagos/$idpago/${aprobar ? 'aprobar' : 'rechazar'}');
  }

  Future<void> cancelar() async {
    await Api.i.dio.post('/api/v1/suscripcion/cancelar');
  }
}
