import 'package:another_telephony/telephony.dart';

class AgroSmsMessage {
  const AgroSmsMessage({
    required this.remitente,
    required this.idMensaje,
    required this.texto,
  });

  final String remitente;
  final String idMensaje;
  final String texto;
}

/// Escucha SMS mientras el proceso/app está activo. La recepción en background
/// requiere configurar onBackgroundMessage y probar el receptor Android.
class SmsReceiverService {
  final Telephony _telephony = Telephony.instance;

  void escuchar({
    required void Function(AgroSmsMessage mensaje) onMensaje,
  }) {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage sms) {
        final remitente = (sms.address ?? '').trim();
        final contenido = sms.body ?? '';
        if (!contenido.startsWith('AGRO1|')) return;

        final primerSeparador = contenido.indexOf('|');
        final segundoSeparador = contenido.indexOf('|', primerSeparador + 1);
        if (primerSeparador < 0 || segundoSeparador < 0) return;

        final id = contenido.substring(primerSeparador + 1, segundoSeparador);
        final texto = contenido.substring(segundoSeparador + 1);
        if (id.isEmpty || remitente.isEmpty || texto.isEmpty) return;

        // En la app real: validar remitente contra el contacto esperado y
        // deduplicar idMensaje antes de insertar en el historial local.
        onMensaje(AgroSmsMessage(
          remitente: remitente,
          idMensaje: id,
          texto: texto,
        ));
      },
      listenInBackground: false,
    );
  }
}
