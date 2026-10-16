import 'api_client.dart';

/// Nómina / jornales de un periodo.
class NominaService {
  Future<List<Map<String, dynamic>>> nominas() async {
    final rows = await Api.i.getList('/api/v1/nomina');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<void> crear(Map<String, dynamic> data) async {
    await Api.i.dio.post('/api/v1/nomina', data: data);
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
