import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:another_telephony/telephony.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'mensajeria_service.dart';
import 'sms_protocolo.dart';

final _mensajeria = MensajeriaService();

/// true: el mensaje sale como SMS de DATOS: solo lo recibe AgroSmart y NO aparece en la app de
/// Mensajes. false: SMS de texto normal `AS|id|texto` (visible en Mensajes); sirve para comparar
/// si algún operador bloqueara los SMS de datos.
const bool kSmsSoloDatos = true;

/// Puente con el código nativo (DataSmsPlugin.kt): envía SMS de datos y entrega los recibidos.
const MethodChannel _canal = MethodChannel('agrosmart/datasms');

/// Mensajería por SMS dentro de la app (solo Android).
///
/// Sin internet, el chat envía el mensaje por SMS al número del contacto, SIN abrir
/// la app de mensajes. Formato del SMS: `AS|<idhilo>|<texto>`.
/// Los SMS entrantes con ese formato se guardan en el celular y se muestran en el
/// mismo chat. Al volver el internet, lo enviado por SMS se sube al servidor.
class SmsService {
  final _nuevos = StreamController<Map<String, dynamic>>.broadcast();

  /// `{ idhilo, mensaje }` cuando llega un SMS del chat con la app abierta.
  Stream<Map<String, dynamic>> get nuevos => _nuevos.stream;

  bool _escuchando = false;
  bool _permiso = false;
  bool _canalListo = false;
  bool _drenando = false;
  bool _repetir = false;

  /// El código nativo avisa ('nuevo') cuando llega un SMS de datos con la app abierta o en segundo plano.
  void _enlazarCanal() {
    if (_canalListo) return;
    _canalListo = true;
    _canal.setMethodCallHandler((call) async {
      if (call.method == 'nuevo') await _drenar();
      return null;
    });
  }

  /// Lee los SMS de datos guardados por el sistema (también los que llegaron con la app cerrada).
  Future<void> _drenar() async {
    if (_drenando) {
      _repetir = true;
      return;
    }
    _drenando = true;
    try {
      do {
        _repetir = false;
        await _drenarUna();
      } while (_repetir);
    } finally {
      _drenando = false;
    }
  }

  Future<void> _drenarUna() async {
    List<dynamic> lista;
    try {
      lista = await _canal.invokeMethod<List<dynamic>>('bandeja') ?? const [];
    } catch (_) {
      return; // sin módulo nativo (otra plataforma) o nada que leer
    }
    for (final e in lista) {
      try {
        final m = (e as Map).cast<String, dynamic>();
        final r = await _procesarDatos('${m['a']}', m['d'] as Uint8List, (m['t'] as num?)?.toInt());
        if (r != null) _nuevos.add(r);
      } catch (_) {}
    }
  }

  bool get disponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<SharedPreferences> _prefs() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // el receptor en segundo plano escribe en otro isolate
    await p.setString('sms_scope', Api.i.cacheScope);
    return p;
  }

  /// Activa la escucha de SMS entrantes. Pide permisos solo si [pedir] es true
  /// o si el usuario ya los había concedido antes.
  Future<void> iniciar({bool pedir = false}) async {
    if (!disponible) return;
    _enlazarCanal();
    unawaited(_drenar()); // SMS de datos que llegaron con la app cerrada
    final p = await SharedPreferences.getInstance();
    if (!pedir && p.getBool('sms_ok') != true) return;
    try {
      _permiso = (await Telephony.instance.requestPhoneAndSmsPermissions) ?? false;
    } catch (_) {
      _permiso = false;
    }
    await p.setBool('sms_ok', _permiso);
    if (!_permiso || _escuchando) return;
    _escuchando = true;
    try {
      Telephony.instance.listenIncomingSms(
        onNewMessage: (m) async {
          final r = await _procesarEntrante(m.address, m.body, m.date);
          if (r != null) _nuevos.add(r);
        },
        onBackgroundMessage: smsBackgroundHandler,
        listenInBackground: true,
      );
    } catch (_) {
      _escuchando = false;
    }
  }

  Future<String?> telefonoDe(int idhilo) async {
    final p = await _prefs();
    return p.getString(_k(Api.i.cacheScope, idhilo, 'tel'));
  }

  Future<void> guardarTelefono(int idhilo, String? tel) async {
    if (tel == null || tel.trim().isEmpty) return;
    final p = await _prefs();
    await p.setString(_k(Api.i.cacheScope, idhilo, 'tel'), tel.trim());
  }

  Future<List<Map<String, dynamic>>> locales(int idhilo) async {
    await _drenar();
    final p = await _prefs();
    final l = _leerLista(p, _k(Api.i.cacheScope, idhilo, 'msgs'));
    l.sort((a, b) => '${a['createdAt']}'.compareTo('${b['createdAt']}'));
    return l;
  }

  /// Envía [texto] por SMS (sin salir de la app) y lo guarda en el chat local.
  Future<Map<String, dynamic>> enviar(int idhilo, String texto) async {
    if (!disponible) throw 'El envío por SMS solo está disponible en Android.';
    final tel = await telefonoDe(idhilo);
    if (tel == null || tel.isEmpty) {
      throw 'No hay número guardado de este contacto. Abre el chat una vez con internet.';
    }
    if (texto.length > 300) throw 'Sin internet, el mensaje puede tener hasta 300 caracteres.';
    await iniciar(pedir: true);
    if (!_permiso) throw 'Activa el permiso de SMS para AgroSmart en los ajustes del celular.';

    // El SMS sale por la línea móvil, no por internet: sin señal (o en modo avión) no se puede.
    try {
      final st = await Telephony.instance.serviceState;
      if (st == ServiceState.POWER_OFF || st == ServiceState.OUT_OF_SERVICE) {
        throw 'Sin señal de celular. El SMS necesita señal móvil: no funciona en modo avión ni sin cobertura. Apaga solo el Wi-Fi y los datos.';
      }
    } on String {
      rethrow;
    } catch (_) {}

    if (kSmsSoloDatos) {
      await _enviarDatos(tel, idhilo, texto);
    } else {
      await _enviarTexto(tel, idhilo, texto);
    }

    final m = <String, dynamic>{
      'idmensaje': null,
      'mio': true,
      'contenido': texto,
      'createdAt': DateTime.now().toIso8601String(),
      'sms': true,
      'pendiente': true, // falta subirlo al servidor
      'smsId': 'out-${DateTime.now().microsecondsSinceEpoch}',
    };
    await _agregarLocal(Api.i.cacheScope, idhilo, m);
    return m;
  }

  /// SMS de datos: sale por la línea móvil hacia el puerto de AgroSmart del otro celular.
  /// No pasa por la app de Mensajes, ni en el que envía ni en el que recibe.
  Future<void> _enviarDatos(String tel, int idhilo, String texto) async {
    final destino = tel.replaceAll(RegExp(r'[^\d+]'), '');
    final List<Uint8List> partes;
    try {
      partes = codificarSms(idhilo, Random().nextInt(0x100000000), texto);
    } on FormatException {
      throw 'El mensaje es demasiado largo para enviarlo por SMS. Acórtalo.';
    }
    for (final d in partes) {
      Map<dynamic, dynamic>? r;
      try {
        r = await _canal.invokeMethod<Map<dynamic, dynamic>>(
            'enviar', {'destino': destino, 'puerto': kSmsPuerto, 'datos': d});
      } on MissingPluginException {
        throw 'Falta el módulo nativo del SMS de datos (ver PASOS_SMS_OCULTO.md).';
      } on PlatformException {
        throw 'Android no permite enviar SMS. Activa el permiso "Enviar SMS" para AgroSmart en Ajustes > Aplicaciones > Permisos.';
      }
      if (r == null || r['ok'] != true) {
        throw 'No se pudo enviar el SMS. Revisa la señal móvil y el saldo de la SIM.';
      }
    }
  }

  /// SMS de texto normal (visible en la app de Mensajes). Solo si [kSmsSoloDatos] es false.
  Future<void> _enviarTexto(String tel, int idhilo, String texto) async {
    final largo = texto.length > 60;
    final enviado = Completer<bool>();
    try {
      await Telephony.instance.sendSms(
        to: tel,
        message: 'AS|$idhilo|$texto',
        isMultipart: largo, // un SMS corto va simple; el plugin no siempre avisa SENT en multiparte
        statusListener: (s) {
          if (s == SendStatus.SENT && !enviado.isCompleted) enviado.complete(true);
        },
      );
    } catch (_) {
      throw 'Android no permite enviar SMS. Activa el permiso "Enviar SMS" para AgroSmart en Ajustes > Aplicaciones > Permisos.';
    }
    // SMS corto: se exige la confirmación de Android. SMS largo (multiparte): el plugin a veces no
    // avisa, así que se da por enviado si no hubo error.
    final ok = await enviado.future.timeout(Duration(seconds: largo ? 4 : 10), onTimeout: () => false);
    if (!ok && !largo) throw 'No se pudo enviar el SMS. Revisa la señal móvil y el saldo de la SIM.';
  }

  /// Quita de lo local los SMS que el servidor ya tiene (evita duplicados).
  Future<void> reconciliar(int idhilo, List<Map<String, dynamic>> servidor) async {
    final p = await _prefs();
    final k = _k(Api.i.cacheScope, idhilo, 'msgs');
    final l = _leerLista(p, k);
    final antes = l.length;
    l.removeWhere((m) =>
        m['pendiente'] != true &&
        servidor.any((s) => s['contenido'] == m['contenido'] && (s['mio'] == true) == (m['mio'] == true)));
    if (l.length != antes) await p.setString(k, jsonEncode(l));
  }

  /// Sube al servidor lo que se envió por SMS mientras no había internet.
  Future<int> flushPendientes({int? idhilo}) async {
    final p = await _prefs();
    final scope = Api.i.cacheScope;
    final ids = idhilo != null
        ? [idhilo]
        : (p.getStringList('sms:$scope:hilos') ?? []).map(int.tryParse).whereType<int>().toList();
    var n = 0;
    for (final id in ids) {
      final k = _k(scope, id, 'msgs');
      final l = _leerLista(p, k);
      for (final m in l.where((m) => m['mio'] == true && m['pendiente'] == true).toList()) {
        try {
          await _mensajeria.enviar(id, '${m['contenido']}');
          l.remove(m);
          n++;
        } on DioException catch (e) {
          if (e.response == null) break; // sigue sin red
          m['pendiente'] = false; // el servidor lo rechazó; queda solo como SMS
        }
      }
      await p.setString(k, jsonEncode(l));
    }
    return n;
  }
}

// ---------------------------------------------------------------------------
// Utilidades (también las usa el receptor en segundo plano).
// ---------------------------------------------------------------------------

String _digitos(String? t) {
  final d = (t ?? '').replaceAll(RegExp(r'\D'), '');
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

String _k(String scope, int idhilo, String campo) => 'sms:$scope:$idhilo:$campo';

List<Map<String, dynamic>> _leerLista(SharedPreferences p, String k) {
  final raw = p.getString(k);
  if (raw == null) return [];
  try {
    return (jsonDecode(raw) as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  } catch (_) {
    return [];
  }
}

Future<bool> _agregarLocal(String scope, int idhilo, Map<String, dynamic> m) async {
  final p = await SharedPreferences.getInstance();
  await p.reload();
  final k = _k(scope, idhilo, 'msgs');
  final l = _leerLista(p, k);
  if (l.any((x) => x['smsId'] == m['smsId'])) return false;
  l.add(m);
  await p.setString(k, jsonEncode(l));
  final ik = 'sms:$scope:hilos';
  final ids = p.getStringList(ik) ?? [];
  if (!ids.contains('$idhilo')) await p.setStringList(ik, [...ids, '$idhilo']);
  return true;
}

/// Si el SMS es del chat (`AS|idhilo|texto`) y viene del número del contacto, lo guarda.
Future<Map<String, dynamic>?> _procesarEntrante(String? address, String? body, int? date) async {
  if (body == null || !body.startsWith('AS|')) return null;
  final partes = body.split('|');
  if (partes.length < 3) return null;
  final idhilo = int.tryParse(partes[1]);
  if (idhilo == null) return null;
  final p = await SharedPreferences.getInstance();
  await p.reload();
  final scope = p.getString('sms_scope') ?? '';
  final tel = p.getString(_k(scope, idhilo, 'tel'));
  // El chat debe existir en este celular. Si el número no coincide con el del perfil (otra SIM,
  // datos de prueba) el mensaje se guarda igual, marcado como «sin verificar».
  if (tel == null) return null;
  final verificado = _digitos(address) == _digitos(tel);
  final texto = partes.sublist(2).join('|');
  final ms = date ?? DateTime.now().millisecondsSinceEpoch;
  final m = <String, dynamic>{
    'idmensaje': null,
    'mio': false,
    'contenido': texto,
    'createdAt': DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String(),
    'sms': true,
    'smsId': 'in-$ms-${texto.hashCode}',
    if (!verificado) 'sinVerificar': true,
  };
  await _agregarLocal(scope, idhilo, m);
  return {'idhilo': idhilo, 'mensaje': m};
}

Map<String, dynamic>? _leerMapa(SharedPreferences p, String k) {
  final raw = p.getString(k);
  if (raw == null) return null;
  try {
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
}

/// SMS de datos de AgroSmart: rearma el mensaje (puede venir en varios SMS) y lo guarda en el chat.
/// Devuelve null si no es de AgroSmart, si faltan partes o si el mensaje ya estaba guardado.
Future<Map<String, dynamic>?> _procesarDatos(String address, Uint8List datos, int? date) async {
  final f = decodificarSms(datos);
  if (f == null) return null;
  final p = await SharedPreferences.getInstance();
  await p.reload();
  final scope = p.getString('sms_scope') ?? '';
  final tel = p.getString(_k(scope, f.idhilo, 'tel'));
  if (tel == null) return null; // chat desconocido en este celular
  final origen = _digitos(address);
  final ahora = DateTime.now().millisecondsSinceEpoch;
  final ens = SmsEnsamblador(_leerMapa(p, 'sms_frag'));
  final texto = ens.agregar(origen, f, ahora);
  ens.limpiar(ahora);
  await p.setString('sms_frag', jsonEncode(ens.toJson()));
  if (texto == null) return null; // faltan partes
  final ms = date ?? ahora;
  final m = <String, dynamic>{
    'idmensaje': null,
    'mio': false,
    'contenido': texto,
    'createdAt': DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String(),
    'sms': true,
    'smsId': 'in-${f.idmsg}-$origen',
    if (origen != _digitos(tel)) 'sinVerificar': true,
  };
  if (!await _agregarLocal(scope, f.idhilo, m)) return null;
  return {'idhilo': f.idhilo, 'mensaje': m};
}

/// Receptor con la app cerrada o en segundo plano.
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage m) async {
  await _procesarEntrante(m.address, m.body, m.date);
}
