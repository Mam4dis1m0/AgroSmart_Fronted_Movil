import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/operacion_service.dart';

/// Simula un celular sin conexión: toda petición falla como si no hubiera red.
class _SinRed implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

const _scope = 'u1f1';
String _clave(String path) => 'cache:$_scope:$path:{}';

Map<String, dynamic> _tarea({String estado = 'Asignado', Map<String, dynamic>? asig}) => {
      'idtarea': 7,
      'tipoactividad': 'Fertilización',
      'estado': estado,
      'asignacionTareas': [
        {'idasigtarea': 70, 'estado': 'Asignado', 'fechainicio': null, 'fechafin': null, 'horastrabajadas': null, ...?asig},
      ],
    };

Future<Map<String, dynamic>> _cacheTarea(SharedPreferences p) async =>
    (jsonDecode(p.getString(_clave('/api/v1/tareas/7'))!) as Map).cast<String, dynamic>();

void main() {
  late HttpClientAdapter original;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      _clave('/api/v1/tareas'): jsonEncode([_tarea()]),
      _clave('/api/v1/tareas/7'): jsonEncode(_tarea()),
      _clave('/detalle-tarea/tarea/7'): jsonEncode([]),
      _clave('/api/v1/tareas/7/insumos-sugeridos'): jsonEncode([
        {'idinsumo': 11, 'nombre': 'Urea'},
        {'idinsumo': 12, 'nombre': 'Foliar'},
      ]),
    });
    original = Api.i.dio.httpClientAdapter;
    Api.i.dio.httpClientAdapter = _SinRed();
    Api.i.token = 't';
    Api.i.cacheScope = _scope;
  });

  tearDown(() {
    Api.i.dio.httpClientAdapter = original;
    Api.i.token = null;
    Api.i.cacheScope = '';
  });

  test('Iniciar sin red encola la acción con la hora del toque y muestra el cronómetro', () async {
    await OperacionService().iniciarAsignacion(70);

    final p = await SharedPreferences.getInstance();
    final cola = jsonDecode(p.getString('cola_offline')!) as List;
    expect(cola, hasLength(1));
    expect(cola.single['path'], '/api/v1/tareas/70/iniciar');
    expect(DateTime.tryParse(cola.single['data']['at']), isNotNull);

    final t = Tarea(await _cacheTarea(p));
    expect(t.estado, 'En progreso');
    expect(t.enCurso, isTrue);
    expect(t.inicioReal, isNotNull);
  });

  test('Finalizar sin red cierra la asignación, calcula las horas del cronómetro y completa la tarea', () async {
    final inicio = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
    SharedPreferences.setMockInitialValues({
      _clave('/api/v1/tareas'): jsonEncode([_tarea(estado: 'En progreso', asig: {'estado': 'En progreso', 'fechainicio': inicio})]),
      _clave('/api/v1/tareas/7'): jsonEncode(_tarea(estado: 'En progreso', asig: {'estado': 'En progreso', 'fechainicio': inicio})),
    });

    await OperacionService().completarAsignacion(70);

    final p = await SharedPreferences.getInstance();
    final t = Tarea(await _cacheTarea(p));
    expect(t.completada, isTrue);
    expect(t.enCurso, isFalse);
    expect(t.asignacion!['horastrabajadas'], closeTo(2, 0.05));
    final lista = jsonDecode(p.getString(_clave('/api/v1/tareas'))!) as List;
    expect(lista.single['estado'], 'Completado');
  });

  test('Con varias asignaciones la tarea no se marca completada hasta que terminen todas', () async {
    final dos = _tarea()..['asignacionTareas'] = [
      {'idasigtarea': 70, 'estado': 'Asignado'},
      {'idasigtarea': 71, 'estado': 'Asignado'},
    ];
    SharedPreferences.setMockInitialValues({
      _clave('/api/v1/tareas'): jsonEncode([dos]),
      _clave('/api/v1/tareas/7'): jsonEncode(dos),
    });

    await OperacionService().completarAsignacion(70);

    final t = Tarea(await _cacheTarea(await SharedPreferences.getInstance()));
    expect(t.completada, isFalse);
    expect(t.asignaciones.firstWhere((a) => a['idasigtarea'] == 70)['estado'], 'Completado');
  });

  test('Registrar un insumo sin red lo muestra como usado y lo quita de las sugerencias', () async {
    await OperacionService().registrarInsumoUsado(7, {'idinsumo': 11, 'cantidadusada': 5}, nombre: 'Urea', unidad: 'kg');

    final p = await SharedPreferences.getInstance();
    final usados = jsonDecode(p.getString(_clave('/detalle-tarea/tarea/7'))!) as List;
    expect(usados.single['idinsumo']['nombre'], 'Urea');
    expect(usados.single['cantidadusada'], 5);
    final sugeridos = jsonDecode(p.getString(_clave('/api/v1/tareas/7/insumos-sugeridos'))!) as List;
    expect(sugeridos.map((x) => x['idinsumo']), [12]);
  });

  test('Una foto tomada sin red se guarda en el celular, se ve completada y se reenvía al volver la red', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('cola_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dir.path);

    final foto = Uint8List.fromList(List.generate(64, (i) => i));
    final enCola = await OperacionService().completarConEvidencia(
      tarea: Tarea(_tarea()), foto: foto, nombreArchivo: 'f.jpg', observaciones: 'Listo',
    );

    expect(enCola, isTrue);
    final p = await SharedPreferences.getInstance();
    final cola = (jsonDecode(p.getString('cola_offline')!) as List).single as Map;
    expect(cola['tipo'], 'subida');
    expect(cola['path'], '/api/v1/tareas/7/completar-con-evidencia');
    final ruta = cola['archivo']['ruta'] as String;
    expect(File(ruta).existsSync(), isTrue);
    expect(Tarea(await _cacheTarea(p)).completada, isTrue);

    // Vuelve la red: se reenvía la foto con la hora original y el archivo temporal se borra
    final enviada = <RequestOptions>[];
    Api.i.dio.httpClientAdapter = _Registra(enviada);
    expect(await Api.i.cola.enviarTodo(Api.i.dio, _scope), 1);

    final form = enviada.single.data as FormData;
    expect(enviada.single.path, '/api/v1/tareas/7/completar-con-evidencia');
    expect(form.files.single.key, 'evidencia');
    expect(form.files.single.value.length, 64);
    expect(form.fields.map((f) => f.key), containsAll(['observaciones', 'idasigtarea', 'at']));
    expect(File(ruta).existsSync(), isFalse);
    expect(Api.i.cola.pendientes.value, 0);
  });
}

/// Simula que ya hay conexión: acepta la petición y la guarda para revisarla.
class _Registra implements HttpClientAdapter {
  _Registra(this.vistas);
  final List<RequestOptions> vistas;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    vistas.add(options);
    return ResponseBody.fromString('{}', 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}
