import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'sms_service.dart';

enum ChatChannel { internet, sms }

/// Decide el canal al enviar. Guarda el mensaje localmente ANTES de llamar
/// a este servicio desde la UI para no perderlo si el envío falla.
class ChatTransportService {
  ChatTransportService({
    required Dio api,
    required String baseUrl,
    required SmsService sms,
  })  : _api = api,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _sms = sms;

  final Dio _api;
  final String _baseUrl;
  final SmsService _sms;

  Future<bool> hayInternetDisponible() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none)) return false;

      // Connectivity indica tipo de red, no garantiza que Internet funcione.
      final response = await _api.get(
        '$_baseUrl/health',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

 Future<ChatChannel> enviarMensaje({
  required String telefono,
  required String texto,
  required String idMensaje,
  required int idhilo,
}) async {
  if (texto.trim().isEmpty) {
    throw ArgumentError('El mensaje está vacío.');
  }

  if (idMensaje.trim().isEmpty) {
    throw ArgumentError('idMensaje es obligatorio.');
  }

  if (await hayInternetDisponible()) {
    await _api.post(
      '$_baseUrl/chat/messages',
      data: {
        'idMensaje': idMensaje,
        'telefonoDestino': telefono,
        'texto': texto,
        'canal': 'INTERNET',
      },
    );

    return ChatChannel.internet;
  }

  // Guardar el número del contacto asociado al hilo.
  await _sms.guardarTelefono(idhilo, telefono);

  // SmsService construye el formato del mensaje internamente.
  await _sms.enviar(idhilo, texto);

  return ChatChannel.sms;
}
}
