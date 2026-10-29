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
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/operacion/plantillas_tab.dart';

class _Servidor implements HttpClientAdapter {
  _Servidor(this.rutas);
  final Map<String, dynamic> rutas;
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

  Map cuerpoDe(String clave) => cuerpos[escrituras.indexOf(clave)] as Map;
}

const _labor = {
  'idplantilla': 9, 'categoria': 'ciclo_corto', 'actividad': 'Fertilización', 'etapa': 'Crecimiento', 'base': 'siembra',
  'diasoffset': 20, 'personasporhectarea': 1.5, 'horasestimadas': 4, 'prioridad': 'Media', 'esrecurrente': true,
  'frecuenciadias': 20, 'diasfin': 80, 'activa': true,
};

Future<_Servidor> _abrir(WidgetTester t, {Map<String, dynamic> extra = const {}}) async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  final srv = _Servidor({
    'GET /api/v1/plantillas': [_labor],
    'GET /api/v1/tareas/config/modo-asignacion': {'modo': 'sugerida'},
    'GET /api/v1/plantillas/categorias': [
      {'id': 'ciclo_corto', 'nombre': 'Ciclo corto', 'ejemplos': 'Maíz, arroz'},
      {'id': 'palma', 'nombre': 'Palma de aceite', 'ejemplos': 'Palma'},
    ],
    ...extra,
  });
  Api.i.dio.httpClientAdapter = srv;
  Api.i.token = 't';
  session.usuario = {'role': 'admin', 'idusuario': 1};
  t.view.physicalSize = const Size(420, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(() {
    Api.i.token = null;
    session.usuario = null;
  });
  await t.pumpWidget(MaterialApp(theme: buildAgroTheme(), home: const Scaffold(body: PlantillasTab())));
  await t.pump(const Duration(milliseconds: 400));
  await t.pump(const Duration(milliseconds: 400));
  return srv;
}

Future<void> _esperar(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _elegirOpcion(WidgetTester t, Finder desplegable, String opcion) async {
  await t.ensureVisible(desplegable);
  await t.tap(desplegable);
  await _esperar(t);
  await t.tap(find.text(opcion).last);
  await _esperar(t);
}

final _etapaCampo = find.widgetWithText(DropdownButtonFormField<dynamic>, 'Etapa');

void main() {
  group('Formulario de labores', () {
    testWidgets('la lista resume las personas por hectárea y las horas para terminar', (t) async {
      await _abrir(t);

      expect(find.text('Fertilización'), findsOneWidget);
      expect(find.textContaining('1,5 personas/ha'), findsOneWidget);
      expect(find.textContaining('4 h'), findsOneWidget);
    });

    testWidgets('al editar, la etapa es una lista de opciones y las personas por hectárea van antes que las horas', (t) async {
      await _abrir(t);
      await t.tap(find.byTooltip('Opciones'));
      await _esperar(t);
      await t.tap(find.text('Editar'));
      await _esperar(t);

      expect(find.text('Editar labor'), findsOneWidget);
      expect(_etapaCampo, findsOneWidget); // un desplegable, no un campo de texto libre
      expect(find.widgetWithText(TextFormField, 'Etapa'), findsNothing);

      final personas = t.getTopLeft(find.widgetWithText(TextFormField, 'Personas sugeridas por hectárea')).dy;
      final horas = t.getTopLeft(find.widgetWithText(TextFormField, 'Horas esperadas para terminar la tarea')).dy;
      final etapa = t.getTopLeft(_etapaCampo).dy;
      expect(etapa, lessThan(personas));
      expect(personas, lessThan(horas));
      expect(find.text('Personas necesarias'), findsNothing);
    });

    testWidgets('las etapas ofrecidas son las del ciclo del cultivo y se puede cambiar de una a otra', (t) async {
      final srv = await _abrir(t);
      await t.tap(find.byTooltip('Opciones'));
      await _esperar(t);
      await t.tap(find.text('Editar'));
      await _esperar(t);

      await t.tap(_etapaCampo);
      await _esperar(t);
      for (final e in ['Preparación', 'Siembra', 'Crecimiento', 'Mantenimiento', 'Cosecha', 'Postcosecha']) {
        expect(find.text(e), findsWidgets, reason: 'falta la etapa $e');
      }
      await t.tap(find.text('Postcosecha').last);
      await _esperar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(t.takeException(), isNull);
      expect(srv.cuerpoDe('PUT /api/v1/plantillas/9')['etapa'], 'Postcosecha');
    });

    testWidgets('«Repetir hasta» se puede dejar vacío al editar y se envía como null', (t) async {
      final srv = await _abrir(t);
      await t.tap(find.byTooltip('Opciones'));
      await _esperar(t);
      await t.tap(find.text('Editar'));
      await _esperar(t);

      await t.enterText(find.widgetWithText(TextFormField, 'Repetir hasta (días desde esa fecha)'), '');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      final cuerpo = srv.cuerpoDe('PUT /api/v1/plantillas/9');
      expect(cuerpo.containsKey('diasfin'), isTrue);
      expect(cuerpo['diasfin'], isNull);
      expect(cuerpo['frecuenciadias'], 20); // lo que no se tocó se conserva
    });

    testWidgets('las personas por hectárea y las horas son obligatorias', (t) async {
      final srv = await _abrir(t);
      await t.tap(find.byTooltip('Opciones'));
      await _esperar(t);
      await t.tap(find.text('Editar'));
      await _esperar(t);

      await t.enterText(find.widgetWithText(TextFormField, 'Personas sugeridas por hectárea'), '');
      await t.enterText(find.widgetWithText(TextFormField, 'Horas esperadas para terminar la tarea'), '');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(find.text('Requerido'), findsNWidgets(2));
      expect(srv.escrituras, isEmpty);
    });

    testWidgets('no acepta menos de 0,1 personas por hectárea ni menos de media hora', (t) async {
      final srv = await _abrir(t);
      await t.tap(find.byTooltip('Opciones'));
      await _esperar(t);
      await t.tap(find.text('Editar'));
      await _esperar(t);

      await t.enterText(find.widgetWithText(TextFormField, 'Personas sugeridas por hectárea'), '0');
      await t.enterText(find.widgetWithText(TextFormField, 'Horas esperadas para terminar la tarea'), '0,2');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(find.textContaining('Debe ser mayor o igual a'), findsNWidgets(2));
      expect(srv.escrituras, isEmpty);
    });
  });

  group('Agregar labores', () {
    testWidgets('ofrece cargar un catálogo o crear una labor propia', (t) async {
      await _abrir(t);

      await t.tap(find.text('Agregar labores'));
      await _esperar(t);

      expect(find.text('Cargar el catálogo de un tipo de cultivo'), findsOneWidget);
      expect(find.text('Crear una labor propia'), findsOneWidget);
    });

    testWidgets('cargar el catálogo solo pregunta la categoría', (t) async {
      final srv = await _abrir(t);

      await t.tap(find.text('Agregar labores'));
      await _esperar(t);
      await t.tap(find.text('Cargar el catálogo de un tipo de cultivo'));
      await _esperar(t);
      await _elegirOpcion(t, find.byType(DropdownButtonFormField<dynamic>), 'Ciclo corto · Maíz, arroz');
      await t.tap(find.widgetWithText(FilledButton, 'Cargar'));
      await _esperar(t);

      expect(srv.cuerpoDe('POST /api/v1/plantillas/adoptar'), {'categoria': 'ciclo_corto'});
    });

    testWidgets('una labor propia se registra con etapa de la lista, personas por hectárea y luego horas', (t) async {
      final srv = await _abrir(t);

      await t.tap(find.text('Agregar labores'));
      await _esperar(t);
      await t.tap(find.text('Crear una labor propia'));
      await _esperar(t);
      expect(find.text('Nueva labor'), findsOneWidget);

      await _elegirOpcion(t, find.widgetWithText(DropdownButtonFormField<dynamic>, 'Categoría de cultivo'), 'Ciclo corto · Maíz, arroz');
      await t.enterText(find.widgetWithText(TextFormField, 'Labor'), 'Aporque');
      await _elegirOpcion(t, _etapaCampo, 'Crecimiento');
      await t.enterText(find.widgetWithText(TextFormField, 'Personas sugeridas por hectárea'), '2');
      await t.enterText(find.widgetWithText(TextFormField, 'Horas esperadas para terminar la tarea'), '6');
      await t.ensureVisible(find.widgetWithText(FilledButton, 'Registrar'));
      await t.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await _esperar(t);

      expect(t.takeException(), isNull);
      final cuerpo = srv.cuerpoDe('POST /api/v1/plantillas');
      expect(cuerpo, {
        'categoria': 'ciclo_corto', 'actividad': 'Aporque', 'etapa': 'Crecimiento', 'base': 'siembra', 'diasoffset': 0,
        'personasporhectarea': 2, 'horasestimadas': 6, 'prioridad': 'Media', 'esrecurrente': false,
      });
    });

    testWidgets('el estado (activa o desactivada) solo aparece al editar, no al crear', (t) async {
      await _abrir(t);

      await t.tap(find.text('Agregar labores'));
      await _esperar(t);
      await t.tap(find.text('Crear una labor propia'));
      await _esperar(t);

      expect(find.widgetWithText(DropdownButtonFormField<dynamic>, 'Estado'), findsNothing);
    });
  });

  group('Campos que se pueden vaciar al editar', () {
    Future<Map<String, dynamic>?> abrir(WidgetTester t, List<FieldDef> campos, Map<String, dynamic> inicial) async {
      Map<String, dynamic>? resultado;
      var cerrado = false;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                resultado = await showForm(c, 'Editar', campos, initial: inicial, edit: true);
                cerrado = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('abrir'));
      await _esperar(t);
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);
      expect(cerrado, isTrue);
      return resultado;
    }

    testWidgets('un campo marcado como vaciable que se deja vacío se envía como null', (t) async {
      final campos = [
        const FieldDef('ubicacion', 'Ubicación', vaciable: true),
        const FieldDef('area', 'Área', type: FT.number, vaciable: true),
      ];
      // Se abre el formulario, se borran ambos campos y se guarda
      Map<String, dynamic>? resultado;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async => resultado = await showForm(c, 'Editar', campos, initial: {'ubicacion': 'Río', 'area': 2.5}, edit: true),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('abrir'));
      await _esperar(t);
      await t.enterText(find.widgetWithText(TextFormField, 'Ubicación'), '');
      await t.enterText(find.widgetWithText(TextFormField, 'Área'), '');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(resultado, {'ubicacion': null, 'area': null});
    });

    testWidgets('sin la marca, vaciar un campo no lo borra: se ignora y conserva el valor que tenía', (t) async {
      Map<String, dynamic>? resultado;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async => resultado = await showForm(c, 'Editar', const [FieldDef('ubicacion', 'Ubicación')],
                  initial: {'ubicacion': 'Río'}, edit: true),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('abrir'));
      await _esperar(t);
      await t.enterText(find.widgetWithText(TextFormField, 'Ubicación'), '');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(resultado, <String, dynamic>{}); // no se envía nada: el servidor conserva «Río»
    });

    testWidgets('un campo vaciable que ya estaba vacío no genera un null innecesario', (t) async {
      final r = await abrir(t, [const FieldDef('ubicacion', 'Ubicación', vaciable: true)], const {});
      expect(r, <String, dynamic>{});
    });

    testWidgets('un campo obligatorio nunca se vacía', (t) async {
      Map<String, dynamic>? resultado;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async => resultado = await showForm(
                  c, 'Editar', const [FieldDef('nombre', 'Nombre', required: true, vaciable: true)],
                  initial: {'nombre': 'Lote Norte'}, edit: true),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('abrir'));
      await _esperar(t);
      await t.enterText(find.widgetWithText(TextFormField, 'Nombre'), '');
      await t.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await _esperar(t);

      expect(find.text('Requerido'), findsOneWidget);
      expect(resultado, isNull);
    });
  });
}
