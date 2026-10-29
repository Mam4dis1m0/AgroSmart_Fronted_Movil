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

  /// PATCH /api/v1/tareas/{idasigtarea}/finalizar — el id es el de la ASIGNACIÓN.
  /// `at` es la hora real del toque: si no hay red la petición se encola y el servidor respeta esta hora.
  Future<void> completarAsignacion(int idasigtarea) async {
    final ahora = DateTime.now();
    final r = await Api.i.dio.patch('/api/v1/tareas/$idasigtarea/finalizar', data: {'at': _iso(ahora)});
    if (_encolado(r)) await _reflejar(idasigtarea, (a) => _cerrar(a, ahora));
  }

  /// PATCH /api/v1/tareas/{idasigtarea}/iniciar — marca la hora de inicio (cronómetro).
  Future<void> iniciarAsignacion(int idasigtarea) async {
    final ahora = DateTime.now();
    final r = await Api.i.dio.patch('/api/v1/tareas/$idasigtarea/iniciar', data: {'at': _iso(ahora)});
    if (_encolado(r)) {
      await _reflejar(idasigtarea, (a) {
        a['estado'] = 'En progreso';
        a['fechainicio'] ??= _iso(ahora);
      });
    }
  }

  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  /// La petición no llegó al servidor: quedó en la cola para enviarse al volver la red.
  static bool _encolado(Response r) => r.data is Map && (r.data as Map)['encolado'] == true;

  /// Cierra la asignación como lo hará el servidor: hora de fin y horas del cronómetro (si no hay horas digitadas).
  static void _cerrar(Map a, DateTime fin) {
    a['estado'] = 'Completado';
    a['fechafin'] ??= _iso(fin);
    final ini = DateTime.tryParse('${a['fechainicio'] ?? ''}');
    if (ini != null && ((a['horastrabajadas'] as num?) ?? 0) == 0) {
      final h = fin.difference(ini.toLocal()).inSeconds / 3600;
      a['horastrabajadas'] = (h < 0 ? 0 : (h * 100).round() / 100);
    }
  }

  /// Refleja en lo guardado (lista y detalle de la tarea) algo hecho sin red, para que la pantalla
  /// lo muestre ya; al volver la conexión la cola lo envía y la lectura real lo confirma.
  Future<void> _reflejar(int idasigtarea, void Function(Map asignacion) cambiar) async {
    bool aplicar(Map tarea) {
      final l = tarea['asignacionTareas'];
      if (l is! List) return false;
      for (final a in l) {
        if (a is Map && (a['idasigtarea'] as num?)?.toInt() == idasigtarea) {
          cambiar(a);
          final vigentes = l.whereType<Map>().where((x) => x['estado'] != 'Reasignada').toList();
          if (vigentes.every((x) => x['estado'] == 'Completado')) {
            tarea['estado'] = 'Completado';
          } else if (vigentes.any((x) => x['fechainicio'] != null && x['estado'] != 'Completado')) {
            tarea['estado'] = 'En progreso';
          }
          return true;
        }
      }
      return false;
    }

    int? idtarea;
    await Api.i.parchearCache('/api/v1/tareas', (d) {
      if (d is List) {
        for (final t in d) {
          if (t is Map && aplicar(t)) idtarea = (t['idtarea'] as num).toInt();
        }
      }
      return d;
    });
    if (idtarea != null) {
      await Api.i.parchearCache('/api/v1/tareas/$idtarea', (d) {
        if (d is Map) aplicar(d);
        return d;
      });
    }
  }

  /// POST /api/v1/tareas/{id}/completar-con-evidencia (multipart; genera PDF y lo envía al admin).
  /// Devuelve true si quedó guardado en el celular para enviarse al volver la red.
  Future<bool> completarConEvidencia({
    required Tarea tarea,
    required Uint8List foto,
    required String nombreArchivo,
    String? observaciones,
  }) async {
    final asig = tarea.asignacion;
    final ahora = DateTime.now();
    final campos = <String, String>{
      if ((observaciones ?? '').isNotEmpty) 'observaciones': observaciones!,
      if (asig != null) 'idasigtarea': '${asig['idasigtarea']}',
      'at': _iso(ahora),
    };
    final ruta = '/api/v1/tareas/${tarea.idtarea}/completar-con-evidencia';
    try {
      await Api.i.dio.post(ruta, data: FormData.fromMap({
        ...campos,
        'evidencia': MultipartFile.fromBytes(foto, filename: nombreArchivo),
      }));
      return false;
    } catch (e) {
      if (!Api.esErrorDeRed(e)) rethrow;
      await Api.i.cola.agregarSubida(
        scope: Api.i.cacheScope, path: ruta, campos: campos, campoArchivo: 'evidencia', bytes: foto, nombreArchivo: nombreArchivo,
      );
      Api.i.offline.value = true;
      if (asig != null) await _reflejar((asig['idasigtarea'] as num).toInt(), (a) => _cerrar(a, ahora));
      return true;
    }
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
    final r = await Api.i.dio.put('/asignacion-tarea/$idasigtarea', data: data);
    if (_encolado(r)) await _reflejar(idasigtarea, (a) => a.addAll(data));
  }

  // ── Insumos usados en una tarea (detalle-tarea) ─────────────────────────
  Future<List<Map<String, dynamic>>> insumosDeTarea(int idtarea) => _list('/detalle-tarea/tarea/$idtarea');

  /// Descuenta stock del insumo (el backend no permite stock negativo).
  Future<void> registrarInsumoUsado(int idtarea, Map<String, dynamic> data, {String? nombre, String? unidad}) async {
    final r = await Api.i.dio.post('/detalle-tarea', data: {...data, 'idtarea': idtarea});
    if (!_encolado(r)) return;
    // Sin red: aparece ya en «Insumos usados» y deja de sugerirse
    await Api.i.parchearCache('/detalle-tarea/tarea/$idtarea', (d) => [
          if (d is List) ...d,
          {
            'iddetalletarea': -DateTime.now().millisecondsSinceEpoch,
            'idinsumo': {'idinsumo': data['idinsumo'], 'nombre': nombre ?? 'Insumo', 'unidadmedida': unidad ?? ''},
            'cantidadusada': data['cantidadusada'],
            '_offline': true,
          },
        ]);
    await Api.i.parchearCache('/api/v1/tareas/$idtarea/insumos-sugeridos', (d) =>
        d is List ? d.where((x) => !(x is Map && x['idinsumo'] == data['idinsumo'])).toList() : d);
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

  /// Insumos de la finca para elegir en un formulario, con la unidad de medida de cada uno.
  Future<({List<MapEntry<dynamic, String>> opciones, Map<dynamic, String> unidades})> insumosConUnidad() async {
    final l = await _list('/api/v1/insumos');
    return (
      opciones: [
        for (final i in l)
          MapEntry(i['idinsumo'], '${i['nombre'] ?? 'Insumo #${i['idinsumo']}'} (${_num(i['stockactual'])} ${i['unidadmedida'] ?? ''} disp.)'.trim()),
      ],
      unidades: {
        for (final i in l)
          if ('${i['unidadmedida'] ?? ''}'.trim().isNotEmpty) i['idinsumo']: '${i['unidadmedida']}'.trim(),
      },
    );
  }

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
  /// Devuelve -1 si no había red: el plan quedó en cola y las tareas se crean al volver la conexión.
  Future<int> generarPlan(int idcultivo, List<int> ids) async {
    final r = await Api.i.dio.post('/api/v1/plantillas/plan/$idcultivo', data: {'ids': ids});
    if (_encolado(r)) return -1;
    return ((r.data as Map)['creadas'] as num?)?.toInt() ?? 0;
  }

  /// A quién conviene asignar la tarea: {numpersonas, sugerencias:[{idusuario, nombre, foto, puntaje, motivos}]}.
  Future<Map<String, dynamic>> sugerenciasAsignacion(int idtarea) async {
    final r = await Api.i.dio.get('/api/v1/tareas/$idtarea/sugerencias');
    return (r.data as Map).cast<String, dynamic>();
  }

  /// Fotos guardadas en la tarea.
  Future<List<Map<String, dynamic>>> evidencias(int idtarea) => _list('/api/v1/tareas/$idtarea/evidencias');

  /// Agrega una foto a la tarea sin completarla.
  /// Devuelve true si no había red y la foto quedó guardada en el celular para enviarse después.
  Future<bool> agregarEvidencia(int idtarea, {required Uint8List foto, required String nombreArchivo, String? observaciones}) async {
    final campos = <String, String>{if ((observaciones ?? '').isNotEmpty) 'observaciones': observaciones!};
    final ruta = '/api/v1/tareas/$idtarea/evidencias';
    try {
      await Api.i.dio.post(ruta, data: FormData.fromMap({
        ...campos,
        'evidencia': MultipartFile.fromBytes(foto, filename: nombreArchivo),
      }));
      return false;
    } catch (e) {
      if (!Api.esErrorDeRed(e)) rethrow;
      await Api.i.cola.agregarSubida(
        scope: Api.i.cacheScope, path: ruta, campos: campos, campoArchivo: 'evidencia', bytes: foto, nombreArchivo: nombreArchivo,
      );
      Api.i.offline.value = true;
      return true;
    }
  }

  /// Insumos que suele gastar esta labor, con cantidad propuesta (plantilla o historial de la finca).
  Future<List<Map<String, dynamic>>> insumosSugeridos(int idtarea) => _list('/api/v1/tareas/$idtarea/insumos-sugeridos');

  /// Pago propuesto al asignar: {modalidad, sugerido, base, detalle, muestras}.
  Future<Map<String, dynamic>> pagoSugerido(int idtarea, int idempleado) async {
    final r = await Api.i.dio.get('/api/v1/tareas/$idtarea/pago-sugerido', queryParameters: {'idempleado': idempleado});
    return (r.data as Map).cast<String, dynamic>();
  }

  /// Desglose de costos: {estimado, insumos, manoObra, transporte, total}.
  Future<Map<String, dynamic>> costosTarea(int idtarea) async {
    final r = await Api.i.dio.get('/api/v1/tareas/$idtarea/costos');
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
