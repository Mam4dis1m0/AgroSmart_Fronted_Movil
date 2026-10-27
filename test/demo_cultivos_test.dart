import 'package:flutter_test/flutter_test.dart';
import 'package:agrosmart_proto/services/demo/demo_data.dart';

void main() {
  test('Los datos de demostración muestran varios cultivos y lotes', () {
    final cultivos =
        (demoGet('/cultivos', const {}) as List).cast<Map<String, dynamic>>();
    final lotes =
        (demoGet('/lotes', const {}) as List).cast<Map<String, dynamic>>();
    final resumen = (demoGet('/api/v1/fincas/dashboard', const {}) as List)
        .cast<Map<String, dynamic>>()
        .first;

    expect(cultivos, hasLength(6));
    expect(lotes, hasLength(6));
    expect(resumen['cultivos'], cultivos.length);
    expect(cultivos.map((cultivo) => cultivo['tipo']), contains('Maíz'));
    expect(cultivos.map((cultivo) => cultivo['tipo']), contains('Mango'));
    expect(cultivos.every((cultivo) => cultivo['idlote'] is Map), isTrue);
    expect(
      cultivos.every((cultivo) => !cultivo.containsKey('fechacosechaestimada')),
      isTrue,
    );
  });

  test('El mismo cultivo permanente tiene varias cosechas de ejemplo', () {
    final cosechas = (demoGet('/api/v1/cosechas', const {}) as List)
        .cast<Map<String, dynamic>>();
    final cosechasMango = cosechas
        .where((cosecha) => (cosecha['idcultivo'] as Map)['tipo'] == 'Mango')
        .toList();

    expect(cosechas, hasLength(6));
    expect(cosechasMango, hasLength(2));
    expect(
      cosechasMango.map((cosecha) => cosecha['fechacosecha']).toSet(),
      hasLength(2),
    );
  });
}
