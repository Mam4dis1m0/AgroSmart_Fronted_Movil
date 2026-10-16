import 'base.dart';

/// Finca / tenant (`GET /api/v1/fincas/activa`, listas de fincas del usuario).
class Finca extends AgroModel {
  const Finca(super.raw);
  factory Finca.fromJson(Map<String, dynamic> j) => Finca(j);

  int get idfinca => (raw['idfinca'] as num?)?.toInt() ?? 0;
  @override
  String get nombre => (raw['nombre'] ?? 'Mi finca').toString();
  String get ubicacion => (raw['ubicacion'] ?? '').toString();
  String get rol => (raw['rol'] ?? '').toString();
  String get plan => (raw['plan'] ?? '').toString();
}
