import 'base.dart';

/// Listado publicado en el marketplace (`/api/v1/marketplace/listados`).
class Listado extends AgroModel {
  const Listado(super.raw);
  factory Listado.fromJson(Map<String, dynamic> j) => Listado(j);

  int get idlistado => (raw['idlistado'] as num?)?.toInt() ?? 0;
  double get precio => (raw['precio'] as num?)?.toDouble() ?? 0;
  String get estado => (raw['estado'] ?? '').toString();
}

/// Orden de compra/venta del marketplace.
class Orden extends AgroModel {
  const Orden(super.raw);
  factory Orden.fromJson(Map<String, dynamic> j) => Orden(j);

  int get idorden => (raw['idorden'] as num?)?.toInt() ?? 0;
  String get estado => (raw['estado'] ?? '').toString();
  double get total => (raw['total'] as num?)?.toDouble() ?? 0;
}

/// Ítem del carrito de compras.
class ItemCarrito extends AgroModel {
  const ItemCarrito(super.raw);
  factory ItemCarrito.fromJson(Map<String, dynamic> j) => ItemCarrito(j);

  int get idcarrito => (raw['idcarrito'] as num?)?.toInt() ?? 0;
  double get cantidad => (raw['cantidad'] as num?)?.toDouble() ?? 0;
}
