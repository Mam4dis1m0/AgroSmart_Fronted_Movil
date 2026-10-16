import 'api_client.dart';

const _mkt = '/api/v1/marketplace';

/// Marketplace: catálogo de ofertas, órdenes, carrito y favoritos.
class MarketplaceService {
  Future<List<Map<String, dynamic>>> listados({
    String? q,
    String? categoria,
    double? lat,
    double? lng,
    int? radioKm,
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await Api.i.getList('$_mkt/listados', query: {
      if ((q ?? '').isNotEmpty) 'q': q,
      if ((categoria ?? '').isNotEmpty) 'categoria': categoria,
      if (lat != null && lng != null) ...{'lat': lat, 'lng': lng, 'radioKm': radioKm ?? 50},
      'limit': limit,
      'offset': offset,
    });
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<Map<String, dynamic>> listado(int id) async {
    final r = await Api.i.dio.get('$_mkt/listados/$id');
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> crearOrden(Map<String, dynamic> data) async {
    await Api.i.dio.post('$_mkt/ordenes', data: data);
  }

  Future<void> agregarAlCarrito(dynamic idlistado, num cantidad) async {
    await Api.i.dio.put('$_mkt/carrito', data: {'idlistado': idlistado, 'cantidad': cantidad});
  }

  Future<void> agregarFavorito(dynamic idlistado) async {
    await Api.i.dio.post('$_mkt/wishlist', data: {'idlistado': idlistado});
  }

  Future<void> quitarFavorito(dynamic idlistado) async {
    await Api.i.dio.delete('$_mkt/wishlist/$idlistado');
  }

  Future<List<Map<String, dynamic>>> misCompras() async {
    final rows = await Api.i.getList('$_mkt/ordenes/mis-compras');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<List<Map<String, dynamic>>> ventas() async {
    final rows = await Api.i.getList('$_mkt/ordenes/ventas');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<void> cancelarOrden(dynamic idorden) async {
    await Api.i.dio.patch('$_mkt/ordenes/$idorden/cancelar');
  }

  Future<void> accionOrden(dynamic idorden, String accion) async {
    await Api.i.dio.patch('$_mkt/ordenes/$idorden/$accion');
  }

  Future<List<Map<String, dynamic>>> carrito() async {
    final rows = await Api.i.getList('$_mkt/carrito');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<void> quitarDelCarrito(dynamic idlistado) async {
    await Api.i.dio.delete('$_mkt/carrito/$idlistado');
  }

  Future<void> ordenarCarrito() async {
    await Api.i.dio.post('$_mkt/carrito/ordenar');
  }

  Future<List<Map<String, dynamic>>> favoritos() async {
    final rows = await Api.i.getList('$_mkt/wishlist');
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<void> actualizarListado(dynamic idlistado, Map<String, dynamic> data) async {
    await Api.i.dio.put('$_mkt/listados/$idlistado', data: data);
  }

  Future<void> destacarListado(dynamic idlistado) async {
    await Api.i.dio.post('$_mkt/listados/$idlistado/destacar');
  }

  Future<String> subirFoto(String base64) async {
    final r = await Api.i.dio.post('$_mkt/fotos', data: {'imagen': base64});
    return '${r.data['url']}';
  }
}
