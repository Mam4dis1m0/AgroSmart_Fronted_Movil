import 'base.dart';

/// Usuario autenticado (`GET /usuarios/me`, respuesta de login).
class Usuario extends AgroModel {
  const Usuario(super.raw);
  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(j);

  int get idusuario => (raw['id'] ?? raw['idusuario'] as num?)?.toInt() ?? 0;
  String get primernombre => (raw['primernombre'] ?? raw['nombre'] ?? '').toString();
  String get primerapellido => (raw['primerapellido'] ?? raw['apellido'] ?? '').toString();
  String get email => (raw['email'] ?? '').toString();
  String get role => (raw['role'] ?? raw['rol'] ?? 'admin').toString();
  String get nombreCompleto => '$primernombre $primerapellido'.trim();
}

/// Miembro/empleado de la finca activa (`GET /api/v1/fincas/activa/miembros`).
class Miembro extends AgroModel {
  const Miembro(super.raw);
  factory Miembro.fromJson(Map<String, dynamic> j) => Miembro(j);

  int get idusuario => (raw['idusuario'] as num?)?.toInt() ?? 0;
  String get primernombre => (raw['primernombre'] ?? '').toString();
  String get primerapellido => (raw['primerapellido'] ?? '').toString();
  String get rol => (raw['rol'] ?? '').toString();
  String get telefono => (raw['telefono'] ?? '').toString();
  bool get activo => raw['activo'] != false;
}
