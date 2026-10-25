import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/services/socket_service.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Momento de un mensaje. Los del servidor traen zona horaria y los de SMS la hora local del
/// celular; al convertirlos a DateTime se pueden comparar entre sí.
DateTime _cuando(Map<String, dynamic> m) =>
    DateTime.tryParse('${m['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);

/// Conversación comprador ↔ vendedor sobre una oferta, en tiempo real.
class HiloPage extends StatefulWidget {
  final Map<String, dynamic> hilo;
  const HiloPage({super.key, required this.hilo});
  @override
  State<HiloPage> createState() => _HiloPageState();
}

class _HiloPageState extends State<HiloPage> {
  final _msgs = <Map<String, dynamic>>[];
  final _in = TextEditingController();
  final _scroll = ScrollController();
  final _subs = <StreamSubscription>[];
  bool _cargando = true;
  bool _hayMas = true;
  bool _cargandoMas = false;
  bool _enviando = false;
  int _leidoHasta = 0;
  Object? _error;
  final _sms = <Map<String, dynamic>>[]; // mensajes enviados/recibidos por SMS
  String? _telefono;

  int get _idhilo => (widget.hilo['idhilo'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarSms();
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
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _in.dispose();
    _scroll.dispose();
    super.dispose();
  }

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

  Future<void> _cargar() async {
    try {
      var l = await mensajeriaService.mensajes(_idhilo);
      // Con internet real: sube lo que se mandó por SMS mientras no había red.
      if (!Api.i.offline.value && await smsService.flushPendientes(idhilo: _idhilo) > 0) {
        l = await mensajeriaService.mensajes(_idhilo);
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
          // Sin servidor pero con mensajes por SMS guardados: se muestran, no es un error.
          _error = locales.isEmpty ? e : null;
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

  /// Muestra solo los últimos 4 dígitos del número, para confirmar a dónde va el SMS.
  String _enmascarar(String t) {
    final d = t.replaceAll(RegExp(r'\D'), '');
    return d.length <= 4 ? t : '•••${d.substring(d.length - 4)}';
  }

  Future<void> _enviar() async {
    final t = _in.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      Map<String, dynamic>? enviado;
      if (!await Api.i.sinRed()) {
        // Hay red: se intenta por internet, pero sin esperar de más.
        final ct = CancelToken();
        final timer = Timer(const Duration(seconds: 8), () => ct.cancel('timeout'));
        try {
          enviado = await mensajeriaService.enviar(_idhilo, t, cancel: ct);
        } on DioException catch (e) {
          if (e.response != null) rethrow; // el servidor respondió con un error real
        } finally {
          timer.cancel();
        }
      }
      if (enviado != null) {
        final m = enviado;
        if (!mounted) return;
        _in.clear();
        setState(() {
          if (!_msgs.any((x) => x['idmensaje'] == m['idmensaje'])) _msgs.add(m);
        });
        return;
      }
      // Sin internet: va por SMS, dentro de la app.
      final sms = await smsService.enviar(_idhilo, t);
      if (!mounted) return;
      _in.clear();
      Api.i.offline.value = true;
      setState(() => _sms.add(sms));
      snack(context, 'SMS enviado al número ${_enmascarar(_telefono ?? '')}');
    } catch (e) {
      if (mounted) snack(context, e is String ? e : Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

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
            if (!off) return const SizedBox.shrink();
            final hayTel = (_telefono ?? '').isNotEmpty;
            return Container(
              width: double.infinity,
              color: AgroColors.warningBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                const Icon(Icons.sms_outlined, size: 16, color: AgroColors.warningText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hayTel
                        ? 'Sin internet: tus mensajes se envían por SMS al ${_enmascarar(_telefono!)} (necesita señal móvil, no modo avión).'
                        : 'Sin internet y sin número de este contacto. Abre el chat una vez con internet para usar SMS.',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AgroColors.warningText),
                  ),
                ),
              ]),
            );
          },
        ),
        Expanded(child: _lista()),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _in,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                  decoration: const InputDecoration(hintText: 'Escribe un mensaje…', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Enviar',
                onPressed: _enviando ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
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
    // Servidor y SMS se mezclan por fecha (antes los SMS quedaban siempre al final).
    final todos = [..._msgs, ..._sms]..sort((a, b) => _cuando(a).compareTo(_cuando(b)));
    if (todos.isEmpty) {
      return const AgroEmpty(icon: Icons.waving_hand_outlined, message: 'Escribe tu primer mensaje para iniciar la conversación.');
    }
    final orden = todos.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: orden.length,
      itemBuilder: (_, i) {
        final m = orden[i];
        final mio = m['mio'] == true;
        final leido = mio && m['sms'] != true && (m['leidoAt'] != null || ((m['idmensaje'] as num?)?.toInt() ?? 0) <= _leidoHasta);
        return Align(
          alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
            decoration: BoxDecoration(
              color: mio ? AgroColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mio ? 16 : 4),
                bottomRight: Radius.circular(mio ? 4 : 16),
              ),
              border: mio ? null : Border.all(color: AgroColors.slateBorder),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              SelectableText(s(m['contenido']),
                  style: TextStyle(color: mio ? Colors.white : AgroColors.textDark, height: 1.35)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (m['sms'] == true) ...[
                  Icon(Icons.sms_outlined, size: 12, color: mio ? AgroColors.mintPale : AgroColors.textMuted),
                  const SizedBox(width: 4),
                  if (m['sinVerificar'] == true) ...[
                    const Icon(Icons.warning_amber_rounded, size: 12, color: AgroColors.warningText),
                    const SizedBox(width: 4),
                  ],
                ],
                Text(fecha(m['createdAt'], hora: true),
                    style: TextStyle(fontSize: 11, color: mio ? AgroColors.mintPale : AgroColors.textMuted)),
                if (mio) ...[
                  const SizedBox(width: 4),
                  Icon(leido ? Icons.done_all : Icons.done, size: 14, color: leido ? AgroColors.mint : AgroColors.mintPale),
                ],
              ]),
            ]),
          ),
        );
      },
    );
  }
}
