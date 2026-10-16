import 'base.dart';

/// Tarea de campo (`/api/v1/tareas`).
class Tarea extends AgroModel {
  const Tarea(super.raw);
  factory Tarea.fromJson(Map<String, dynamic> j) => Tarea(j);

  int get idtarea => (raw['idtarea'] as num?)?.toInt() ?? 0;
  String get estado => (raw['estado'] ?? '').toString();
  dynamic get idcultivo => raw['idcultivo'];
  dynamic get idempleado => raw['idempleado'];

  bool get completada => estado.toLowerCase().startsWith('completad');
  bool get pendiente => estado.toLowerCase().startsWith('pendiente');
}
