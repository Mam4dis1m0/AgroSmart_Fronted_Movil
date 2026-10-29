import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/views/operacion/tarea_detalle_view.dart';

/// Servidor simulado: responde lo que devolvería el backend y anota las escrituras.
class _Servidor implements HttpClientAdapter {
  final escrituras = <String>[];
  final cuerpos = <dynamic>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final ruta = o.path;
    dynamic r;
    if (o.method != 'GET') {
      escrituras.add('${o.method} $ruta');
      cuerpos.add(o.data);
      r = {'ok': true};
    } else if (ruta == '/api/v1/tareas') {
      r = [_tarea()];
    } else if (ruta == '/api/v1/tareas/7') {
      r = _tarea();
    } else if (ruta == '/api/v1/tareas/7-no-usado') {
      r = {
        'idtarea': 7, 'tipoactividad': 'Fertilización', 'estado': 'En progreso', 'fechaprogramada': '2026-10-28',
        'prioridad': 'Alta', 'horasestimadas': 4, 'costototal': 20000,
        'idcultivo': {'idcultivo': 3, 'tipo': 'Maíz', 'nombrelote': 'Lote 1'},
        'asignacionTareas': [
          {
            'idasigtarea': 70, 'estado': 'En progreso', 'fechainicio': DateTime.now().toUtc().subtract(const Duration(minutes: 20)).toIso8601String(),
            'fechafin': null, 'horastrabajadas': null, 'pagoacordado': 30000,
            'idempleado': {'idusuario': 5, 'idusuario2': {'primernombre': 'Ana', 'primerapellido': 'Gómez'}},
          },
        ],
      };
    } else if (ruta == '/api/v1/tareas/7/insumos-sugeridos') {
      r = [
        {'idinsumo': 11, 'nombre': 'Urea', 'unidad': 'kg', 'cantidad': 12.5, 'stockactual': 40, 'origen': 'plantilla', 'tipoinsumo': 'Fertilizante',
         'candidatos': [{'idinsumo': 11, 'nombre': 'Urea', 'unidadmedida': 'kg', 'stockactual': 40}, {'idinsumo': 12, 'nombre': 'Compost', 'unidadmedida': 'bulto', 'stockactual': 100}]},
        {'idinsumo': null, 'nombre': 'Herbicida', 'unidad': 'L', 'cantidad': null, 'stockactual': null, 'origen': 'plantilla', 'tipoinsumo': 'Herbicida', 'candidatos': []},
      ];
    } else if (ruta == '/api/v1/tareas/7/costos') {
      r = {'estimado': 20000, 'insumos': 0, 'manoObra': 0, 'transporte': 0, 'total': 0};
    } else if (ruta == '/api/v1/insumos') {
      r = [{'idinsumo': 11, 'nombre': 'Urea', 'stockactual': 40, 'unidadmedida': 'kg'}, {'idinsumo': 12, 'nombre': 'Compost', 'stockactual': 100, 'unidadmedida': 'bulto'}, {'idinsumo': 13, 'nombre': 'Sin unidad', 'stockactual': 5, 'unidadmedida': null}];
    } else {
      r = []; // detalle-tarea, evidencias…
    }
    return ResponseBody.fromString(jsonEncode(r), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Future<_Servidor> _abrir(WidgetTester t, String rol) async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  final srv = _Servidor();
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
  await t.pumpWidget(MaterialApp(theme: buildAgroTheme(), home: const TareaDetallePage(idtarea: 7)));
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
  return srv;
}

Map<String, dynamic> _tarea() => {
      'idtarea': 7, 'tipoactividad': 'Fertilización', 'estado': 'En progreso', 'fechaprogramada': '2026-10-28',
      'prioridad': 'Alta', 'horasestimadas': 4, 'costototal': 20000,
      'idcultivo': {'idcultivo': 3, 'tipo': 'Maíz', 'nombrelote': 'Lote 1'},
      'asignacionTareas': [
        {
          'idasigtarea': 70, 'estado': 'En progreso',
          'fechainicio': DateTime.now().toUtc().subtract(const Duration(minutes: 20)).toIso8601String(),
          'fechafin': null, 'horastrabajadas': null, 'pagoacordado': 30000,
          'idempleado': {'idusuario': 5, 'idusuario2': {'primernombre': 'Ana', 'primerapellido': 'Gómez'}},
        },
      ],
    };

void main() {
  for (final rol in ['empleado', 'admin']) {
    group('Detalle de tarea ($rol)', () {
      testWidgets('se dibuja sin errores con cronómetro, sugeridos y evidencia', (t) async {
        await _abrir(t, rol);

        expect(t.takeException(), isNull);
        expect(find.text('Fertilización'), findsWidgets);
        expect(find.text('Sugeridos para esta labor'), findsOneWidget);
        expect(find.text('Urea'), findsOneWidget);
        expect(
          find.text('Agregar foto'),
          rol == 'empleado' ? findsOneWidget : findsNothing,
        );
        await t.pump(const Duration(seconds: 2)); // el cronómetro avanza
        expect(t.takeException(), isNull);
      });

      testWidgets('confirmar un insumo sugerido con un toque lo registra', (t) async {
        final srv = await _abrir(t, rol);

        await t.tap(find.byTooltip('Confirmar').first);
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));

        expect(t.takeException(), isNull);
        expect(srv.escrituras, contains('POST /detalle-tarea'));
        final cuerpo = srv.cuerpos[srv.escrituras.indexOf('POST /detalle-tarea')] as Map;
        expect(cuerpo['idinsumo'], 11);
        expect(cuerpo['cantidadusada'], 12.5);
        expect(cuerpo['idtarea'], 7);
      });

      testWidgets('editar un sugerido abre el formulario, permite cambiar el insumo y registrar', (t) async {
        final srv = await _abrir(t, rol);

        await t.tap(find.text('Urea'));
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
        expect(find.text('Insumo usado'), findsOneWidget);
        await t.pump(const Duration(milliseconds: 500)); // termina de subir la hoja

        await t.tap(find.widgetWithText(FilledButton, 'Registrar'));
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));

        expect(t.takeException(), isNull);
        expect(srv.escrituras, contains('POST /detalle-tarea'));
      });

      testWidgets('el formulario muestra la unidad de medida del insumo y la actualiza al cambiarlo', (t) async {
        await _abrir(t, rol);

        await t.tap(find.text('Urea'));
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));

        expect(find.text('Unidad de medida: kg'), findsOneWidget);
        expect(find.text('kg'), findsOneWidget); // sufijo del campo de cantidad

        await t.tap(find.byType(DropdownButtonFormField<dynamic>));
        await t.pump(const Duration(milliseconds: 500));
        await t.tap(find.textContaining('Compost').last);
        await t.pump(const Duration(milliseconds: 500));

        expect(t.takeException(), isNull);
        expect(find.text('Unidad de medida: bulto'), findsOneWidget);
        expect(find.text('bulto'), findsOneWidget);
      });

      testWidgets('el registro manual indica la unidad al elegir el insumo', (t) async {
        await _abrir(t, rol);

        await t.tap(find.text('Registrar').first);
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text('La unidad de medida aparece al elegir el insumo'), findsOneWidget);

        await t.tap(find.byType(DropdownButtonFormField<dynamic>));
        await t.pump(const Duration(milliseconds: 500));
        await t.tap(find.textContaining('Compost').last);
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text('Unidad de medida: bulto'), findsOneWidget);

        await t.tap(find.byType(DropdownButtonFormField<dynamic>));
        await t.pump(const Duration(milliseconds: 500));
        await t.tap(find.textContaining('Sin unidad').last);
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text('Este insumo no tiene unidad registrada'), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('un sugerido sin insumo ni cantidad pide completarlos en vez de fallar', (t) async {
        await _abrir(t, rol);

        await t.tap(find.byTooltip('Confirmar').last);
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));

        expect(t.takeException(), isNull);
        expect(find.text('Insumo usado'), findsOneWidget);
      });

      testWidgets('el botón Registrar del encabezado abre el formulario manual', (t) async {
        await _abrir(t, rol);

        await t.tap(find.text('Registrar').first);
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));

        expect(t.takeException(), isNull);
        expect(find.text('Registrar insumo usado'), findsOneWidget);
      });
    });
  }

  for (final rol in ['empleado', 'admin']) {
    testWidgets('Completar y registrar tiempo funcionan ($rol)', (t) async {
      final srv = await _abrir(t, rol);

      await t.tap(find.text('Registrar tiempo'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      expect(find.text('Tiempo trabajado'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      expect(srv.escrituras, contains('PUT /asignacion-tarea/70'));

      await t.pump(const Duration(seconds: 6)); // se cierra el aviso «Tiempo registrado», que tapa el botón
      await t.dragUntilVisible(find.text('Marcar como completada'), find.byType(ListView).first, const Offset(0, -300));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Marcar como completada'));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      await t.tap(find.text('Completar').last);
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.takeException(), isNull);
      expect(srv.escrituras, contains('PATCH /api/v1/tareas/70/finalizar'));
    });
  }
}
