import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrosmart_proto/views/operacion/tareas_view.dart';

Widget _app(Widget hijo, ValueChanged<List<int>?> alCerrar) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () async => alCerrar(await showModalBottomSheet<List<int>>(context: c, isScrollControlled: true, builder: (_) => hijo)),
            child: const Text('abrir'),
          ),
        ),
      ),
    );

const _sug = [
  {'idusuario': 1, 'nombre': 'Ana Gómez', 'foto': '', 'motivos': ['Sin carga esa semana', 'Hizo la vez anterior']},
  {'idusuario': 2, 'nombre': 'Luis Pérez', 'foto': '', 'motivos': ['6 h ya asignadas esa semana']},
  {'idusuario': 3, 'nombre': 'Rosa Díaz', 'foto': '', 'motivos': ['Conoce este cultivo']},
];

void main() {
  testWidgets('Para una persona queda preseleccionada la mejor y elegir otra reemplaza la selección', (t) async {
    List<int>? res;
    await t.pumpWidget(_app(const SelectorSugerido(sugerencias: _sug), (r) => res = r));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    expect(find.textContaining('Hizo la vez anterior'), findsOneWidget);

    await t.tap(find.text('Luis Pérez'));
    await t.pumpAndSettle();
    await t.tap(find.text('Asignar'));
    await t.pumpAndSettle();

    expect(res, [2]);
  });

  testWidgets('Una labor de cuadrilla preselecciona a las N mejores personas', (t) async {
    List<int>? res;
    await t.pumpWidget(_app(const SelectorSugerido(sugerencias: _sug, personas: 2), (r) => res = r));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    expect(find.text('Asignar a 2 personas'), findsOneWidget);
    await t.tap(find.text('Asignar a 2 personas'));
    await t.pumpAndSettle();

    expect(res!..sort(), [1, 2]);
  });

  testWidgets('"Elegir a otra persona" devuelve una lista vacía', (t) async {
    List<int>? res;
    await t.pumpWidget(_app(const SelectorSugerido(sugerencias: _sug), (r) => res = r));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    await t.tap(find.text('Elegir a otra persona'));
    await t.pumpAndSettle();

    expect(res, isEmpty);
  });
}
