import 'package:flutter/material.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'tareas_view.dart';

/// Detalle de una tarea: datos, asignación, horas trabajadas e insumos usados.
class TareaDetallePage extends StatefulWidget {
  final int idtarea;
  const TareaDetallePage({super.key, required this.idtarea});
  @override
  State<TareaDetallePage> createState() => _TareaDetallePageState();
}

class _TareaDetallePageState extends State<TareaDetallePage> {
  late Future<(Tarea, List<Map<String, dynamic>>)> _f = _load();

  Future<(Tarea, List<Map<String, dynamic>>)> _load() async {
    final r = await Future.wait<dynamic>([
      operacionService.tarea(widget.idtarea),
      operacionService.insumosDeTarea(widget.idtarea).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    return (r[0] as Tarea, (r[1] as List).cast<Map<String, dynamic>>());
  }

  void _recargar() => setState(() => _f = _load());

  Future<void> _registrarInsumo() async {
    final opc = await cargar(context, operacionService.insumosOpc);
    if (opc == null || !mounted) return;
    if (opc.isEmpty) return snack(context, 'No hay insumos registrados en la finca');
    final d = await showForm(context, 'Registrar insumo usado', [
      FieldDef('idinsumo', 'Insumo', type: FT.select, required: true, options: opc),
      const FieldDef('cantidadusada', 'Cantidad usada', type: FT.number, required: true, min: 0),
    ], okLabel: 'Registrar', edit: false);
    if (d == null || !mounted) return;
    if (await run(context, () => operacionService.registrarInsumoUsado(widget.idtarea, d), ok: 'Insumo registrado y descontado del stock')) {
      _recargar();
    }
  }

  Future<void> _horas(Map<String, dynamic> asig) async {
    final d = await showForm(context, 'Tiempo trabajado', const [
      FieldDef('horastrabajadas', 'Horas trabajadas', type: FT.number, min: 0),
      FieldDef('jornadastrabajadas', 'Jornales trabajados', type: FT.number, min: 0),
    ], initial: asig, edit: true);
    if (d == null || !mounted) return;
    if (await run(context, () => operacionService.actualizarAsignacion((asig['idasigtarea'] as num).toInt(), d), ok: 'Tiempo registrado')) {
      _recargar();
    }
  }

  Future<void> _quitarInsumo(Map<String, dynamic> d) async {
    if (!await confirmar(context, 'El registro se eliminará.', titulo: '¿Quitar este insumo de la tarea?', ok: 'Quitar', destructivo: true)) {
      return;
    }
    if (!mounted) return;
    if (await run(context, () => operacionService.eliminarInsumoUsado((d['iddetalletarea'] as num).toInt()), ok: 'Registro eliminado')) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Tarea, List<Map<String, dynamic>>)>(
      future: _f,
      builder: (c, snap) {
        final t = snap.data?.$1;
        return Scaffold(
          appBar: AppBar(
            title: Text(t == null || t.actividad.isEmpty ? 'Tarea' : t.actividad),
            actions: [
              if (t != null)
                RowMenu(item: t.raw, reload: _recargar, actions: [
                  for (final a in AccionesTarea.para(t))
                    if (a.label != 'Eliminar') a
                    else
                      RowAction(a.label, (ctx, it, _) async {
                        if (await AccionesTarea.eliminar(ctx, t) && ctx.mounted) Navigator.pop(ctx);
                      }, icon: a.icon, destructive: true),
                ]),
            ],
          ),
          body: () {
            if (t == null && snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
            final insumos = snap.data!.$2;
            final asig = t!.asignacion;
            final costoInsumos = insumos.fold<double>(0, (a, d) {
              final i = d['idinsumo'];
              return a + n(d['cantidadusada']) * n(i is Map ? i['costounitario'] : 0);
            });
            return RefreshIndicator(
              onRefresh: () async {
                _recargar();
                await _f;
              },
              child: ListView(padding: const EdgeInsets.all(14), children: [
                AgroCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(t.actividad, style: AgroText.title.copyWith(fontSize: 17))),
                      if (t.estado.isNotEmpty) StatusBadge(t.estado),
                    ]),
                    const SizedBox(height: 10),
                    InfoRow('Fecha programada', fecha(t.fechaprogramada)),
                    InfoRow('Cultivo', t.cultivoNombre),
                    if (n(t.raw['costototal']) > 0) InfoRow('Costo estimado', money(t.raw['costototal'])),
                  ]),
                ),
                const SizedBox(height: 14),
                const AgroSectionHeader('Asignación'),
                const SizedBox(height: 8),
                AgroCard(
                  child: asig == null
                      ? Row(children: [
                          const Expanded(child: Text('Sin asignar todavía', style: AgroText.muted)),
                          if (esAdmin)
                            FilledButton.icon(
                              onPressed: () async {
                                if (await AccionesTarea.asignar(context, t)) _recargar();
                              },
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Asignar'),
                            ),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            AgroAvatar(url: t.empleadoFoto, nombre: t.empleadoNombre, radius: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(t.empleadoNombre.isEmpty ? (esAdmin ? 'Empleado' : 'Tú') : t.empleadoNombre, style: AgroText.title)),
                            if (s(asig['estado']).isNotEmpty) StatusBadge(s(asig['estado'])),
                          ]),
                          const SizedBox(height: 8),
                          InfoRow('Asignada el', fecha(asig['fechaasignacion'])),
                          if (n(asig['pagoacordado']) > 0) InfoRow('Pago acordado', money(asig['pagoacordado'])),
                          InfoRow('Horas trabajadas', cant(asig['horastrabajadas'])),
                          InfoRow('Jornales trabajados', cant(asig['jornadastrabajadas'])),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _horas(asig),
                              icon: const Icon(Icons.timer_outlined),
                              label: const Text('Registrar tiempo'),
                            ),
                          ),
                        ]),
                ),
                const SizedBox(height: 14),
                AgroSectionHeader('Insumos usados', action: t.completada ? null : 'Registrar', onAction: _registrarInsumo),
                const SizedBox(height: 8),
                if (insumos.isEmpty)
                  const AgroEmpty(icon: Icons.inventory_2_outlined, message: 'No se han registrado insumos en esta tarea')
                else ...[
                  for (final d in insumos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AgroListCard(
                        leading: const AgroIconTile(icon: Icons.inventory_2),
                        title: Text(s(d['idinsumo'] is Map ? d['idinsumo']['nombre'] : 'Insumo'), style: AgroText.title),
                        subtitle: Text(
                          '${cant(d['cantidadusada'])} ${s(d['idinsumo'] is Map ? d['idinsumo']['unidadmedida'] : '')}'.trim(),
                          style: AgroText.muted,
                        ),
                        trailing: esAdmin
                            ? IconButton(
                                tooltip: 'Quitar registro',
                                icon: const Icon(Icons.delete_outline, color: AgroColors.danger),
                                onPressed: () => _quitarInsumo(d),
                              )
                            : null,
                      ),
                    ),
                  if (costoInsumos > 0)
                    AgroCard(color: AgroColors.surfaceGreen, child: InfoRow('Costo de insumos', money(costoInsumos), strong: true)),
                ],
                if (!t.completada && (session.esEmpleado || esAdmin)) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      if (await AccionesTarea.completarConFoto(context, t)) _recargar();
                    },
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Completar con foto de evidencia'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await AccionesTarea.completar(context, t)) _recargar();
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marcar como completada'),
                  ),
                ],
              ]),
            );
          }(),
        );
      },
    );
  }
}
