import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/plan/plan_view.dart';

/// Nómina (Premium): liquidación de jornales y horas de las tareas completadas.
class NominaPage extends StatefulWidget {
  const NominaPage({super.key});
  @override
  State<NominaPage> createState() => _NominaPageState();
}

class _NominaPageState extends State<NominaPage> {
  final _k = GlobalKey<ListPageState>();
  Object? _premium;

  Future<List<dynamic>> _load() async {
    try {
      final l = await nominaService.nominas();
      if (_premium != null && mounted) setState(() => _premium = null);
      return l;
    } catch (e) {
      if (Api.esPremiumRequerido(e) && mounted) setState(() => _premium = e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_premium != null) {
      return PremiumNotice(
        message: 'La nómina calcula automáticamente lo que debes pagar a cada empleado según las tareas completadas.',
        onVerPlanes: () => pushPage(context, 'Plan y suscripción', const PlanPage()),
      );
    }
    return ListPage(
      key: _k,
      loader: _load,
      empty: 'Aún no hay nóminas.\nCrea una para liquidar un periodo.',
      emptyIcon: Icons.payments_outlined,
      addLabel: 'Nueva nómina',
      onAdd: (reload) async {
        final d = await showForm(context, 'Nueva nómina', const [
          FieldDef('fechainicio', 'Desde', type: FT.date, required: true),
          FieldDef('fechafin', 'Hasta', type: FT.date, required: true, after: 'fechainicio'),
        ], okLabel: 'Calcular');
        if (d == null || !context.mounted) return;
        if (await run(context, () => nominaService.crear(d), ok: 'Nómina calculada (en borrador)')) reload();
      },
      itemBuilder: (c, nm, reload) {
        final est = s(nm['estado']).toUpperCase();
        return AgroListCard(
          leading: AgroIconTile(icon: est == 'PAGADA' ? Icons.check_circle : Icons.payments),
          title: Text('${fecha(nm['fechainicio'])} – ${fecha(nm['fechafin'])}', style: AgroText.title),
          subtitle: Text('${cant(nm['empleados'])} empleado(s)', style: AgroText.muted),
          badges: StatusBadge(est),
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(money(nm['total']), style: AgroText.amount),
              const Icon(Icons.chevron_right, color: AgroColors.textMuted),
            ]),
          ),
          onTap: () async {
            await Navigator.of(c).push(MaterialPageRoute(builder: (_) => NominaDetallePage(idnomina: nm['idnomina'])));
            reload();
          },
        );
      },
    );
  }
}

class NominaDetallePage extends StatefulWidget {
  final dynamic idnomina;
  const NominaDetallePage({super.key, required this.idnomina});
  @override
  State<NominaDetallePage> createState() => _NominaDetallePageState();
}

class _NominaDetallePageState extends State<NominaDetallePage> {
  late Future<Map<String, dynamic>> _f = nominaService.detalle(widget.idnomina);

  void _recargar() => setState(() => _f = nominaService.detalle(widget.idnomina));

  Future<void> _deducciones(Map<String, dynamic> d) async {
    final r = await showForm(context, 'Deducciones de ${s(d['primernombre'])}', const [
      FieldDef('deducciones', 'Deducciones (COP)', type: FT.number, required: true, min: 0,
          helper: 'Préstamos, anticipos, seguridad social…'),
    ], initial: {'deducciones': d['deducciones']}, edit: true);
    if (r == null || !mounted) return;
    if (await run(context, () => nominaService.ajustarDeducciones(d['idnominadetalle'], r['deducciones'] as num),
        ok: 'Deducciones actualizadas')) {
      _recargar();
    }
  }

  Future<void> _accion(String est) async {
    final id = widget.idnomina;
    switch (est) {
      case 'BORRADOR':
        if (!await confirmar(context, 'Después de confirmarla ya no podrás ajustar deducciones.',
            titulo: '¿Confirmar la nómina?', ok: 'Confirmar')) {
          return;
        }
        if (!mounted) return;
        if (await run(context, () => nominaService.confirmar(id), ok: 'Nómina confirmada')) _recargar();
      case 'CONFIRMADA':
        if (!await confirmar(context, 'Se registrará el pago a todos los empleados de esta nómina.',
            titulo: '¿Marcar como pagada?', ok: 'Marcar pagada')) {
          return;
        }
        if (!mounted) return;
        if (await run(context, () => nominaService.pagar(id), ok: 'Nómina pagada')) _recargar();
    }
  }

  Future<void> _eliminar() async {
    if (!await confirmar(context, 'Solo se pueden eliminar nóminas en borrador.',
        titulo: '¿Eliminar esta nómina?', ok: 'Eliminar', destructivo: true)) {
      return;
    }
    if (!mounted) return;
    if (await run(context, () => nominaService.eliminar(widget.idnomina), ok: 'Nómina eliminada') && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (c, snap) {
        final est = s(snap.data?['estado']).toUpperCase();
        return Scaffold(
          appBar: AppBar(title: const Text('Detalle de nómina'), actions: [
            if (est == 'BORRADOR')
              IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline), onPressed: _eliminar),
          ]),
          bottomNavigationBar: est == 'BORRADOR' || est == 'CONFIRMADA'
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      onPressed: () => _accion(est),
                      icon: Icon(est == 'BORRADOR' ? Icons.verified : Icons.payments),
                      label: Text(est == 'BORRADOR' ? 'Confirmar nómina' : 'Marcar como pagada'),
                    ),
                  ),
                )
              : null,
          body: () {
            if (!snap.hasData && snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
            final nm = snap.data!;
            final det = [for (final d in (nm['detalles'] as List?) ?? const []) (d as Map).cast<String, dynamic>()];
            return RefreshIndicator(
              onRefresh: () async {
                _recargar();
                await _f;
              },
              child: ListView(padding: const EdgeInsets.all(14), children: [
                AgroCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${fecha(nm['fechainicio'])} – ${fecha(nm['fechafin'])}', style: AgroText.title)),
                      StatusBadge(est),
                    ]),
                    const SizedBox(height: 10),
                    InfoRow('Empleados', cant(det.length)),
                    InfoRow('Total a pagar', money(nm['total']), strong: true),
                    if (est == 'BORRADOR')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Toca un empleado para ajustar sus deducciones antes de confirmar.', style: AgroText.muted),
                      ),
                  ]),
                ),
                const SizedBox(height: 14),
                const AgroSectionHeader('Empleados'),
                const SizedBox(height: 8),
                if (det.isEmpty) const AgroEmpty(message: 'No hubo tareas completadas en este periodo'),
                for (final d in det)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AgroCard(
                      onTap: est == 'BORRADOR' ? () => _deducciones(d) : null,
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          AgroAvatar(url: s(d['fotoperfil']), nombre: '${s(d['primernombre'])} ${s(d['primerapellido'])}', radius: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text('${s(d['primernombre'])} ${s(d['primerapellido'])}', style: AgroText.title)),
                          Text(money(d['neto']), style: AgroText.amount),
                          if (est == 'BORRADOR') const Icon(Icons.edit_outlined, size: 18, color: AgroColors.textMuted),
                        ]),
                        const SizedBox(height: 8),
                        InfoRow('Horas', '${cant(d['horas'])} × ${money(d['valorhora'])}'),
                        InfoRow('Jornales', '${cant(d['jornadas'])} × ${money(d['valorjornal'])}'),
                        InfoRow('Bruto', money(d['bruto'])),
                        InfoRow('Deducciones', '- ${money(d['deducciones'])}'),
                      ]),
                    ),
                  ),
              ]),
            );
          }(),
        );
      },
    );
  }
}
