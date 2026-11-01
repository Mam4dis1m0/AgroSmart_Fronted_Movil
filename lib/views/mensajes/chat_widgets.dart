import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Colores del chat (estilo WhatsApp, con la paleta de AgroSmart).
class ChatColors {
  ChatColors._();
  static const fondo = Color(0xFFEFEAE2);
  static const garabato = Color(0xFFE3DBCC);
  static const mia = Color(0xFFD9FDD3);
  static const otra = Colors.white;
  static const leido = Color(0xFF53BDEB);
  static const hora = Color(0xFF667781);
}

/// Fondo beige con garabatos del campo (hojas, gotas, sol…), como el papel tapiz de WhatsApp.
class FondoChat extends StatelessWidget {
  final Widget child;
  const FondoChat({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: ChatColors.fondo,
        child: CustomPaint(painter: _Garabatos(), child: child),
      );
}

class _Garabatos extends CustomPainter {
  static const _iconos = <IconData>[
    Icons.eco_outlined,
    Icons.water_drop_outlined,
    Icons.wb_sunny_outlined,
    Icons.grass,
    Icons.agriculture_outlined,
    Icons.spa_outlined,
    Icons.local_florist_outlined,
    Icons.shopping_basket_outlined,
  ];

  static List<TextPainter>? _cache;

  static List<TextPainter> _pintores() {
    return _cache ??= [
      for (final i in _iconos)
        TextPainter(
          text: TextSpan(
            text: String.fromCharCode(i.codePoint),
            style: TextStyle(fontFamily: i.fontFamily, package: i.fontPackage, fontSize: 26, color: ChatColors.garabato),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ps = _pintores();
    const paso = 78.0;
    var fila = 0;
    for (double y = 10; y < size.height + paso; y += paso, fila++) {
      var col = 0;
      for (double x = fila.isOdd ? paso / 2 : 0; x < size.width + paso; x += paso, col++) {
        final tp = ps[(fila * 3 + col) % ps.length];
        canvas.save();
        canvas.translate(x + 20, y + 20);
        canvas.rotate((((fila * 7 + col * 5) % 9) - 4) * 0.13);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Burbuja: texto, foto o audio + hora y estado abajo a la derecha.
class BurbujaChat extends StatelessWidget {
  final bool mio;
  final String hora;
  final Widget contenido;
  final bool conMargenTexto; // true: el pie va en la misma línea que el texto si cabe
  final bool leido;
  final bool pendiente; // reloj: falta enviarlo
  final bool sms;
  final bool sinVerificar;
  final bool sinPadding; // foto sola: ocupa toda la burbuja
  const BurbujaChat({
    super.key,
    required this.mio,
    required this.hora,
    required this.contenido,
    this.conMargenTexto = false,
    this.leido = false,
    this.pendiente = false,
    this.sms = false,
    this.sinVerificar = false,
    this.sinPadding = false,
  });

  Widget _pie() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (sms) ...[
        const Icon(Icons.sms_outlined, size: 12, color: ChatColors.hora),
        const SizedBox(width: 3),
      ],
      if (sinVerificar) ...[
        const Icon(Icons.warning_amber_rounded, size: 12, color: AgroColors.warningText),
        const SizedBox(width: 3),
      ],
      Text(hora, style: const TextStyle(fontSize: 11, color: ChatColors.hora)),
      if (mio) ...[
        const SizedBox(width: 3),
        Icon(
          pendiente ? Icons.schedule : (leido ? Icons.done_all : Icons.done),
          size: 15,
          color: leido && !pendiente ? ChatColors.leido : ChatColors.hora,
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cuerpo = conMargenTexto
        ? Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.end, children: [
            contenido,
            const SizedBox(width: 10),
            Padding(padding: const EdgeInsets.only(top: 3), child: _pie()),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            contenido,
            const SizedBox(height: 2),
            Padding(padding: EdgeInsets.only(right: sinPadding ? 6 : 0, bottom: sinPadding ? 3 : 0), child: _pie()),
          ]);
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.fromLTRB(mio ? 40 : 4, 2, mio ? 4 : 40, 2),
        padding: sinPadding ? const EdgeInsets.all(3) : const EdgeInsets.fromLTRB(9, 6, 9, 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
        decoration: BoxDecoration(
          color: mio ? ChatColors.mia : ChatColors.otra,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mio ? 12 : 3),
            topRight: Radius.circular(mio ? 3 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 1))],
        ),
        child: cuerpo,
      ),
    );
  }
}

/// «Hoy», «Ayer» o la fecha, centrado.
class ChipDia extends StatelessWidget {
  final DateTime dia;
  const ChipDia(this.dia, {super.key});
  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final d = DateTime(hoy.year, hoy.month, hoy.day);
    final dif = d.difference(DateTime(dia.year, dia.month, dia.day)).inDays;
    final t = dif == 0 ? 'Hoy' : (dif == 1 ? 'Ayer' : '${dia.day}/${dia.month}/${dia.year}');
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 1))],
        ),
        child: Text(t, style: const TextStyle(fontSize: 12, color: ChatColors.hora, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Foto dentro de la burbuja (del servidor o un archivo local pendiente). Toque = pantalla completa.
class ImagenAdjunta extends StatelessWidget {
  final String? url;
  final String? path;
  final String? pie;
  const ImagenAdjunta({super.key, this.url, this.path, this.pie});

  Widget _imagen({BoxFit fit = BoxFit.cover, double? w, double? h}) {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        width: w,
        height: h,
        fit: fit,
        placeholder: (_, __) => Container(width: w, height: h, color: AgroColors.surfaceGreen, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, __, ___) => Container(width: w, height: h, color: AgroColors.surfaceGreen, child: const Icon(Icons.broken_image_outlined)),
      );
    }
    if (path != null && path!.isNotEmpty) {
      return Image.file(File(path!), width: w, height: h, fit: fit, errorBuilder: (_, __, ___) => Container(width: w, height: h, color: AgroColors.surfaceGreen, child: const Icon(Icons.broken_image_outlined)));
    }
    return Container(width: w, height: h, color: AgroColors.surfaceGreen);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
            body: Center(child: InteractiveViewer(minScale: 1, maxScale: 5, child: _imagen(fit: BoxFit.contain))),
          ),
        )),
        child: ClipRRect(borderRadius: BorderRadius.circular(9), child: _imagen(w: 230, h: 230)),
      ),
      if (pie != null && pie!.isNotEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(6, 6, 6, 0), child: Text(pie!, style: const TextStyle(height: 1.3))),
    ]);
  }
}

/// Nota de voz con reproducir/pausar y barra de avance.
class AudioAdjunto extends StatefulWidget {
  final String? url;
  final String? path;
  final int duracionSeg;
  final bool mio;
  const AudioAdjunto({super.key, this.url, this.path, required this.duracionSeg, required this.mio});
  @override
  State<AudioAdjunto> createState() => _AudioAdjuntoState();
}

class _AudioAdjuntoState extends State<AudioAdjunto> {
  final _p = AudioPlayer();
  final _subs = <StreamSubscription>[];
  PlayerState _estado = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    _subs.add(_p.onPlayerStateChanged.listen((e) {
      if (mounted) setState(() => _estado = e);
    }));
    _subs.add(_p.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    }));
    _subs.add(_p.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_p.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _pos = Duration.zero;
          _estado = PlayerState.stopped;
          _cargado = false;
        });
      }
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p.dispose();
    super.dispose();
  }

  Future<void> _alternar() async {
    try {
      if (_estado == PlayerState.playing) {
        await _p.pause();
        return;
      }
      if (_cargado && _estado == PlayerState.paused) {
        await _p.resume();
        return;
      }
      final u = widget.url;
      final Source src = (u != null && u.isNotEmpty) ? UrlSource(u) : DeviceFileSource(widget.path ?? '');
      await _p.play(src);
      _cargado = true;
    } catch (_) {
      if (mounted) snack(context, 'No se pudo reproducir el audio');
    }
  }

  String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur ?? Duration(seconds: widget.duracionSeg);
    final avance = total.inMilliseconds > 0 ? (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final sonando = _estado == PlayerState.playing;
    return SizedBox(
      width: 230,
      child: Row(children: [
        IconButton(
          onPressed: _alternar,
          icon: Icon(sonando ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 38, color: AgroColors.primary),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: avance, minHeight: 4, backgroundColor: const Color(0x22000000), color: AgroColors.primaryLight),
            const SizedBox(height: 4),
            Text(sonando || _pos > Duration.zero ? _mmss(_pos) : _mmss(total), style: const TextStyle(fontSize: 11.5, color: ChatColors.hora)),
          ]),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.mic, size: 20, color: ChatColors.hora),
      ]),
    );
  }
}

/// Barra que reemplaza la caja de texto mientras se graba un audio.
class BarraGrabacion extends StatelessWidget {
  final int segundos;
  final VoidCallback onCancelar;
  const BarraGrabacion({super.key, required this.segundos, required this.onCancelar});
  @override
  Widget build(BuildContext context) {
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Row(children: [
        IconButton(onPressed: onCancelar, tooltip: 'Descartar', icon: const Icon(Icons.delete_outline, color: AgroColors.danger)),
        const Icon(Icons.fiber_manual_record, size: 14, color: AgroColors.danger),
        const SizedBox(width: 6),
        Text('$m:$s', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const Spacer(),
        const Padding(padding: EdgeInsets.only(right: 12), child: Text('Grabando…', style: TextStyle(color: ChatColors.hora))),
      ]),
    );
  }
}
