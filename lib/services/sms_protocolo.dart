import 'dart:convert';
import 'dart:typed_data';

/// Protocolo de los SMS de datos de AgroSmart.
///
/// Un SMS de datos va a un PUERTO de la app y Android lo entrega a AgroSmart: NO se guarda
/// ni se muestra en la app de Mensajes. Cada SMS admite 140 bytes (133 con puerto), así que un
/// mensaje largo se parte en varios SMS y se rearma al recibirlo.
///
/// Este archivo no depende de Flutter para poder probarse solo.

/// Puerto de la app. DEBE ser el mismo `android:port` del receptor en AndroidManifest.xml.
const int kSmsPuerto = 6170;

/// Bytes por SMS de datos. El límite real es 133; se deja margen.
const int kSmsMaxDatos = 128;

/// Máximo de SMS en los que se parte un mensaje.
const int kSmsMaxPartes = 8;

const int _kMagia = 0x41; // 'A'
const int _kCabecera = 11; // magia(1) + idhilo(4) + idmsg(4) + parte(1) + total(1)

/// Un SMS de datos ya interpretado.
class SmsFragmento {
  final int idhilo;
  final int idmsg;
  final int parte;
  final int total;
  final String texto;
  const SmsFragmento(this.idhilo, this.idmsg, this.parte, this.total, this.texto);
}

/// Parte [texto] en SMS de datos de máximo [kSmsMaxDatos] bytes. Nunca corta un carácter
/// (tildes, ñ o emojis) por la mitad. Lanza [FormatException] si no cabe en [kSmsMaxPartes].
List<Uint8List> codificarSms(int idhilo, int idmsg, String texto) {
  final maxTexto = kSmsMaxDatos - _kCabecera;
  final trozos = <List<int>>[];
  var actual = <int>[];
  for (final r in texto.runes) {
    final b = utf8.encode(String.fromCharCode(r));
    if (actual.length + b.length > maxTexto) {
      trozos.add(actual);
      actual = <int>[];
    }
    actual.addAll(b);
  }
  if (actual.isNotEmpty || trozos.isEmpty) trozos.add(actual);
  if (trozos.length > kSmsMaxPartes) {
    throw const FormatException('El mensaje es demasiado largo para enviarlo por SMS.');
  }
  final total = trozos.length;
  final salida = <Uint8List>[];
  for (var i = 0; i < total; i++) {
    final c = trozos[i];
    final d = Uint8List(_kCabecera + c.length);
    final bd = ByteData.sublistView(d);
    bd.setUint8(0, _kMagia);
    bd.setUint32(1, idhilo);
    bd.setUint32(5, idmsg);
    bd.setUint8(9, i);
    bd.setUint8(10, total);
    d.setRange(_kCabecera, d.length, c);
    salida.add(d);
  }
  return salida;
}

/// Interpreta un SMS de datos recibido. Devuelve null si no es de AgroSmart o viene dañado.
SmsFragmento? decodificarSms(Uint8List b) {
  if (b.length <= _kCabecera || b[0] != _kMagia) return null;
  final bd = ByteData.sublistView(b);
  final parte = bd.getUint8(9);
  final total = bd.getUint8(10);
  if (total == 0 || total > kSmsMaxPartes || parte >= total) return null;
  String texto;
  try {
    texto = utf8.decode(b.sublist(_kCabecera));
  } catch (_) {
    return null;
  }
  return SmsFragmento(bd.getUint32(1), bd.getUint32(5), parte, total, texto);
}

/// Junta los SMS de un mismo mensaje, lleguen en el orden que lleguen y aunque se repitan.
/// Su estado se puede guardar (toJson) para seguir cuando la app se cierra entre un SMS y otro.
class SmsEnsamblador {
  final Map<String, Map<String, dynamic>> _pend = {};

  SmsEnsamblador([Map<String, dynamic>? previo]) {
    if (previo == null) return;
    previo.forEach((k, v) {
      if (v is Map) _pend[k] = v.cast<String, dynamic>();
    });
  }

  /// Agrega un fragmento. Devuelve el texto completo cuando ya llegaron todas las partes
  /// (y lo quita del estado); si faltan partes, devuelve null.
  String? agregar(String origen, SmsFragmento f, int ahoraMs) {
    final k = '$origen|${f.idhilo}|${f.idmsg}';
    final e = _pend.putIfAbsent(k, () => <String, dynamic>{'n': f.total, 't': ahoraMs, 'p': <String, dynamic>{}});
    if (e['n'] != f.total) {
      // Mismo identificador pero otro total: es un mensaje distinto; se empieza de nuevo.
      e['n'] = f.total;
      e['t'] = ahoraMs;
      e['p'] = <String, dynamic>{};
    }
    final p = (e['p'] as Map).cast<String, dynamic>();
    p['${f.parte}'] = f.texto;
    e['p'] = p;
    if (p.length < f.total) return null;
    final sb = StringBuffer();
    for (var i = 0; i < f.total; i++) {
      final t = p['$i'];
      if (t == null) return null;
      sb.write(t);
    }
    _pend.remove(k);
    return sb.toString();
  }

  /// Descarta mensajes incompletos de hace más de [maxEdadMs] (por defecto 2 días).
  void limpiar(int ahoraMs, {int maxEdadMs = 172800000}) {
    _pend.removeWhere((_, e) => ahoraMs - ((e['t'] as num?)?.toInt() ?? 0) > maxEdadMs);
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_pend);
}
