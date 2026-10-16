import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

const _estados = ['Pendiente', 'En progreso', 'Completada'];

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
        tint: (i) => n(i['stockactual']) <= n(i['stockminimo']) ? const Color(0xFFFFFBEB) : null,
        badge: (i) => n(i['stockactual']) <= n(i['stockminimo']) ? const StatusBadge('atencion') : null,
        extra: (i) => [
          RowAction('Registrar compra', (ctx, item, reload) async {
            final d = await showForm(ctx, 'Compra de ${s(item['nombre'])}', const [
              FieldDef('cantidad', 'Cantidad', type: FT.number, required: true),
              FieldDef('costounitario', 'Costo unitario', type: FT.number, required: true),
              FieldDef('proveedor', 'Proveedor'),
            ]);
            if (d == null || !ctx.mounted) return;
            if (await run(ctx, () => operacionService.registrarCompra(item['idinsumo'], d),
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

  Future<List<FieldDef>> _fields() async {
    return [
      const FieldDef('tipoactividad', 'Actividad (riego, poda…)', required: true),
      const FieldDef('fechaprogramada', 'Fecha programada', type: FT.date),
      FieldDef('estado', 'Estado', type: FT.select, options: [for (final e in _estados) MapEntry(e, e)]),
      FieldDef('idcultivo', 'Cultivo', type: FT.select, options: await operacionService.cultivosOpc()),
      const FieldDef('costototal', 'Costo total', type: FT.number),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => operacionService.tareas().then((l) => l.map((e) => e.toMap()).toList()),
      empty: 'No hay tareas',
      addLabel: 'Nueva tarea',
      onAdd: esAdmin
          ? (reload) async {
              final f = await _fields();
              if (!context.mounted) return;
              final d = await showForm(context, 'Nueva tarea', f);
              if (d == null || !context.mounted) return;
              if (await run(context, () => operacionService.crearTarea(d), ok: 'Tarea creada')) {
                reload();
              }
            }
          : null,
      itemBuilder: (c, t, reload) {
        final estado = s(t['estado']);
        final done = estado.toLowerCase().contains('complet');
        return AgroListCard(
          leading: AgroIconTile(
            icon: done ? Icons.check : Icons.pending_actions,
            color: done ? AgroColors.primary : const Color(0xFFB45309),
            bg: done ? AgroColors.surfaceGreen : const Color(0xFFFEF3C7),
          ),
          title: Text(s(t['tipoactividad']).isEmpty ? 'Tarea #${t['idtarea']}' : s(t['tipoactividad']),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
          subtitle: Text('${d10(t['fechaprogramada'])}${n(t['costototal']) > 0 ? ' · ${money(t['costototal'])}' : ''}',
              style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
          badges: estado.isEmpty ? null : StatusBadge(estado),
          trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                final id = t['idtarea'];
                if (v == 'Completada') {
                  if (await run(c, () => operacionService.completarTarea(id), ok: 'Tarea completada')) reload();
                } else if (_estados.contains(v)) {
                  if (await run(c, () => operacionService.actualizarTarea(id, {'estado': v}))) reload();
                } else if (v == 'asignar') {
                  final emps = await operacionService.empleadosOpciones();
                  if (!c.mounted) return;
                  if (emps.isEmpty) return snack(c, 'No hay empleados activos en la finca');
                  final d = await showForm(c, 'Asignar tarea', [
                    FieldDef('idempleado', 'Empleado', type: FT.select, required: true, options: emps),
                    const FieldDef('pagoacordado', 'Pago acordado', type: FT.number),
                  ], okLabel: 'Asignar');
                  if (d == null || !c.mounted) return;
                  if (await run(c, () => operacionService.asignarTarea(id, d), ok: 'Tarea asignada')) reload();
                } else if (v == 'editar') {
                  final f = await _fields();
                  if (!c.mounted) return;
                  final d = await showForm(c, 'Editar tarea', f, initial: t);
                  if (d == null || !c.mounted) return;
                  if (await run(c, () => operacionService.actualizarTarea(id, d), ok: 'Guardado')) reload();
                } else if (v == 'eliminar') {
                  if (!await confirmar(c, '¿Eliminar esta tarea?') || !c.mounted) return;
                  if (await run(c, () => operacionService.eliminarTarea(id), ok: 'Eliminada')) reload();
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
        );
      },
    );
  }
}
