import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/mensajes/bandeja_view.dart';

/// Órdenes del comprador.
class ComprasTab extends StatelessWidget {
  const ComprasTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => marketplaceService.misCompras(),
      empty: 'Aún no has comprado.\nExplora el catálogo para encontrar productos.',
      emptyIcon: Icons.receipt_long,
      itemBuilder: (c, o, reload) {
        final est = s(o['estado']).toUpperCase();
        final cancelable = est == 'PENDIENTE' || est == 'ACEPTADA';
        final idlistado = (o['idlistado'] as num?)?.toInt();
        return AgroListCard(
          leading: const AgroIconTile(icon: Icons.receipt_long),
          title: Text(s(o['titulo']), style: AgroText.title),
          subtitle: Text(
            '${juntar([s(o['finca']), '${cant(o['cantidad'])} ${s(o['unidad'])}'])}\n${money(o['subtotal'])} · ${fecha(o['createdAt'])}',
            style: AgroText.muted,
          ),
          badges: StatusBadge(est),
          trailing: RowMenu(item: o, reload: reload, actions: [
            if (idlistado != null)
              RowAction('Chatear con el vendedor', (ctx, it, _) => chatearConVendedor(ctx, idlistado, idorden: (it['idorden'] as num?)?.toInt()),
                  icon: Icons.chat_bubble_outline),
            if (cancelable)
              RowAction('Cancelar orden', (ctx, it, r) async {
                if (!await confirmar(ctx, 'El vendedor será notificado de la cancelación.',
                    titulo: '¿Cancelar esta orden?', ok: 'Cancelar orden', destructivo: true)) {
                  return;
                }
                if (!ctx.mounted) return;
                if (await run(ctx, () => marketplaceService.cancelarOrden(it['idorden']), ok: 'Orden cancelada')) r();
              }, icon: Icons.cancel_outlined, destructive: true),
          ]),
        );
      },
    );
  }
}
