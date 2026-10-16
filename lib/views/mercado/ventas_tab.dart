import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Órdenes recibidas por la finca (vendedor).
class VentasTab extends StatefulWidget {
  const VentasTab({super.key});
  @override
  State<VentasTab> createState() => _VentasTabState();
}

class _VentasTabState extends State<VentasTab> {
  String? _filtro;
  static const _estados = {'Pendientes': 'PENDIENTE', 'Aceptadas': 'ACEPTADA', 'Cerradas': 'CERRADA'};

  Future<void> _accion(BuildContext c, Map<String, dynamic> o, String a, VoidCallback reload) async {
    final (titulo, msg, ok, destructivo, exito) = switch (a) {
      'aceptar' => ('¿Aceptar la orden?', 'Se reservará la cantidad para el comprador.', 'Aceptar', false, 'Orden aceptada'),
      'rechazar' => ('¿Rechazar la orden?', 'El comprador será notificado.', 'Rechazar', true, 'Orden rechazada'),
      'cerrar' => ('¿Cerrar la venta?', 'Confirma que entregaste el producto y recibiste el pago. Se liquidará la comisión.', 'Cerrar venta', false, 'Venta cerrada'),
      _ => ('¿Cancelar la orden?', 'La cantidad vuelve a estar disponible y el comprador será notificado.', 'Cancelar orden', true, 'Orden cancelada'),
    };
    if (!await confirmar(c, msg, titulo: titulo, ok: ok, destructivo: destructivo) || !c.mounted) return;
    if (await run(c, () => marketplaceService.accionOrden(o['idorden'], a), ok: exito)) reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => marketplaceService.ventas(),
      filter: _filtro == null ? null : (o) => s(o['estado']).toUpperCase() == _estados[_filtro],
      header: FilterChips(
        options: _estados.keys.toList(),
        selected: _filtro,
        onSelected: (v) => setState(() => _filtro = v),
      ),
      empty: _filtro == null ? 'Aún no tienes ventas' : 'No hay órdenes en este estado',
      emptyIcon: Icons.point_of_sale,
      itemBuilder: (c, o, reload) {
        final est = s(o['estado']).toUpperCase();
        return AgroCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s(o['titulo']), style: AgroText.title)),
              StatusBadge(est),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline, size: 16, color: AgroColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(juntar([s(o['compradorNombre']), s(o['compradorTelefono'])]), style: AgroText.muted)),
            ]),
            const SizedBox(height: 6),
            InfoRow('Cantidad', '${cant(o['cantidad'])} ${s(o['unidad'])}'),
            InfoRow('Subtotal', money(o['subtotal'])),
            InfoRow('Neto para ti', money(o['netovendedor']), strong: true),
            if (s(o['puntoentrega']).isNotEmpty) InfoRow('Entrega', s(o['puntoentrega'])),
            if (s(o['notas']).isNotEmpty) InfoRow('Notas', s(o['notas'])),
            if (est == 'PENDIENTE' || est == 'ACEPTADA') ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (est == 'PENDIENTE') ...[
                  FilledButton(onPressed: () => _accion(c, o, 'aceptar', reload), child: const Text('Aceptar')),
                  OutlinedButton(onPressed: () => _accion(c, o, 'rechazar', reload), child: const Text('Rechazar')),
                ],
                if (est == 'ACEPTADA') ...[
                  FilledButton(onPressed: () => _accion(c, o, 'cerrar', reload), child: const Text('Cerrar venta')),
                  OutlinedButton(onPressed: () => _accion(c, o, 'cancelar', reload), child: const Text('Cancelar')),
                ],
              ]),
            ],
          ]),
        );
      },
    );
  }
}
