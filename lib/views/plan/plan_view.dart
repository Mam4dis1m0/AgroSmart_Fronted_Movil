import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Plan de la finca (Freemium / Premium), suscripción y pagos.
class PlanPage extends StatefulWidget {
  const PlanPage({super.key});
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late Future<List<dynamic>> _f = _load();

  Future<List<dynamic>> _load() => Future.wait<dynamic>([
        planService.planes(),
        planService.suscripcion(),
        planService.pagos().catchError((_) => <Map<String, dynamic>>[]),
      ]);

  void _recargar() => setState(() => _f = _load());

  Future<void> _contratar(Map<String, dynamic>? premium) async {
    final precio = premium == null ? '' : ' por ${money(premium['preciomensual'])} al mes';
    if (!await confirmar(context, 'Activarás Premium para «${s(session.fincaActiva['nombre'])}»$precio. (Pasarela de pago simulada)',
        titulo: '¿Contratar Premium?', ok: 'Contratar')) {
      return;
    }
    if (!mounted) return;
    if (await run(context, planService.contratar, ok: '¡Premium activado!')) {
      await session.actualizarFincaActiva({'plan': 'PREMIUM'});
      _recargar();
    }
  }

  Future<void> _cancelar() async {
    if (!await confirmar(context, 'Volverás a Freemium. Tus datos se conservan, pero se aplicarán los límites del plan gratuito.',
        titulo: '¿Cancelar la suscripción?', ok: 'Cancelar suscripción', destructivo: true)) {
      return;
    }
    if (!mounted) return;
    if (await run(context, planService.cancelar, ok: 'Suscripción cancelada')) {
      await session.actualizarFincaActiva({'plan': 'FREEMIUM'});
      _recargar();
    }
  }

  String _limite(dynamic v) => v == null || n(v) <= 0 ? 'Ilimitado' : cant(v);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _f,
      builder: (c, snap) {
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
        final planes = (snap.data![0] as List).cast<Map<String, dynamic>>();
        final info = snap.data![1] as Map<String, dynamic>;
        final pagos = (snap.data![2] as List).cast<Map<String, dynamic>>();
        final sus = (info['suscripcion'] as Map?)?.cast<String, dynamic>();
        final efectivo = (info['planEfectivo'] as Map?)?.cast<String, dynamic>() ?? const {};
        final codigo = s(efectivo['codigo']).toUpperCase();
        final esPremium = codigo == 'PREMIUM';
        final premium = planes.where((p) => s(p['codigo']).toUpperCase() == 'PREMIUM').firstOrNull;

        return RefreshIndicator(
          onRefresh: () async {
            _recargar();
            await _f;
          },
          child: ListView(padding: const EdgeInsets.all(14), children: [
            AgroHeroCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TU PLAN ACTUAL', style: TextStyle(color: AgroColors.mintPale, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(esPremium ? Icons.workspace_premium : Icons.eco, color: esPremium ? AgroColors.amber : AgroColors.mint),
                  const SizedBox(width: 8),
                  Text(esPremium ? 'Premium' : 'Freemium', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
                if (sus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Vigente hasta ${fecha(sus['fechafin'])}${sus['renovacionautomatica'] == true ? ' · se renueva automáticamente' : ''}',
                    style: const TextStyle(color: AgroColors.mintPale, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  AgroHeroStat(label: 'Cultivos', value: _limite(efectivo['maxcultivos'])),
                  const SizedBox(width: 8),
                  AgroHeroStat(label: 'Empleados', value: _limite(efectivo['maxempleados'])),
                  const SizedBox(width: 8),
                  AgroHeroStat(label: 'Comisión', value: '${cant(efectivo['comisionmarketplace'])}%'),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            const AgroSectionHeader('Planes disponibles'),
            const SizedBox(height: 8),
            for (final p in planes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AgroCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(s(p['nombre']), style: AgroText.title.copyWith(fontSize: 16))),
                      if (s(p['codigo']).toUpperCase() == codigo) const StatusBadge('activo'),
                    ]),
                    const SizedBox(height: 4),
                    Text(n(p['preciomensual']) == 0 ? 'Gratis' : '${money(p['preciomensual'])} / mes', style: AgroText.amount.copyWith(fontSize: 18)),
                    if (s(p['descripcion']).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(s(p['descripcion']), style: AgroText.muted),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _chip(Icons.grass, 'Cultivos: ${_limite(p['maxcultivos'])}'),
                      _chip(Icons.group, 'Empleados: ${_limite(p['maxempleados'])}'),
                      _chip(Icons.agriculture, 'Fincas: ${_limite(p['maxfincas'])}'),
                      _chip(Icons.percent, 'Comisión ${cant(p['comisionmarketplace'])}%'),
                    ]),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            if (!esPremium)
              FilledButton.icon(
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Contratar Premium'),
                onPressed: () => _contratar(premium),
              )
            else if (sus != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AgroColors.danger, side: const BorderSide(color: AgroColors.danger, width: 1.5)),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar suscripción'),
                onPressed: _cancelar,
              ),
            if (pagos.isNotEmpty) ...[
              const SizedBox(height: 22),
              const AgroSectionHeader('Historial de pagos'),
              const SizedBox(height: 8),
              for (final p in pagos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AgroListCard(
                    leading: const AgroIconTile(icon: Icons.receipt_long),
                    title: Text(s(p['tipo']).isEmpty ? 'Pago' : _capital(s(p['tipo'])), style: AgroText.title),
                    subtitle: Text(juntar([fecha(p['created_at']), s(p['proveedor'])]), style: AgroText.muted),
                    badges: s(p['estado']).isEmpty ? null : StatusBadge(s(p['estado'])),
                    trailing: Padding(padding: const EdgeInsets.only(right: 8), child: Text(money(p['monto']), style: AgroText.amount)),
                  ),
                ),
            ],
          ]),
        );
      },
    );
  }

  static String _capital(String t) {
    final x = t.replaceAll('_', ' ').toLowerCase();
    return x[0].toUpperCase() + x.substring(1);
  }

  Widget _chip(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AgroColors.neutralBg, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: AgroColors.primary),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AgroColors.textDark)),
        ]),
      );
}
