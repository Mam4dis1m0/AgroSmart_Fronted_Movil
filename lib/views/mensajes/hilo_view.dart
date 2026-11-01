import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/services/socket_service.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'chat_widgets.dart';

/// Momento de un mensaje. Los del servidor traen zona horaria y los de SMS la hora local del
/// celular; al convertirlos a DateTime se pueden comparar entre sí.
DateTime _cuando(Map<String, dynamic> m) =>
    DateTime.tryParse('${m['createdAt']}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);

String _hora(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Conversación comprador ↔ vendedor sobre una oferta, en tiempo real.
///
/// Reglas de envío:
///  - Con Wi-Fi o datos: siempre por la app (internet). Si el servidor no responde NO se manda
///    SMS solo; el texto se queda en la caja y se ofrece «Enviar por SMS».
///  - Sin Wi-Fi ni datos: el texto sale por SMS con el saldo de la SIM, desde la app.
///  - Fotos y audios: con internet suben al servidor; sin conexión quedan pendientes y suben solos.
class HiloPage extends StatefulWidget {
  final Map<String, dynamic> hilo;
  const HiloPage({super.key, required this.hilo});
  @override
  State<HiloPage> createState() => _HiloPageState();
}

class _HiloPageState extends State<HiloPage> {
  final _msgs = <Map<String, dynamic>>[];
  final _sms = <Map<String, dynamic>>[]; // enviados/recibidos por SMS
  final _pend = <Map<String, dynamic>>[]; // fotos/audios esperando conexión
  final _in = TextEditingController();
  final _scroll = ScrollController();
  final _subs = <StreamSubscription>[];
  final _rec = AudioRecorder();

  bool _cargando = true;
  bool _hayMas = true;
  bool _cargandoMas = false;
  bool _enviando = false;
  bool _sinRed = false; // sin Wi-Fi ni datos: único caso en que se usa SMS
  bool _smsDatos = true;
  int _leidoHasta = 0;
  Object? _error;
  String? _telefono;

  bool _grabando = false;
  int _segGrab = 0;
  Timer? _tGrab;

  int get _idhilo => (widget.hilo['idhilo'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarSms();
    _cargarPend();
    smsService.soloDatos().then((v) {
      if (mounted) setState(() => _smsDatos = v);
    });
    Api.i.sinRed().then((v) {
      if (mounted) setState(() => _sinRed = v);
    });
    _subs.add(Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) setState(() => _sinRed = r.every((x) => x == ConnectivityResult.none));
    }));
    _scroll.addListener(() {
      // La lista está invertida: el "final" del scroll son los mensajes más antiguos.
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 80) _cargarAnteriores();
    });
    _subs.add(socketService.nuevos.listen((e) {
      if ((e['idhilo'] as num?)?.toInt() != _idhilo) return;
      final m = (e['mensaje'] as Map).cast<String, dynamic>();
      if (_msgs.any((x) => x['idmensaje'] == m['idmensaje'])) return;
      setState(() => _msgs.add(m));
      if (m['mio'] != true) _marcarLeidos();
      _recargarSms(); // si ya llegó por SMS, se quita la copia local
    }));
    _subs.add(smsService.nuevos.listen((e) {
      if ((e['idhilo'] as num?)?.toInt() != _idhilo) return;
      setState(() => _sms.add((e['mensaje'] as Map).cast<String, dynamic>()));
    }));
    _subs.add(socketService.leidos.listen((e) {
      if ((e['idhilo'] as num?)?.toInt() != _idhilo) return;
      setState(() => _leidoHasta = (e['hasta'] as num?)?.toInt() ?? _leidoHasta);
    }));
    // Un adjunto pendiente subió (o falló): se actualiza la lista de pendientes y los mensajes.
    _subs.add(adjuntosService.cambios.listen((id) {
      if (id != _idhilo) return;
      _cargarPend();
      _cargar();
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _tGrab?.cancel();
    _rec.dispose();
    _in.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Carga ──────────────────────────────────────────────────────────────────

  /// Teléfono del contacto (se guarda con internet) + SMS locales.
  Future<void> _cargarSms() async {
    await smsService.iniciar(pedir: true);
    try {
      final d = await mensajeriaService.hilo(_idhilo);
      await smsService.guardarTelefono(_idhilo, d['otroTelefono']?.toString());
    } catch (_) {}
    final tel = await smsService.telefonoDe(_idhilo);
    final l = await smsService.locales(_idhilo);
    if (!mounted) return;
    setState(() {
      _telefono = tel;
      _sms
        ..clear()
        ..addAll(l);
    });
  }

  Future<void> _recargarSms() async {
    await smsService.reconciliar(_idhilo, _msgs);
    final l = await smsService.locales(_idhilo);
    if (!mounted) return;
    setState(() {
      _sms
        ..clear()
        ..addAll(l);
    });
  }

  Future<void> _cargarPend() async {
    final l = await adjuntosService.pendientes(_idhilo);
    if (!mounted) return;
    setState(() {
      _pend
        ..clear()
        ..addAll(l);
    });
  }

  Future<void> _cargar() async {
    try {
      var l = await mensajeriaService.mensajes(_idhilo);
      // Con internet real: sube lo que se mandó por SMS y los adjuntos que esperaban conexión.
      if (!Api.i.offline.value) {
        final a = await smsService.flushPendientes(idhilo: _idhilo);
        final b = await adjuntosService.flush(idhilo: _idhilo);
        if (a + b > 0) l = await mensajeriaService.mensajes(_idhilo);
      }
      if (!mounted) return;
      setState(() {
        _msgs
          ..clear()
          ..addAll(l);
        _hayMas = l.length >= 30;
        _cargando = false;
        _error = null;
      });
      await _recargarSms();
      _marcarLeidos();
    } catch (e) {
      final locales = await smsService.locales(_idhilo);
      if (mounted) {
        setState(() {
          _sms
            ..clear()
            ..addAll(locales);
          // Sin servidor pero con mensajes por SMS o adjuntos guardados: se muestran, no es un error.
          _error = (locales.isEmpty && _pend.isEmpty) ? e : null;
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cargarAnteriores() async {
    if (!_hayMas || _cargandoMas || _msgs.isEmpty) return;
    _cargandoMas = true;
    try {
      final l = await mensajeriaService.mensajes(_idhilo, antes: (_msgs.first['idmensaje'] as num).toInt());
      if (!mounted) return;
      setState(() {
        _msgs.insertAll(0, l);
        _hayMas = l.length >= 30;
      });
    } catch (_) {
    } finally {
      _cargandoMas = false;
    }
  }

  Future<void> _marcarLeidos() async {
    try {
      await mensajeriaService.marcarLeidos(_idhilo);
      contadores.refrescar();
    } catch (_) {}
  }

  // ── Envío de texto ─────────────────────────────────────────────────────────

  /// Muestra solo los últimos 4 dígitos del número, para confirmar a dónde va el SMS.
  String _enmascarar(String t) {
    final d = t.replaceAll(RegExp(r'\D'), '');
    return d.length <= 4 ? t : '•••${d.substring(d.length - 4)}';
  }

  /// SMS enviado desde la app (sin abrir la app de mensajes del celular).
  Future<void> _enviarPorSms(String t, {bool limpiar = true}) async {
    try {
      final sms = await smsService.enviar(_idhilo, t);
      if (!mounted) return;
      if (limpiar) _in.clear();
      setState(() => _sms.add(sms));
      snack(context, 'SMS enviado al número ${_enmascarar(_telefono ?? '')}');
    } catch (e) {
      if (mounted) snack(context, e is String ? e : Api.errorMsg(e));
    }
  }

  Future<void> _enviar() async {
    final t = _in.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      // 1) Sin Wi-Fi ni datos: es el ÚNICO caso en que se usa SMS (dentro de la app).
      if (await Api.i.sinRed()) {
        await _enviarPorSms(t);
        return;
      }
      // 2) Con red: SIEMPRE por la app (internet). Nunca se cae a SMS en silencio.
      final ct = CancelToken();
      final timer = Timer(const Duration(seconds: 20), () => ct.cancel('timeout'));
      try {
        final m = await mensajeriaService.enviar(_idhilo, t, cancel: ct);
        if (!mounted) return;
        _in.clear();
        setState(() {
          if (!_msgs.any((x) => x['idmensaje'] == m['idmensaje'])) _msgs.add(m);
        });
      } on DioException catch (e) {
        if (e.response != null) rethrow; // el servidor respondió con un error real
        // Hay red pero el servidor no responde: el texto se queda en la caja para reintentar
        // y el SMS se ofrece como opción (no sale solo: tiene costo).
        if (!mounted) return;
        final puedeSms = smsService.disponible && (_telefono ?? '').isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No se pudo enviar: el servidor no responde. Tu mensaje sigue aquí para reintentar.'),
          duration: const Duration(seconds: 8),
          action: puedeSms ? SnackBarAction(label: 'Enviar por SMS', onPressed: () => _enviarPorSms(t)) : null,
        ));
      } finally {
        timer.cancel();
      }
    } catch (e) {
      if (mounted) snack(context, e is String ? e : Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── Fotos y audios ─────────────────────────────────────────────────────────

  Future<void> _menuAdjuntar() async {
    final op = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Cámara'), onTap: () => Navigator.pop(ctx, 'cam')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galería'), onTap: () => Navigator.pop(ctx, 'gal')),
        ]),
      ),
    );
    if (op == null) return;
    try {
      final x = await ImagePicker().pickImage(
        source: op == 'cam' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 75,
      );
      if (x == null) return;
      await _enviarAdjunto(x.path, 'IMAGEN');
    } catch (_) {
      if (mounted) snack(context, 'No se pudo abrir la cámara o la galería');
    }
  }

  Future<void> _iniciarGrabacion() async {
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) snack(context, 'Activa el permiso de micrófono para AgroSmart en los ajustes del celular.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final ruta = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000, sampleRate: 22050, numChannels: 1), path: ruta);
      _segGrab = 0;
      _tGrab = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _segGrab++);
        if (_segGrab >= 120) _detenerGrabacion(enviar: true); // máximo 2 minutos
      });
      setState(() => _grabando = true);
    } catch (e) {
      if (mounted) snack(context, 'No se pudo grabar: $e');
    }
  }

  Future<void> _detenerGrabacion({required bool enviar}) async {
    _tGrab?.cancel();
    final dur = _segGrab;
    String? ruta;
    try {
      ruta = await _rec.stop();
    } catch (_) {}
    if (mounted) setState(() => _grabando = false);
    if (ruta == null) return;
    if (!enviar) {
      try {
        await File(ruta).delete();
      } catch (_) {}
      return;
    }
    if (dur < 1) {
      if (mounted) snack(context, 'Audio demasiado corto');
      return;
    }
    await _enviarAdjunto(ruta, 'AUDIO', dur: dur);
  }

  Future<void> _enviarAdjunto(String path, String tipo, {int? dur}) async {
    // Sin Wi-Fi ni datos: queda guardado en el celular y sube solo al volver la conexión.
    if (await Api.i.sinRed()) {
      await _guardarPendiente(path, tipo, dur);
      _ofrecerAvisoSms(tipo);
      return;
    }
    if (mounted) setState(() => _enviando = true);
    try {
      final ct = CancelToken();
      final timer = Timer(const Duration(seconds: 90), () => ct.cancel('timeout'));
      try {
        final m = await adjuntosService.subir(_idhilo, path: path, tipo: tipo, duracionSeg: dur, cancel: ct);
        if (!mounted) return;
        setState(() {
          if (!_msgs.any((x) => x['idmensaje'] == m['idmensaje'])) _msgs.add(m);
        });
      } finally {
        timer.cancel();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response != null) {
        snack(context, Api.errorMsg(e)); // error real del servidor (formato, tamaño…)
      } else {
        await _guardarPendiente(path, tipo, dur);
        if (mounted) snack(context, 'El servidor no responde. Se enviará solo cuando vuelva la conexión.');
      }
    } catch (e) {
      if (mounted) snack(context, e is String ? e : Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _guardarPendiente(String path, String tipo, int? dur) async {
    final m = await adjuntosService.encolar(_idhilo, path: path, tipo: tipo, duracionSeg: dur);
    if (mounted) setState(() => _pend.add(m));
  }

  /// Un SMS no puede llevar una foto o un audio: se ofrece avisar de que está esperando internet.
  void _ofrecerAvisoSms(String tipo) {
    if (!mounted) return;
    final puedeSms = smsService.disponible && (_telefono ?? '').isNotEmpty;
    final txt = tipo == 'AUDIO'
        ? 'Te envie un audio por AgroSmart. Lo escuchas cuando tengas internet.'
        : 'Te envie una foto por AgroSmart. La veras cuando tengas internet.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Sin internet: ${tipo == 'AUDIO' ? 'el audio' : 'la foto'} se enviará cuando vuelva la conexión.'),
      duration: const Duration(seconds: 8),
      action: puedeSms ? SnackBarAction(label: 'Avisar por SMS', onPressed: () => _enviarPorSms(txt, limpiar: false)) : null,
    ));
  }

  Future<void> _cambiarModoSms() async {
    final nuevo = !_smsDatos;
    await smsService.fijarSoloDatos(nuevo);
    if (!mounted) return;
    setState(() => _smsDatos = nuevo);
    snack(
      context,
      nuevo
          ? 'SMS ocultos: solo los recibe AgroSmart (no salen en Mensajes).'
          : 'SMS normales: se ven también en la app de Mensajes del celular. Úsalo si los ocultos no llegan.',
    );
  }

  // ── Pantalla ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final h = widget.hilo;
    final otro = s(h['otroNombre']).isEmpty ? (h['miRol'] == 'comprador' ? 'Vendedor' : 'Comprador') : s(h['otroNombre']);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          AgroAvatar(url: s(h['otroFoto']), nombre: otro, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(otro, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(s(h['titulo']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AgroColors.mintPale)),
            ]),
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más',
            onSelected: (v) {
              if (v == 'modo') _cambiarModoSms();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'modo',
                child: Row(children: [
                  Icon(_smsDatos ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_smsDatos ? 'SMS ocultos (solo AgroSmart)\nToca para usar SMS normales' : 'SMS normales (se ven en Mensajes)\nToca para usar SMS ocultos', style: const TextStyle(fontSize: 13))),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (h['precio'] != null)
          Material(
            color: Colors.white,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.sell_outlined),
              title: Text('${money(h['precio'])} / ${s(h['unidad'])}', style: AgroText.amount),
              trailing: s(h['estadoOrden']).isEmpty ? null : StatusBadge(s(h['estadoOrden'])),
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: Api.i.offline,
          builder: (_, off, __) {
            if (!off && !_sinRed) return const SizedBox.shrink();
            final hayTel = (_telefono ?? '').isNotEmpty;
            final texto = _sinRed
                ? (hayTel
                    ? 'Sin Wi-Fi ni datos: el texto se envía por SMS al ${_enmascarar(_telefono!)} con el saldo de tu SIM. Fotos y audios esperan a que vuelva internet.'
                    : 'Sin internet y sin número de este contacto. Abre el chat una vez con internet para usar SMS.')
                : 'No hay conexión con el servidor. Los mensajes no se mandan por SMS solos; si falla un envío podrás elegir «Enviar por SMS».';
            return Container(
              width: double.infinity,
              color: AgroColors.warningBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                Icon(_sinRed ? Icons.sms_outlined : Icons.cloud_off_outlined, size: 16, color: AgroColors.warningText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AgroColors.warningText)),
                ),
              ]),
            );
          },
        ),
        Expanded(child: FondoChat(child: _lista())),
        _entrada(),
      ]),
    );
  }

  Widget _entrada() {
    return Container(
      color: ChatColors.fondo,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: _grabando
                  ? BarraGrabacion(segundos: _segGrab, onCancelar: () => _detenerGrabacion(enviar: false))
                  : Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        IconButton(tooltip: 'Adjuntar', onPressed: _enviando ? null : _menuAdjuntar, icon: const Icon(Icons.attach_file, color: ChatColors.hora)),
                        Expanded(
                          child: TextField(
                            controller: _in,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 2000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Escribe un mensaje',
                              counterText: '',
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        IconButton(tooltip: 'Cámara', onPressed: _enviando ? null : () => _fotoRapida(), icon: const Icon(Icons.photo_camera_outlined, color: ChatColors.hora)),
                      ]),
                    ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _in,
              builder: (_, v, __) {
                final hayTexto = v.text.trim().isNotEmpty;
                final Widget icono = _enviando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(hayTexto || _grabando ? Icons.send_rounded : Icons.mic, color: Colors.white);
                return Material(
                  color: AgroColors.primaryLight,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _enviando
                        ? null
                        : () {
                            if (_grabando) {
                              _detenerGrabacion(enviar: true);
                            } else if (hayTexto) {
                              _enviar();
                            } else {
                              _iniciarGrabacion();
                            }
                          },
                    child: SizedBox(width: 48, height: 48, child: Center(child: icono)),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  /// Atajo del icono de cámara: toma la foto y la envía.
  Future<void> _fotoRapida() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
      if (x != null) await _enviarAdjunto(x.path, 'IMAGEN');
    } catch (_) {
      if (mounted) snack(context, 'No se pudo abrir la cámara');
    }
  }

  Widget _lista() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AgroError(
        message: Api.errorMsg(_error!),
        onRetry: () {
          setState(() => _cargando = true);
          _cargar();
        },
      );
    }
    // Servidor, SMS y adjuntos pendientes se mezclan por fecha.
    final todos = [..._msgs, ..._sms, ..._pend]..sort((a, b) => _cuando(a).compareTo(_cuando(b)));
    if (todos.isEmpty) {
      return const AgroEmpty(icon: Icons.waving_hand_outlined, message: 'Escribe tu primer mensaje para iniciar la conversación.');
    }
    final orden = todos.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      itemCount: orden.length,
      itemBuilder: (_, i) {
        final m = orden[i];
        final t = _cuando(m);
        // En la lista invertida el siguiente índice es el mensaje anterior en el tiempo.
        final nuevoDia = i == orden.length - 1 ||
            (() {
              final a = _cuando(orden[i + 1]);
              return a.year != t.year || a.month != t.month || a.day != t.day;
            })();
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (nuevoDia) ChipDia(DateTime(t.year, t.month, t.day)),
          _burbuja(m, t),
        ]);
      },
    );
  }

  Widget _burbuja(Map<String, dynamic> m, DateTime t) {
    final mio = m['mio'] == true;
    final pendienteAdj = m['adjPend'] == true;
    final esSms = m['sms'] == true;
    final leido = mio &&
        !esSms &&
        !pendienteAdj &&
        (m['leidoAt'] != null || ((m['idmensaje'] as num?)?.toInt() ?? 0) <= _leidoHasta);
    final tipo = s(m['tipo']);
    final texto = s(m['contenido']);
    final url = m['adjuntoUrl'] as String?;
    final path = m['path'] as String?;

    Widget contenido;
    var soloFoto = false;
    var inline = false;
    if (tipo == 'IMAGEN') {
      soloFoto = texto.isEmpty;
      contenido = ImagenAdjunta(url: url, path: path, pie: texto);
    } else if (tipo == 'AUDIO') {
      contenido = AudioAdjunto(url: url, path: path, duracionSeg: (m['duracionSeg'] as num?)?.toInt() ?? 0, mio: mio);
    } else {
      inline = true;
      contenido = SelectableText(texto, style: const TextStyle(height: 1.3, fontSize: 15, color: AgroColors.textDark));
    }

    final burbuja = BurbujaChat(
      mio: mio,
      hora: _hora(t),
      contenido: contenido,
      conMargenTexto: inline,
      leido: leido,
      pendiente: pendienteAdj,
      sms: esSms,
      sinVerificar: m['sinVerificar'] == true,
      sinPadding: soloFoto,
    );
    if (!pendienteAdj) return burbuja;

    // Adjunto pendiente: estado y, si el servidor lo rechazó, reintentar o descartar.
    final fallo = m['fallo'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      burbuja,
      Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 4),
        child: fallo
            ? Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('No se pudo enviar: ${s(m['error'])}', style: const TextStyle(fontSize: 11.5, color: AgroColors.dangerText)),
                TextButton(onPressed: () => adjuntosService.reintentar(_idhilo, '${m['adjId']}'), child: const Text('Reintentar')),
                TextButton(onPressed: () => adjuntosService.descartar(_idhilo, '${m['adjId']}'), child: const Text('Descartar')),
              ])
            : const Text('Se enviará cuando haya internet', style: TextStyle(fontSize: 11.5, color: ChatColors.hora)),
      ),
    ]);
  }
}
