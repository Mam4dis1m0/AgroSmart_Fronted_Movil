import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'main.dart';
import 'operacion.dart';
import 'produccion.dart';
import 'ui.dart';

// ── Inicio / Dashboard ──────────────────────────────────────────────────────
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  Future<Map<String, dynamic>> _load() async {
    final out = <String, dynamic>{};
    try {
      final f = await Api.i.dio.get('/api/v1/fincas/activa');
      out['finca'] = (f.data as Map).cast<String, dynamic>();
    } catch (_) {}
    if (esAdmin) {
      final rows = await Api.i.getList('/api/v1/fincas/dashboard');
      for (final r in rows) {
        if (r['idfinca'] == session.idfinca) out['kpi'] = (r as Map).cast<String, dynamic>();
      }
    } else {
      final t = await Api.i.getList('/api/v1/tareas');
      final low = await Api.i.getList('/api/v1/insumos/stock-bajo');
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
        if (snap.hasError) return Center(child: Text(Api.errorMsg(snap.error!)));
        final d = snap.data!;
        final f = (d['finca'] as Map?)?.cast<String, dynamic>() ?? {};
        final k = (d['kpi'] as Map?)?.cast<String, dynamic>() ?? {};
        Widget kpi(String label, dynamic v, IconData i, Color col) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(i, color: col),
                  const SizedBox(height: 6),
                  Text(s(v), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            );
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Hola, ${session.nombre} 👋', style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${s(f['nombre'])}${s(f['ubicacion']).isEmpty ? '' : ' · ${s(f['ubicacion'])}'}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              kpi('Tareas pendientes', k['tareas_pendientes'] ?? 0, Icons.pending_actions, Colors.blueGrey),
              kpi('En progreso', k['tareas_en_progreso'] ?? 0, Icons.autorenew, Colors.orange),
              kpi('Completadas', k['tareas_completadas'] ?? 0, Icons.check_circle, Colors.green),
              kpi('Insumos con stock bajo', k['insumos_stock_bajo'] ?? 0, Icons.warning_amber, Colors.red),
              if (k['cultivos'] != null) kpi('Cultivos', k['cultivos'], Icons.grass, Colors.green),
              if (k['miembros'] != null) kpi('Miembros', k['miembros'], Icons.group, Colors.indigo),
              if (k['ventas_marketplace'] != null) kpi('Ventas marketplace', money(k['ventas_marketplace']), Icons.storefront, Colors.teal),
            ],
          ),
        ]);
      },
    );
  }
}

// ── Más: menú ───────────────────────────────────────────────────────────────
class MasPage extends StatelessWidget {
  const MasPage({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, Widget page) => ListTile(
          leading: Icon(i),
          title: Text(t),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => pushPage(context, t, page),
        );
    return ListView(children: [
      item(Icons.person, 'Mi perfil', const PerfilPage()),
      if (esAdmin) item(Icons.group, 'Equipo', const EquipoPage()),
      if (esAdmin) item(Icons.payments, 'Nómina', const NominaPage()),
      if (esAdmin) item(Icons.bar_chart, 'Reportes', const ReportesPage()),
      if (esAdmin) item(Icons.workspace_premium, 'Plan y suscripción', const PlanPage()),
      item(Icons.smart_toy, 'Asistente IA', const AsistentePage()),
      item(Icons.notifications, 'Avisos', const NotificacionesList()),
      if (esAdmin) item(Icons.history, 'Auditoría', const AuditoriaPage()),
      const Divider(),
      if (session.fincas.length > 1)
        ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('Cambiar de finca'), onTap: session.cambiarFinca),
      ListTile(leading: const Icon(Icons.logout), title: const Text('Cerrar sesión'), onTap: session.logout),
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

  Future<Map<String, dynamic>> _load() async {
    final r = await Api.i.dio.get('/usuarios/me');
    final d = (r.data as Map).cast<String, dynamic>();
    return (d['usuario'] as Map?)?.cast<String, dynamic>() ?? d;
  }

  @override
  Widget build(BuildContext context) {
    final id = session.usuario?['id'];
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(Api.errorMsg(snap.error!)));
        final u = snap.data!;
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Center(child: CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40))),
          const SizedBox(height: 12),
          Center(child: Text('${s(u['nombre'])} ${s(u['apellido'])}', style: Theme.of(c).textTheme.titleLarge)),
          Center(child: Text(s(u['email']), style: const TextStyle(color: Colors.grey))),
          Center(child: Chip(label: Text(s(u['role'] ?? session.rol)))),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.edit),
            label: const Text('Editar datos'),
            onPressed: () async {
              final d = await showForm(c, 'Editar datos', const [
                FieldDef('primernombre', 'Nombre'),
                FieldDef('primerapellido', 'Apellido'),
                FieldDef('telefono', 'Teléfono'),
                FieldDef('cedula', 'Cédula'),
              ]);
              if (d == null || !c.mounted) return;
              if (await run(c, () => Api.i.dio.put('/usuarios/$id', data: d), ok: 'Perfil actualizado')) {
                session.usuario?['nombre'] = d['primernombre'] ?? session.usuario?['nombre'];
                setState(() => _f = _load());
              }
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.lock),
            label: const Text('Cambiar contraseña'),
            onPressed: () async {
              final d = await showForm(c, 'Cambiar contraseña', const [
                FieldDef('contrasenaActual', 'Contraseña actual', type: FT.password, required: true),
                FieldDef('contrasenaNueva', 'Contraseña nueva (mín. 6)', type: FT.password, required: true),
              ]);
              if (d == null || !c.mounted) return;
              await run(c, () => Api.i.dio.put('/usuarios/$id/password', data: d), ok: 'Contraseña actualizada');
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
      loader: () => Api.i.getList('/api/v1/fincas/activa/miembros'),
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
        if (await run(context, () => Api.i.dio.post('/usuarios/empleados', data: d), ok: 'Empleado registrado')) reload();
      },
      itemBuilder: (c, m, reload) {
        final activo = m['activo'] != false;
        final propio = m['idusuario'] == session.usuario?['id'];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(s(m['primernombre']).isEmpty ? '?' : s(m['primernombre'])[0].toUpperCase())),
            title: Text('${s(m['primernombre'])} ${s(m['primerapellido'])}'),
            subtitle: Text('${s(m['email'])}\n${s(m['rol'])}${s(m['telefono']).isEmpty ? '' : ' · ${s(m['telefono'])}'}'),
            isThreeLine: true,
            trailing: propio
                ? null
                : Switch(
                    value: activo,
                    onChanged: (v) async {
                      if (await run(c, () => Api.i.dio.patch('/api/v1/fincas/activa/miembros/${m['idusuario']}', data: {'activo': v}))) reload();
                    },
                  ),
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
      loader: () => Api.i.getList('/api/v1/nomina'),
      empty: 'Aún no hay nóminas',
      addLabel: 'Nueva nómina',
      onAdd: (reload) async {
        final d = await showForm(context, 'Nueva nómina', const [
          FieldDef('fechainicio', 'Desde', type: FT.date, required: true),
          FieldDef('fechafin', 'Hasta', type: FT.date, required: true),
        ], okLabel: 'Calcular');
        if (d == null || !context.mounted) return;
        if (await run(context, () => Api.i.dio.post('/api/v1/nomina', data: d), ok: 'Nómina creada')) reload();
      },
      itemBuilder: (c, nm, reload) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.payments)),
          title: Text('${d10(nm['fechainicio'])} → ${d10(nm['fechafin'])}'),
          subtitle: Text('${s(nm['estado'])} · ${s(nm['empleados'])} empleados'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(money(nm['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                final id = nm['idnomina'];
                if (v == 'eliminar') {
                  if (!await confirmar(c, '¿Eliminar esta nómina?') || !c.mounted) return;
                  if (await run(c, () => Api.i.dio.delete('/api/v1/nomina/$id'), ok: 'Eliminada')) reload();
                } else {
                  if (await run(c, () => Api.i.dio.patch('/api/v1/nomina/$id/$v'), ok: v == 'pagar' ? 'Nómina pagada' : 'Nómina confirmada')) reload();
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
    final planes = await Api.i.getList('/api/v1/planes');
    Map<String, dynamic>? sus;
    try {
      final r = await Api.i.dio.get('/api/v1/suscripcion');
      if (r.data is Map) sus = (r.data as Map).cast<String, dynamic>();
    } catch (_) {}
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
              if (await run(c, () => Api.i.dio.post('/api/v1/suscripcion/contratar'), ok: 'Suscripción activada')) setState(() => _f = _load());
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              if (!await confirmar(c, '¿Cancelar la suscripción?') || !c.mounted) return;
              if (await run(c, () => Api.i.dio.post('/api/v1/suscripcion/cancelar'), ok: 'Suscripción cancelada')) setState(() => _f = _load());
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
      final r = await Api.i.dio.post('/api/v1/chat', data: {
        'system': 'Eres el asistente de AgroSmart, experto en agronomía y gestión de fincas en Colombia. Responde en español, claro y breve.',
        'messages': _msgs,
      });
      final txt = (r.data['content'] as List).first['text'];
      setState(() => _msgs.add({'role': 'assistant', 'content': s(txt)}));
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
      loader: () => Api.i.getList('/auditoria'),
      empty: 'Sin eventos',
      itemBuilder: (c, a, _) => Card(
        child: ListTile(
          leading: Icon(s(a['operacion']) == 'DENEGADO' ? Icons.block : Icons.edit_note,
              color: s(a['operacion']) == 'DENEGADO' ? Colors.red : null),
          title: Text('${s(a['operacion'])} · ${s(a['tablaNombre'] ?? a['tabla_nombre'])}'),
          subtitle: Text(s(a['descripcion'])),
        ),
      ),
    );
  }
}

// ── Notificaciones ──────────────────────────────────────────────────────────
class NotificacionesList extends StatelessWidget {
  const NotificacionesList({super.key});
  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => Api.i.getList('/notificaciones'),
      empty: 'No tienes avisos',
      itemBuilder: (c, nt, reload) {
        final leida = nt['leida'] == true;
        return Card(
          child: ListTile(
            leading: Icon(leida ? Icons.notifications_none : Icons.notifications_active, color: leida ? Colors.grey : Colors.orange),
            title: Text(s(nt['titulo']), style: TextStyle(fontWeight: leida ? FontWeight.normal : FontWeight.bold)),
            subtitle: Text(s(nt['mensaje'])),
            onTap: leida
                ? null
                : () async {
                    if (await run(c, () => Api.i.dio.put('/notificaciones/${nt['idnotificacion']}/leer'))) reload();
                  },
          ),
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

  Map<String, dynamic> get _q => {if (_desde != null) 'desde': _desde, if (_hasta != null) 'hasta': _hasta};

  Future<List<dynamic>> _cargar() async {
    final r = await Api.i.dio.get('/api/v1/reportes/costos', queryParameters: _q);
    return r.data is List ? r.data as List : [];
  }

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
      final r = await Api.i.dio.get<List<int>>(
        '/api/v1/reportes/exportar',
        queryParameters: {'tipo': tipo, ..._q},
        options: Options(responseType: ResponseType.bytes),
      );
      final cd = r.headers.value('content-disposition') ?? '';
      final name = RegExp(r'filename="([^"]+)"').firstMatch(cd)?.group(1) ?? 'reporte_$tipo.csv';
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(r.data!);
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
