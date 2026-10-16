import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/theme.dart';

void main() {
  testWidgets('El design system AgroSmart renderiza badges y tarjetas', (WidgetTester tester) async {
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
}
