import 'api_client.dart';

/// Asistente IA (función Premium).
class ChatService {
  static const _system =
      'Eres el asistente de AgroSmart, experto en agronomía y gestión de fincas en Colombia. Responde en español, claro y breve.';

  /// Envía el historial [{role, content}] y devuelve la respuesta en texto.
  Future<String> enviar(List<Map<String, String>> messages) async {
    final r = await Api.i.dio.post('/api/v1/chat', data: {
      'system': _system,
      'messages': messages,
    });
    final content = r.data['content'] as List;
    if (content.isEmpty) return '';
    return '${content.first['text']}';
  }
}
