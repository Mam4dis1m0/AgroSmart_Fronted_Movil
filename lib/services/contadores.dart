import 'package:flutter/foundation.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'api_client.dart';

/// Contadores de no leídos para las insignias de la navegación.
class Contadores {
  final ValueNotifier<int> avisos = ValueNotifier(0);
  final ValueNotifier<int> mensajes = ValueNotifier(0);

  Future<void> refrescar() async {
    if (!session.logged) return;
    try {
      final r = await Api.i.dio.get('/notificaciones/no-leidas');
      avisos.value = r.data is List ? (r.data as List).length : 0;
    } catch (_) {}
    if (session.esComprador || esAdmin) {
      try {
        final r = await Api.i.dio.get('/api/v1/mensajeria/no-leidos');
        mensajes.value = r.data is Map ? ((r.data['total'] as num?)?.toInt() ?? 0) : 0;
      } catch (_) {}
    }
  }

  void limpiar() {
    avisos.value = 0;
    mensajes.value = 0;
  }
}

final contadores = Contadores();
