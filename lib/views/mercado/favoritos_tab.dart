import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'detalle_listado_view.dart';

/// Favoritos del comprador (wishlist, Premium).
class FavoritosTab extends StatelessWidget {
  const FavoritosTab({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => marketplaceService.favoritos(),
      empty: 'Sin favoritos.\nToca el corazón en una oferta para guardarla.',
      emptyIcon: Icons.favorite_border,
      itemBuilder: (c, w, reload) {
        final agotado = w['disponible'] == false;
        return AgroListCard(
          leading: AgroIconTile(
            icon: Icons.favorite,
            color: agotado ? AgroColors.textMuted : AgroColors.danger,
            bg: agotado ? AgroColors.neutralBg : AgroColors.dangerBg,
          ),
          title: Text(s(w['titulo']), style: AgroText.title),
          subtitle: Text('${money(w['preciounitario'])} / ${s(w['unidad'])}', style: AgroText.muted),
          badges: agotado ? const StatusBadge('agotado') : null,
          onTap: () async {
            await Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalleListadoPage(id: (w['idlistado'] as num).toInt())));
            reload();
          },
          trailing: IconButton(
            tooltip: 'Quitar de favoritos',
            icon: const Icon(Icons.delete_outline, color: AgroColors.danger),
            onPressed: () async {
              if (await run(c, () => marketplaceService.quitarFavorito(w['idlistado']), ok: 'Quitado de favoritos')) reload();
            },
          ),
        );
      },
    );
  }
}
