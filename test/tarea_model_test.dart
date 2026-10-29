import 'package:flutter_test/flutter_test.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/views/operacion/agenda_view.dart';

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  final hoy = DateTime.now();

  test('Una tarea abierta con fecha pasada está atrasada; completada o futura, no', () {
    final ayer = _ymd(hoy.subtract(const Duration(days: 1)));
    final manana = _ymd(hoy.add(const Duration(days: 1)));

    expect(Tarea({'estado': 'Pendiente', 'fechaprogramada': ayer}).atrasada, isTrue);
    expect(Tarea({'estado': 'Completado', 'fechaprogramada': ayer}).atrasada, isFalse);
    expect(Tarea({'estado': 'Asignado', 'fechaprogramada': manana}).atrasada, isFalse);
    expect(Tarea({'estado': 'Asignado', 'fechaprogramada': _ymd(hoy)}).atrasada, isFalse);
    expect(const Tarea({'estado': 'Pendiente'}).atrasada, isFalse);
  });

  test('La asignación vigente ignora las reasignadas', () {
    const t = Tarea({
      'estado': 'Asignado',
      'asignacionTareas': [
        {'idasigtarea': 5, 'estado': 'Reasignada'},
        {'idasigtarea': 3, 'estado': 'Asignado'},
      ],
    });
    expect(t.asignacion?['idasigtarea'], 3);
  });

  test('El cronómetro corre solo si la asignación empezó y no ha terminado', () {
    const iniciada = Tarea({
      'estado': 'En progreso',
      'asignacionTareas': [
        {'idasigtarea': 1, 'estado': 'En progreso', 'fechainicio': '2026-10-27T10:00:00.000Z', 'fechafin': null},
      ],
    });
    expect(iniciada.enCurso, isTrue);
    expect(iniciada.inicioReal, isNotNull);

    const terminada = Tarea({
      'estado': 'Completado',
      'asignacionTareas': [
        {'idasigtarea': 1, 'fechainicio': '2026-10-27T10:00:00.000Z', 'fechafin': '2026-10-27T12:00:00.000Z'},
      ],
    });
    expect(terminada.enCurso, isFalse);

    expect(const Tarea({'estado': 'Asignado', 'asignacionTareas': [{'idasigtarea': 1}]}).enCurso, isFalse);
  });

  test('La semana de la agenda empieza el lunes', () {
    expect(inicioSemana(DateTime(2026, 10, 28, 15, 30)), DateTime(2026, 10, 26)); // miércoles
    expect(inicioSemana(DateTime(2026, 10, 26)), DateTime(2026, 10, 26)); // lunes
    expect(inicioSemana(DateTime(2026, 11, 1)), DateTime(2026, 10, 26)); // domingo
  });
}
