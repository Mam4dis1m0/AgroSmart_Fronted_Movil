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
  bool get _puedeComprar => session.esComprador || esAdmin;

  @override
  void initState() {
    super.initState();
    _cant.addListener(() => setState(() {}));
    if (_puedeComprar) _cargarFavorito();
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
      if (mounted)
        setState(() => _favorito =
            l.any((w) => (w['idlistado'] as num?)?.toInt() == widget.id));
    } catch (_) {
      if (mounted) setState(() => _favorito = false);
    }
  }

  Future<void> _toggleFavorito() async {
    final era = _favorito == true;
    final ok = await run(
      context,
      () => era
          ? marketplaceService.quitarFavorito(widget.id)
          : marketplaceService.agregarFavorito(widget.id),
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
    if (cant == null)
      return snack(context, 'Ingresa una cantidad válida (máximo ${cant_(l)})');
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
        if (_entrega.text.trim().isNotEmpty)
          'puntoentrega': _entrega.text.trim(),
        if (_notas.text.trim().isNotEmpty) 'notas': _notas.text.trim(),
      }),
      ok: 'Orden enviada al vendedor',
    );
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _carrito(Map<String, dynamic> l) async {
    final cant = _cantidad(l);
    if (cant == null)
      return snack(context, 'Ingresa una cantidad válida (máximo ${cant_(l)})');
    await run(context,
        () => marketplaceService.agregarAlCarrito(l['idlistado'], cant),
        ok: 'Agregado al carrito');
  }

  String cant_(Map<String, dynamic> l, [num? c]) =>
      '${cant(c ?? l['volumendisponible'])} ${s(l['unidad'])}'.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgroColors.page,
      appBar: AppBar(title: const Text('Oferta'), actions: [
        if (_puedeComprar && _favorito != null)
          IconButton(
            tooltip:
                _favorito! ? 'Quitar de favoritos' : 'Guardar en favoritos',
            icon: Icon(_favorito! ? Icons.favorite : Icons.favorite_border,
                color: _favorito! ? AgroColors.dangerBg : null),
            onPressed: _toggleFavorito,
          ),
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return AgroError(
              message: Api.errorMsg(snap.error!),
              onRetry: () =>
                  setState(() => _f = marketplaceService.listado(widget.id)),
            );
          }
          final l = snap.data!;
          final fotos = [
            for (final foto in (l['fotos'] as List?) ?? const [])
              s(foto is Map ? foto['url'] : foto)
          ].where((url) => url.isNotEmpty).toList();
          final cat = s(l['categoria']);
          final cantidad = _cantidad(l);
          final total = (cantidad ?? 0) * n(l['preciounitario']);
          final excede = (num.tryParse(_cant.text.replaceAll(',', '.')) ?? 0) >
              n(l['volumendisponible']);
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 250,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (fotos.isNotEmpty)
                          PageView(
                            controller: _fotos,
                            onPageChanged: (i) => setState(() => _foto = i),
                            children: [
                              for (final f in fotos)
                                Image(
                                  image: CachedNetworkImageProvider(f),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, p) => p == null
                                      ? child
                                      : const _ProductPhotoPlaceholder(),
                                  errorBuilder: (_, __, ___) =>
                                      const _ProductPhotoPlaceholder(),
                                ),
                            ],
                          )
                        else
                          const _ProductPhotoPlaceholder(),
                        Positioned(
                          left: 13,
                          top: 13,
                          child: Wrap(
                            spacing: 7,
                            children: [
                              if (cat.isNotEmpty) CropBadge(cat),
                              if (l['destacado'] == true)
                                const StatusBadge('destacado'),
                            ],
                          ),
                        ),
                        if (fotos.length > 1)
                          Positioned(
                            right: 13,
                            bottom: 13,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    AgroColors.forest.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_foto + 1} / ${fotos.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (fotos.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < fotos.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _foto ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _foto
                                    ? AgroColors.primary
                                    : AgroColors.handle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ]),
                  ),
                const SizedBox(height: 16),
                Text(s(l['titulo']),
                    style: const TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AgroColors.forestDeep)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                        color: AgroColors.surfaceLime, shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_rounded,
                        size: 17, color: AgroColors.primary),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      juntar([s(l['finca']), s(l['ubicacion'])]),
                      style: AgroText.muted,
                    ),
                  ),
                ]),
                const SizedBox(height: 15),
                AgroCard(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE7F8D8), Color(0xFFF9FCEC)],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PRECIO POR UNIDAD',
                                style: TextStyle(
                                    color: AgroColors.primaryLight,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                              money(l['preciounitario']),
                              style: const TextStyle(
                                  color: AgroColors.forest,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'por ${s(l['unidad']).isEmpty ? 'unidad' : s(l['unidad'])}',
                              style: AgroText.muted,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 18, color: AgroColors.primary),
                            const SizedBox(height: 3),
                            Text(cant_(l),
                                style: const TextStyle(
                                    color: AgroColors.forest,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                            const Text('disponibles',
                                style: TextStyle(
                                    color: AgroColors.textMuted, fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (s(l['descripcion']).isNotEmpty) ...[
                  const SizedBox(height: 17),
                  const Text('Sobre este producto',
                      style: TextStyle(
                          color: AgroColors.forest,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(s(l['descripcion']),
                      style: const TextStyle(
                          color: AgroColors.textDark, height: 1.45)),
                ],
                if (_puedeComprar) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => chatearConVendedor(context, widget.id),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Preguntar al productor'),
                  ),
                  const SizedBox(height: 18),
                  const Row(children: [
                    Icon(Icons.shopping_bag_outlined,
                        color: AgroColors.primary, size: 20),
                    SizedBox(width: 7),
                    Text('Llévalo a tu finca',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AgroColors.forest)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cant,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          'Cantidad (${s(l['unidad']).isEmpty ? 'unidades' : s(l['unidad'])})',
                      errorText:
                          excede ? 'Solo hay ${cant_(l)} disponibles' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _entrega,
                      decoration: const InputDecoration(
                          labelText: 'Punto de entrega (opcional)')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _notas,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Notas para el vendedor (opcional)')),
                  const SizedBox(height: 12),
                  AgroCard(
                    gradient: const LinearGradient(
                        colors: [AgroColors.surfaceLime, Colors.white]),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child:
                        InfoRow('Total estimado', money(total), strong: true),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _busy || cantidad == null ? null : () => _comprar(l),
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Comprar ahora'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: cantidad == null ? null : () => _carrito(l),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Agregar al carrito'),
                  ),
                ],
              ]);
        },
      ),
    );
  }
}

class _ProductPhotoPlaceholder extends StatelessWidget {
  const _ProductPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AgroColors.surfaceLime, Color(0xFFD8EEC6)],
        ),
      ),
      child: Center(
        child: Icon(Icons.agriculture_rounded,
            size: 64, color: AgroColors.primaryLight),
      ),
    );
  }
}
