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
    final d = r.data;
    final content = d is Map ? d['content'] : null;
    if (content is List && content.isNotEmpty) return '${content.first['text'] ?? ''}';
    if (d is Map && d['message'] != null) return '${d['message']}';
    return '';
  }
}
