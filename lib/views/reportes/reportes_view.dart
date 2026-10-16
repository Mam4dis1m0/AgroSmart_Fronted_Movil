import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/plan/plan_view.dart';

/// Reportes (Premium): costos por cultivo + exportación CSV.
class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  DateTime? _desde, _hasta;
  late Future<List<Map<String, dynamic>>> _f = _cargar();
  String? _exportando;

  Future<List<Map<String, dynamic>>> _cargar() =>
      reporteService.costos(desde: _desde == null ? null : ymd(_desde!), hasta: _hasta == null ? null : ymd(_hasta!));

  Future<void> _rango() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _desde != null && _hasta != null ? DateTimeRange(start: _desde!, end: _hasta!) : null,
      saveText: 'Aplicar',
    );
    if (r == null || !mounted) return;
    setState(() {
      _desde = r.start;
      _hasta = r.end;
      _f = _cargar();
    });
  }

  String _errBytes(Object e) {
    if (e is DioException && e.response?.data is List<int>) {
      try {
        final m = jsonDecode(utf8.decode(e.response!.data as List<int>));
        if (m is Map && m['code'] == 'PLAN_PREMIUM_REQUERIDO') return Api.errorMsg(DioException(requestOptions: e.requestOptions, response: Response(requestOptions: e.requestOptions, data: m)));
        if (m is Map && m['message'] != null) return m['message'].toString();
      } catch (_) {}
    }
    return Api.errorMsg(e);
  }

  Future<void> _exportar(String tipo) async {
    setState(() => _exportando = tipo);
    try {
      final arch = await reporteService.exportar(tipo, desde: _desde == null ? null : ymd(_desde!), hasta: _hasta == null ? null : ymd(_hasta!));
      final x = kIsWeb
          ? XFile.fromData(Uint8List.fromList(arch.bytes), name: arch.nombre, mimeType: 'text/csv')
          : await () async {
              final dir = await getTemporaryDirectory();
              final f = File('${dir.path}/${arch.nombre}');
              await f.writeAsBytes(arch.bytes);
              return XFile(f.path, mimeType: 'text/csv');
            }();
      await Share.shareXFiles([x], text: 'Reporte AgroSmart ($tipo)');
    } catch (e) {
      if (mounted) snack(context, _errBytes(e));
    } finally {
      if (mounted) setState(() => _exportando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodo = _desde == null ? 'Todo el historial' : '${fecha(_desde!.toIso8601String())} – ${fecha(_hasta!.toIso8601String())}';
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _f = _cargar());
        await _f;
      },
      child: ListView(padding: const EdgeInsets.all(14), children: [
        AgroCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          onTap: _rango,
          child: Row(children: [
            const Icon(Icons.date_range, color: AgroColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Periodo', style: AgroText.muted),
                Text(periodo, style: AgroText.title),
              ]),
            ),
            if (_desde != null)
              IconButton(
                tooltip: 'Quitar filtro',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _desde = _hasta = null;
                  _f = _cargar();
                }),
              )
            else
              const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.chevron_right, color: AgroColors.textMuted)),
          ]),
        ),
        const SizedBox(height: 16),
        const AgroSectionHeader('Exportar a CSV (abre en Excel)'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (tipo, label, icon) in const [
            ('gastos', 'Gastos', Icons.receipt_long),
            ('insumos', 'Insumos', Icons.inventory_2),
            ('cultivo', 'Cultivos', Icons.grass),
          ])
            ActionChip(
              avatar: _exportando == tipo
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(icon, size: 18, color: AgroColors.primary),
              label: Text(label),
              onPressed: _exportando == null ? () => _exportar(tipo) : null,
            ),
        ]),
        const SizedBox(height: 22),
        const AgroSectionHeader('Costos por cultivo'),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (c, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              if (Api.esPremiumRequerido(snap.error!)) {
                return PremiumNotice(
                  message: 'Los reportes muestran cuánto te cuesta cada cultivo entre insumos y mano de obra.',
                  onVerPlanes: () => pushPage(context, 'Plan y suscripción', const PlanPage()),
                );
              }
              return AgroError(message: Api.errorMsg(snap.error!), onRetry: () => setState(() => _f = _cargar()));
            }
            final rows = snap.data!;
            if (rows.isEmpty) return const AgroEmpty(icon: Icons.bar_chart, message: 'Sin costos registrados en el periodo');
            final maxT = rows.map((r) => n(r['total'])).fold<double>(1, (a, b) => b > a ? b : a);
            final total = rows.fold<double>(0, (a, r) => a + n(r['total']));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AgroCard(
                color: AgroColors.surfaceGreen,
                child: InfoRow('Total del periodo', money(total), strong: true),
              ),
              const SizedBox(height: 8),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AgroCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(s(r['cultivo']).isEmpty ? 'Cultivo #${r['idcultivo']}' : s(r['cultivo']), style: AgroText.title),
                        ),
                        Text(money(r['total']), style: AgroText.amount),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: n(r['total']) / maxT,
                          minHeight: 8,
                          backgroundColor: AgroColors.neutralBg,
                          semanticsLabel: 'Proporción del costo',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Insumos ${money(r['costo_insumos'])} · Mano de obra ${money(r['costo_mano_obra'])}', style: AgroText.muted),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
