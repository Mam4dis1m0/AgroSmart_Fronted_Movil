import 'base.dart';

/// Costo agregado por cultivo (`/api/v1/reportes/costos`).
class CostoCultivo extends AgroModel {
  const CostoCultivo(super.raw);
  factory CostoCultivo.fromJson(Map<String, dynamic> j) => CostoCultivo(j);

  dynamic get idcultivo => raw['idcultivo'];
  String get cultivo => (raw['cultivo'] ?? '').toString();
  double get total => (raw['total'] as num?)?.toDouble() ?? 0;
  double get costoInsumos => (raw['costo_insumos'] as num?)?.toDouble() ?? 0;
  double get costoManoObra => (raw['costo_mano_obra'] as num?)?.toDouble() ?? 0;
}
