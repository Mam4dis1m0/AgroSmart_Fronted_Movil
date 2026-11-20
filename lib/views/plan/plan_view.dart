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
        planService.metodosPago(),
      ]);

  void _recargar() => setState(() => _f = _load());

  Future<void> _contratar(Map<String, dynamic>? premium, Map<String, dynamic> metodos,
      {bool renovar = false}) async {
    final m = ScaffoldMessenger.of(context);
    void aviso(String t) => m.showSnackBar(SnackBar(content: Text(t)));
    final precio = premium == null ? '' : money(premium['preciomensual']);
    final finca = s(session.fincaActiva['nombre']);
    final nequi = (metodos['nequi'] as Map?)?.cast<String, dynamic>();

    String metodo;
    String? referencia;
    String? comprobante;
    if (nequi != null) {
      // Paso 1: datos para transferir.
      if (!await confirmar(
          context,
          'Transfiere ${precio.isEmpty ? 'el valor del plan' : precio} desde tu app Nequi a:\n\n'
          '📱 ${s(nequi['numero'])}\n'
          '👤 ${s(nequi['titular'])}\n\n'
          'Cuando termines, toca «Ya transferí» y envía la referencia del comprobante.',
          titulo: renovar ? 'Renovar Premium con Nequi' : 'Pagar Premium con Nequi',
          ok: 'Ya transferí')) {
        return;
      }
      if (!mounted) return;
      // Paso 2: referencia + foto del comprobante.
      final r = await showForm(
        context,
        'Comprobante de Nequi',
        const [
          FieldDef('referencia', 'Referencia de la transferencia',
              required: true,
              minLength: 4,
              helper: 'Aparece en el comprobante de Nequi (por ejemplo M1234567).'),
          FieldDef('comprobante', 'Foto o captura del comprobante', type: FT.image),
        ],
        okLabel: 'Enviar',
      );
      if (r == null) return;
      metodo = 'NEQUI';
      referencia = s(r['referencia']).trim();
      comprobante = s(r['comprobante']);
    } else if (metodos['simulado'] == true) {
      if (!await confirmar(
          context,
          '${renovar ? 'Pagarás un mes más' : 'Activarás Premium'} para «$finca»'
          '${precio.isEmpty ? '' : ' por $precio'}.\n\n'
          'Modo de prueba: no se hace un cobro real.',
          titulo: renovar ? '¿Renovar Premium?' : '¿Contratar Premium?',
          ok: 'Continuar')) {
        return;
      }
      metodo = 'SIMULADO';
    } else {
      aviso('Los pagos aún no están disponibles. Intenta más tarde.');
      return;
    }
    if (!mounted) return;

    try {
      final r = await planService.contratar(
          metodo: metodo, referencia: referencia, comprobante: comprobante);
      final estado = s((r['pago'] as Map)['estado']).toUpperCase();
      if (estado == 'APROBADO') {
        aviso(renovar ? '¡Listo! Sumamos un mes más a tu Premium.' : '¡Premium activado!');
        await session.actualizarFincaActiva({'plan': 'PREMIUM'});
      } else {
        aviso(s(r['mensaje']).isEmpty
            ? 'Recibimos tu comprobante. Activaremos Premium al confirmarlo.'
            : s(r['mensaje']));
      }
    } catch (e) {
      aviso(Api.errorMsg(e));
    }
    _recargar();
  }

  /// Faltan 7 días o menos para que venza (se puede pagar el mes siguiente).
  bool _porVencer(Map<String, dynamic>? sus) {
    final f = DateTime.tryParse(s(sus?['fechafin']));
    return f != null && f.difference(DateTime.now()).inDays <= 7;
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
        final metodos = snap.data![3] as Map<String, dynamic>;
        final enRevision = pagos.any((p) => s(p['estado']).toUpperCase() == 'PENDIENTE');
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
                  Flexible(child: Text(esPremium ? 'Premium' : 'Freemium', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
                ]),
                if (sus != null && esPremium) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Vigente hasta ${fecha(sus['fechafin'])}${sus['renovacionautomatica'] == true ? ' · se renueva automáticamente' : ' · renuévalo pagando el mes siguiente'}',
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
            if (enRevision) ...[
              const AgroCard(
                child: Row(children: [
                  Icon(Icons.hourglass_top_rounded, color: AgroColors.warningText),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Tu pago por Nequi está en revisión. Activaremos Premium en cuanto confirmemos la transferencia.'),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            if (!esPremium)
              FilledButton.icon(
                icon: const Icon(Icons.workspace_premium),
                label: const Text('Contratar Premium'),
                onPressed: enRevision ? null : () => _contratar(premium, metodos),
              )
            else if (sus != null) ...[
              if (_porVencer(sus)) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.autorenew),
                  label: const Text('Pagar el próximo mes'),
                  onPressed: enRevision ? null : () => _contratar(premium, metodos, renovar: true),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AgroColors.danger, side: const BorderSide(color: AgroColors.danger, width: 1.5)),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar suscripción'),
                onPressed: _cancelar,
              ),
            ],
            if (metodos['revisor'] == true) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Revisar pagos de Nequi'),
                onPressed: () async {
                  await pushPage(context, 'Pagos por revisar', const _RevisarPagosView());
                  _recargar();
                },
              ),
            ],
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

/// Lista de transferencias Nequi por confirmar (solo revisores de pagos).
class _RevisarPagosView extends StatefulWidget {
  const _RevisarPagosView();
  @override
  State<_RevisarPagosView> createState() => _RevisarPagosViewState();
}

class _RevisarPagosViewState extends State<_RevisarPagosView> {
  late Future<List<Map<String, dynamic>>> _f = planService.porRevisar();

  void _recargar() => setState(() => _f = planService.porRevisar());

  Future<void> _revisar(Map<String, dynamic> p, bool aprobar) async {
    final ok = await confirmar(
      context,
      aprobar
          ? '¿Confirmas que recibiste ${money(p['monto'])} en Nequi con la referencia ${s(p['referencia'])}? Se activará Premium para «${s(p['finca'])}».'
          : '¿Rechazar este pago? La finca conservará su plan actual.',
      titulo: aprobar ? 'Aprobar pago' : 'Rechazar pago',
      ok: aprobar ? 'Aprobar' : 'Rechazar',
      destructivo: !aprobar,
    );
    if (!ok || !mounted) return;
    if (await run(context, () => planService.revisar((p['idpago'] as num).toInt(), aprobar: aprobar),
        ok: aprobar ? 'Pago aprobado: Premium activado' : 'Pago rechazado')) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
        final pagos = snap.data!;
        if (pagos.isEmpty) {
          return const AgroEmpty(icon: Icons.task_alt, message: 'No hay pagos por revisar');
        }
        return ListView(padding: const EdgeInsets.all(14), children: [
          for (final p in pagos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AgroCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(s(p['finca']), style: AgroText.title),
                  const SizedBox(height: 4),
                  Text(juntar([s(p['usuario']), s(p['email']), fecha(p['created_at'])]), style: AgroText.muted),
                  const SizedBox(height: 8),
                  Text('${money(p['monto'])} · Ref. ${s(p['referencia'])}', style: AgroText.amount),
                  if (s(p['comprobanteurl']).startsWith('http')) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        s(p['comprobanteurl']),
                        height: 260,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('No se pudo cargar el comprobante'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AgroColors.danger),
                        onPressed: () => _revisar(p, false),
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _revisar(p, true),
                        child: const Text('Aprobar'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
