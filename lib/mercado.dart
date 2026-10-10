import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'produccion.dart';
import 'ui.dart';

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
          loader: () => Api.i.getList('$_mkt/listados', query: {if (_query.isNotEmpty) 'q': _query, 'limit': 30}),
          empty: 'No hay ofertas publicadas',
          itemBuilder: (c, l, _) {
            final fotos = (l['fotos'] as List?) ?? [];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalleListadoPage(id: l['idlistado'] as int))),
                child: Row(children: [
                  SizedBox(
                    width: 96, height: 96,
                    child: fotos.isNotEmpty
                        ? Image.network(s(fotos.first), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))
                        : Container(color: Colors.green.shade50, child: const Icon(Icons.eco, color: Colors.green)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s(l['titulo']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${s(l['finca'])} · ${s(l['ubicacion'])}', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('${money(l['preciounitario'])} / ${s(l['unidad'])}',
                            style: TextStyle(color: Theme.of(c).colorScheme.primary, fontWeight: FontWeight.w600)),
                        Text('Disponible: ${n(l['volumendisponible'])} ${s(l['unidad'])}', style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                  if (l['destacado'] == true) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.star, color: Colors.amber)),
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
  late final Future<Map<String, dynamic>> _f = Api.i.dio
      .get('$_mkt/listados/${widget.id}')
      .then((r) => (r.data as Map).cast<String, dynamic>());
  final _cant = TextEditingController(text: '1');
  final _entrega = TextEditingController();

  Future<void> _comprar(Map<String, dynamic> l) async {
    final cant = num.tryParse(_cant.text.replaceAll(',', '.'));
    if (cant == null || cant <= 0) return snack(context, 'Cantidad inválida');
    final ok = await run(
      context,
      () => Api.i.dio.post('$_mkt/ordenes', data: {
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
    await run(context, () => Api.i.dio.put('$_mkt/carrito', data: {'idlistado': l['idlistado'], 'cantidad': cant}), ok: 'Agregado al carrito');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oferta')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text(Api.errorMsg(snap.error!)));
          final l = snap.data!;
          final fotos = (l['fotos'] as List?) ?? [];
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (fotos.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView(children: [
                  for (final f in fotos) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(s(f), fit: BoxFit.cover)),
                ]),
              ),
            const SizedBox(height: 12),
            Text(s(l['titulo']), style: Theme.of(c).textTheme.headlineSmall),
            Text('${s(l['finca'])} · ${s(l['ubicacion'])}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('${money(l['preciounitario'])} / ${s(l['unidad'])}',
                style: TextStyle(fontSize: 22, color: Theme.of(c).colorScheme.primary, fontWeight: FontWeight.bold)),
            Text('Disponible: ${n(l['volumendisponible'])} ${s(l['unidad'])}'),
            if (s(l['descripcion']).isNotEmpty) ...[const SizedBox(height: 12), Text(s(l['descripcion']))],
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
Color _colorOrden(String e) {
  switch (e.toUpperCase()) {
    case 'CERRADA': return Colors.green;
    case 'ACEPTADA': return Colors.blue;
    case 'RECHAZADA':
    case 'CANCELADA': return Colors.red;
    default: return Colors.orange;
  }
}

class ComprasTab extends StatelessWidget {
  const ComprasTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => Api.i.getList('$_mkt/ordenes/mis-compras'),
      empty: 'Aún no has comprado',
      itemBuilder: (c, o, reload) {
        final est = s(o['estado']).toUpperCase();
        final cancelable = est == 'PENDIENTE' || est == 'ACEPTADA';
        return Card(
          child: ListTile(
            leading: Icon(Icons.receipt_long, color: _colorOrden(est)),
            title: Text(s(o['titulo'])),
            subtitle: Text('${s(o['finca'])} · ${n(o['cantidad'])} ${s(o['unidad'])}\n${money(o['subtotal'])} · $est'),
            isThreeLine: true,
            trailing: cancelable
                ? IconButton(
                    tooltip: 'Cancelar',
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: () async {
                      if (!await confirmar(c, '¿Cancelar esta orden?') || !c.mounted) return;
                      if (await run(c, () => Api.i.dio.patch('$_mkt/ordenes/${o['idorden']}/cancelar'), ok: 'Orden cancelada')) reload();
                    },
                  )
                : null,
          ),
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
        loader: () => Api.i.getList('$_mkt/carrito'),
        empty: 'Tu carrito está vacío (función Premium)',
        itemBuilder: (c, it, reload) => Card(
          child: ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: Text(s(it['titulo'])),
            subtitle: Text('${n(it['cantidad'])} ${s(it['unidad'])} · ${money(it['subtotal'])}'
                '${it['disponible'] == false ? '\nNo disponible' : ''}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await run(c, () => Api.i.dio.delete('$_mkt/carrito/${it['idlistado']}'))) reload();
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.shopping_bag),
        label: const Text('Ordenar carrito'),
        onPressed: () async {
          if (await run(context, () => Api.i.dio.post('$_mkt/carrito/ordenar'), ok: 'Órdenes enviadas')) {
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
      subtitle: (l) => '${s(l['estado'])} · ${n(l['volumendisponible'] ?? l['volumen'])} ${s(l['unidad'])} · ${money(l['preciounitario'])}',
      extra: (l) => [
        RowAction('Destacar (Premium)', (ctx, item, reload) async {
          if (await run(ctx, () => Api.i.dio.post('$_mkt/listados/${item['idlistado']}/destacar'), ok: 'Oferta destacada')) reload();
        }),
      ],
    );
  }
}

class VentasTab extends StatelessWidget {
  const VentasTab({super.key});

  Future<void> _accion(BuildContext c, Map<String, dynamic> o, String a, VoidCallback reload, String ok) async {
    if (await run(c, () => Api.i.dio.patch('$_mkt/ordenes/${o['idorden']}/$a'), ok: ok)) reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => Api.i.getList('$_mkt/ordenes/ventas'),
      empty: 'Aún no tienes ventas',
      itemBuilder: (c, o, reload) {
        final est = s(o['estado']).toUpperCase();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s(o['titulo']), style: const TextStyle(fontWeight: FontWeight.bold))),
                Chip(label: Text(est), backgroundColor: _colorOrden(est).withValues(alpha: .15)),
              ]),
              Text('${s(o['compradorNombre'])} · ${s(o['compradorTelefono'])}'),
              Text('${n(o['cantidad'])} ${s(o['unidad'])} · subtotal ${money(o['subtotal'])} · neto ${money(o['netovendedor'])}'),
              if (s(o['puntoentrega']).isNotEmpty) Text('Entrega: ${s(o['puntoentrega'])}'),
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
          ),
        );
      },
    );
  }
}
