import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Inventario de insumos con alerta de stock bajo, compras e historial.
class InsumosTab extends StatelessWidget {
  const InsumosTab({super.key});

  static bool _bajo(Map<String, dynamic> i) => n(i['stockminimo']) > 0 && n(i['stockactual']) <= n(i['stockminimo']);

  @override
  Widget build(BuildContext context) {
    return CrudList(
      path: '/api/v1/insumos',
      idKey: 'idinsumo',
      singular: 'insumo',
      icon: Icons.inventory_2,
      canEdit: esAdmin,
      empty: 'Aún no registras insumos.\nAgrega fertilizantes, semillas o herramientas.',
      fields: () async => const [
        FieldDef('nombre', 'Nombre', required: true, minLength: 2),
        FieldDef('tipo', 'Tipo de insumo', type: FT.selectOther, options: [
          MapEntry('Fertilizante', 'Fertilizante'),
          MapEntry('Semilla', 'Semilla'),
          MapEntry('Plaguicida', 'Plaguicida'),
          MapEntry('Herbicida', 'Herbicida'),
          MapEntry('Fungicida', 'Fungicida'),
          MapEntry('Herramienta', 'Herramienta'),
          MapEntry('Combustible', 'Combustible'),
        ]),
        FieldDef('unidadmedida', 'Unidad de medida', type: FT.selectOther, options: [
          MapEntry('kg', 'Kilogramos (kg)'),
          MapEntry('g', 'Gramos (g)'),
          MapEntry('L', 'Litros (L)'),
          MapEntry('ml', 'Mililitros (ml)'),
          MapEntry('bulto', 'Bultos'),
          MapEntry('unidad', 'Unidades'),
          MapEntry('galón', 'Galones'),
        ]),
        FieldDef('stockactual', 'Stock actual', type: FT.number, min: 0),
        FieldDef('stockminimo', 'Stock mínimo (alerta)', type: FT.number, min: 0),
        FieldDef('costounitario', 'Costo unitario (COP)', type: FT.number, min: 0),
      ],
      title: (i) => s(i['nombre']),
      subtitle: (i) => juntar([
        s(i['tipo']),
        'mín. ${cant(i['stockminimo'])} ${s(i['unidadmedida'])}'.trim(),
        if (n(i['costounitario']) > 0) '${money(i['costounitario'])}/u',
      ]),
      trailingText: (i) => '${cant(i['stockactual'])} ${s(i['unidadmedida'])}'.trim(),
      tint: (i) => _bajo(i) ? AgroColors.warningSoft : null,
      badge: (i) => _bajo(i) ? const StatusBadge('atencion') : null,
      extra: (i) => [
        if (esAdmin) ...[
          RowAction('Registrar compra', (ctx, item, reload) async {
            final d = await showForm(ctx, 'Compra de ${s(item['nombre'])}', [
              FieldDef('cantidad', 'Cantidad (${s(item['unidadmedida']).isEmpty ? 'unidades' : s(item['unidadmedida'])})',
                  type: FT.number, required: true, min: 0),
              const FieldDef('costounitario', 'Costo unitario (COP)', type: FT.number, required: true, min: 0),
              const FieldDef('proveedor', 'Proveedor'),
              const FieldDef('fechacompra', 'Fecha de compra', type: FT.date),
            ], initial: {'costounitario': item['costounitario']}, edit: false, okLabel: 'Registrar compra');
            if (d == null || !ctx.mounted) return;
            if (await run(ctx, () => operacionService.registrarCompra(item['idinsumo'], d), ok: 'Compra registrada, stock actualizado')) {
              reload();
            }
          }, icon: Icons.add_shopping_cart),
          RowAction('Historial de compras', (ctx, item, _) async {
            await pushPage(ctx, 'Compras · ${s(item['nombre'])}', _HistorialCompras(insumo: item));
          }, icon: Icons.history),
        ],
      ],
    );
  }
}

class _HistorialCompras extends StatelessWidget {
  final Map<String, dynamic> insumo;
  const _HistorialCompras({required this.insumo});

  @override
  Widget build(BuildContext context) {
    final u = s(insumo['unidadmedida']);
    return AsyncList(
      loader: () => operacionService.comprasInsumo((insumo['idinsumo'] as num).toInt()),
      empty: 'No hay compras registradas para este insumo',
      emptyIcon: Icons.receipt_long,
      itemBuilder: (c, p, _) => AgroListCard(
        leading: const AgroIconTile(icon: Icons.receipt_long),
        title: Text('${cant(p['cantidad'])} $u · ${money(p['costototal'] ?? n(p['cantidad']) * n(p['costounitario']))}', style: AgroText.title),
        subtitle: Text(juntar([fecha(p['fechacompra']), s(p['proveedor']), '${money(p['costounitario'])}/u']), style: AgroText.muted),
      ),
    );
  }
}
