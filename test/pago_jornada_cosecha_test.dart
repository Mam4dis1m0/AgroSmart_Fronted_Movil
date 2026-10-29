import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/views/equipo/jornada_card.dart';
import 'package:agrosmart_proto/views/nomina/nomina_view.dart';
import 'package:agrosmart_proto/views/operacion/tarea_detalle_view.dart';

/// Servidor simulado: responde lo que devolvería el backend y anota las escrituras.
class _Servidor implements HttpClientAdapter {
  _Servidor(this.rutas);
  final Map<String, dynamic> rutas; // 'GET /ruta' → respuesta
  final escrituras = <String>[];
  final cuerpos = <dynamic>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final clave = '${o.method} ${o.path}';
    if (o.method != 'GET') {
      escrituras.add(clave);
      cuerpos.add(o.data);
    }
    final r = rutas[clave] ?? (o.method == 'GET' ? [] : {'ok': true});
    return ResponseBody.fromString(jsonEncode(r), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}

  Object? cuerpoDe(String clave) => cuerpos[escrituras.indexOf(clave)];
}

Future<_Servidor> _preparar(WidgetTester t, Map<String, dynamic> rutas, Widget home, {String rol = 'admin'}) async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  final srv = _Servidor(rutas);
  Api.i.dio.httpClientAdapter = srv;
  Api.i.token = 't';
  session.usuario = {'role': rol, 'idusuario': 5};
  t.view.physicalSize = const Size(420, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(() {
    Api.i.token = null;
    session.usuario = null;
  });
  await t.pumpWidget(MaterialApp(theme: buildAgroTheme(), home: home));
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
  return srv;
}

Future<void> _esperar(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Map<String, dynamic> _tarea({String actividad = 'Cosecha', String? etapa = 'Cosecha'}) => {
      'idtarea': 7, 'tipoactividad': actividad, 'estado': 'En progreso', 'fechaprogramada': '2026-10-28',
      'prioridad': 'Alta', 'horasestimadas': 16, 'etapa': etapa,
      'idcultivo': {'idcultivo': 3, 'tipo': 'Maíz', 'nombrelote': 'Lote 1'},
      'asignacionTareas': [
        {
          'idasigtarea': 70, 'estado': 'En progreso',
          'fechainicio': DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
          'fechafin': null, 'horastrabajadas': null, 'pagoacordado': 30000,
          'idempleado': {'idusuario': 5, 'idusuario2': {'primernombre': 'Ana', 'primerapellido': 'Gómez'}},
        },
      ],
    };

void main() {
  group('Tarea de cosecha', () {
    test('se reconoce por la etapa o por el nombre de la actividad', () {
      expect(Tarea(_tarea()).esCosecha, isTrue);
      expect(Tarea(_tarea(actividad: 'Cosecha de racimos', etapa: null)).esCosecha, isTrue);
      expect(Tarea(_tarea(actividad: 'Fertilización', etapa: 'Crecimiento')).esCosecha, isFalse);
    });

    testWidgets('al completarla pide lo recolectado y lo envía junto con la finalización', (t) async {
      final srv = await _preparar(t, {'GET /api/v1/tareas/7': _tarea()}, const TareaDetallePage(idtarea: 7), rol: 'empleado');

      await t.dragUntilVisible(find.text('Marcar como completada'), find.byType(ListView).first, const Offset(0, -300));
      await t.tap(find.text('Marcar como completada'));
      await _esperar(t);
      await t.tap(find.text('Completar').last);
      await _esperar(t);

      expect(find.text('Lo recolectado'), findsOneWidget);
      expect(srv.escrituras, isEmpty); // todavía no se completó: falta la cantidad

      await t.enterText(find.widgetWithText(TextFormField, 'Cantidad recolectada'), '120,5');
      await t.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await _esperar(t);

      expect(t.takeException(), isNull);
      expect(srv.escrituras, contains('PATCH /api/v1/tareas/70/finalizar'));
      final cuerpo = srv.cuerpoDe('PATCH /api/v1/tareas/70/finalizar') as Map;
      expect(cuerpo['cosecha'], {'cantidad': 120.5, 'unidad': 'Kilo'});
      expect(DateTime.tryParse(cuerpo['at']), isNotNull);
    });

    testWidgets('si se cierra el formulario de lo recolectado la tarea no se completa', (t) async {
      final srv = await _preparar(t, {'GET /api/v1/tareas/7': _tarea()}, const TareaDetallePage(idtarea: 7), rol: 'empleado');

      await t.dragUntilVisible(find.text('Marcar como completada'), find.byType(ListView).first, const Offset(0, -300));
      await t.tap(find.text('Marcar como completada'));
      await _esperar(t);
      await t.tap(find.text('Completar').last);
      await _esperar(t);
      await t.tapAt(const Offset(10, 10)); // toca fuera de la hoja
      await _esperar(t);

      expect(srv.escrituras, isEmpty);
    });

    testWidgets('una tarea de cosecha sin cultivo avisa que lo recolectado no quedará registrado', (t) async {
      final sinCultivo = {..._tarea(), 'idcultivo': null};
      final srv = await _preparar(t, {'GET /api/v1/tareas/7': sinCultivo}, const TareaDetallePage(idtarea: 7), rol: 'empleado');

      await t.dragUntilVisible(find.text('Marcar como completada'), find.byType(ListView).first, const Offset(0, -300));
      await t.tap(find.text('Marcar como completada'));
      await _esperar(t);
      await t.tap(find.text('Completar').last);
      await _esperar(t);

      expect(find.text('Tarea sin cultivo'), findsOneWidget);
      expect(find.text('Lo recolectado'), findsNothing); // no pide una cantidad que se perdería
      expect(srv.escrituras, isEmpty);

      await t.tap(find.text('Completar igual'));
      await _esperar(t);

      final cuerpo = srv.cuerpoDe('PATCH /api/v1/tareas/70/finalizar') as Map;
      expect(cuerpo.containsKey('cosecha'), isFalse);
    });

    testWidgets('en esa advertencia se puede cancelar y la tarea queda sin completar', (t) async {
      final sinCultivo = {..._tarea(), 'idcultivo': null};
      final srv = await _preparar(t, {'GET /api/v1/tareas/7': sinCultivo}, const TareaDetallePage(idtarea: 7), rol: 'empleado');

      await t.dragUntilVisible(find.text('Marcar como completada'), find.byType(ListView).first, const Offset(0, -300));
      await t.tap(find.text('Marcar como completada'));
      await _esperar(t);
      await t.tap(find.text('Completar').last);
      await _esperar(t);
      await t.tap(find.text('Cancelar'));
      await _esperar(t);

      expect(srv.escrituras, isEmpty);
    });

    testWidgets('una tarea común se completa sin preguntar por cosecha', (t) async {
      final srv = await _preparar(
        t,
        {'GET /api/v1/tareas/7': _tarea(actividad: 'Fertilización', etapa: 'Crecimiento')},
        const TareaDetallePage(idtarea: 7),
        rol: 'empleado',
      );

      await t.dragUntilVisible(find.text('Marcar como completada'), find.byType(ListView).first, const Offset(0, -300));
      await t.tap(find.text('Marcar como completada'));
      await _esperar(t);
      await t.tap(find.text('Completar').last);
      await _esperar(t);

      expect(find.text('Lo recolectado'), findsNothing);
      final cuerpo = srv.cuerpoDe('PATCH /api/v1/tareas/70/finalizar') as Map;
      expect(cuerpo.containsKey('cosecha'), isFalse);
    });
  });

  group('Tiempo trabajado sin jornales', () {
    testWidgets('el detalle y el formulario solo hablan de horas', (t) async {
      final srv = await _preparar(t, {'GET /api/v1/tareas/7': _tarea()}, const TareaDetallePage(idtarea: 7));

      expect(find.text('Horas trabajadas'), findsOneWidget);
      expect(find.text('Jornales trabajados'), findsNothing);

      await t.tap(find.text('Registrar tiempo'));
      await _esperar(t);
      expect(find.widgetWithText(TextFormField, 'Horas trabajadas'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Jornales trabajados'), findsNothing);
      expect(find.textContaining('no cambia lo que se te paga'), findsOneWidget);
      expect(srv.escrituras, isEmpty);
    });
  });

  group('Sin pago por tarea', () {
    testWidgets('el detalle ya no muestra «Pago acordado» aunque la asignación tenga un valor guardado', (t) async {
      await _preparar(t, {'GET /api/v1/tareas/7': _tarea()}, const TareaDetallePage(idtarea: 7));

      expect(find.text('Pago acordado'), findsNothing);
      expect(find.text('Asignación'), findsOneWidget);
    });
  });

  group('Asignar sin pago', () {
    final sinAsignar = {..._tarea(actividad: 'Fertilización', etapa: 'Crecimiento'), 'asignacionTareas': <dynamic>[]};
    final rutas = <String, dynamic>{
      'GET /api/v1/tareas/7': sinAsignar,
      'GET /api/v1/fincas/activa/miembros': [
        {'idusuario': 5, 'rol': 'empleado', 'activo': true, 'primernombre': 'Ana', 'primerapellido': 'Gómez'},
      ],
      'GET /api/v1/tareas/7/sugerencias': {
        'numpersonas': 1,
        'sugerencias': [
          {'idusuario': 5, 'nombre': 'Ana Gómez', 'foto': '', 'puntaje': 100, 'motivos': ['Sin carga esa semana']},
        ],
      },
    };

    testWidgets('aceptar una sugerencia asigna de una vez, sin pedir ni enviar ningún pago', (t) async {
      final srv = await _preparar(t, rutas, const TareaDetallePage(idtarea: 7));

      await t.tap(find.widgetWithText(FilledButton, 'Asignar'));
      await _esperar(t);
      expect(find.text('Sugerencias del sistema'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Asignar').last);
      await _esperar(t);

      expect(t.takeException(), isNull);
      expect(find.textContaining('Pago'), findsNothing); // ningún formulario de pago
      expect(srv.escrituras, ['PATCH /api/v1/tareas/7/asignar']);
      expect(srv.cuerpoDe('PATCH /api/v1/tareas/7/asignar'), {'idempleado': 5, 'origenasignacion': 'sugerida'});
    });

    testWidgets('elegir a otra persona solo pregunta quién, sin pago', (t) async {
      final srv = await _preparar(t, rutas, const TareaDetallePage(idtarea: 7));

      await t.tap(find.widgetWithText(FilledButton, 'Asignar'));
      await _esperar(t);
      await t.tap(find.text('Elegir a otra persona'));
      await _esperar(t);

      expect(find.text('Asignar tarea'), findsOneWidget);
      expect(find.textContaining('Pago acordado'), findsNothing);

      await t.tap(find.byType(DropdownButtonFormField<dynamic>));
      await _esperar(t);
      await t.tap(find.text('Ana Gómez').last);
      await _esperar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Asignar').last);
      await _esperar(t);

      expect(srv.cuerpoDe('PATCH /api/v1/tareas/7/asignar'), {'idempleado': 5, 'origenasignacion': 'manual'});
    });
  });

  group('Jornada de la finca', () {
    const jornada = {
      'inicio': '07:00', 'fin': '16:00', 'descanso': 60, 'horasJornada': 8, 'personas': 2, 'personasIndicadas': null,
      'empleadosConPago': 2, 'empleadosSinPago': 0, 'pagoDiarioPromedio': 57500, 'pagoDiarioEquipo': 115000, 'costoHora': 7187.5,
    };

    testWidgets('muestra el horario, el pago diario del equipo y el costo promedio por hora', (t) async {
      await _preparar(t, {'GET /api/v1/tareas/config/jornada': jornada}, const Scaffold(body: JornadaCard()));

      expect(find.textContaining('07:00 – 16:00'), findsOneWidget);
      expect(find.text('Costo promedio por hora de mano de obra'), findsOneWidget);
      expect(find.textContaining('No afecta lo que se le paga a nadie'), findsOneWidget);
    });

    testWidgets('sin pagos configurados explica qué falta en vez de mostrar un costo engañoso', (t) async {
      await _preparar(
        t,
        {'GET /api/v1/tareas/config/jornada': {...jornada, 'costoHora': 0, 'empleadosConPago': 0, 'empleadosSinPago': 2}},
        const Scaffold(body: JornadaCard()),
      );

      expect(find.textContaining('Configura el pago de tus empleados'), findsOneWidget);
    });

    testWidgets('se puede cambiar el horario y las personas; el guardado envía números y horas HH:MM', (t) async {
      final srv = await _preparar(t, {'GET /api/v1/tareas/config/jornada': jornada}, const Scaffold(body: JornadaCard()));

      await t.tap(find.textContaining('07:00 – 16:00'));
      await _esperar(t);
      expect(find.text('Jornada de la finca'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget); // la hora de entrada llega precargada

      await t.enterText(find.widgetWithText(TextFormField, 'Personas que trabajan en un día normal'), '5');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(t.takeException(), isNull);
      expect(srv.cuerpoDe('PUT /api/v1/tareas/config/jornada'), {
        'jornadainicio': '07:00', 'jornadafin': '16:00', 'jornadadescanso': 60, 'jornadapersonas': 5,
      });
    });

    testWidgets('dejar vacías las personas envía null (se cuentan todos los empleados)', (t) async {
      final srv = await _preparar(t, {'GET /api/v1/tareas/config/jornada': jornada}, const Scaffold(body: JornadaCard()));

      await t.tap(find.textContaining('07:00 – 16:00'));
      await _esperar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect((srv.cuerpoDe('PUT /api/v1/tareas/config/jornada') as Map)['jornadapersonas'], isNull);
    });
  });

  group('Nómina por período', () {
    Map<String, dynamic> nomina({String tipo = 'dia', num unidades = 18, num valor = 60000}) => {
          'idnomina': 5, 'fechainicio': '2026-10-01', 'fechafin': '2026-10-31', 'estado': 'BORRADOR', 'total': unidades * valor,
          'detalles': <Map<String, dynamic>>[
            {
              'idnominadetalle': 11, 'idempleado': 5, 'primernombre': 'Ana', 'primerapellido': 'Gómez', 'tipopago': tipo,
              'horas': 0, 'jornadas': unidades, 'valorhora': 0, 'valorjornal': valor, 'bruto': unidades * valor,
              'deducciones': 0, 'neto': unidades * valor, 'pagado': false,
            },
          ],
        };

    testWidgets('muestra días × valor del día y deja corregir los días trabajados', (t) async {
      final srv = await _preparar(t, {'GET /api/v1/nomina/5': nomina()}, const NominaDetallePage(idnomina: 5));

      expect(find.text('Días trabajados'), findsOneWidget);
      expect(find.text('Horas'), findsNothing);

      await t.tap(find.text('Ana Gómez'));
      await _esperar(t);
      expect(find.text('Pago de Ana'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Días trabajados'), '19');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(t.takeException(), isNull);
      expect(srv.escrituras, ['PATCH /api/v1/nomina/detalle/11/unidades']);
      expect(srv.cuerpoDe('PATCH /api/v1/nomina/detalle/11/unidades'), {'unidades': 19});
    });

    testWidgets('el pago por mes se rotula en meses y no en horas ni jornales', (t) async {
      await _preparar(t, {'GET /api/v1/nomina/5': nomina(tipo: 'mes', unidades: 1, valor: 1300000)}, const NominaDetallePage(idnomina: 5));

      expect(find.text('Meses'), findsOneWidget);
      expect(find.text('Jornales'), findsNothing);
    });

    testWidgets('solo cambiar deducciones no toca los días', (t) async {
      final srv = await _preparar(t, {'GET /api/v1/nomina/5': nomina()}, const NominaDetallePage(idnomina: 5));

      await t.tap(find.text('Ana Gómez'));
      await _esperar(t);
      await t.enterText(find.widgetWithText(TextFormField, 'Deducciones (COP)'), '50000');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(srv.escrituras, ['PATCH /api/v1/nomina/detalle/11/deducciones']);
    });

    testWidgets('una línea antigua (horas y jornales) solo permite ajustar deducciones', (t) async {
      final antigua = nomina();
      (antigua['detalles'] as List<Map<String, dynamic>>).first
        ..['tipopago'] = null
        ..['horas'] = 40
        ..['valorhora'] = 5000;
      await _preparar(t, {'GET /api/v1/nomina/5': antigua}, const NominaDetallePage(idnomina: 5));

      expect(find.text('Horas'), findsOneWidget);
      await t.tap(find.text('Ana Gómez'));
      await _esperar(t);
      expect(find.widgetWithText(TextFormField, 'Días trabajados'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Deducciones (COP)'), findsOneWidget);
    });
  });
}
