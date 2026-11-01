import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/voz_service.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/operacion/operacion_view.dart';
import 'package:agrosmart_proto/views/produccion/produccion_view.dart';

/// Pone el botón «Hablar» (solo administradores) encima de una pantalla.
class ConVoz extends StatelessWidget {
  final Widget child;
  const ConVoz({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: child),
      if (esAdmin)
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'voz-asistente',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VozAsistentePage())),
            icon: const Icon(Icons.mic),
            label: const Text('Hablar'),
          ),
        ),
    ]);
  }
}

/// «Crea el lote El Mirador de 2 hectáreas, siembra café el lunes y programa fertilización para Juan»:
/// la voz se convierte en texto, la IA lo convierte en pasos (lote → cultivo → tareas) y, al confirmar,
/// la app los crea en orden.
class VozAsistentePage extends StatefulWidget {
  const VozAsistentePage({super.key});
  @override
  State<VozAsistentePage> createState() => _VozAsistentePageState();
}

class _VozAsistentePageState extends State<VozAsistentePage> {
  final _texto = TextEditingController();
  final _stt = stt.SpeechToText();
  bool _sttListo = false;
  bool _escuchando = false;
  String? _locale;
  String _base = ''; // lo dictado en tandas anteriores (Android corta el micrófono tras unos segundos de silencio)
  double _nivel = 0;

  bool _interpretando = false;
  List<Map<String, dynamic>> _acciones = [];
  List<String> _faltantes = [];
  String _entendido = '';
  final _marcadas = <String>{};

  // Ejecución
  bool _ejecutando = false;
  bool _terminado = false;
  final _estado = <String, String>{}; // id → pendiente | ejecutando | ok | error
  final _errores = <String, String>{};
  final _ids = <String, int>{}; // id de la acción → id real creado

  static const _ejemplos = [
    'Crea el lote El Mirador de dos hectáreas y siembra café el lunes',
    'En el cultivo de café programa fertilización para mañana y asígnasela a Juan',
  ];

  @override
  void dispose() {
    _stt.cancel();
    _texto.dispose();
    super.dispose();
  }

  // ─── Voz a texto ───────────────────────────────────────────────────────────

  Future<bool> _prepararVoz() async {
    if (_sttListo) return true;
    try {
      _sttListo = await _stt.initialize(
        onStatus: (st) {
          // Android cierra la escucha solo; si el usuario sigue dictando, se reanuda.
          if ((st == 'done' || st == 'notListening') && _escuchando) {
            _base = _texto.text.trim();
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted && _escuchando) _escuchar();
            });
          }
        },
        onError: (e) {
          if (!mounted) return;
          if (e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout') return; // silencio: se reanuda
          setState(() => _escuchando = false);
          snack(context, 'No se pudo usar el micrófono (${e.errorMsg}).');
        },
      );
      if (_sttListo) {
        final locales = await _stt.locales();
        String norm(String s) => s.toLowerCase().replaceAll('-', '_');
        for (final pref in const ['es_co', 'es_419', 'es_mx', 'es_es']) {
          final l = locales.where((x) => norm(x.localeId) == pref).toList();
          if (l.isNotEmpty) {
            _locale = l.first.localeId;
            break;
          }
        }
        _locale ??= locales.where((x) => norm(x.localeId).startsWith('es')).map((x) => x.localeId).firstOrNull;
      }
    } catch (_) {
      _sttListo = false;
    }
    return _sttListo;
  }

  Future<void> _alternarVoz() async {
    if (_escuchando) {
      await _stt.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }
    if (!await _prepararVoz()) {
      if (mounted) {
        snack(context, 'No se pudo activar el reconocimiento de voz. Revisa el permiso del micrófono y que el celular tenga los servicios de voz de Google.');
      }
      return;
    }
    _base = _texto.text.trim();
    setState(() => _escuchando = true);
    await _escuchar();
  }

  Future<void> _escuchar() async {
    try {
      await _stt.listen(
        localeId: _locale,
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(seconds: 10),
        onSoundLevelChange: (l) {
          if (mounted) setState(() => _nivel = l);
        },
        listenOptions: stt.SpeechListenOptions(partialResults: true, listenMode: stt.ListenMode.dictation, cancelOnError: false),
        onResult: (r) {
          final t = [_base, r.recognizedWords].where((x) => x.isNotEmpty).join(' ');
          _texto.value = TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
          if (r.finalResult) _base = t;
          if (mounted) setState(() {});
        },
      );
    } catch (_) {
      if (mounted) setState(() => _escuchando = false);
    }
  }

  // ─── IA: texto → plan ──────────────────────────────────────────────────────

  Future<void> _interpretar() async {
    if (_escuchando) await _alternarVoz();
    final t = _texto.text.trim();
    if (t.isEmpty) {
      snack(context, 'Pulsa el micrófono y dime qué quieres crear.');
      return;
    }
    if (await Api.i.sinRed()) {
      snack(context, 'Necesitas internet para que la IA entienda tu voz.');
      return;
    }
    setState(() {
      _interpretando = true;
      _terminado = false;
      _estado.clear();
      _errores.clear();
      _ids.clear();
    });
    try {
      final r = await vozService.interpretar(t);
      if (!mounted) return;
      final acc = [for (final a in (r['acciones'] as List? ?? const [])) (a as Map).cast<String, dynamic>()];
      setState(() {
        _acciones = acc;
        _faltantes = [for (final f in (r['faltantes'] as List? ?? const [])) '$f'];
        _entendido = '${r['entendido'] ?? ''}';
        _marcadas
          ..clear()
          ..addAll(acc.map((a) => '${a['id']}'));
      });
      if (acc.isEmpty && _faltantes.isEmpty) snack(context, 'No entendí qué crear. Prueba con otro ejemplo.');
    } catch (e) {
      if (mounted) snack(context, Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _interpretando = false);
    }
  }

  // ─── Ejecutar el plan, paso a paso ─────────────────────────────────────────

  int _idDe(Response r, String clave) {
    final d = r.data;
    if (d is Map && d['encolado'] == true) throw 'Se perdió la conexión. Vuelve a intentarlo con internet.';
    final v = d is Map ? d[clave] : null;
    if (v is num) return v.toInt();
    throw 'El servidor no devolvió el id creado.';
  }

  int? _resolver(dynamic ref) {
    if (ref is num) return ref.toInt();
    if (ref is String) return _ids[ref];
    return null;
  }

  List<Map<String, dynamic>> get _seleccion => [for (final a in _acciones) if (_marcadas.contains('${a['id']}')) a];

  Future<void> _crear() async {
    if (_ejecutando) return;
    if (await Api.i.sinRed()) {
      if (mounted) snack(context, 'Necesitas internet para crear todo por voz.');
      return;
    }
    setState(() {
      _ejecutando = true;
      _terminado = false;
      for (final a in _seleccion) {
        if (_estado['${a['id']}'] != 'ok') _estado['${a['id']}'] = 'pendiente';
      }
      _errores.clear();
    });
    var fallo = false;
    for (final a in _seleccion) {
      final id = '${a['id']}';
      if (_estado[id] == 'ok') continue; // ya creado en un intento anterior
      setState(() => _estado[id] = 'ejecutando');
      try {
        final datos = Map<String, dynamic>.from(a['datos'] as Map);
        switch ('${a['tipo']}') {
          case 'crear_lote':
            _ids[id] = _idDe(await Api.i.dio.post('/lotes', data: datos), 'idlote');
          case 'crear_cultivo':
            final lote = _resolver(a['lote']);
            if (lote == null) throw 'Falta el lote de este cultivo (¿se creó el lote antes?).';
            _ids[id] = _idDe(await Api.i.dio.post('/cultivos', data: {...datos, 'idlote': lote}), 'idcultivo');
          case 'crear_tarea':
            final cultivo = _resolver(a['cultivo']);
            final idTarea = _idDe(
              await Api.i.dio.post('/api/v1/tareas', data: {'estado': 'Pendiente', ...datos, if (cultivo != null) 'idcultivo': cultivo}),
              'idtarea',
            );
            final emp = a['empleado'];
            if (emp is num) await Api.i.dio.patch('/api/v1/tareas/$idTarea/asignar', data: {'idempleado': emp.toInt()});
            _ids[id] = idTarea;
        }
        if (mounted) setState(() => _estado[id] = 'ok');
      } catch (e) {
        fallo = true;
        if (mounted) {
          setState(() {
            _estado[id] = 'error';
            _errores[id] = e is String ? e : Api.errorMsg(e);
          });
        }
        break; // los pasos siguientes dependen de este
      }
    }
    if (!mounted) return;
    setState(() {
      _ejecutando = false;
      _terminado = !fallo;
    });
  }

  void _ir(Widget pagina, String titulo) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(titulo)), body: pagina)));
  }

  // ─── Diseño ────────────────────────────────────────────────────────────────

  bool _hay(String tipo) => _acciones.any((a) => a['tipo'] == tipo);

  /// «ninguno» | «plan» | «activo» | «hecho» para la barra Lote → Cultivo → Tareas.
  String _etapa(String tipo) {
    final l = [for (final a in _seleccion) if (a['tipo'] == tipo) '${a['id']}'];
    if (l.isEmpty) return 'ninguno';
    if (l.every((i) => _estado[i] == 'ok')) return 'hecho';
    if (l.any((i) => _estado[i] == 'ejecutando' || _estado[i] == 'error')) return 'activo';
    return 'plan';
  }

  Widget _barraEtapas() {
    Widget paso(String tipo, IconData icono, String texto) {
      final e = _etapa(tipo);
      final activo = e == 'activo';
      final hecho = e == 'hecho';
      final color = e == 'ninguno' ? AgroColors.textMuted : AgroColors.primary;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? AgroColors.primary : (hecho ? AgroColors.surfaceGreen : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: e == 'ninguno' ? AgroColors.slateBorder : AgroColors.primary),
          ),
          child: Column(children: [
            Icon(hecho ? Icons.check_circle : icono, color: activo ? Colors.white : color, size: 22),
            const SizedBox(height: 2),
            Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: activo ? Colors.white : color)),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        paso('crear_lote', Icons.landscape, 'Lote'),
        const Icon(Icons.chevron_right, color: AgroColors.textMuted),
        paso('crear_cultivo', Icons.grass, 'Cultivo'),
        const Icon(Icons.chevron_right, color: AgroColors.textMuted),
        paso('crear_tarea', Icons.task_alt, 'Tareas'),
      ]),
    );
  }

  Widget _tarjetaAccion(Map<String, dynamic> a) {
    final id = '${a['id']}';
    final tipo = '${a['tipo']}';
    final icono = tipo == 'crear_lote' ? Icons.landscape : (tipo == 'crear_cultivo' ? Icons.grass : Icons.task_alt);
    final est = _estado[id];
    final bloqueado = _ejecutando || est == 'ok';
    Widget fin;
    switch (est) {
      case 'ejecutando':
        fin = const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5));
      case 'ok':
        fin = const Icon(Icons.check_circle, color: AgroColors.primary);
      case 'error':
        fin = const Icon(Icons.error, color: Colors.red);
      default:
        fin = Checkbox(
          value: _marcadas.contains(id),
          onChanged: bloqueado
              ? null
              : (v) => setState(() {
                    if (v == true) {
                      _marcadas.add(id);
                    } else {
                      _marcadas.remove(id);
                    }
                  }),
        );
    }
    final resumen = [for (final r in (a['resumen'] as List? ?? const [])) '$r'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: est == 'error' ? Colors.red : (est == 'ok' ? AgroColors.primary : AgroColors.slateBorder)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 20, backgroundColor: AgroColors.surfaceGreen, child: Icon(icono, color: AgroColors.primary, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['titulo']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
            for (final r in resumen) Text(r, style: const TextStyle(fontSize: 13, color: AgroColors.textMuted)),
            if (_errores[id] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_errores[id]!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.red)),
              ),
          ]),
        ),
        fin,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _seleccion.length;
    final hayError = _errores.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente por voz')),
      body: Column(children: [
        _barraEtapas(),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(
              controller: _texto,
              minLines: 3,
              maxLines: 6,
              enabled: !_ejecutando,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Pulsa el micrófono y dime qué quieres crear…\nPuedes corregir el texto aquí.',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                suffixIcon: _texto.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _ejecutando
                            ? null
                            : () => setState(() {
                                  _texto.clear();
                                  _acciones = [];
                                  _faltantes = [];
                                  _entendido = '';
                                }),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Row(children: [
              // Micrófono: crece con el volumen de la voz
              GestureDetector(
                onTap: _ejecutando ? null : _alternarVoz,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 64 + (_escuchando ? (_nivel.clamp(0, 10)) * 2.2 : 0),
                  height: 64 + (_escuchando ? (_nivel.clamp(0, 10)) * 2.2 : 0),
                  decoration: BoxDecoration(
                    color: _escuchando ? Colors.red : AgroColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: (_escuchando ? Colors.red : AgroColors.primary).withValues(alpha: .3), blurRadius: 14, spreadRadius: 2)],
                  ),
                  child: Icon(_escuchando ? Icons.stop : Icons.mic, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _escuchando ? 'Te escucho… toca para detener' : 'Toca el micrófono y habla con calma',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AgroColors.textDark),
                ),
              ),
              FilledButton.icon(
                onPressed: (_interpretando || _ejecutando) ? null : _interpretar,
                icon: _interpretando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: const Text('Entender'),
              ),
            ]),
            if (_acciones.isEmpty && _faltantes.isEmpty) ...[
              const SizedBox(height: 18),
              const Text('Ejemplos', style: TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textMuted)),
              const SizedBox(height: 6),
              for (final e in _ejemplos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.format_quote, size: 16),
                    label: Text(e, style: const TextStyle(fontSize: 12.5)),
                    onPressed: () => setState(() => _texto.text = e),
                  ),
                ),
            ],
            if (_entendido.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Entendí: $_entendido', style: const TextStyle(fontWeight: FontWeight.w700, color: AgroColors.textDark)),
            ],
            if (_acciones.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final a in _acciones) _tarjetaAccion(a),
            ],
            if (_faltantes.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AgroColors.warningBg, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Me falta saber:', style: TextStyle(fontWeight: FontWeight.w800, color: AgroColors.warningText)),
                  for (final f in _faltantes) Text('• $f', style: const TextStyle(color: AgroColors.warningText)),
                  const SizedBox(height: 4),
                  const Text('Dilo con el micrófono (se agrega al texto) y pulsa «Entender» otra vez.',
                      style: TextStyle(fontSize: 12, color: AgroColors.warningText)),
                ]),
              ),
            if (_terminado) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AgroColors.surfaceGreen, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.check_circle, color: AgroColors.primary),
                    SizedBox(width: 8),
                    Text('¡Listo! Todo quedó creado', style: TextStyle(fontWeight: FontWeight.w800, color: AgroColors.primary)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (_hay('crear_lote')) OutlinedButton.icon(onPressed: () => _ir(const ProduccionPage(initialIndex: 1), 'Lotes'), icon: const Icon(Icons.landscape), label: const Text('Ver lotes')),
                    if (_hay('crear_cultivo')) OutlinedButton.icon(onPressed: () => _ir(const ProduccionPage(initialIndex: 2), 'Cultivos'), icon: const Icon(Icons.grass), label: const Text('Ver cultivos')),
                    if (_hay('crear_tarea')) OutlinedButton.icon(onPressed: () => _ir(const OperacionPage(initialIndex: 0), 'Tareas'), icon: const Icon(Icons.task_alt), label: const Text('Ver tareas')),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 90),
          ]),
        ),
        if (_acciones.isNotEmpty && !_terminado)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (n == 0 || _ejecutando) ? null : _crear,
                  icon: _ejecutando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(hayError ? Icons.refresh : Icons.check),
                  label: Text(_ejecutando ? 'Creando…' : (hayError ? 'Reintentar los pasos que faltan' : 'Crear todo ($n ${n == 1 ? 'paso' : 'pasos'})')),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
