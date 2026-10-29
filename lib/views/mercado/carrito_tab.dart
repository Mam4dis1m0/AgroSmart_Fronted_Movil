import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Carrito de compras: varias ofertas en una sola acción.
class CarritoTab extends StatefulWidget {
  const CarritoTab({super.key});
  @override
  State<CarritoTab> createState() => _CarritoTabState();
}

class _CarritoTabState extends State<CarritoTab> {
  final _k = GlobalKey<AsyncListState>();
  List<Map<String, dynamic>> _items = const [];

  Future<List<dynamic>> _load() async {
    final l = await marketplaceService.carrito();
    if (mounted) setState(() => _items = l);
    return l;
  }

  Future<void> _ordenar() async {
    final disponibles = _items.where((i) => i['disponible'] != false).toList();
    final total = disponibles.fold<double>(0, (a, i) => a + n(i['subtotal']));
    if (!await confirmar(
      context,
      'Se enviará una orden por cada producto (${disponibles.length}) por un total de ${money(total)}.',
      titulo: '¿Ordenar el carrito?',
      ok: 'Enviar órdenes',
    )) {
      return;
    }
    if (!mounted) return;
    if (await run(context, marketplaceService.ordenarCarrito,
        ok: 'Órdenes enviadas a los vendedores')) {
      _k.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items
        .where((i) => i['disponible'] != false)
        .fold<double>(0, (a, i) => a + n(i['subtotal']));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncList(
        key: _k,
        loader: _load,
        empty: 'Tu carrito está vacío',
        emptyIcon: Icons.shopping_cart_outlined,
        itemBuilder: (c, it, reload) {
          final fotos = (it['fotos'] as List?) ?? const [];
          final foto = fotos.isEmpty
              ? ''
              : s(fotos.first is Map
                  ? (fotos.first as Map)['url']
                  : fotos.first);
          return AgroListCard(
            leading: AgroProductThumb(url: foto),
            title: Text(s(it['titulo']), style: AgroText.title),
            subtitle: Text(
              '${cant(it['cantidad'])} ${s(it['unidad'])} · ${money(it['subtotal'])}',
              style: AgroText.muted,
            ),
            badges:
                it['disponible'] == false ? const StatusBadge('agotado') : null,
            trailing: IconButton(
              tooltip: 'Quitar del carrito',
              icon: const Icon(Icons.delete_outline, color: AgroColors.danger),
              onPressed: () async {
                if (!await confirmar(
                  c,
                  '«${s(it['titulo'])}» saldrá de tu carrito.',
                  titulo: '¿Quitar producto?',
                  ok: 'Quitar',
                  destructivo: true,
                )) {
                  return;
                }
                if (!c.mounted) return;
                if (await run(
                    c,
                    () =>
                        marketplaceService.quitarDelCarrito(it['idlistado']))) {
                  reload();
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              icon: const Icon(Icons.shopping_bag),
              label: Text('Ordenar · ${money(total)}'),
              onPressed: _ordenar,
            ),
    );
  }
}
