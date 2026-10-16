import 'package:flutter/material.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/shell.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

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
        fincaService.activa().then((f) => f.toMap()).catchError((_) => <String, dynamic>{}),
        fincaService.dashboard(session.idfinca ?? 0),
      ]);
      return {'finca': r[0], 'kpi': r[1]};
    }
    final r = await Future.wait<dynamic>([
      fincaService.activa().then((f) => f.toMap()).catchError((_) => <String, dynamic>{}),
      operacionService.tareas(),
      produccionService.insumosStockBajo().then<List<dynamic>>((l) => l).catchError((_) => <dynamic>[]),
    ]);
    final t = (r[1] as List).map((e) => e.toMap()).toList();
    return {
      'finca': r[0],
      'kpi': {
        'tareas_pendientes': t.where((x) => est(x, 'pendiente') || est(x, 'asignad')).length,
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (c, snap) {
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
        final d = snap.data!;
        final f = (d['finca'] as Map?)?.cast<String, dynamic>() ?? {};
        final k = (d['kpi'] as Map?)?.cast<String, dynamic>() ?? {};
        final pendientes = n(k['tareas_pendientes']);
        final progreso = n(k['tareas_en_progreso']);
        final completadas = n(k['tareas_completadas']);
        final stockBajo = n(k['insumos_stock_bajo']);
        final nombreFinca = s(f['nombre']).isEmpty ? s(session.fincaActiva['nombre']) : s(f['nombre']);
        final ubic = s(f['ubicacion']);
        void tareas() => HomeShell.irA(c, ShellTab.tareas);
        return RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(padding: const EdgeInsets.all(14), children: [
            AgroHeroCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('AGROSMART',
                          style: TextStyle(color: AgroColors.mintPale, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 3),
                      Text('¡Hola, ${session.nombre}!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.place, size: 14, color: AgroColors.mintPale),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(juntar([nombreFinca, ubic]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AgroColors.mintPale, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ]),
                  ),
                  const AgroIconTile(icon: Icons.agriculture, color: AgroColors.mintPale, bg: AgroColors.forestTile, size: 44),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  AgroHeroStat(label: 'Pendientes', value: cant(pendientes), valueColor: AgroColors.amber),
                  const SizedBox(width: 8),
                  AgroHeroStat(label: 'En progreso', value: cant(progreso)),
                  const SizedBox(width: 8),
                  AgroHeroStat(label: 'Stock bajo', value: cant(stockBajo), valueColor: stockBajo > 0 ? AgroColors.amber : Colors.white),
                ]),
              ]),
            ),
            if (stockBajo > 0) ...[
              const SizedBox(height: 10),
              AgroAlert(
                message: 'Tienes ${stockBajo == 1 ? 'un insumo' : '${cant(stockBajo)} insumos'} con stock bajo',
                action: 'Revisar',
                onAction: () => HomeShell.irA(c, ShellTab.tareas, sub: 1),
              ),
            ],
            const SizedBox(height: 18),
            const AgroSectionHeader('Resumen'),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (_, box) {
              final w = (box.maxWidth - 10) / 2;
              final cards = <Widget>[
                AgroStatCard(label: 'Completadas', value: cant(completadas), icon: Icons.check_circle, color: AgroColors.primaryLight, onTap: tareas),
                AgroStatCard(label: 'En progreso', value: cant(progreso), icon: Icons.autorenew, color: AgroColors.warning, onTap: tareas),
                if (k['cultivos'] != null)
                  AgroStatCard(
                      label: 'Cultivos', value: cant(k['cultivos']), icon: Icons.grass, color: AgroColors.primaryLight,
                      onTap: () => HomeShell.irA(c, ShellTab.cultivos, sub: 1)),
                if (k['miembros'] != null) AgroStatCard(label: 'Miembros', value: cant(k['miembros']), icon: Icons.group, color: AgroColors.indigo),
                if (k['ventas_marketplace'] != null)
                  AgroStatCard(
                      label: 'Ventas cerradas', value: money(k['ventas_marketplace']), icon: Icons.storefront, color: AgroColors.teal,
                      onTap: () => HomeShell.irA(c, ShellTab.mercado, sub: 2)),
              ];
              return Wrap(spacing: 10, runSpacing: 10, children: [for (final w0 in cards) SizedBox(width: w, child: w0)]);
            }),
          ]),
        );
      },
    );
  }
}
