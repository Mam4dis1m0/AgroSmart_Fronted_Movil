import 'api_client.dart';
import '../models/finca.dart';
import '../models/usuario.dart';

/// Fincas (tenant): datos, KPIs, miembros y empleados.
class FincaService {
  /// GET /api/v1/fincas/activa
  Future<Finca> activa() async {
    final r = await Api.i.dio.get('/api/v1/fincas/activa');
    return Finca.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// PUT /api/v1/fincas/activa
  Future<Map<String, dynamic>> actualizarActiva(Map<String, dynamic> data) async {
    final r = await Api.i.dio.put('/api/v1/fincas/activa', data: data);
    return r.data is Map ? (r.data as Map).cast<String, dynamic>() : data;
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

  /// DELETE /api/v1/fincas/activa/miembros/{idusuario}
  Future<void> quitarMiembro(int idusuario) async {
    await Api.i.dio.delete('/api/v1/fincas/activa/miembros/$idusuario');
  }

  /// GET /api/v1/empleados/{idusuario} -> tarifas (montoporhora, montoporjornal)
  Future<Map<String, dynamic>?> empleado(int idusuario) async {
    try {
      final r = await Api.i.dio.get('/api/v1/empleados/$idusuario');
      return r.data is Map ? (r.data as Map).cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// PUT /api/v1/empleados/{idusuario}
  Future<void> actualizarTarifas(int idusuario, Map<String, dynamic> data) async {
    await Api.i.dio.put('/api/v1/empleados/$idusuario', data: data);
  }
}
