import 'package:flutter/material.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/shell.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/operacion/tarea_detalle_view.dart';
import 'package:agrosmart_proto/views/operacion/tareas_view.dart';

/// Inicio del EMPLEADO: directamente "Mis tareas de hoy", sin tarjetas de KPI.
///
/// - Filtros por fecha (Hoy / Esta semana / Todas) y por estado.
/// - Cada tarea trae acciones directas: actualizar estado y registrar horas.
/// - BotÃ³n flotante para registrar horas de cualquier tarea (p. ej. la de ayer).
/// - Funciona sin internet: los cambios se muestran al instante y se envÃ­an solos
///   al volver la red (la franja "N cambios pendientes" vive en el shell).
class EmpleadoInicioPage extends StatefulWidget {
  const EmpleadoInicioPage({super.key});
  @override
  State<EmpleadoInicioPage> createState() => _EmpleadoInicioPageState();
}

enum _Rango { hoy, semana, todas }

class _Datos {
  final List<Tarea> tareas;
  final int stockBajo;
  const _Datos(this.tareas, this.stockBajo);
}

class _EmpleadoInicioPageState extends State<EmpleadoInicioPage> {
  late Future<_Datos> _f = _load();
  _Rango _rango = _Rango.hoy;
  String? _estado; // 'Pendientes' | 'En progreso' | 'Completadas' | null = todas

  // Cambios hechos sin internet: se ven al instante aunque la lista venga del cachÃ©.
  final Map<int, String> _estadoLocal = {};
  final Map<int, double> _horasLocal = {};

  Future<_Datos> _load() async {
    final r = await Future.wait<dynamic>([
      operacionService.tareas(), // el backend solo devuelve las del empleado
      produccionService
          .insumosStockBajo()
          .then<List<dynamic>>((l) => l)
          .catchError((_) => <dynamic>[]),
    ]);
    // Con internet el servidor manda la verdad: se descartan los cambios locales.
    if (!Api.i.offline.value) {
      _estadoLocal.clear();
      _horasLocal.clear();
    }
    return _Datos((r[0] as List).cast<Tarea>(), (r[1] as List).length);
  }

  Future<void> _recargar() async {
    setState(() => _f = _load());
    try {
      await _f;
    } catch (_) {}
  }

  // â”€â”€ Lectura de una tarea (con los cambios locales aplicados) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _est(Tarea t) => _estadoLocal[t.idtarea] ?? t.estado;
  bool _hecha(Tarea t) => _est(t).toLowerCase().startsWith('completad');
  bool _enProgreso(Tarea t) => _est(t).toLowerCase().startsWith('en progreso');
  double _horas(Tarea t) =>
      _horasLocal[t.idtarea] ?? n(t.asignacion?['horastrabajadas']);

  DateTime _hoy() {
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  DateTime? _fecha(Tarea t) {
    final d = DateTime.tryParse(t.fechaprogramada);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  bool _enRango(Tarea t) {
    if (_rango == _Rango.todas) return true;
    final f = _fecha(t);
    if (f == null) return true;
    final h = _hoy();
    if (f.isBefore(h)) return !_hecha(t); // las atrasadas siguen visibles
    final limite =
        _rango == _Rango.hoy ? h : DateTime(h.year, h.month, h.day + 6);
    return !f.isAfter(limite);
  }

  bool _estadoOk(Tarea t) => switch (_estado) {
        'Pendientes' => !_hecha(t) && !_enProgreso(t),
        'En progreso' => _enProgreso(t),
        'Completadas' => _hecha(t),
        _ => true,
      };

  List<Tarea> _visibles(List<Tarea> todas) {
    final l = todas.where((t) => _enRango(t) && _estadoOk(t)).toList();
    l.sort((a, b) {
      final ha = _hecha(a) ? 1 : 0, hb = _hecha(b) ? 1 : 0;
      if (ha != hb) return ha.compareTo(hb); // las completadas al final
      final fa = _fecha(a), fb = _fecha(b);
      if (fa == null || fb == null) {
        return fa == null ? (fb == null ? 0 : 1) : -1;
      }
      return fa.compareTo(fb);
    });
    return l;
  }

  // â”€â”€ Acciones â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      snack(context, 'Esta tarea ya estÃ¡ completada y no se puede reabrir.');
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
                  'Ya empecÃ© la labor en el lote'),
            _opcion(ctx, 'completar', Icons.check_circle_outline, 'Completada',
                'Labor terminada; se avisa al administrador'),
            _opcion(ctx, 'foto', Icons.photo_camera_outlined,
                'Completada con foto',
                'Adjunta evidencia y se envÃ­a el PDF al administrador'),
          ],
        ),
      ),
    );
    if (op == null || !mounted) return;
    bool ok;
    switch (op) {
      case 'iniciar':
        if (!mounted) return;
        ok = await AccionesTarea.iniciar(context, t);
        break;
      case 'completar':
        if (!mounted) return;
        ok = await AccionesTarea.completar(context, t);
        break;
      default:
        if (!mounted) return;
        ok = await AccionesTarea.completarConFoto(context, t);
        break;
    }
    if (!ok || !mounted) return;
    setState(() =>
        _estadoLocal[t.idtarea] = op == 'iniciar' ? 'En progreso' : 'Completado');
    contadores.refrescar();
    _recargar();
  }

  Future<void> _registrarHoras(List<Tarea> todas, {Tarea? tarea}) async {
    final candidatas = todas.where((t) => t.asignacion != null).toList();
    if (candidatas.isEmpty) {
      snack(context, 'No tienes tareas asignadas para registrar horas.');
      return;
    }
    final r = await showModalBottomSheet<(Tarea, double)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _HorasSheet(tareas: candidatas, inicial: tarea, horasDe: _horas),
    );
    if (r == null || !mounted) return;
    final (t, hrs) = r;
    final total = _horas(t) + hrs; // el backend guarda el total acumulado
    final id = (t.asignacion!['idasigtarea'] as num).toInt();
    final ok = await run(
      context,
      () => operacionService.actualizarAsignacion(id, {'horastrabajadas': total}),
      ok: '+${cant(hrs)} h registradas',
    );
    if (!ok || !mounted) return;
    setState(() => _horasLocal[t.idtarea] = total);
    _recargar();
  }

  // â”€â”€ UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FutureBuilder<_Datos>(
        future: _f,
        builder: (c, snap) => !snap.hasData
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _registrarHoras(snap.data!.tareas),
                backgroundColor: AgroColors.forest,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.timer_outlined, color: AgroColors.mint),
                label: const Text('Registrar horas',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
      ),
      body: FutureBuilder<_Datos>(
        future: _f,
        builder: (c, snap) {
          if (!snap.hasData && snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError && !snap.hasData) {
            return AgroError(
                message: Api.errorMsg(snap.error!), onRetry: _recargar);
          }
          final datos = snap.data!;
          final visibles = _visibles(datos.tareas);
          final listas = visibles.where(_hecha).length;
          final nombre = session.nombre.trim().split(' ').first;
          final titulo = switch (_rango) {
            _Rango.hoy => 'Mis tareas de hoy',
            _Rango.semana => 'Mis tareas de la semana',
            _Rango.todas => 'Todas mis tareas',
          };
          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AgroColors.textDark,
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(
                              nombre.isEmpty
                                  ? 'Operaciones de campo'
                                  : 'Hola, $nombre Â· operaciones de campo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AgroText.muted),
                        ]),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: AgroColors.surfaceGreen,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AgroColors.tabBorder)),
                    child: Text('$listas/${visibles.length} listas',
                        style: const TextStyle(
                            color: AgroColors.forest,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 14),
                _Segmentos(
                  etiquetas: const ['Hoy', 'Esta semana', 'Todas'],
                  actual: _rango.index,
                  onChanged: (i) => setState(() => _rango = _Rango.values[i]),
                ),
                const SizedBox(height: 10),
                FilterChips(
                  options: const ['Pendientes', 'En progreso', 'Completadas'],
                  selected: _estado,
                  onSelected: (v) => setState(() => _estado = v),
                ),
                if (datos.stockBajo > 0) ...[
                  const SizedBox(height: 12),
                  AgroAlert(
                    message:
                        'Hay ${datos.stockBajo == 1 ? 'un insumo' : '${cant(datos.stockBajo)} insumos'} con stock bajo',
                    action: 'Ver',
                    onAction: () => HomeShell.irA(c, ShellTab.tareas, sub: 1),
                  ),
                ],
                const SizedBox(height: 14),
                if (visibles.isEmpty)
                  _vacio(datos.tareas.isEmpty)
                else
                  for (final t in visibles) _tarjeta(c, t, datos.tareas),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _vacio(bool sinNingunaTarea) {
    return AgroCard(
      color: AgroColors.surfaceGreen,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(children: [
        const AgroIconTile(
            icon: Icons.eco_outlined, bg: Colors.white, size: 56),
        const SizedBox(height: 12),
        Text(
            sinNingunaTarea
                ? 'AÃºn no tienes tareas asignadas'
                : 'Â¡Todo al dÃ­a en el campo! ðŸŒ±',
            textAlign: TextAlign.center,
            style: AgroText.title.copyWith(fontSize: 15)),
        const SizedBox(height: 6),
        Text(
            sinNingunaTarea
                ? 'Cuando tu administrador te asigne una labor, te llegarÃ¡ un aviso.'
                : 'No tienes tareas para este filtro. Tus labores programadas estÃ¡n cubiertas.',
            textAlign: TextAlign.center,
            style: AgroText.muted),
        if (!sinNingunaTarea && (_rango != _Rango.todas || _estado != null)) ...[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => setState(() {
              _rango = _rango == _Rango.hoy ? _Rango.semana : _Rango.todas;
              _estado = null;
            }),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(_rango == _Rango.hoy
                ? 'Ver tareas de la semana'
                : 'Ver todas mis tareas'),
          ),
        ],
      ]),
    );
  }

  Widget _tarjeta(BuildContext c, Tarea t, List<Tarea> todas) {
    final hecha = _hecha(t);
    final f = _fecha(t);
    final atrasada = !hecha && f != null && f.isBefore(_hoy());
    const compacto = TextStyle(
        fontFamily: kAgroFont, fontSize: 12.5, fontWeight: FontWeight.w700);
    const relleno = EdgeInsets.symmetric(horizontal: 8, vertical: 10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AgroCard(
        color: hecha ? AgroColors.neutralBg : Colors.white,
        padding: const EdgeInsets.all(14),
        onTap: () async {
          await Navigator.of(c).push(MaterialPageRoute(
              builder: (_) => TareaDetallePage(idtarea: t.idtarea)));
          if (mounted) _recargar();
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (t.cultivoNombre.isNotEmpty)
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: AgroColors.surfaceGreen,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AgroColors.mintBorder)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.grass, size: 14, color: AgroColors.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(t.cultivoNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AgroColors.forest,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
            const Spacer(),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _cambiarEstado(t),
              child: StatusBadge(_est(t)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(t.actividad.isEmpty ? 'Tarea #${t.idtarea}' : t.actividad,
              style: AgroText.title.copyWith(
                fontSize: 16,
                color: hecha ? AgroColors.textMuted : AgroColors.textDark,
                decoration: hecha ? TextDecoration.lineThrough : null,
              )),
          if (f != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.event_outlined,
                  size: 14,
                  color: atrasada ? AgroColors.danger : AgroColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    juntar([
                      fecha(t.fechaprogramada),
                      if (atrasada) 'Atrasada',
                    ]),
                    style: atrasada
                        ? AgroText.muted.copyWith(
                            color: AgroColors.danger,
                            fontWeight: FontWeight.w800)
                        : AgroText.muted),
              ),
            ]),
          ],
          const Divider(height: 22, color: AgroColors.slateBorder),
          Row(children: [
            const Icon(Icons.timer_outlined,
                size: 16, color: AgroColors.primary),
            const SizedBox(width: 6),
            Expanded(
                child: Text('${cant(_horas(t))} h registradas',
                    style: AgroText.muted)),
            if (hecha)
              TextButton.icon(
                onPressed: () => _registrarHoras(todas, tarea: t),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar horas'),
              ),
          ]),
          if (!hecha) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _cambiarEstado(t),
                  style: OutlinedButton.styleFrom(
                      padding: relleno, textStyle: compacto),
                  child: const Text('Actualizar estado',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _registrarHoras(todas, tarea: t),
                  style: FilledButton.styleFrom(
                      padding: relleno, textStyle: compacto),
                  icon: const Icon(Icons.timer_outlined, size: 16),
                  label: const Text('Registrar horas',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Selector de rango (Hoy Â· Esta semana Â· Todas) con el estilo del sistema.
class _Segmentos extends StatelessWidget {
  final List<String> etiquetas;
  final int actual;
  final ValueChanged<int> onChanged;
  const _Segmentos(
      {required this.etiquetas, required this.actual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AgroColors.neutralBg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < etiquetas.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == actual,
              label: etiquetas[i],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == actual ? AgroColors.forest : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(etiquetas[i],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: i == actual
                              ? Colors.white
                              : AgroColors.textMuted)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Hoja para registrar horas: atajos (+1, +2, +4, +8) o valor libre.
/// Devuelve (tarea, horas a sumar).
class _HorasSheet extends StatefulWidget {
  final List<Tarea> tareas;
  final Tarea? inicial; // si viene, no se muestra el selector de tarea
  final double Function(Tarea) horasDe;
  const _HorasSheet(
      {required this.tareas, required this.inicial, required this.horasDe});
  @override
  State<_HorasSheet> createState() => _HorasSheetState();
}

class _HorasSheetState extends State<_HorasSheet> {
  late Tarea _t = widget.inicial ?? widget.tareas.first;
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
    Navigator.pop(context, (_t, h));
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _t.actividad.isEmpty ? 'Tarea #${_t.idtarea}' : _t.actividad;
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
            Text('Registrar horas trabajadas',
                style: AgroText.title.copyWith(fontSize: 17)),
            const SizedBox(height: 12),
            if (widget.inicial == null)
              DropdownButtonFormField<int>(
                initialValue: _t.idtarea,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tarea'),
                items: [
                  for (final t in widget.tareas)
                    DropdownMenuItem<int>(
                      value: t.idtarea,
                      child: Text(
                          juntar([
                            t.actividad.isEmpty
                                ? 'Tarea #${t.idtarea}'
                                : t.actividad,
                            t.cultivoNombre
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _t = widget.tareas
                    .firstWhere((x) => x.idtarea == v, orElse: () => _t)),
              )
            else
              Text(juntar([titulo, _t.cultivoNombre]), style: AgroText.muted),
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
                'Se suman a las ${cant(widget.horasDe(_t))} h ya registradas en esta tarea.',
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
