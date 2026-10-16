import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/mensajes/hilo_view.dart';
import 'package:agrosmart_proto/views/mercado/compras_tab.dart';
import 'package:agrosmart_proto/views/mercado/detalle_listado_view.dart';
import 'package:agrosmart_proto/views/mercado/ventas_tab.dart';

/// Avisos (notificaciones) de la finca y del marketplace.
class AvisosPage extends StatefulWidget {
  const AvisosPage({super.key});
  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

class _AvisosPageState extends State<AvisosPage> {
  final _k = GlobalKey<ListPageState>();
  bool _soloNoLeidas = false;

  (IconData, Color, Color) _estilo(String tipo, bool leida) {
    if (leida) return (_icono(tipo), AgroColors.textMuted, AgroColors.neutralBg);
    return switch (tipo) {
      'ORDEN_RECHAZADA' || 'ORDEN_CANCELADA' => (_icono(tipo), AgroColors.danger, AgroColors.dangerBg),
      'ORDEN_ACEPTADA' || 'ORDEN_NUEVA' => (_icono(tipo), AgroColors.primary, AgroColors.surfaceGreen),
      'MENSAJE_MERCADO' => (_icono(tipo), AgroColors.info, AgroColors.infoBg),
      _ => (_icono(tipo), AgroColors.warning, AgroColors.warningBg),
    };
  }

  IconData _icono(String tipo) => switch (tipo) {
        'ORDEN_NUEVA' => Icons.shopping_bag_outlined,
        'ORDEN_ACEPTADA' => Icons.verified_outlined,
        'ORDEN_RECHAZADA' || 'ORDEN_CANCELADA' => Icons.cancel_outlined,
        'OFERTA_CERCANA' => Icons.place_outlined,
        'MENSAJE_MERCADO' => Icons.chat_bubble_outline,
        _ => Icons.notifications_none,
      };

  Future<void> _abrir(BuildContext c, Map<String, dynamic> nt, VoidCallback reload) async {
    if (nt['leida'] != true) {
      await run(c, () => avisoService.marcarLeida(nt['idnotificacion']));
      contadores.refrescar();
      reload();
    }
    if (!c.mounted) return;
    final tipo = s(nt['tipo']);
    final id = (nt['idregistro'] as num?)?.toInt();
    switch (tipo) {
      case 'ORDEN_NUEVA':
        if (esAdmin) await pushPage(c, 'Ventas', const VentasTab());
      case 'ORDEN_ACEPTADA' || 'ORDEN_RECHAZADA' || 'ORDEN_CANCELADA':
        await pushPage(c, session.esComprador ? 'Mis compras' : 'Ventas', session.esComprador ? const ComprasTab() : const VentasTab());
      case 'OFERTA_CERCANA':
        if (id != null) await Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetalleListadoPage(id: id)));
      case 'MENSAJE_MERCADO':
        if (id == null) return;
        final hilo = await cargar(c, () => mensajeriaService.hilo(id));
        if (hilo != null && c.mounted) await Navigator.of(c).push(MaterialPageRoute(builder: (_) => HiloPage(hilo: hilo)));
    }
  }

  Future<void> _marcarTodas() async {
    if (await run(context, avisoService.marcarTodas, ok: 'Todos los avisos marcados como leídos')) {
      contadores.refrescar();
      _k.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
        child: Row(children: [
          Expanded(
            child: FilterChips(
              options: const ['No leídas'],
              selected: _soloNoLeidas ? 'No leídas' : null,
              onSelected: (v) => setState(() => _soloNoLeidas = v != null),
            ),
          ),
          TextButton.icon(onPressed: _marcarTodas, icon: const Icon(Icons.done_all), label: const Text('Marcar todas')),
        ]),
      ),
      Expanded(
        child: ListPage(
          key: _k,
          loader: () => avisoService.notificaciones().then((l) => l.map((e) => e.toMap()).toList()),
          filter: _soloNoLeidas ? (nt) => nt['leida'] != true : null,
          empty: _soloNoLeidas ? 'No tienes avisos sin leer' : 'No tienes avisos',
          emptyIcon: Icons.notifications_none,
          itemBuilder: (c, nt, reload) {
            final leida = nt['leida'] == true;
            final (icon, color, bg) = _estilo(s(nt['tipo']), leida);
            final titulo = s(nt['titulo']).isEmpty ? 'Aviso' : s(nt['titulo']);
            return AgroListCard(
              tint: leida ? null : AgroColors.warningSoft,
              leading: AgroIconTile(icon: icon, color: color, bg: bg),
              title: Text(titulo, style: AgroText.title.copyWith(fontWeight: leida ? FontWeight.w600 : FontWeight.w800)),
              subtitle: Text('${s(nt['mensaje'])}\n${fecha(nt['fecha'], hora: true)}', style: AgroText.muted),
              onTap: () => _abrir(c, nt, reload),
              trailing: esAdmin
                  ? RowMenu(item: nt, reload: reload, actions: [
                      RowAction('Eliminar aviso', (ctx, it, r) async {
                        if (!await confirmar(ctx, 'Se eliminará para todos los miembros de la finca.',
                            titulo: '¿Eliminar aviso?', ok: 'Eliminar', destructivo: true)) {
                          return;
                        }
                        if (!ctx.mounted) return;
                        if (await run(ctx, () => avisoService.eliminar(it['idnotificacion']), ok: 'Aviso eliminado')) {
                          r();
                          contadores.refrescar();
                        }
                      }, icon: Icons.delete_outline, destructive: true),
                    ])
                  : null,
            );
          },
        ),
      ),
    ]);
  }
}
