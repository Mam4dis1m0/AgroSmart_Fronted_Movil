import 'base.dart';

/// Aviso/notificación (`/notificaciones`).
class Notificacion extends AgroModel {
  const Notificacion(super.raw);
  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(j);

  int get idnotificacion => (raw['idnotificacion'] as num?)?.toInt() ?? 0;
  String get titulo => (raw['titulo'] ?? '').toString();
  String get mensaje => (raw['mensaje'] ?? '').toString();
  bool get leida => raw['leida'] == true;
}

/// Evento de auditoría (`/auditoria`).
class EventoAuditoria extends AgroModel {
  const EventoAuditoria(super.raw);
  factory EventoAuditoria.fromJson(Map<String, dynamic> j) => EventoAuditoria(j);

  String get operacion => (raw['operacion'] ?? '').toString();
  String get descripcion => (raw['descripcion'] ?? '').toString();
  String get tabla => (raw['tablaNombre'] ?? raw['tabla_nombre'] ?? '').toString();
  bool get denegado => operacion == 'DENEGADO';
}
