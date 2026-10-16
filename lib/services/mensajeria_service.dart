import 'api_client.dart';

const _msj = '/api/v1/mensajeria';

/// Mensajería comprador ↔ vendedor del Marketplace (admin y comprador).
class MensajeriaService {
  Map<String, dynamic> _map(dynamic d) => (d as Map).cast<String, dynamic>();

  /// "Chatear con el vendedor": crea el hilo o devuelve el existente.
  Future<Map<String, dynamic>> abrirHilo(int idlistado, {int? idorden}) async {
    final r = await Api.i.dio.post('$_msj/hilos', data: {'idlistado': idlistado, if (idorden != null) 'idorden': idorden});
    return _map(r.data);
  }

  Future<List<Map<String, dynamic>>> hilos() async {
    final r = await Api.i.dio.get('$_msj/hilos');
    return [for (final h in (r.data as List)) _map(h)];
  }

  Future<Map<String, dynamic>> hilo(int idhilo) async => _map((await Api.i.dio.get('$_msj/hilos/$idhilo')).data);

  /// Mensajes en orden cronológico. [antes] pagina hacia atrás.
  Future<List<Map<String, dynamic>>> mensajes(int idhilo, {int? antes, int limite = 30}) async {
    final r = await Api.i.dio.get('$_msj/hilos/$idhilo/mensajes', queryParameters: {
      if (antes != null) 'antes': antes,
      'limite': limite,
    });
    return [for (final m in (r.data as List)) _map(m)];
  }

  Future<Map<String, dynamic>> enviar(int idhilo, String contenido) async {
    final r = await Api.i.dio.post('$_msj/hilos/$idhilo/mensajes', data: {'contenido': contenido});
    return _map(r.data);
  }

  Future<void> marcarLeidos(int idhilo) async {
    await Api.i.dio.patch('$_msj/hilos/$idhilo/leidos');
  }

  Future<int> noLeidos() async {
    final r = await Api.i.dio.get('$_msj/no-leidos');
    return (r.data is Map ? (r.data['total'] as num?)?.toInt() : null) ?? 0;
  }
}
