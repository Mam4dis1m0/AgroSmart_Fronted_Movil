import 'package:flutter/material.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/operacion/tarea_detalle_view.dart';
import 'package:agrosmart_proto/views/operacion/tareas_view.dart';

/// Inicio del EMPLEADO: su lista de trabajo.
///
/// - Un solo filtro (FilterChips por estado, con contador). La fecha ya no es un
///   segundo filtro: las tareas se agrupan solas en Atrasadas · Para hoy · Próximas.
/// - Cada tarjeta muestra el estado, las horas de SU asignación y dos acciones:
///   cambiar el estado y registrar horas.
/// - Las horas viven en la asignación (idasigtarea): ahí se leen y se guardan.
/// - Sin internet: los cambios se ven al instante y se envían solos al volver la
///   red (la franja "N cambios pendientes" vive en el shell).
class EmpleadoInicioPage extends StatefulWidget {
  const EmpleadoInicioPage({super.key});
  @override
  State<EmpleadoInicioPage> createState() => _EmpleadoInicioPageState();
}

enum _Filtro { pendientes, enProgreso, completadas }

enum _Grupo { atrasadas, hoy, proximas, completadas }

const _tituloFiltro = {
  _Filtro.pendientes: 'Pendientes',
  _Filtro.enProgreso: 'En progreso',
  _Filtro.completadas: 'Completadas',
};

const _tituloGrupo = {
  _Grupo.atrasadas: 'Atrasadas',
  _Grupo.hoy: 'Para hoy',
  _Grupo.proximas: 'Próximas',
  _Grupo.completadas: 'Completadas',
};

/// Completadas que se muestran en la vista «Todas» (el resto, con «Ver todas»).
const _maxCompletadas = 5;

class _EmpleadoInicioPageState extends State<EmpleadoInicioPage> {
  late Future<List<Tarea>> _f = _load();
  _Filtro? _filtro; // null = todas

  // Cambios hechos sin internet: se ven al instante aunque la lista venga del caché.
  final Map<int, String> _estadoLocal = {}; // idtarea -> estado
  final Map<int, double> _horasLocal = {}; // idasigtarea -> horas acumuladas

  Future<List<Tarea>> _load() async {
    // El backend solo devuelve las tareas del empleado.
    final tareas = await operacionService.tareas();
    // Con internet el servidor manda la verdad: se descartan los cambios locales.
    if (!Api.i.offline.value) {
      _estadoLocal.clear();
      _horasLocal.clear();
    }
    return tareas;
  }

  Future<void> _recargar() async {
    setState(() => _f = _load());
    try {
      await _f;
    } catch (_) {}
  }

  // ── Lectura de una tarea (con los cambios locales aplicados) ──────────────
  String _est(Tarea t) => _estadoLocal[t.idtarea] ?? t.estado;
  bool _hecha(Tarea t) => _est(t).toLowerCase().startsWith('completad');
  bool _enProgreso(Tarea t) => _est(t).toLowerCase().startsWith('en progreso');

  /// Id del usuario en sesión (el que llega en el login).
  int? get _miId {
    final u = session.usuario;
    final id = n(u?['id'] ?? u?['idusuario']).toInt();
    return id > 0 ? id : null;
  }

  /// Mi asignación de la tarea. Una tarea reasignada puede traer varias y las
  /// horas se guardan en la MÍA, no en la más reciente a secas.
  Map<String, dynamic>? _asig(Tarea t) {
    final id = _miId;
    if (id != null) {
      final mias = t.asignaciones.where((a) {
        final e = a['idempleado'];
        final u = e is Map ? e['idusuario2'] : null;
        return u is Map && n(u['idusuario']).toInt() == id;
      }).toList()
        ..sort((a, b) => n(b['idasigtarea']).compareTo(n(a['idasigtarea'])));
      if (mias.isNotEmpty) return mias.first;
    }
    return t.asignacion; // sin datos para distinguir: la más reciente
  }

  int? _idAsig(Tarea t) {
    final v = _asig(t)?['idasigtarea'];
    return v is num ? v.toInt() : null;
  }

  double _horas(Tarea t) {
    final id = _idAsig(t);
    if (id == null) return 0;
    return _horasLocal[id] ?? n(_asig(t)?['horastrabajadas']);
  }

  DateTime _hoy() {
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  DateTime? _fecha(Tarea t) {
    final d = DateTime.tryParse(t.fechaprogramada);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  // ── Filtro y grupos ───────────────────────────────────────────────────────
  bool _cumple(Tarea t, _Filtro? f) => switch (f) {
        _Filtro.pendientes => !_hecha(t) && !_enProgreso(t),
        _Filtro.enProgreso => _enProgreso(t),
        _Filtro.completadas => _hecha(t),
        null => true,
      };

  /// Texto del chip con su contador: «Pendientes (3)».
  String _chip(List<Tarea> todas, _Filtro f) =>
      '${_tituloFiltro[f]} (${todas.where((t) => _cumple(t, f)).length})';

  _Filtro? _filtroDe(String? etiqueta, List<Tarea> todas) {
    for (final f in _Filtro.values) {
      if (_chip(todas, f) == etiqueta) return f;
    }
    return null;
  }

  _Grupo _grupo(Tarea t) {
    if (_hecha(t)) return _Grupo.completadas;
    final f = _fecha(t);
    if (f == null) return _Grupo.proximas;
    final h = _hoy();
    if (f.isBefore(h)) return _Grupo.atrasadas;
    return f == h ? _Grupo.hoy : _Grupo.proximas;
  }

  int _porFecha(Tarea a, Tarea b) {
    final fa = _fecha(a), fb = _fecha(b);
    if (fa == null || fb == null) {
      return fa == null ? (fb == null ? 0 : 1) : -1;
    }
    return fa.compareTo(fb);
  }

  Map<_Grupo, List<Tarea>> _agrupar(List<Tarea> todas) {
    final g = {for (final k in _Grupo.values) k: <Tarea>[]};
    for (final t in todas) {
      if (_cumple(t, _filtro)) g[_grupo(t)]!.add(t);
    }
    for (final k in _Grupo.values) {
      if (k == _Grupo.completadas) {
        g[k]!.sort((a, b) => _porFecha(b, a)); // las más recientes primero
      } else {
        g[k]!.sort(_porFecha);
      }
    }
    return g;
  }

  // ── Acciones ──────────────────────────────────────────────────────────────
  Widget _opcion(BuildContext ctx, String valor, IconData icono, String titulo,
      String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AgroListCard(
        onTap: () => Navigator.pop(ctx, valor),
        leading: AgroIconTile(icon: icono),
        title: Text(titulo, style: AgroText.title),
        subtitle: Text(sub, style: AgroText.muted),
        trailing: const Icon(Icons.chevron_right, color: AgroColors.textMuted),
      ),
    );
  }

  Future<void> _cambiarEstado(Tarea t) async {
    if (_hecha(t)) {
      snack(context, 'Esta tarea ya está completada y no se puede reabrir.');
      return;
    }
    final op = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AgroColors.handle,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Actualizar estado',
                style: AgroText.title.copyWith(fontSize: 17)),
            const SizedBox(height: 2),
            Text(t.actividad.isEmpty ? 'Tarea #${t.idtarea}' : t.actividad,
                style: AgroText.muted),
            const SizedBox(height: 14),
            if (!_enProgreso(t))
              _opcion(ctx, 'iniciar', Icons.play_arrow_rounded, 'En progreso',
                  'Ya empecé la labor en el lote'),
            _opcion(ctx, 'completar', Icons.check_circle_outline, 'Completada',
                'Labor terminada; se avisa al administrador'),
            _opcion(ctx, 'foto', Icons.photo_camera_outlined,
                'Completada con foto',
                'Adjunta evidencia y se envía el PDF al administrador'),
          ],
        ),
      ),
    );
    if (op == null || !mounted) return;
    final ok = switch (op) {
      'iniciar' => await AccionesTarea.iniciar(context, t),
      'completar' => await AccionesTarea.completar(context, t),
      _ => await AccionesTarea.completarConFoto(context, t),
    };
    if (!ok || !mounted) return;
    setState(() =>
        _estadoLocal[t.idtarea] = op == 'iniciar' ? 'En progreso' : 'Completado');
    contadores.refrescar();
    _recargar();
  }

  Future<void> _registrarHoras(Tarea t) async {
    final idAsig = _idAsig(t);
    if (idAsig == null) {
      snack(context, 'Esta tarea todavía no tiene una asignación a tu nombre.');
      return;
    }
    final actuales = _horas(t);
    final sumar = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HorasSheet(
        titulo: t.actividad.isEmpty ? 'Tarea #${t.idtarea}' : t.actividad,
        detalle: t.cultivoNombre,
        horasActuales: actuales,
      ),
    );
    if (sumar == null || !mounted) return;
    // El backend guarda el total acumulado de la asignación: se envía ya sumado.
    final total = ((actuales + sumar) * 100).round() / 100;
    final ok = await run(
      context,
      () => operacionService
          .actualizarAsignacion(idAsig, {'horastrabajadas': total}),
      ok: '+${cant(sumar)} h registradas',
    );
    if (!ok || !mounted) return;
    setState(() => _horasLocal[idAsig] = total);
    _recargar();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tarea>>(
      future: _f,
      builder: (c, snap) {
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError && !snap.hasData) {
          return AgroError(
              message: Api.errorMsg(snap.error!), onRetry: _recargar);
        }
        final todas = snap.data!;
        final grupos = _agrupar(todas);
        final visibles = grupos.values.fold<int>(0, (a, l) => a + l.length);
        final conTitulos = grupos.values.where((l) => l.isNotEmpty).length > 1;
        final nombre = session.nombre.trim().split(' ').first;
        return RefreshIndicator(
          onRefresh: _recargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AgroColors.textDark,
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Hoy · ${fecha(_hoy())}', style: AgroText.muted),
              const SizedBox(height: 14),
              if (todas.isEmpty)
                const AgroEmpty(
                  icon: Icons.task_alt,
                  message: 'Aún no tienes tareas asignadas.\n'
                      'Cuando tu administrador te asigne una labor, te llegará un aviso.',
                )
              else ...[
                FilterChips(
                  options: [for (final f in _Filtro.values) _chip(todas, f)],
                  selected: _filtro == null ? null : _chip(todas, _filtro!),
                  allLabel: 'Todas (${todas.length})',
                  onSelected: (v) =>
                      setState(() => _filtro = _filtroDe(v, todas)),
                ),
                const SizedBox(height: 14),
                if (visibles == 0)
                  AgroEmpty(
                    icon: Icons.task_alt,
                    message: 'No tienes tareas en este filtro.',
                    action: OutlinedButton(
                      onPressed: () => setState(() => _filtro = null),
                      child: const Text('Ver todas'),
                    ),
                  )
                else
                  for (final g in _Grupo.values)
                    if (grupos[g]!.isNotEmpty)
                      ..._seccion(g, grupos[g]!, conTitulos),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _seccion(_Grupo g, List<Tarea> lista, bool conTitulos) {
    // En «Todas» las completadas se recortan para no crecer sin fin con el tiempo.
    final recortar = conTitulos &&
        g == _Grupo.completadas &&
        _filtro == null &&
        lista.length > _maxCompletadas;
    final mostrar = recortar ? lista.sublist(0, _maxCompletadas) : lista;
    return [
      if (conTitulos)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: AgroSectionHeader(
            _tituloGrupo[g]!,
            action: recortar ? 'Ver todas (${lista.length})' : null,
            onAction: recortar
                ? () => setState(() => _filtro = _Filtro.completadas)
                : null,
          ),
        ),
      for (final t in mostrar) _tarjeta(t),
      const SizedBox(height: 6),
    ];
  }

  Widget _tarjeta(Tarea t) {
    final hecha = _hecha(t);
    final enProgreso = _enProgreso(t);
    final f = _fecha(t);
    final atrasada = !hecha && f != null && f.isBefore(_hoy());
    final tieneAsig = _idAsig(t) != null;
    final horas = _horas(t);
    final haySub = f != null || t.cultivoNombre.isNotEmpty;
    const texto =
        TextStyle(fontFamily: kAgroFont, fontSize: 13, fontWeight: FontWeight.w700);
    const relleno = EdgeInsets.symmetric(horizontal: 8, vertical: 8);
    const alto = Size(0, 40);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AgroListCard(
        tint: hecha ? AgroColors.neutralBg : null,
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TareaDetallePage(idtarea: t.idtarea)));
          if (mounted) _recargar();
        },
        leading: AgroIconTile(
          icon: hecha
              ? Icons.check
              : (enProgreso ? Icons.autorenew : Icons.pending_actions),
          color: hecha
              ? AgroColors.primary
              : (atrasada ? AgroColors.danger : AgroColors.warning),
          bg: hecha
              ? AgroColors.surfaceGreen
              : (atrasada ? AgroColors.dangerBg : AgroColors.warningBg),
        ),
        title: Text(
          t.actividad.isEmpty ? 'Tarea #${t.idtarea}' : t.actividad,
          style: AgroText.title.copyWith(
            color: hecha ? AgroColors.textMuted : null,
            decoration: hecha ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: !haySub
            ? null
            : Text.rich(
                TextSpan(children: [
                  if (f != null)
                    TextSpan(
                      text: juntar([
                        fecha(t.fechaprogramada),
                        if (atrasada) 'Atrasada',
                      ]),
                      style: atrasada
                          ? const TextStyle(
                              color: AgroColors.danger,
                              fontWeight: FontWeight.w800)
                          : null,
                    ),
                  if (f != null && t.cultivoNombre.isNotEmpty)
                    const TextSpan(text: ' · '),
                  if (t.cultivoNombre.isNotEmpty)
                    TextSpan(text: t.cultivoNombre),
                ]),
                style: AgroText.muted,
              ),
        badges: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StatusBadge(_est(t)),
              if (t.evidencias > 0) ...[
                const SizedBox(width: 6),
                const Icon(Icons.photo_camera_outlined,
                    size: 16, color: AgroColors.primary),
                const SizedBox(width: 4),
                Text('${t.evidencias}', style: AgroText.muted),
              ],
              const Spacer(),
              if (tieneAsig) ...[
                const Icon(Icons.timer_outlined,
                    size: 16, color: AgroColors.primary),
                const SizedBox(width: 4),
                Text('${cant(horas)} h', style: AgroText.muted),
              ],
              if (hecha && tieneAsig)
                IconButton(
                  tooltip: 'Agregar horas',
                  onPressed: () => _registrarHoras(t),
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 20,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            if (!hecha) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cambiarEstado(t),
                    style: OutlinedButton.styleFrom(
                        padding: relleno, textStyle: texto, minimumSize: alto),
                    icon: const Icon(Icons.sync_alt, size: 16),
                    label: const Text('Estado'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: tieneAsig ? () => _registrarHoras(t) : null,
                    style: FilledButton.styleFrom(
                        padding: relleno, textStyle: texto, minimumSize: alto),
                    icon: const Icon(Icons.timer_outlined, size: 16),
                    label: const Text('Horas'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hoja para registrar horas: atajos (+1, +2, +4, +8) o valor libre.
/// Devuelve las horas a SUMAR a las ya registradas en la asignación.
class _HorasSheet extends StatefulWidget {
  final String titulo;
  final String detalle;
  final double horasActuales;
  const _HorasSheet(
      {required this.titulo,
      required this.detalle,
      required this.horasActuales});
  @override
  State<_HorasSheet> createState() => _HorasSheetState();
}

class _HorasSheetState extends State<_HorasSheet> {
  final _ctl = TextEditingController(text: '2');
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  double? get _valor => double.tryParse(_ctl.text.trim().replaceAll(',', '.'));

  void _guardar() {
    final h = _valor;
    if (h == null || h < 0.5 || h > 14) {
      setState(() => _error = 'Escribe entre 0,5 y 14 horas');
      return;
    }
    Navigator.pop(context, h);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AgroColors.handle,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Registrar horas',
                style: AgroText.title.copyWith(fontSize: 17)),
            const SizedBox(height: 2),
            Text(juntar([widget.titulo, widget.detalle]),
                style: AgroText.muted),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              for (final h in const [1, 2, 4, 8])
                ChoiceChip(
                  label: Text('+$h h'),
                  selected: _valor == h.toDouble(),
                  onSelected: (_) => setState(() {
                    _ctl.text = '$h';
                    _error = null;
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _ctl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Horas a sumar',
                suffixText: 'h',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
                'Llevas ${cant(widget.horasActuales)} h en esta tarea; lo que escribas se suma a eso.',
                style: AgroText.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Guardar horas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
