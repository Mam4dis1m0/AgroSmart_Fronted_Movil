import 'base.dart';

/// Tarea de campo (`/api/v1/tareas`). Incluye `asignacionTareas` y `idcultivo` anidados.
class Tarea extends AgroModel {
  const Tarea(super.raw);
  factory Tarea.fromJson(Map<String, dynamic> j) => Tarea(j);

  /// Estados que maneja el backend.
  static const estados = ['Pendiente', 'Asignado', 'En progreso', 'Completado'];

  int get idtarea => (raw['idtarea'] as num?)?.toInt() ?? 0;
  String get estado => (raw['estado'] ?? '').toString();
  String get actividad => (raw['tipoactividad'] ?? '').toString();
  String get fechaprogramada {
    final f = (raw['fechaprogramada'] ?? '').toString();
    return f.length >= 10 ? f.substring(0, 10) : f;
  }

  Map<String, dynamic>? get cultivo => raw['idcultivo'] is Map ? (raw['idcultivo'] as Map).cast<String, dynamic>() : null;
  dynamic get idcultivo => cultivo?['idcultivo'] ?? raw['idcultivo'];
  String get cultivoNombre {
    final c = cultivo;
    if (c == null) return '';
    final ref = (c['nombrelote'] ?? '').toString();
    return '${c['tipo'] ?? ''}${ref.isEmpty ? '' : ' · $ref'}';
  }

  String get lote => (cultivo?['nombrelote'] ?? '').toString();

  List<Map<String, dynamic>> get asignaciones => [
        for (final a in (raw['asignacionTareas'] as List?) ?? const []) (a as Map).cast<String, dynamic>(),
      ];

  /// Asignación vigente (la más reciente que no fue reasignada a otra persona).
  Map<String, dynamic>? get asignacion {
    final l = asignaciones.where((a) => a['estado'] != 'Reasignada').toList();
    if (l.isEmpty) return null;
    l.sort((a, b) => ((b['idasigtarea'] as num?) ?? 0).compareTo((a['idasigtarea'] as num?) ?? 0));
    return l.first;
  }

  String get prioridad => (raw['prioridad'] ?? 'Media').toString();

  /// Hora real en que alguien empezó a trabajar la tarea (null si aún no).
  DateTime? get inicioReal => DateTime.tryParse((asignacion?['fechainicio'] ?? raw['fechainicio'] ?? '').toString())?.toLocal();

  /// La asignación vigente ya empezó y no ha terminado: el cronómetro está corriendo.
  bool get enCurso => !completada && asignacion?['fechainicio'] != null && asignacion?['fechafin'] == null;

  /// Pasó la fecha programada y la tarea sigue abierta.
  bool get atrasada {
    if (completada) return false;
    final f = DateTime.tryParse(fechaprogramada);
    if (f == null) return false;
    final hoy = DateTime.now();
    return f.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  double get costoReal => (raw['costoreal'] as num?)?.toDouble() ?? 0;

  String get empleadoNombre {
    final e = asignacion?['idempleado'];
    final u = e is Map ? e['idusuario2'] : null;
    if (u is! Map) return '';
    return '${u['primernombre'] ?? ''} ${u['primerapellido'] ?? ''}'.trim();
  }

  /// Foto de perfil del empleado asignado ('' si no tiene).
  String get empleadoFoto {
    final e = asignacion?['idempleado'];
    final u = e is Map ? e['idusuario2'] : null;
    return u is Map ? (u['fotoperfil']?.toString() ?? '') : '';
  }

  bool get completada => estado.toLowerCase().startsWith('completad');
  bool get pendiente => estado.toLowerCase().startsWith('pendiente');

  /// Fotos de evidencia ya subidas a la tarea (las trae el listado de tareas).
  int get evidencias => (raw['evidencias'] as num?)?.toInt() ?? 0;

  /// Forma plana para el formulario de edición.
  Map<String, dynamic> toForm() => {...raw, 'idcultivo': idcultivo};
}
