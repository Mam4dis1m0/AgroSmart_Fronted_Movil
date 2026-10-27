import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/views/produccion/produccion_view.dart';

void main() {
  testWidgets('El design system AgroSmart renderiza badges y tarjetas',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgroTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              CropBadge('palma'),
              StatusBadge('activa'),
              AgroCard(child: Text('Hola AgroSmart')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Palma'), findsOneWidget);
    expect(find.text('Activa'), findsOneWidget);
    expect(find.text('Hola AgroSmart'), findsOneWidget);
  });

  testWidgets('La barra distribuye cinco secciones y centra el mercado',
      (WidgetTester tester) async {
    var selected = -1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AgroBottomNav(
            index: 0,
            onTap: (value) => selected = value,
            items: const [
              AgroNavItem('Inicio', Icons.home),
              AgroNavItem('Cultivos', Icons.grass),
              AgroNavItem('Mercado', Icons.storefront, prominent: true),
              AgroNavItem('Tareas', Icons.checklist),
              AgroNavItem('Equipo', Icons.groups_outlined),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Mercado'), findsOneWidget);
    final centers = [
      for (final label in ['Inicio', 'Cultivos', 'Mercado', 'Tareas', 'Equipo'])
        tester.getCenter(find.text(label)).dx,
    ];
    expect((centers[2] - 195).abs(), lessThan(1));
    for (var i = 1; i < centers.length - 1; i++) {
      expect(
        ((centers[i] - centers[i - 1]) - (centers[i + 1] - centers[i])).abs(),
        lessThan(1),
      );
    }
    await tester.tap(find.text('Mercado'));
    expect(selected, 2);
  });

  testWidgets('El formulario permite escribir un tipo de cultivo personalizado',
      (WidgetTester tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showForm(context, 'Nuevo cultivo', const [
                  FieldDef(
                    'tipo',
                    'Tipo de cultivo',
                    type: FT.selectOther,
                    required: true,
                    options: [MapEntry('Maíz', 'Maíz')],
                  ),
                ]);
              },
              child: const Text('Crear cultivo'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Crear cultivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otro (escribir)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Lulo');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(result?['tipo'], 'Lulo');
  });

  testWidgets('El formulario de lote ofrece agregar una foto',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showForm(context, 'Nuevo lote', const [
                FieldDef('imagenurl', 'Foto del lote', type: FT.image),
              ]),
              child: const Text('Crear lote'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Crear lote'));
    await tester.pumpAndSettle();

    expect(find.text('Foto del lote'), findsOneWidget);
    expect(find.text('Tomar o elegir foto'), findsOneWidget);
  });

  testWidgets('La unidad de cosecha ofrece opciones y permite escribir otra',
      (WidgetTester tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showForm(context, 'Nueva cosecha', const [
                  FieldDef(
                    'unidad',
                    'Unidad',
                    type: FT.selectOther,
                    required: true,
                    options: [
                      MapEntry('Caja', 'Caja'),
                      MapEntry('Kilo', 'Kilo'),
                      MapEntry('Canasta', 'Canasta'),
                      MapEntry('Libra', 'Libra'),
                      MapEntry('Racimo', 'Racimo'),
                    ],
                  ),
                ]);
              },
              child: const Text('Crear cosecha'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Crear cosecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Requerido'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<dynamic>));
    await tester.pumpAndSettle();
    expect(find.text('Caja'), findsOneWidget);
    expect(find.text('Kilo'), findsOneWidget);
    expect(find.text('Canasta'), findsOneWidget);
    expect(find.text('Libra'), findsOneWidget);
    expect(find.text('Racimo'), findsOneWidget);
    await tester.tap(find.text('Otro (escribir)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Saco');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(result?['unidad'], 'Saco');
  });

  testWidgets('Un formulario puede mostrar una fecha inicial editable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showForm(
                context,
                'Nueva cosecha',
                const [
                  FieldDef('fechacosecha', 'Fecha', type: FT.date),
                ],
                initial: const {'fechacosecha': '2026-10-27'},
                edit: false,
              ),
              child: const Text('Crear cosecha'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Crear cosecha'));
    await tester.pumpAndSettle();

    final dateField = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(dateField.controller?.text, '2026-10-27');
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('La guía de cultivos explica ciclos y cosechas recurrentes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GuiaCultivosPage())),
    );

    expect(find.text('Conoce tus cultivos'), findsOneWidget);
    expect(find.text('Cultivos de ciclo de siembra'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cultivos permanentes'), 250);
    await tester.pumpAndSettle();
    expect(find.text('Cultivos permanentes'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mango y cítricos'), 250);
    await tester.pumpAndSettle();
    expect(find.text('Mango y cítricos'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Palma de aceite'), 250);
    await tester.pumpAndSettle();
    expect(find.text('Palma de aceite'), findsOneWidget);
  });

  testWidgets('La pestaña Guía aparece primero con icono de ayuda',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TabsPage(
            tabs: {
              'Guía': Text('Ayuda de cultivos'),
              'Lotes': Text('Lotes'),
            },
            tabIcons: {'Guía': Icons.help_outline},
          ),
        ),
      ),
    );

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.tabs.first, isA<Tab>());
    expect((tabBar.tabs.first as Tab).text, 'Guía');
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.text('Ayuda de cultivos'), findsOneWidget);
  });
}
