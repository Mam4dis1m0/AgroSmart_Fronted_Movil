import 'api_client.dart';
import '../models/finca.dart';
import '../models/usuario.dart';

/// Fincas (tenant): datos, KPIs y miembros.
class FincaService {
  /// GET /api/v1/fincas/activa
  Future<Finca> activa() async {
    final r = await Api.i.dio.get('/api/v1/fincas/activa');
    return Finca.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// GET /api/v1/fincas/dashboard -> fila KPI de la finca activa
  Future<Map<String, dynamic>> dashboard(int idfinca) async {
    final rows = await Api.i.getList('/api/v1/fincas/dashboard');
    for (final r in rows) {
      if (r['idfinca'] == idfinca) return (r as Map).cast<String, dynamic>();
    }
    return const {};
  }

  /// GET /api/v1/fincas/activa/miembros
  Future<List<Miembro>> miembros() async {
    final rows = await Api.i.getList('/api/v1/fincas/activa/miembros');
    return [for (final r in rows) Miembro.fromJson((r as Map).cast<String, dynamic>())];
  }

  /// POST /usuarios/empleados
  Future<void> registrarEmpleado(Map<String, dynamic> data) async {
    await Api.i.dio.post('/usuarios/empleados', data: data);
  }

  /// PATCH /api/v1/fincas/activa/miembros/{idusuario}
  Future<void> setMiembroActivo(int idusuario, bool activo) async {
    await Api.i.dio.patch('/api/v1/fincas/activa/miembros/$idusuario', data: {'activo': activo});
  }
}
