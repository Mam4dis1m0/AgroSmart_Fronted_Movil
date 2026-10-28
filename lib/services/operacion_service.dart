import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/operacion.dart';

/// Operación diaria: tareas, asignaciones, insumos usados y compras de insumos.
class OperacionService {
  Future<List<Map<String, dynamic>>> _list(String path, {Map<String, dynamic>? query}) async {
    final rows = await Api.i.getList(path, query: query);
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  /// GET /api/v1/tareas (el empleado solo recibe las suyas)
  Future<List<Tarea>> tareas() async =>
      [for (final m in await _list('/api/v1/tareas')) Tarea.fromJson(m)];

  /// GET /api/v1/tareas/{id}
  Future<Tarea> tarea(int id) async {
    final r = await Api.i.dio.get('/api/v1/tareas/$id');
    return Tarea.fromJson((r.data as Map).cast<String, dynamic>());
  }

  /// POST /api/v1/tareas
  Future<void> crearTarea(Map<String, dynamic> data) async {
    await Api.i.dio.post('/api/v1/tareas', data: {'estado': 'Pendiente', ...data});
  }

  /// PATCH /api/v1/tareas/{idasigtarea}/completar — el id es el de la ASIGNACIÓN.
  /// `at` es la hora real del toque: si no hay red la petición se encola y el servidor respeta esta hora.
  Future<void> completarAsignacion(int idasigtarea) async {
    await Api.i.dio.patch('/api/v1/tareas/$idasigtarea/finalizar', data: {'at': _ahora()});
  }

  /// PATCH /api/v1/tareas/{idasigtarea}/iniciar — marca la hora de inicio (cronómetro).
  Future<void> iniciarAsignacion(int idasigtarea) async {
    await Api.i.dio.patch('/api/v1/tareas/$idasigtarea/iniciar', data: {'at': _ahora()});
  }

  static String _ahora() => DateTime.now().toUtc().toIso8601String();

  /// POST /api/v1/tareas/{id}/completar-con-evidencia (multipart; genera PDF y lo envía al admin)
  Future<void> completarConEvidencia({
    required Tarea tarea,
    required Uint8List foto,
    required String nombreArchivo,
    String? observaciones,
    String? nombreEmpleado,
  }) async {
    final asig = tarea.asignacion;
    final form = FormData.fromMap({
      'evidencia': MultipartFile.fromBytes(foto, filename: nombreArchivo),
      'tipoactividad': tarea.actividad,
      if (tarea.fechaprogramada.isNotEmpty) 'fechaprogramada': tarea.fechaprogramada,
      if ((observaciones ?? '').isNotEmpty) 'observaciones': observaciones,
      if ((nombreEmpleado ?? '').isNotEmpty) 'nombreEmpleado': nombreEmpleado,
      if (tarea.lote.isNotEmpty) 'lote': tarea.lote,
      if (asig != null) 'idasigtarea': '${asig['idasigtarea']}',
      'at': _ahora(),
    });
    await Api.i.dio.post('/api/v1/tareas/${tarea.idtarea}/completar-con-evidencia', data: form);
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

  /// PUT /asignacion-tarea/{id}: horas/jornadas trabajadas o estado.
  Future<void> actualizarAsignacion(int idasigtarea, Map<String, dynamic> data) async {
    await Api.i.dio.put('/asignacion-tarea/$idasigtarea', data: data);
  }

  // ── Insumos usados en una tarea (detalle-tarea) ─────────────────────────
  Future<List<Map<String, dynamic>>> insumosDeTarea(int idtarea) => _list('/detalle-tarea/tarea/$idtarea');

  /// Descuenta stock del insumo (el backend no permite stock negativo).
  Future<void> registrarInsumoUsado(int idtarea, Map<String, dynamic> data) async {
    await Api.i.dio.post('/detalle-tarea', data: {...data, 'idtarea': idtarea});
  }

  Future<void> eliminarInsumoUsado(int iddetalle) async {
    await Api.i.dio.delete('/detalle-tarea/$iddetalle');
  }

  // ── Insumos ─────────────────────────────────────────────────────────────
  /// POST /api/v1/insumos/{id}/compras
  Future<void> registrarCompra(dynamic idinsumo, Map<String, dynamic> data) async {
    await Api.i.dio.post('/api/v1/insumos/$idinsumo/compras',
        data: {...data, 'actualizarCostoUnitario': true});
  }

  /// GET /api/v1/insumos/compras?idinsumo=
  Future<List<Map<String, dynamic>>> comprasInsumo(int idinsumo) =>
      _list('/api/v1/insumos/compras', query: {'idinsumo': idinsumo});

  Future<List<MapEntry<dynamic, String>>> insumosOpc() async => [
        for (final i in await _list('/api/v1/insumos'))
          MapEntry(i['idinsumo'],
              '${i['nombre'] ?? 'Insumo #${i['idinsumo']}'} (${_num(i['stockactual'])} ${i['unidadmedida'] ?? ''} disp.)'.trim()),
      ];

  static String _num(dynamic v) {
    final x = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(2);
  }

  // ── Plantillas de labores y plan del cultivo ────────────────────────────

  /// Categorías de manejo (ciclo corto, perennes, palma…).
  Future<List<MapEntry<dynamic, String>>> categoriasOpc() async => [
        for (final c in await _list('/api/v1/plantillas/categorias')) MapEntry(c['id'], '${c['nombre']} · ${c['ejemplos']}'),
      ];

  /// Qué tareas se crearían para el cultivo (no crea nada).
  Future<Map<String, dynamic>> planLabores(int idcultivo) async {
    final r = await Api.i.dio.get('/api/v1/plantillas/plan/$idcultivo');
    return (r.data as Map).cast<String, dynamic>();
  }

  /// Crea las tareas elegidas del plan; devuelve cuántas se crearon.
  Future<int> generarPlan(int idcultivo, List<int> ids) async {
    final r = await Api.i.dio.post('/api/v1/plantillas/plan/$idcultivo', data: {'ids': ids});
    return ((r.data as Map)['creadas'] as num?)?.toInt() ?? 0;
  }

  /// A quién conviene asignar la tarea: {numpersonas, sugerencias:[{idusuario, nombre, foto, puntaje, motivos}]}.
  Future<Map<String, dynamic>> sugerenciasAsignacion(int idtarea) async {
    final r = await Api.i.dio.get('/api/v1/tareas/$idtarea/sugerencias');
    return (r.data as Map).cast<String, dynamic>();
  }

  /// manual | sugerida | automatica
  Future<String> modoAsignacion() async {
    final r = await Api.i.dio.get('/api/v1/tareas/config/modo-asignacion');
    return ((r.data as Map)['modo'] ?? 'sugerida').toString();
  }

  Future<void> cambiarModoAsignacion(String modo) async {
    await Api.i.dio.put('/api/v1/tareas/config/modo-asignacion', data: {'modo': modo});
  }

  /// Plantillas propias de la finca.
  Future<List<Map<String, dynamic>>> plantillas() => _list('/api/v1/plantillas');

  Future<void> adoptarCategoria(String categoria) async {
    await Api.i.dio.post('/api/v1/plantillas/adoptar', data: {'categoria': categoria});
  }

  Future<void> crearPlantilla(Map<String, dynamic> data) async {
    await Api.i.dio.post('/api/v1/plantillas', data: data);
  }

  Future<void> actualizarPlantilla(int id, Map<String, dynamic> data) async {
    await Api.i.dio.put('/api/v1/plantillas/$id', data: data);
  }

  /// Opciones de cultivo para selects.
  Future<List<MapEntry<dynamic, String>>> cultivosOpc() async => [
        for (final c in await _list('/cultivos'))
          MapEntry(c['idcultivo'],
              '${c['tipo'] ?? ''}'.isEmpty ? 'Cultivo #${c['idcultivo']}' : '${c['tipo']}${'${c['nombrelote'] ?? ''}'.isEmpty ? '' : ' · ${c['nombrelote']}'}'),
      ];

  /// Opciones de empleados activos para asignar tareas.
  Future<List<MapEntry<dynamic, String>>> empleadosOpciones() async => [
        for (final m in await _list('/api/v1/fincas/activa/miembros'))
          if (m['rol'] == 'empleado' && m['activo'] != false)
            MapEntry(m['idusuario'], '${m['primernombre'] ?? ''} ${m['primerapellido'] ?? ''}'.trim()),
      ];
}
