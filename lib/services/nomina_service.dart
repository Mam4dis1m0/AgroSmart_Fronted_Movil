import 'api_client.dart';

/// Nómina / jornales de un periodo. Flujo: BORRADOR → CONFIRMADA → PAGADA.
class NominaService {
  Future<List<Map<String, dynamic>>> nominas() async {
    final rows = await Api.i.getList('/api/v1/nomina');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  /// GET /api/v1/nomina/{id} -> { ..., detalles: [ {idnominadetalle, primernombre, horas, jornadas, bruto, deducciones, neto} ] }
  Future<Map<String, dynamic>> detalle(dynamic idnomina) async {
    final r = await Api.i.dio.get('/api/v1/nomina/$idnomina');
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> crear(Map<String, dynamic> data) async {
    await Api.i.dio.post('/api/v1/nomina', data: data);
  }

  /// PATCH /api/v1/nomina/detalle/{iddetalle}/deducciones (solo en BORRADOR)
  Future<void> ajustarDeducciones(dynamic iddetalle, num deducciones) async {
    await Api.i.dio.patch('/api/v1/nomina/detalle/$iddetalle/deducciones', data: {'deducciones': deducciones});
  }

  /// PATCH /api/v1/nomina/detalle/{iddetalle}/unidades (solo en BORRADOR): corrige los días, semanas o meses pagados.
  Future<void> ajustarUnidades(dynamic iddetalle, num unidades) async {
    await Api.i.dio.patch('/api/v1/nomina/detalle/$iddetalle/unidades', data: {'unidades': unidades});
  }

  Future<void> confirmar(dynamic idnomina) async {
    await Api.i.dio.patch('/api/v1/nomina/$idnomina/confirmar');
  }

  Future<void> pagar(dynamic idnomina) async {
    await Api.i.dio.patch('/api/v1/nomina/$idnomina/pagar');
  }

  Future<void> eliminar(dynamic idnomina) async {
    await Api.i.dio.delete('/api/v1/nomina/$idnomina');
  }
}
