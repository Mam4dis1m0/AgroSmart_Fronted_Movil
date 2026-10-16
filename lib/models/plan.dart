import 'base.dart';

/// Plan de suscripción (`/api/v1/planes`).
class Plan extends AgroModel {
  const Plan(super.raw);
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(j);

  double get preciomensual => (raw['preciomensual'] as num?)?.toDouble() ?? 0;
  String get descripcion => (raw['descripcion'] ?? '').toString();
  dynamic get maxcultivos => raw['maxcultivos'];
  dynamic get maxempleados => raw['maxempleados'];
  dynamic get maxfincas => raw['maxfincas'];
  dynamic get comisionmarketplace => raw['comisionmarketplace'];
}

/// Suscripción actual de la finca (`/api/v1/suscripcion`).
class Suscripcion extends AgroModel {
  const Suscripcion(super.raw);
  factory Suscripcion.fromJson(Map<String, dynamic> j) => Suscripcion(j);
  String get estado => (raw['estado'] ?? '').toString();
}
