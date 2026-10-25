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

  /// Asignación vigente (la más reciente).
  Map<String, dynamic>? get asignacion {
    final l = asignaciones;
    if (l.isEmpty) return null;
    l.sort((a, b) => ((b['idasigtarea'] as num?) ?? 0).compareTo((a['idasigtarea'] as num?) ?? 0));
    return l.first;
  }

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

  /// Forma plana para el formulario de edición.
  Map<String, dynamic> toForm() => {...raw, 'idcultivo': idcultivo};
}
