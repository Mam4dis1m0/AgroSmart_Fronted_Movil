import 'base.dart';

/// Nómina / jornales de un periodo (`/api/v1/nomina`).
class Nomina extends AgroModel {
  const Nomina(super.raw);
  factory Nomina.fromJson(Map<String, dynamic> j) => Nomina(j);

  int get idnomina => (raw['idnomina'] as num?)?.toInt() ?? 0;
  String get estado => (raw['estado'] ?? '').toString();
  double get total => (raw['total'] as num?)?.toDouble() ?? 0;
  dynamic get fechainicio => raw['fechainicio'];
  dynamic get fechafin => raw['fechafin'];
}
