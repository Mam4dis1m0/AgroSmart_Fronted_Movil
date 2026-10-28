import 'package:flutter/material.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/shell.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/inicio/inicio_empleado.dart';

/// Inicio / Dashboard de la finca activa.
class InicioPage extends StatefulWidget {
  const InicioPage({super.key});
  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  late Future<Map<String, dynamic>> _f = _load();

  Future<Map<String, dynamic>> _load() async {
    bool est(dynamic x, String p) => s(x['estado']).toLowerCase().startsWith(p);
    if (esAdmin) {
      final r = await Future.wait<dynamic>([
        fincaService
            .activa()
            .then((f) => f.toMap())
            .catchError((_) => <String, dynamic>{}),
        fincaService.dashboard(session.idfinca ?? 0),
      ]);
      return {'finca': r[0], 'kpi': r[1]};
    }
    final r = await Future.wait<dynamic>([
      fincaService
          .activa()
          .then((f) => f.toMap())
          .catchError((_) => <String, dynamic>{}),
      operacionService.tareas(),
      produccionService
          .insumosStockBajo()
          .then<List<dynamic>>((l) => l)
          .catchError((_) => <dynamic>[]),
    ]);
    final t = (r[1] as List).map((e) => e.toMap()).toList();
    return {
      'finca': r[0],
      'kpi': {
        'tareas_pendientes':
            t.where((x) => est(x, 'pendiente') || est(x, 'asignad')).length,
        'tareas_en_progreso': t.where((x) => est(x, 'en progreso')).length,
        'tareas_completadas': t.where((x) => est(x, 'completad')).length,
        'insumos_stock_bajo': (r[2] as List).length,
      },
    };
  }

  Future<void> _recargar() async {
    setState(() => _f = _load());
    await _f;
  }

  @override
  Widget build(BuildContext context) {
    // El empleado entra directo a Â«Mis tareas de hoyÂ» (sin tarjetas de KPI).
    if (session.esEmpleado) return const EmpleadoInicioPage();
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (c, snap) {
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return AgroError(
              message: Api.errorMsg(snap.error!), onRetry: _recargar);
        }
        final d = snap.data!;
        final f = (d['finca'] as Map?)?.cast<String, dynamic>() ?? {};
        final k = (d['kpi'] as Map?)?.cast<String, dynamic>() ?? {};
        final pendientes = n(k['tareas_pendientes']);
        final progreso = n(k['tareas_en_progreso']);
        final completadas = n(k['tareas_completadas']);
        final stockBajo = n(k['insumos_stock_bajo']);
        final nombreFinca = s(f['nombre']).isEmpty
            ? s(session.fincaActiva['nombre'])
            : s(f['nombre']);
        final ubic = s(f['ubicacion']);
        void tareas() => HomeShell.irA(c, ShellTab.tareas);
        final resumen = <Widget>[
          if (k['cultivos'] != null)
            _metricCard(
              label: 'Cultivos activos',
              value: cant(k['cultivos']),
              icon: Icons.grass,
              onTap: () => HomeShell.irA(c, ShellTab.cultivos, sub: 1),
            ),
          if (k['miembros'] != null)
            _metricCard(
              label: 'Personas en el equipo',
              value: cant(k['miembros']),
              icon: Icons.groups_outlined,
            ),
          if (k['ventas_marketplace'] != null)
            _metricCard(
              label: 'Ventas cerradas',
              value: money(k['ventas_marketplace']),
              icon: Icons.storefront_outlined,
              onTap: () => HomeShell.irA(c, ShellTab.mercado, sub: 2),
            ),
          _metricCard(
            label: 'Tareas completadas',
            value: cant(completadas),
            icon: Icons.check_circle_outline,
            onTap: tareas,
          ),
        ];
        return RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                Text(
                  esAdmin ? 'PANEL DE ADMINISTRACIÃ“N' : 'RESUMEN DE ACTIVIDAD',
                  style: const TextStyle(
                    color: AgroColors.primaryLight,
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hola, ${session.nombre.split(' ').first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AgroColors.textDark,
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 17, color: AgroColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      juntar([nombreFinca, ubic]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AgroColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                AgroCard(
                  padding: const EdgeInsets.all(16),
                  onTap: tareas,
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AgroColors.surfaceGreen,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.checklist_rounded,
                          color: AgroColors.primary, size: 23),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tareas por atender',
                                style: TextStyle(
                                    color: AgroColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(
                              '${cant(pendientes)} pendientes Â· ${cant(progreso)} en progreso',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AgroColors.textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800),
                            ),
                          ]),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: AgroColors.textMuted),
                  ]),
                ),
                if (stockBajo > 0) ...[
                  const SizedBox(height: 12),
                  AgroAlert(
                    message:
                        'Tienes ${stockBajo == 1 ? 'un insumo' : '${cant(stockBajo)} insumos'} con stock bajo',
                    action: 'Revisar',
                    onAction: () => HomeShell.irA(c, ShellTab.tareas, sub: 2),
                  ),
                ],
                const SizedBox(height: 24),
                const AgroSectionHeader('Resumen de la finca'),
                const SizedBox(height: 10),
                LayoutBuilder(builder: (_, box) {
                  final width = (box.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final card in resumen)
                        SizedBox(width: width, child: card)
                    ],
                  );
                }),
              ]),
        );
      },
    );
  }
}

Widget _metricCard({
  required String label,
  required String value,
  required IconData icon,
  VoidCallback? onTap,
}) {
  return AgroCard(
    padding: const EdgeInsets.all(14),
    onTap: onTap,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AgroColors.surfaceGreen,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: AgroColors.primary),
        ),
        const Spacer(),
        if (onTap != null)
          const Icon(Icons.arrow_outward_rounded,
              size: 16, color: AgroColors.textMuted),
      ]),
      const SizedBox(height: 14),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AgroColors.textDark,
            fontSize: 21,
            height: 1.05,
            fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AgroColors.textMuted,
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w600),
      ),
    ]),
  );
}
