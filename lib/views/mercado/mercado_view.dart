import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

const _mkt = '/api/v1/marketplace';

class MercadoPage extends StatelessWidget {
  const MercadoPage({super.key});
  @override
  Widget build(BuildContext context) {
    return TabsPage(tabs: {
      'Catálogo': const CatalogoTab(),
      if (session.esComprador) ...{
        'Mis compras': const ComprasTab(),
        'Carrito': const CarritoTab(),
        'Favoritos': const FavoritosTab(),
      },
      if (esAdmin) ...{
        'Mis ofertas': const MisOfertasTab(),
        'Ventas': const VentasTab(),
      },
    });
  }
}

// ── Catálogo ────────────────────────────────────────────────────────────────
class CatalogoTab extends StatefulWidget {
  const CatalogoTab({super.key});
  @override
  State<CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<CatalogoTab> {
  final _q = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Buscar productos agrícolas...',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () { _q.clear(); setState(() => _query = ''); }),
          ),
        ),
      ),
      Expanded(
        child: AsyncList(
          key: ValueKey(_query),
          loader: () => marketplaceService.listados(q: _query, limit: 30),
          empty: 'No hay ofertas publicadas',
          itemBuilder: (c, l, _) {
            final fotos = (l['fotos'] as List?) ?? [];
            final cat = s(l['categoria']);
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AgroColors.slateBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalleListadoPage(id: l['idlistado'] as int))),
                child: Row(children: [
                  SizedBox(
                    width: 100, height: 108,
                    child: fotos.isNotEmpty
                        ? Image.network(s(fotos.first), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))
                        : Container(color: AgroColors.surfaceGreen, child: const Icon(Icons.eco, color: AgroColors.primary)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s(l['titulo']), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
                        const SizedBox(height: 2),
                        Text('${s(l['finca'])} · ${s(l['ubicacion'])}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        if (cat.isNotEmpty) CropBadge(cat, showIcon: false),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: Text('${money(l['preciounitario'])} / ${s(l['unidad'])}',
                                style: const TextStyle(color: AgroColors.primary, fontWeight: FontWeight.w900)),
                          ),
                          if (l['destacado'] == true) const Icon(Icons.star, size: 16, color: AgroColors.amber),
                        ]),
                        Text('Disponible: ${n(l['volumendisponible'])} ${s(l['unidad'])}',
                            style: const TextStyle(fontSize: 11, color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class DetalleListadoPage extends StatefulWidget {
  final int id;
  const DetalleListadoPage({super.key, required this.id});
  @override
  State<DetalleListadoPage> createState() => _DetalleListadoPageState();
}

class _DetalleListadoPageState extends State<DetalleListadoPage> {
  late final Future<Map<String, dynamic>> _f = marketplaceService.listado(widget.id);
  final _cant = TextEditingController(text: '1');
  final _entrega = TextEditingController();

  Future<void> _comprar(Map<String, dynamic> l) async {
    final cant = num.tryParse(_cant.text.replaceAll(',', '.'));
    if (cant == null || cant <= 0) return snack(context, 'Cantidad inválida');
    final ok = await run(
      context,
      () => marketplaceService.crearOrden({
        'idlistado': l['idlistado'],
        'cantidad': cant,
        if (_entrega.text.trim().isNotEmpty) 'puntoentrega': _entrega.text.trim(),
      }),
      ok: 'Orden enviada al vendedor',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _carrito(Map<String, dynamic> l) async {
    final cant = num.tryParse(_cant.text.replaceAll(',', '.'));
    if (cant == null || cant <= 0) return snack(context, 'Cantidad inválida');
    await run(context, () => marketplaceService.agregarAlCarrito(l['idlistado'], cant), ok: 'Agregado al carrito');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oferta'), actions: [
        if (session.esComprador)
          IconButton(
            tooltip: 'Guardar en favoritos (Premium)',
            icon: const Icon(Icons.favorite_border),
            onPressed: () => run(context, () => marketplaceService.agregarFavorito(widget.id), ok: 'Guardado en favoritos'),
          ),
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!));
          final l = snap.data!;
          final fotos = (l['fotos'] as List?) ?? [];
          final cat = s(l['categoria']);
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (fotos.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView(children: [
                  for (final f in fotos) ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(s(f), fit: BoxFit.cover)),
                ]),
              ),
            const SizedBox(height: 14),
            if (cat.isNotEmpty) ...[CropBadge(cat), const SizedBox(height: 8)],
            Text(s(l['titulo']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AgroColors.textDark)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.store, size: 14, color: AgroColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text('${s(l['finca'])} · ${s(l['ubicacion'])}',
                  style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600))),
              if (l['destacado'] == true) const Icon(Icons.star, size: 16, color: AgroColors.amber),
            ]),
            const SizedBox(height: 8),
            Text('${money(l['preciounitario'])} / ${s(l['unidad'])}',
                style: const TextStyle(fontSize: 24, color: AgroColors.primary, fontWeight: FontWeight.w900)),
            Text('Disponible: ${n(l['volumendisponible'])} ${s(l['unidad'])}',
                style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
            if (s(l['descripcion']).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(s(l['descripcion']), style: const TextStyle(color: AgroColors.textDark, height: 1.4)),
            ],
            if (session.esComprador) ...[
              const Divider(height: 32),
              TextField(
                controller: _cant,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Cantidad (${s(l['unidad'])})', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(controller: _entrega, decoration: const InputDecoration(labelText: 'Punto de entrega (opcional)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () => _comprar(l), icon: const Icon(Icons.shopping_bag), label: const Text('Comprar')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => _carrito(l), icon: const Icon(Icons.add_shopping_cart), label: const Text('Agregar al carrito (Premium)')),
            ],
          ]);
        },
      ),
    );
  }
}

// ── Comprador: compras y carrito ────────────────────────────────────────────
class ComprasTab extends StatelessWidget {
  const ComprasTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => marketplaceService.misCompras(),
      empty: 'Aún no has comprado',
      itemBuilder: (c, o, reload) {
        final est = s(o['estado']).toUpperCase();
        final cancelable = est == 'PENDIENTE' || est == 'ACEPTADA';
        return AgroListCard(
          leading: const AgroIconTile(icon: Icons.receipt_long),
          title: Text(s(o['titulo']), style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
          subtitle: Text('${s(o['finca'])} · ${n(o['cantidad'])} ${s(o['unidad'])}\n${money(o['subtotal'])}',
              style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600, height: 1.35)),
          badges: StatusBadge(est.toLowerCase()),
          trailing: cancelable
              ? IconButton(
                  tooltip: 'Cancelar',
                  icon: const Icon(Icons.cancel_outlined, color: Color(0xFFB91C1C)),
                  onPressed: () async {
                    if (!await confirmar(c, '¿Cancelar esta orden?') || !c.mounted) return;
                    if (await run(c, () => marketplaceService.cancelarOrden(o['idorden']), ok: 'Orden cancelada')) reload();
                  },
                )
              : null,
        );
      },
    );
  }
}

class CarritoTab extends StatefulWidget {
  const CarritoTab({super.key});
  @override
  State<CarritoTab> createState() => _CarritoTabState();
}

class _CarritoTabState extends State<CarritoTab> {
  final _k = GlobalKey<AsyncListState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncList(
        key: _k,
        loader: () => marketplaceService.carrito(),
        empty: 'Tu carrito está vacío (función Premium)',
        itemBuilder: (c, it, reload) => AgroListCard(
          leading: const AgroIconTile(icon: Icons.shopping_cart),
          title: Text(s(it['titulo']), style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
          subtitle: Text('${n(it['cantidad'])} ${s(it['unidad'])} · ${money(it['subtotal'])}',
              style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
          badges: it['disponible'] == false ? const StatusBadge('agotado') : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
            onPressed: () async {
              if (await run(c, () => marketplaceService.quitarDelCarrito(it['idlistado']))) reload();
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.shopping_bag),
        label: const Text('Ordenar carrito'),
        onPressed: () async {
          if (await run(context, () => marketplaceService.ordenarCarrito(), ok: 'Órdenes enviadas')) {
            _k.currentState?.reload();
          }
        },
      ),
    );
  }
}

// ── Vendedor (admin): ofertas y ventas ──────────────────────────────────────
class MisOfertasTab extends StatelessWidget {
  const MisOfertasTab({super.key});
  @override
  Widget build(BuildContext context) {
    return CrudList(
      path: '$_mkt/listados',
      listPath: '$_mkt/listados/mios',
      idKey: 'idlistado',
      singular: 'oferta',
      icon: Icons.sell,
      canEdit: true,
      fields: () async => [
        const FieldDef('titulo', 'Título', required: true),
        const FieldDef('descripcion', 'Descripción', type: FT.multiline),
        const FieldDef('categoria', 'Categoría'),
        const FieldDef('volumen', 'Volumen disponible', type: FT.number, required: true),
        const FieldDef('unidad', 'Unidad (kg, t, bultos…)'),
        const FieldDef('preciounitario', 'Precio por unidad (COP)', type: FT.number, required: true),
        const FieldDef('ubicacion', 'Ubicación'),
        FieldDef('estado', 'Estado', type: FT.select, onlyEdit: true, options: [
          MapEntry('BORRADOR', 'Borrador'),
          MapEntry('PUBLICADO', 'Publicado'),
          MapEntry('PAUSADO', 'Pausado'),
        ]),
      ],
      normalize: (l) => {...l, 'volumen': l['volumen'] ?? l['volumendisponible']},
      title: (l) => s(l['titulo']),
      subtitle: (l) => '${n(l['volumendisponible'] ?? l['volumen'])} ${s(l['unidad'])} · ${money(l['preciounitario'])}',
      badge: (l) => StatusBadge(s(l['estado'])),
      extra: (l) => [
        RowAction('Agregar foto', (ctx, item, reload) async {
          final actuales = ((item['fotos'] as List?) ?? []).map((e) => e.toString()).toList();
          if (actuales.length >= 6) return snack(ctx, 'Máximo 6 fotos por oferta');
          final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
          if (x == null || !ctx.mounted) return;
          final b64 = 'data:image/jpeg;base64,${base64Encode(await x.readAsBytes())}';
          try {
            final url = await marketplaceService.subirFoto(b64);
            await marketplaceService.actualizarListado(item['idlistado'], {'fotos': [...actuales, url]});
            if (ctx.mounted) snack(ctx, 'Foto agregada');
            reload();
          } catch (e) {
            if (ctx.mounted) snack(ctx, Api.errorMsg(e));
          }
        }),
        RowAction('Quitar todas las fotos', (ctx, item, reload) async {
          if (await run(ctx, () => marketplaceService.actualizarListado(item['idlistado'], {'fotos': <String>[]}), ok: 'Fotos eliminadas')) reload();
        }),
        RowAction('Destacar (Premium)', (ctx, item, reload) async {
          if (await run(ctx, () => marketplaceService.destacarListado(item['idlistado']), ok: 'Oferta destacada')) reload();
        }),
      ],
    );
  }
}

class VentasTab extends StatelessWidget {
  const VentasTab({super.key});

  Future<void> _accion(BuildContext c, Map<String, dynamic> o, String a, VoidCallback reload, String ok) async {
    if (await run(c, () => marketplaceService.accionOrden(o['idorden'], a), ok: ok)) reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => marketplaceService.ventas(),
      empty: 'Aún no tienes ventas',
      itemBuilder: (c, o, reload) {
        final est = s(o['estado']).toUpperCase();
        return AgroCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s(o['titulo']), style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark))),
              StatusBadge(est.toLowerCase()),
            ]),
            const SizedBox(height: 6),
            Text('${s(o['compradorNombre'])} · ${s(o['compradorTelefono'])}',
                style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
            Text('${n(o['cantidad'])} ${s(o['unidad'])} · subtotal ${money(o['subtotal'])} · neto ${money(o['netovendedor'])}',
                style: const TextStyle(color: AgroColors.textDark, fontWeight: FontWeight.w600)),
            if (s(o['puntoentrega']).isNotEmpty)
              Text('Entrega: ${s(o['puntoentrega'])}', style: const TextStyle(color: AgroColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
                if (est == 'PENDIENTE') ...[
                  FilledButton(onPressed: () => _accion(c, o, 'aceptar', reload, 'Orden aceptada'), child: const Text('Aceptar')),
                  OutlinedButton(onPressed: () => _accion(c, o, 'rechazar', reload, 'Orden rechazada'), child: const Text('Rechazar')),
                ],
                if (est == 'ACEPTADA') ...[
                  FilledButton(onPressed: () => _accion(c, o, 'cerrar', reload, 'Venta cerrada'), child: const Text('Cerrar venta')),
                  OutlinedButton(onPressed: () => _accion(c, o, 'cancelar', reload, 'Orden cancelada'), child: const Text('Cancelar')),
                ],
              ]),
            ]),
        );
      },
    );
  }
}

// ── Favoritos (wishlist, Premium) ───────────────────────────────────────────
class FavoritosTab extends StatelessWidget {
  const FavoritosTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => marketplaceService.favoritos(),
      empty: 'Sin favoritos (función Premium)',
      itemBuilder: (c, w, reload) => AgroListCard(
        leading: AgroIconTile(
          icon: Icons.favorite,
          color: w['disponible'] == false ? AgroColors.textMuted : const Color(0xFFDC2626),
          bg: w['disponible'] == false ? const Color(0xFFF1F5F9) : const Color(0xFFFEE2E2),
        ),
        title: Text(s(w['titulo']), style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
        subtitle: Text('${money(w['preciounitario'])} / ${s(w['unidad'])}',
            style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
        badges: w['disponible'] == false ? const StatusBadge('agotado') : null,
        onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalleListadoPage(id: w['idlistado'] as int))),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
          onPressed: () async {
            if (await run(c, () => marketplaceService.quitarFavorito(w['idlistado']))) reload();
          },
        ),
      ),
    );
  }
}
