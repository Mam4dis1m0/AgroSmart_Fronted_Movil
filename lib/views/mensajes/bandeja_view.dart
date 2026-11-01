import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/services/socket_service.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'chat_widgets.dart';
import 'hilo_view.dart';

Future<void> abrirBandeja(BuildContext c) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => const BandejaPage()));

/// Abre (o crea) la conversación con el vendedor de una oferta.
Future<void> chatearConVendedor(BuildContext c, int idlistado, {int? idorden}) async {
  final hilo = await cargar(c, () => mensajeriaService.abrirHilo(idlistado, idorden: idorden));
  if (hilo == null || !c.mounted) return;
  await Navigator.of(c).push(MaterialPageRoute(builder: (_) => HiloPage(hilo: hilo)));
}

enum _Filtro { todos, noLeidos, fijados }

/// Bandeja de conversaciones del Marketplace, al estilo de una app de chat:
/// buscador, filtros (Todos · No leídos · Fijados) y una fila por conversación.
class BandejaPage extends StatefulWidget {
  const BandejaPage({super.key});
  @override
  State<BandejaPage> createState() => _BandejaPageState();
}

class _BandejaPageState extends State<BandejaPage> {
  late Future<List<Map<String, dynamic>>> _f = mensajeriaService.hilos();
  final _q = TextEditingController();
  final _subs = <StreamSubscription>[];
  _Filtro _filtro = _Filtro.todos;
  Set<String> _fijados = {};

  String get _kFijados => 'chat_fijados:${Api.i.cacheScope}';

  @override
  void initState() {
    super.initState();
    _subs.add(socketService.nuevos.listen((_) => _recargar()));
    _subs.add(socketService.leidos.listen((_) => _recargar()));
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _fijados = (p.getStringList(_kFijados) ?? []).toSet());
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _q.dispose();
    super.dispose();
  }

  void _recargar() {
    if (mounted) setState(() => _f = mensajeriaService.hilos());
  }

  Future<void> _alternarFijado(String id) async {
    final nuevo = {..._fijados};
    if (!nuevo.remove(id)) nuevo.add(id);
    setState(() => _fijados = nuevo);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kFijados, nuevo.toList());
  }

  String _etiqueta(dynamic iso) {
    final t = DateTime.tryParse(s(iso))?.toLocal();
    if (t == null) return '';
    final hoy = DateTime.now();
    final dif = DateTime(hoy.year, hoy.month, hoy.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (dif == 0) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (dif == 1) return 'Ayer';
    return '${t.day}/${t.month}/${t.year}';
  }

  Widget _chip(String t, _Filtro f, {int? n}) {
    final sel = _filtro == f;
    return GestureDetector(
      onTap: () => setState(() => _filtro = f),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AgroColors.mint : AgroColors.slateBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? AgroColors.primary : AgroColors.textMuted)),
          if (n != null && n > 0) ...[
            const SizedBox(width: 6),
            Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AgroColors.textMuted)),
          ],
        ]),
      ),
    );
  }

  /// Vista previa del último mensaje: ✓✓ si es mío, y icono para fotos y audios.
  Widget _vista(String txt, {required bool mio, required bool noLeido}) {
    final esFoto = txt.startsWith('📷');
    final esAudio = txt.startsWith('🎤');
    final texto = esFoto ? txt.replaceFirst('📷', '').trim() : (esAudio ? txt.replaceFirst('🎤', '').trim() : txt);
    final color = noLeido ? AgroColors.textDark : AgroColors.textMuted;
    return Row(children: [
      if (mio) ...[
        const Icon(Icons.done_all, size: 17, color: AgroColors.textMuted),
        const SizedBox(width: 4),
      ],
      if (esFoto || esAudio) ...[
        Icon(esFoto ? Icons.photo_camera : Icons.mic, size: 16, color: color),
        const SizedBox(width: 3),
      ],
      Expanded(
        child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: color, fontWeight: noLeido ? FontWeight.w700 : FontWeight.w500)),
      ),
    ]);
  }

  Widget _fila(Map<String, dynamic> h) {
    final id = '${h['idhilo']}';
    final nombre = s(h['otroNombre']).isEmpty ? 'Usuario' : s(h['otroNombre']);
    final noLeidos = n(h['noLeidos']).round();
    final mio = h['ultimoRemitente'] != null && h['ultimoRemitente'] != h['otroId'];
    final fijado = _fijados.contains(id);
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HiloPage(hilo: h)));
        _recargar();
        contadores.refrescar();
      },
      onLongPress: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListTile(
            leading: Icon(fijado ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(fijado ? 'Quitar de fijados' : 'Fijar conversación'),
            onTap: () {
              Navigator.pop(ctx);
              _alternarFijado(id);
            },
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          AgroAvatar(url: s(h['otroFoto']), nombre: nombre, radius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Row(children: [
                    Flexible(child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AgroColors.textDark))),
                    if (s(h['titulo']).isNotEmpty)
                      Flexible(
                        child: Text('  ·  ${s(h['titulo'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AgroColors.primaryLight, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(_etiqueta(h['ultimoMensajeAt']), style: TextStyle(fontSize: 12, color: noLeidos > 0 ? AgroColors.primaryLight : AgroColors.textMuted, fontWeight: noLeidos > 0 ? FontWeight.w700 : FontWeight.w500)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: _vista(s(h['ultimoContenido']), mio: mio, noLeido: noLeidos > 0)),
                if (fijado) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.push_pin, size: 16, color: AgroColors.textMuted)),
                if (noLeidos > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 22),
                    decoration: BoxDecoration(color: AgroColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Text('$noLeidos', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
          final todos = snap.data ?? [];
          final sinLeer = todos.where((h) => n(h['noLeidos']) > 0).length;
          final q = _q.text.trim().toLowerCase();
          final lista = todos.where((h) {
            if (_filtro == _Filtro.noLeidos && n(h['noLeidos']) == 0) return false;
            if (_filtro == _Filtro.fijados && !_fijados.contains('${h['idhilo']}')) return false;
            if (q.isEmpty) return true;
            return s(h['otroNombre']).toLowerCase().contains(q) ||
                s(h['titulo']).toLowerCase().contains(q) ||
                s(h['ultimoContenido']).toLowerCase().contains(q);
          }).toList()
            // Los fijados primero; dentro de cada grupo se conserva el orden del servidor (más reciente primero).
            ..sort((a, b) => (_fijados.contains('${b['idhilo']}') ? 1 : 0) - (_fijados.contains('${a['idhilo']}') ? 1 : 0));
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar un chat o una oferta',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F5),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: const BorderSide(color: AgroColors.mint)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('Todos', _Filtro.todos),
                    _chip('No leídos', _Filtro.noLeidos, n: sinLeer),
                    _chip('Fijados', _Filtro.fijados),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const AgroEmpty(
                      icon: Icons.chat_bubble_outline,
                      message: 'No hay conversaciones aquí.\nAbre una oferta del catálogo y toca «Chatear con el vendedor».',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _recargar();
                        await _f;
                      },
                      child: ListView.separated(
                        itemCount: lista.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 88, color: Color(0xFFE9EDEF)),
                        itemBuilder: (_, i) => _fila(lista[i]),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
