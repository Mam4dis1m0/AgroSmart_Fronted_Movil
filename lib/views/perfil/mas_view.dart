import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

// ── Más: menú ───────────────────────────────────────────────────────────────
class MasPage extends StatelessWidget {
  const MasPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String title,
      String? sub,
      VoidCallback? onTap,
      Color? iconColor,
      Color? iconBg,
      Color? titleColor,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AgroListCard(
          leading: AgroIconTile(icon: icon, color: iconColor, bg: iconBg),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: titleColor ?? AgroColors.textDark)),
          subtitle: sub == null ? null : Text(sub, style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: AgroColors.textMuted),
          onTap: onTap,
        ),
      );
    }

    Widget entry(IconData icon, String title, String sub, Widget page) =>
        tile(icon: icon, title: title, sub: sub, onTap: () => pushPage(context, title, page));

    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 10), child: AgroSectionHeader(title)),
            ...children,
          ],
        );

    return ListView(padding: const EdgeInsets.all(14), children: [
      section('Cuenta', [
        entry(Icons.person, 'Mi perfil', 'Datos personales y contraseña', const PerfilPage()),
      ]),
      if (esAdmin)
        section('Gestión', [
          entry(Icons.group, 'Equipo', 'Empleados y accesos', const EquipoPage()),
          entry(Icons.payments, 'Nómina', 'Pagos y jornales', const NominaPage()),
          entry(Icons.bar_chart, 'Reportes', 'Costos por cultivo y exportación', const ReportesPage()),
          entry(Icons.workspace_premium, 'Plan y suscripción', 'Administra tu plan', const PlanPage()),
        ]),
      section('Herramientas', [
        entry(Icons.smart_toy, 'Asistente IA', 'Consultas agrícolas (Premium)', const AsistentePage()),
        entry(Icons.notifications, 'Avisos', 'Notificaciones', const NotificacionesList()),
        if (esAdmin) entry(Icons.history, 'Auditoría', 'Registro de actividad', const AuditoriaPage()),
      ]),
      section('Sesión', [
        if (session.fincas.length > 1)
          tile(icon: Icons.swap_horiz, title: 'Cambiar de finca', sub: 'Selecciona otra finca', onTap: session.cambiarFinca),
        tile(
          icon: Icons.logout,
          title: 'Cerrar sesión',
          onTap: session.logout,
          iconColor: const Color(0xFFB91C1C),
          iconBg: const Color(0xFFFEE2E2),
          titleColor: const Color(0xFFB91C1C),
        ),
      ]),
    ]);
  }
}

// ── Perfil ──────────────────────────────────────────────────────────────────
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late Future<Map<String, dynamic>> _f = _load();

  Future<Map<String, dynamic>> _load() => authService.me();

  @override
  Widget build(BuildContext context) {
    final id = session.usuario?['id'];
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!));
        final u = snap.data!;
        final nombre = '${s(u['nombre'])} ${s(u['apellido'])}'.trim();
        final initials = nombre.isEmpty
            ? '?'
            : nombre.split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
        return ListView(padding: const EdgeInsets.all(14), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A2216), Color(0xFF15432B)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF214D36)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AgroColors.surfaceGreen,
                child: Text(initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AgroColors.forest)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre.isEmpty ? 'Usuario' : nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(s(u['email']), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFA3E5BC), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(s(u['role'] ?? session.rol).toUpperCase(),
                        style: const TextStyle(color: AgroColors.mint, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const AgroSectionHeader('Cuenta'),
          const SizedBox(height: 10),
          AgroListCard(
            leading: const AgroIconTile(icon: Icons.edit),
            title: const Text('Editar datos', style: TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
            trailing: const Icon(Icons.chevron_right, color: AgroColors.textMuted),
            onTap: () async {
              final d = await showForm(c, 'Editar datos', const [
                FieldDef('primernombre', 'Nombre'),
                FieldDef('primerapellido', 'Apellido'),
                FieldDef('telefono', 'Teléfono'),
                FieldDef('cedula', 'Cédula'),
              ]);
              if (d == null || !c.mounted) return;
              if (await run(c, () => authService.actualizarUsuario(id as int, d), ok: 'Perfil actualizado')) {
                session.usuario?['nombre'] = d['primernombre'] ?? session.usuario?['nombre'];
                setState(() => _f = _load());
              }
            },
          ),
          const SizedBox(height: 8),
          AgroListCard(
            leading: const AgroIconTile(icon: Icons.lock),
            title: const Text('Cambiar contraseña', style: TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
            trailing: const Icon(Icons.chevron_right, color: AgroColors.textMuted),
            onTap: () async {
              final d = await showForm(c, 'Cambiar contraseña', const [
                FieldDef('contrasenaActual', 'Contraseña actual', type: FT.password, required: true),
                FieldDef('contrasenaNueva', 'Contraseña nueva (mín. 6)', type: FT.password, required: true),
              ]);
              if (d == null || !c.mounted) return;
              await run(c, () => authService.cambiarContrasena(id as int, d), ok: 'Contraseña actualizada');
            },
          ),
        ]);
      },
    );
  }
}

// ── Equipo ──────────────────────────────────────────────────────────────────
class EquipoPage extends StatelessWidget {
  const EquipoPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => fincaService.miembros().then((l) => l.map((e) => e.toMap()).toList()),
      addLabel: 'Nuevo empleado',
      onAdd: (reload) async {
        final d = await showForm(context, 'Registrar empleado', const [
          FieldDef('primernombre', 'Primer nombre', required: true),
          FieldDef('primerapellido', 'Primer apellido', required: true),
          FieldDef('email', 'Correo', type: FT.email, required: true),
          FieldDef('contrasena', 'Contraseña (mín. 6)', type: FT.password, required: true),
          FieldDef('cedula', 'Cédula', required: true),
          FieldDef('telefono', 'Teléfono'),
          FieldDef('montoporhora', 'Pago por hora', type: FT.number),
          FieldDef('montoporjornal', 'Pago por jornal', type: FT.number),
        ]);
        if (d == null || !context.mounted) return;
        if (await run(context, () => fincaService.registrarEmpleado(d), ok: 'Empleado registrado')) reload();
      },
      itemBuilder: (c, m, reload) {
        final activo = m['activo'] != false;
        final propio = m['idusuario'] == session.usuario?['id'];
        return AgroListCard(
          leading: CircleAvatar(
            backgroundColor: AgroColors.surfaceGreen,
            child: Text(s(m['primernombre']).isEmpty ? '?' : s(m['primernombre'])[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900, color: AgroColors.forest)),
          ),
          title: Text('${s(m['primernombre'])} ${s(m['primerapellido'])}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
          subtitle: Text('${s(m['email'])}\n${s(m['rol'])}${s(m['telefono']).isEmpty ? '' : ' · ${s(m['telefono'])}'}',
              style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600, height: 1.35)),
          trailing: propio
              ? null
              : Switch(
                  value: activo,
                  onChanged: (v) async {
                    if (await run(c, () => fincaService.setMiembroActivo(m['idusuario'] as int, v))) reload();
                  },
                ),
        );
      },
    );
  }
}

// ── Nómina ──────────────────────────────────────────────────────────────────
class NominaPage extends StatelessWidget {
  const NominaPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => nominaService.nominas(),
      empty: 'Aún no hay nóminas',
      addLabel: 'Nueva nómina',
      onAdd: (reload) async {
        final d = await showForm(context, 'Nueva nómina', const [
          FieldDef('fechainicio', 'Desde', type: FT.date, required: true),
          FieldDef('fechafin', 'Hasta', type: FT.date, required: true),
        ], okLabel: 'Calcular');
        if (d == null || !context.mounted) return;
        if (await run(context, () => nominaService.crear(d), ok: 'Nómina creada')) reload();
      },
      itemBuilder: (c, nm, reload) => AgroListCard(
        leading: const AgroIconTile(icon: Icons.payments),
        title: Text('${d10(nm['fechainicio'])} → ${d10(nm['fechafin'])}',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
        subtitle: Text('${s(nm['estado'])} · ${s(nm['empleados'])} empleados',
            style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
        badges: StatusBadge(s(nm['estado'])),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(money(nm['total']), style: const TextStyle(fontWeight: FontWeight.w900, color: AgroColors.primary)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final id = nm['idnomina'];
              if (v == 'eliminar') {
                if (!await confirmar(c, '¿Eliminar esta nómina?') || !c.mounted) return;
                if (await run(c, () => nominaService.eliminar(id), ok: 'Eliminada')) reload();
              } else {
                final ok = await run(c, () => v == 'pagar' ? nominaService.pagar(id) : nominaService.confirmar(id),
                    ok: v == 'pagar' ? 'Nómina pagada' : 'Nómina confirmada');
                if (ok) reload();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'confirmar', child: Text('Confirmar')),
              PopupMenuItem(value: 'pagar', child: Text('Marcar como pagada')),
              PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Plan y suscripción ──────────────────────────────────────────────────────
class PlanPage extends StatefulWidget {
  const PlanPage({super.key});
  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late Future<List<dynamic>> _f = _load();

  Future<List<dynamic>> _load() async {
    final planes = await planService.planes();
    final sus = await planService.suscripcion();
    return [sus, planes];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(Api.errorMsg(snap.error!)));
        final sus = snap.data![0] as Map<String, dynamic>?;
        final planes = snap.data![1] as List;
        return ListView(padding: const EdgeInsets.all(12), children: [
          if (sus != null) KvCard(title: 'Tu suscripción', data: sus),
          for (final p in planes)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s(p['nombre'])}  ·  ${money(p['preciomensual'])}/mes', style: Theme.of(c).textTheme.titleMedium),
                  Text(s(p['descripcion'])),
                  const SizedBox(height: 6),
                  Text('Cultivos: ${s(p['maxcultivos'])} · Empleados: ${s(p['maxempleados'])} · Fincas: ${s(p['maxfincas'])} · Comisión: ${s(p['comisionmarketplace'])}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Contratar Premium'),
            onPressed: () async {
              if (!await confirmar(c, '¿Contratar el plan Premium para esta finca?') || !c.mounted) return;
              if (await run(c, () => planService.contratar(), ok: 'Suscripción activada')) setState(() => _f = _load());
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              if (!await confirmar(c, '¿Cancelar la suscripción?') || !c.mounted) return;
              if (await run(c, () => planService.cancelar(), ok: 'Suscripción cancelada')) setState(() => _f = _load());
            },
            child: const Text('Cancelar suscripción'),
          ),
        ]);
      },
    );
  }
}

// ── Asistente IA (Premium) ──────────────────────────────────────────────────
class AsistentePage extends StatefulWidget {
  const AsistentePage({super.key});
  @override
  State<AsistentePage> createState() => _AsistentePageState();
}

class _AsistentePageState extends State<AsistentePage> {
  final _msgs = <Map<String, String>>[];
  final _in = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    final t = _in.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() {
      _msgs.add({'role': 'user', 'content': t});
      _in.clear();
      _busy = true;
    });
    try {
      final txt = await chatService.enviar(_msgs);
      setState(() => _msgs.add({'role': 'assistant', 'content': txt}));
    } catch (e) {
      setState(() => _msgs.add({'role': 'assistant', 'content': '⚠️ ${Api.errorMsg(e)}'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Expanded(
        child: _msgs.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Pregúntame sobre cultivos, plagas, riego, costos… (función Premium)', textAlign: TextAlign.center)))
            : ListView(padding: const EdgeInsets.all(12), children: [
                for (final m in _msgs)
                  Align(
                    alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
                      decoration: BoxDecoration(
                        color: m['role'] == 'user' ? cs.primaryContainer : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m['content']!),
                    ),
                  ),
                if (_busy) const Padding(padding: EdgeInsets.all(8), child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
              ]),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(child: TextField(controller: _in, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Escribe tu pregunta…', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _busy ? null : _send, icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }
}

// ── Auditoría ───────────────────────────────────────────────────────────────
class AuditoriaPage extends StatelessWidget {
  const AuditoriaPage({super.key});
  @override
  Widget build(BuildContext context) {
    return AsyncList(
      loader: () => avisoService.auditoria().then((l) => l.map((e) => e.toMap()).toList()),
      empty: 'Sin eventos',
      itemBuilder: (c, a, _) {
        final denegado = s(a['operacion']) == 'DENEGADO';
        return AgroListCard(
          leading: AgroIconTile(
            icon: denegado ? Icons.block : Icons.edit_note,
            color: denegado ? const Color(0xFFB91C1C) : AgroColors.primary,
            bg: denegado ? const Color(0xFFFEE2E2) : AgroColors.surfaceGreen,
          ),
          title: Text('${s(a['operacion'])} · ${s(a['tablaNombre'] ?? a['tabla_nombre'])}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
          subtitle: Text(s(a['descripcion']), style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}

// ── Notificaciones ──────────────────────────────────────────────────────────
class NotificacionesList extends StatelessWidget {
  const NotificacionesList({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => avisoService.notificaciones().then((l) => l.map((e) => e.toMap()).toList()),
      empty: 'No tienes avisos',
      itemBuilder: (c, nt, reload) {
        final leida = nt['leida'] == true;
        return AgroListCard(
          tint: leida ? null : const Color(0xFFFFFBEB),
          leading: AgroIconTile(
            icon: leida ? Icons.notifications_none : Icons.notifications_active,
            color: leida ? AgroColors.textMuted : const Color(0xFFB45309),
            bg: leida ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7),
          ),
          title: Text(s(nt['titulo']), style: TextStyle(fontWeight: leida ? FontWeight.w700 : FontWeight.w900, color: AgroColors.textDark)),
          subtitle: Text(s(nt['mensaje']), style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
          onTap: leida
              ? null
              : () async {
                  if (await run(c, () => avisoService.marcarLeida(nt['idnotificacion']))) reload();
                },
        );
      },
    );
  }
}

// ── Reportes (Premium): costos por cultivo + exportar a Excel (CSV) ─────────
class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  String? _desde, _hasta;
  late Future<List<dynamic>> _f = _cargar();

  Future<List<dynamic>> _cargar() => reporteService.costos(desde: _desde, hasta: _hasta);

  String _fmt(DateTime p) => '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';

  Future<void> _fecha(bool desde) async {
    final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (p == null) return;
    setState(() {
      if (desde) { _desde = _fmt(p); } else { _hasta = _fmt(p); }
      _f = _cargar();
    });
  }

  String _errBytes(Object e) {
    if (e is DioException && e.response?.data is List<int>) {
      try {
        final m = jsonDecode(utf8.decode(e.response!.data as List<int>));
        if (m is Map && m['message'] != null) return m['message'].toString();
      } catch (_) {}
    }
    return Api.errorMsg(e);
  }

  Future<void> _exportar(String tipo) async {
    try {
      final arch = await reporteService.exportar(tipo, desde: _desde, hasta: _hasta);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${arch.nombre}');
      await f.writeAsBytes(arch.bytes);
      await Share.shareXFiles([XFile(f.path)], text: 'Reporte AgroSmart ($tipo)');
    } catch (e) {
      if (mounted) snack(context, _errBytes(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => _fecha(true), icon: const Icon(Icons.event), label: Text(_desde ?? 'Desde'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => _fecha(false), icon: const Icon(Icons.event), label: Text(_hasta ?? 'Hasta'))),
        if (_desde != null || _hasta != null)
          IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _desde = null; _hasta = null; _f = _cargar(); })),
      ]),
      const SizedBox(height: 12),
      Text('Exportar a Excel (CSV)', style: Theme.of(context).textTheme.titleSmall),
      Wrap(spacing: 8, children: [
        ActionChip(avatar: const Icon(Icons.download, size: 18), label: const Text('Gastos'), onPressed: () => _exportar('gastos')),
        ActionChip(avatar: const Icon(Icons.download, size: 18), label: const Text('Insumos'), onPressed: () => _exportar('insumos')),
        ActionChip(avatar: const Icon(Icons.download, size: 18), label: const Text('Cultivos'), onPressed: () => _exportar('cultivo')),
      ]),
      const Divider(height: 28),
      Text('Costos por cultivo (Premium)', style: Theme.of(context).textTheme.titleMedium),
      FutureBuilder<List<dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          if (snap.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text(Api.errorMsg(snap.error!)));
          final rows = snap.data!;
          if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Sin datos en el periodo'));
          final maxT = rows.map((r) => n(r['total'])).fold<double>(1, (a, b) => b > a ? b : a);
          final total = rows.fold<double>(0, (a, r) => a + n(r['total']));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Total del periodo: ${money(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            for (final r in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(s(r['cultivo']).isEmpty ? 'Cultivo #${r['idcultivo']}' : s(r['cultivo']), style: const TextStyle(fontWeight: FontWeight.bold))),
                      Text(money(r['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: n(r['total']) / maxT, minHeight: 6),
                    const SizedBox(height: 6),
                    Text('Insumos ${money(r['costo_insumos'])} · Mano de obra ${money(r['costo_mano_obra'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    ]);
  }
}
