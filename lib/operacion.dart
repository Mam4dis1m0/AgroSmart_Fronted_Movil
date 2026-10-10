import 'package:flutter/material.dart';
import 'api.dart';
import 'produccion.dart';
import 'ui.dart';

const _estados = ['Pendiente', 'En progreso', 'Completada'];

/// Empleados activos de la finca (para asignar tareas).
Future<List<MapEntry<dynamic, String>>> empleadosOpciones() async {
  final ms = await Api.i.getList('/api/v1/fincas/activa/miembros');
  return [
    for (final m in ms)
      if (m['rol'] == 'empleado' && m['activo'] != false)
        MapEntry(m['idusuario'], '${s(m['primernombre'])} ${s(m['primerapellido'])}'.trim()),
  ];
}

class OperacionPage extends StatelessWidget {
  const OperacionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return TabsPage(tabs: {
      'Tareas': const TareasPage(),
      'Insumos': CrudList(
        path: '/api/v1/insumos',
        idKey: 'idinsumo',
        singular: 'insumo',
        icon: Icons.inventory_2,
        canEdit: esAdmin,
        fields: () async => const [
          FieldDef('nombre', 'Nombre', required: true),
          FieldDef('tipo', 'Tipo (fertilizante, semilla…)'),
          FieldDef('unidadmedida', 'Unidad de medida'),
          FieldDef('stockactual', 'Stock actual', type: FT.number),
          FieldDef('stockminimo', 'Stock mínimo', type: FT.number),
          FieldDef('costounitario', 'Costo unitario', type: FT.number),
        ],
        title: (i) => s(i['nombre']),
        subtitle: (i) => '${s(i['tipo'])} · mínimo ${n(i['stockminimo'])} ${s(i['unidadmedida'])} · ${money(i['costounitario'])}',
        trailingText: (i) => '${n(i['stockactual'])} ${s(i['unidadmedida'])}',
        tint: (i) => n(i['stockactual']) <= n(i['stockminimo']) ? Colors.red.shade50 : null,
        extra: (i) => [
          RowAction('Registrar compra', (ctx, item, reload) async {
            final d = await showForm(ctx, 'Compra de ${s(item['nombre'])}', const [
              FieldDef('cantidad', 'Cantidad', type: FT.number, required: true),
              FieldDef('costounitario', 'Costo unitario', type: FT.number, required: true),
              FieldDef('proveedor', 'Proveedor'),
            ]);
            if (d == null || !ctx.mounted) return;
            if (await run(ctx, () => Api.i.dio.post('/api/v1/insumos/${item['idinsumo']}/compras', data: {...d, 'actualizarCostoUnitario': true}),
                ok: 'Compra registrada, stock actualizado')) {
              reload();
            }
          }),
        ],
      ),
    });
  }
}

class TareasPage extends StatelessWidget {
  const TareasPage({super.key});

  Color _color(String e) {
    final x = e.toLowerCase();
    if (x.contains('complet')) return Colors.green;
    if (x.contains('progreso')) return Colors.orange;
    return Colors.blueGrey;
  }

  Future<List<FieldDef>> _fields() async {
    final cultivos = await Api.i.getList('/cultivos');
    return [
      const FieldDef('tipoactividad', 'Actividad (riego, poda…)', required: true),
      const FieldDef('fechaprogramada', 'Fecha programada', type: FT.date),
      FieldDef('estado', 'Estado', type: FT.select, options: [for (final e in _estados) MapEntry(e, e)]),
      FieldDef('idcultivo', 'Cultivo', type: FT.select, options: [
        for (final c in cultivos) MapEntry(c['idcultivo'], s(c['tipo']).isEmpty ? 'Cultivo #${c['idcultivo']}' : s(c['tipo'])),
      ]),
      const FieldDef('costototal', 'Costo total', type: FT.number),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => Api.i.getList('/api/v1/tareas'),
      empty: 'No hay tareas',
      addLabel: 'Nueva tarea',
      onAdd: esAdmin
          ? (reload) async {
              final f = await _fields();
              if (!context.mounted) return;
              final d = await showForm(context, 'Nueva tarea', f);
              if (d == null || !context.mounted) return;
              if (await run(context, () => Api.i.dio.post('/api/v1/tareas', data: {'estado': 'Pendiente', ...d}), ok: 'Tarea creada')) {
                reload();
              }
            }
          : null,
      itemBuilder: (c, t, reload) {
        final estado = s(t['estado']);
        final done = estado.toLowerCase().contains('complet');
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _color(estado).withValues(alpha: .15),
              child: Icon(done ? Icons.check : Icons.pending_actions, color: _color(estado)),
            ),
            title: Text(s(t['tipoactividad']).isEmpty ? 'Tarea #${t['idtarea']}' : s(t['tipoactividad'])),
            subtitle: Text('${d10(t['fechaprogramada'])} · ${estado.isEmpty ? '—' : estado}'
                '${n(t['costototal']) > 0 ? ' · ${money(t['costototal'])}' : ''}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                final id = t['idtarea'];
                if (v == 'Completada') {
                  if (await run(c, () => Api.i.dio.patch('/api/v1/tareas/$id/completar'), ok: 'Tarea completada')) reload();
                } else if (_estados.contains(v)) {
                  if (await run(c, () => Api.i.dio.put('/api/v1/tareas/$id', data: {'estado': v}))) reload();
                } else if (v == 'asignar') {
                  final emps = await empleadosOpciones();
                  if (!c.mounted) return;
                  if (emps.isEmpty) return snack(c, 'No hay empleados activos en la finca');
                  final d = await showForm(c, 'Asignar tarea', [
                    FieldDef('idempleado', 'Empleado', type: FT.select, required: true, options: emps),
                    const FieldDef('pagoacordado', 'Pago acordado', type: FT.number),
                  ], okLabel: 'Asignar');
                  if (d == null || !c.mounted) return;
                  if (await run(c, () => Api.i.dio.patch('/api/v1/tareas/$id/asignar', data: d), ok: 'Tarea asignada')) reload();
                } else if (v == 'editar') {
                  final f = await _fields();
                  if (!c.mounted) return;
                  final d = await showForm(c, 'Editar tarea', f, initial: t);
                  if (d == null || !c.mounted) return;
                  if (await run(c, () => Api.i.dio.put('/api/v1/tareas/$id', data: d), ok: 'Guardado')) reload();
                } else if (v == 'eliminar') {
                  if (!await confirmar(c, '¿Eliminar esta tarea?') || !c.mounted) return;
                  if (await run(c, () => Api.i.dio.delete('/api/v1/tareas/$id'), ok: 'Eliminada')) reload();
                }
              },
              itemBuilder: (_) => [
                for (final e in _estados) PopupMenuItem(value: e, child: Text('Marcar: $e')),
                if (esAdmin) ...const [
                  PopupMenuItem(value: 'asignar', child: Text('Asignar a empleado')),
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
