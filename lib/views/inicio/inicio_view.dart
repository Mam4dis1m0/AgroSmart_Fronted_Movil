import 'package:flutter/material.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/operacion/operacion_view.dart';

// ── Inicio / Dashboard ──────────────────────────────────────────────────────
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  Future<Map<String, dynamic>> _load() async {
    final out = <String, dynamic>{};
    try {
      out['finca'] = (await fincaService.activa()).toMap();
    } catch (_) {}
    if (esAdmin) {
      out['kpi'] = await fincaService.dashboard(session.idfinca ?? 0);
    } else {
      final t = (await operacionService.tareas()).map((e) => e.toMap()).toList();
      final low = (await produccionService.insumosStockBajo()).map((e) => e.toMap()).toList();
      bool est(dynamic x, String p) => s(x['estado']).toLowerCase().startsWith(p);
      out['kpi'] = {
        'tareas_pendientes': t.where((x) => est(x, 'pendiente')).length,
        'tareas_en_progreso': t.where((x) => est(x, 'en progreso')).length,
        'tareas_completadas': t.where((x) => est(x, 'completad')).length,
        'insumos_stock_bajo': low.length,
      };
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!));
        final d = snap.data!;
        final f = (d['finca'] as Map?)?.cast<String, dynamic>() ?? {};
        final k = (d['kpi'] as Map?)?.cast<String, dynamic>() ?? {};
        final pendientes = n(k['tareas_pendientes']);
        final progreso = n(k['tareas_en_progreso']);
        final completadas = n(k['tareas_completadas']);
        final stockBajo = n(k['insumos_stock_bajo']);
        final ubic = s(f['ubicacion']);
        return ListView(padding: const EdgeInsets.all(14), children: [
          AgroHeroCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('AGROSMART',
                        style: TextStyle(color: Color(0xFFA3E5BC), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const SizedBox(height: 3),
                    Text('¡Hola, ${session.nombre}!',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.place, size: 12, color: Color(0xFFA3E5BC)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text('${s(f['nombre'])}${ubic.isEmpty ? '' : ' · $ubic'}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFA3E5BC), fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ]),
                ),
                const AgroIconTile(icon: Icons.agriculture, color: Color(0xFFA3E5BC), bg: Color(0xFF143B26), size: 42),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                AgroHeroStat(label: 'PENDIENTES', value: s(pendientes), valueColor: AgroColors.amber),
                const SizedBox(width: 8),
                AgroHeroStat(label: 'EN PROGRESO', value: s(progreso)),
                const SizedBox(width: 8),
                AgroHeroStat(label: 'STOCK BAJO', value: s(stockBajo), valueColor: stockBajo > 0 ? AgroColors.amber : Colors.white),
              ]),
            ]),
          ),
          if (stockBajo > 0) ...[
            const SizedBox(height: 10),
            AgroAlert(
              message: 'Tienes ${stockBajo == 1 ? 'un insumo' : '$stockBajo insumos'} con stock bajo',
              action: 'Revisar',
              onAction: () => pushPage(c, 'Insumos', const OperacionPage()),
            ),
          ],
          const SizedBox(height: 18),
          const AgroSectionHeader('Resumen'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              AgroStatCard(label: 'Completadas', value: s(completadas), icon: Icons.check_circle, color: const Color(0xFF2D6A4F)),
              AgroStatCard(label: 'En progreso', value: s(progreso), icon: Icons.autorenew, color: const Color(0xFFB45309)),
              if (k['cultivos'] != null)
                AgroStatCard(label: 'Cultivos', value: s(k['cultivos']), icon: Icons.grass, color: const Color(0xFF2D6A4F)),
              if (k['miembros'] != null)
                AgroStatCard(label: 'Miembros', value: s(k['miembros']), icon: Icons.group, color: const Color(0xFF4338CA)),
              if (k['ventas_marketplace'] != null)
                AgroStatCard(label: 'Ventas marketplace', value: money(k['ventas_marketplace']), icon: Icons.storefront, color: const Color(0xFF0F766E)),
            ],
          ),
        ]);
      },
    );
  }
}
