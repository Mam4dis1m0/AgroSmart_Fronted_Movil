import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/mensajes/bandeja_view.dart';

/// Detalle de una oferta del catálogo: fotos, datos, compra, carrito, favorito y chat.
class DetalleListadoPage extends StatefulWidget {
  final int id;
  const DetalleListadoPage({super.key, required this.id});
  @override
  State<DetalleListadoPage> createState() => _DetalleListadoPageState();
}

class _DetalleListadoPageState extends State<DetalleListadoPage> {
  late Future<Map<String, dynamic>> _f = marketplaceService.listado(widget.id);
  final _cant = TextEditingController(text: '1');
  final _entrega = TextEditingController();
  final _notas = TextEditingController();
  final _fotos = PageController();
  int _foto = 0;
  bool? _favorito;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cant.addListener(() => setState(() {}));
    if (session.esComprador) _cargarFavorito();
  }

  @override
  void dispose() {
    _cant.dispose();
    _entrega.dispose();
    _notas.dispose();
    _fotos.dispose();
    super.dispose();
  }

  Future<void> _cargarFavorito() async {
    try {
      final l = await marketplaceService.favoritos();
      if (mounted) setState(() => _favorito = l.any((w) => (w['idlistado'] as num?)?.toInt() == widget.id));
    } catch (_) {
      if (mounted) setState(() => _favorito = false);
    }
  }

  Future<void> _toggleFavorito() async {
    final era = _favorito == true;
    final ok = await run(
      context,
      () => era ? marketplaceService.quitarFavorito(widget.id) : marketplaceService.agregarFavorito(widget.id),
      ok: era ? 'Quitado de favoritos' : 'Guardado en favoritos',
    );
    if (ok && mounted) setState(() => _favorito = !era);
  }

  num? _cantidad(Map<String, dynamic> l) {
    final c = num.tryParse(_cant.text.replaceAll(',', '.'));
    if (c == null || c <= 0) return null;
    if (c > n(l['volumendisponible'])) return null;
    return c;
  }

  Future<void> _comprar(Map<String, dynamic> l) async {
    final cant = _cantidad(l);
    if (cant == null) return snack(context, 'Ingresa una cantidad válida (máximo ${cant_(l)})');
    final total = cant * n(l['preciounitario']);
    if (!await confirmar(
      context,
      '${cant_(l, cant)} de «${s(l['titulo'])}» por ${money(total)}.\nEl vendedor debe aceptar la orden.',
      titulo: '¿Enviar orden de compra?',
      ok: 'Enviar orden',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => marketplaceService.crearOrden({
        'idlistado': l['idlistado'],
        'cantidad': cant,
        if (_entrega.text.trim().isNotEmpty) 'puntoentrega': _entrega.text.trim(),
        if (_notas.text.trim().isNotEmpty) 'notas': _notas.text.trim(),
      }),
      ok: 'Orden enviada al vendedor',
    );
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _carrito(Map<String, dynamic> l) async {
    final cant = _cantidad(l);
    if (cant == null) return snack(context, 'Ingresa una cantidad válida (máximo ${cant_(l)})');
    await run(context, () => marketplaceService.agregarAlCarrito(l['idlistado'], cant), ok: 'Agregado al carrito');
  }

  String cant_(Map<String, dynamic> l, [num? c]) => '${cant(c ?? l['volumendisponible'])} ${s(l['unidad'])}'.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oferta'), actions: [
        if (session.esComprador && _favorito != null)
          IconButton(
            tooltip: _favorito! ? 'Quitar de favoritos' : 'Guardar en favoritos (Premium)',
            icon: Icon(_favorito! ? Icons.favorite : Icons.favorite_border, color: _favorito! ? AgroColors.dangerBg : null),
            onPressed: _toggleFavorito,
          ),
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return AgroError(
              message: Api.errorMsg(snap.error!),
              onRetry: () => setState(() => _f = marketplaceService.listado(widget.id)),
            );
          }
          final l = snap.data!;
          final fotos = [for (final f in (l['fotos'] as List?) ?? const []) s(f)];
          final cat = s(l['categoria']);
          final cantidad = _cantidad(l);
          final total = (cantidad ?? 0) * n(l['preciounitario']);
          final excede = (num.tryParse(_cant.text.replaceAll(',', '.')) ?? 0) > n(l['volumendisponible']);
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (fotos.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 230,
                  child: PageView(
                    controller: _fotos,
                    onPageChanged: (i) => setState(() => _foto = i),
                    children: [
                      for (final f in fotos)
                        Image(
                          image: CachedNetworkImageProvider(f),
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, p) => p == null ? child : const ColoredBox(color: AgroColors.surfaceGreen, child: Center(child: CircularProgressIndicator())),
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: AgroColors.surfaceGreen,
                            child: Center(child: Icon(Icons.image_not_supported_outlined, size: 40, color: AgroColors.textMuted)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (fotos.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < fotos.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _foto ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _foto ? AgroColors.primary : AgroColors.handle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 14),
            ],
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (cat.isNotEmpty) CropBadge(cat),
              if (l['destacado'] == true) const StatusBadge('destacado'),
            ]),
            const SizedBox(height: 8),
            Text(s(l['titulo']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.store, size: 16, color: AgroColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(juntar([s(l['finca']), s(l['ubicacion'])]), style: AgroText.muted)),
            ]),
            const SizedBox(height: 10),
            Text('${money(l['preciounitario'])} / ${s(l['unidad']).isEmpty ? 'unidad' : s(l['unidad'])}',
                style: const TextStyle(fontSize: 24, color: AgroColors.primary, fontWeight: FontWeight.w800)),
            Text('Disponible: ${cant_(l)}', style: AgroText.muted),
            if (s(l['descripcion']).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(s(l['descripcion']), style: const TextStyle(color: AgroColors.textDark, height: 1.45)),
            ],
            if (session.esComprador) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => chatearConVendedor(context, widget.id),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chatear con el vendedor'),
              ),
              const Divider(height: 32),
              const Text('Comprar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
              const SizedBox(height: 10),
              TextField(
                controller: _cant,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cantidad (${s(l['unidad']).isEmpty ? 'unidades' : s(l['unidad'])})',
                  errorText: excede ? 'Solo hay ${cant_(l)} disponibles' : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _entrega, decoration: const InputDecoration(labelText: 'Punto de entrega (opcional)')),
              const SizedBox(height: 12),
              TextField(controller: _notas, maxLines: 2, decoration: const InputDecoration(labelText: 'Notas para el vendedor (opcional)')),
              const SizedBox(height: 12),
              AgroCard(
                color: AgroColors.surfaceGreen,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: InfoRow('Total estimado', money(total), strong: true),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || cantidad == null ? null : () => _comprar(l),
                icon: const Icon(Icons.shopping_bag),
                label: const Text('Comprar ahora'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: cantidad == null ? null : () => _carrito(l),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar al carrito (Premium)'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
