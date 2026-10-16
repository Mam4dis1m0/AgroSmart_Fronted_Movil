import 'base.dart';

/// Lote de la finca (`/lotes`).
class Lote extends AgroModel {
  const Lote(super.raw);
  factory Lote.fromJson(Map<String, dynamic> j) => Lote(j);
  int get idlote => (raw['idlote'] as num?)?.toInt() ?? 0;
}

/// Cultivo sembrado en un lote (`/cultivos`).
class Cultivo extends AgroModel {
  const Cultivo(super.raw);
  factory Cultivo.fromJson(Map<String, dynamic> j) => Cultivo(j);
  int get idcultivo => (raw['idcultivo'] as num?)?.toInt() ?? 0;
  dynamic get idlote => raw['idlote'];
}

/// Cosecha registrada (`/api/v1/cosechas`).
class Cosecha extends AgroModel {
  const Cosecha(super.raw);
  factory Cosecha.fromJson(Map<String, dynamic> j) => Cosecha(j);
  int get idcosecha => (raw['idcosecha'] as num?)?.toInt() ?? 0;
}

/// Palma registrada (`/palmas`).
class Palma extends AgroModel {
  const Palma(super.raw);
  factory Palma.fromJson(Map<String, dynamic> j) => Palma(j);
  int get idpalma => (raw['idpalma'] as num?)?.toInt() ?? 0;
}

/// Producción de palma (`/produccion-palma`).
class ProduccionPalma extends AgroModel {
  const ProduccionPalma(super.raw);
  factory ProduccionPalma.fromJson(Map<String, dynamic> j) => ProduccionPalma(j);
  int get idproduccion => (raw['idproduccion'] as num?)?.toInt() ?? 0;
}

/// Insumo / inventario (`/api/v1/insumos`).
class Insumo extends AgroModel {
  const Insumo(super.raw);
  factory Insumo.fromJson(Map<String, dynamic> j) => Insumo(j);
  int get idinsumo => (raw['idinsumo'] as num?)?.toInt() ?? 0;
  double get stock => (raw['stock'] as num?)?.toDouble() ?? 0;
}
