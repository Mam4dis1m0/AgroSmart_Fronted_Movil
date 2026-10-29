import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'tarea_detalle_view.dart';
import 'tareas_view.dart';

const _orden = {'Alta': 0, 'Media': 1, 'Baja': 2};

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lunes de la semana de [d].
DateTime inicioSemana(DateTime d) => _dia(d).subtract(Duration(days: d.weekday - 1));

/// Agenda de trabajo. El empleado ve «Mi día» (atrasadas, hoy y la semana); el administrador ve la
/// semana completa de la finca y puede filtrar por persona, cultivo y prioridad.
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});
  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late Future<List<Tarea>> _f = operacionService.tareas();
  DateTime _semana = inicioSemana(DateTime.now());
  String? _empleado, _cultivo, _prioridad;

  void _recargar() {
    if (!mounted) return;
    setState(() {
      _f = operacionService.tareas();
    });
  }

  bool _pasa(Tarea t) =>
      (_empleado == null || t.empleadoNombre == _empleado) &&
      (_cultivo == null || t.cultivoNombre == _cultivo) &&
      (_prioridad == null || t.prioridad == _prioridad);

  int _cmp(Tarea a, Tarea b) {
    final p = (_orden[a.prioridad] ?? 1).compareTo(_orden[b.prioridad] ?? 1);
    return p != 0 ? p : a.fechaprogramada.compareTo(b.fechaprogramada);
  }

  Future<void> _filtros(List<Tarea> todas) async {
    List<MapEntry<dynamic, String>> opc(Iterable<String> v) => [
          for (final x in ({...v}..remove('')).toList()..sort()) MapEntry(x, x),
        ];
    final d = await showForm(
      context,
      'Filtrar agenda',
      [
        FieldDef('empleado', 'Persona', type: FT.select, options: opc(todas.map((t) => t.empleadoNombre))),
        FieldDef('cultivo', 'Cultivo', type: FT.select, options: opc(todas.map((t) => t.cultivoNombre))),
        const FieldDef('prioridad', 'Prioridad', type: FT.select, options: [
          MapEntry('Alta', 'Alta'), MapEntry('Media', 'Media'), MapEntry('Baja', 'Baja'),
        ]),
      ],
      initial: {'empleado': _empleado, 'cultivo': _cultivo, 'prioridad': _prioridad},
      okLabel: 'Aplicar',
      edit: true,
    );
    if (d == null) return;
    String? v(String k) => s(d[k]).isEmpty ? null : s(d[k]);
    setState(() {
      _empleado = v('empleado');
      _cultivo = v('cultivo');
      _prioridad = v('prioridad');
    });
  }

  Widget _tarjeta(Tarea t) {
    final cursor = t.enCurso;
    return AgroListCard(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TareaDetallePage(idtarea: t.idtarea)));
        _recargar();
      },
      leading: AgroIconTile(
        icon: cursor ? Icons.timer_outlined : (t.prioridad == 'Alta' ? Icons.priority_high : Icons.pending_actions),
        color: t.atrasada ? AgroColors.danger : AgroColors.warning,
        bg: t.atrasada ? AgroColors.dangerBg : AgroColors.warningBg,
      ),
      title: Text(t.actividad.isEmpty ? 'Tarea #${t.idtarea}' : t.actividad, style: AgroText.title),
      subtitle: Text(
        juntar([
          t.cultivoNombre,
          if (esAdmin) (t.empleadoNombre.isEmpty ? 'Sin asignar' : t.empleadoNombre),
          if (n(t.raw['horasestimadas']) > 0) '${cant(t.raw['horasestimadas'])} h',
        ]),
        style: AgroText.muted,
      ),
      badges: Wrap(spacing: 6, children: [
        if (t.prioridad == 'Alta') Text('Prioridad alta', style: AgroText.muted.copyWith(color: AgroColors.danger)),
        if (t.estado.isNotEmpty) StatusBadge(t.estado),
      ]),
      trailing: t.asignacion == null || t.completada
          ? null
          : IconButton(
              tooltip: cursor ? 'Finalizar' : 'Iniciar',
              icon: Icon(cursor ? Icons.stop_circle_outlined : Icons.play_circle_outline, color: AgroColors.primary, size: 30),
              onPressed: () async {
                final ok = cursor ? await AccionesTarea.completar(context, t) : await AccionesTarea.iniciar(context, t);
                if (ok) _recargar();
              },
            ),
    );
  }

  List<Widget> _seccion(String titulo, List<Tarea> l, {Color? color}) {
    if (l.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Text('$titulo · ${l.length}', style: AgroText.title.copyWith(color: color)),
      ),
      for (final t in l) Padding(padding: const EdgeInsets.only(bottom: 8), child: _tarjeta(t)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tarea>>(
      future: _f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
        final todas = snap.data!;
        final abiertas = todas.where((t) => !t.completada && _pasa(t)).toList()..sort(_cmp);
        final hoy = _dia(DateTime.now());
        DateTime? f(Tarea t) => DateTime.tryParse(t.fechaprogramada);
        final atrasadas = abiertas.where((t) => t.atrasada).toList();
        final filtrando = _empleado != null || _cultivo != null || _prioridad != null;

        final cuerpo = <Widget>[];
        if (esAdmin) {
          final fin = _semana.add(const Duration(days: 6));
          cuerpo.add(Row(children: [
            IconButton(onPressed: () => setState(() => _semana = _semana.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: Text(
                  '${DateFormat('d MMM', 'es').format(_semana)} – ${DateFormat('d MMM', 'es').format(fin)}',
                  style: AgroText.title,
                ),
              ),
            ),
            IconButton(onPressed: () => setState(() => _semana = _semana.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
          ]));
          if (_semana == inicioSemana(hoy)) cuerpo.addAll(_seccion('Atrasadas', atrasadas, color: AgroColors.danger));
          for (var i = 0; i < 7; i++) {
            final d = _semana.add(Duration(days: i));
            final delDia = abiertas.where((t) => f(t) != null && _dia(f(t)!) == d && !t.atrasada).toList();
            final etiqueta = toBeginningOfSentenceCase(DateFormat('EEEE d', 'es').format(d));
            cuerpo.addAll(_seccion(d == hoy ? 'Hoy · $etiqueta' : etiqueta, delDia));
          }
          if (cuerpo.length == 1) {
            cuerpo.add(const AgroEmpty(icon: Icons.event_available_outlined, message: 'No hay tareas abiertas esta semana'));
          }
        } else {
          final deHoy = abiertas.where((t) => f(t) != null && _dia(f(t)!) == hoy).toList();
          final semana = abiertas
              .where((t) => f(t) != null && _dia(f(t)!).isAfter(hoy) && _dia(f(t)!).isBefore(hoy.add(const Duration(days: 8))))
              .toList();
          cuerpo
            ..addAll(_seccion('Atrasadas', atrasadas, color: AgroColors.danger))
            ..addAll(_seccion('Hoy', deHoy))
            ..addAll(_seccion('Próximos 7 días', semana));
          if (cuerpo.isEmpty) {
            cuerpo.add(const AgroEmpty(icon: Icons.task_alt, message: 'Estás al día: no tienes tareas pendientes'));
          }
        }

        return RefreshIndicator(
          onRefresh: () async {
            _recargar();
            await _f;
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
            if (esAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: ActionChip(
                  avatar: Icon(Icons.filter_list, size: 18, color: filtrando ? AgroColors.primary : null),
                  label: Text(filtrando ? 'Filtros activos' : 'Filtrar'),
                  onPressed: () => _filtros(todas),
                ),
              ),
            ...cuerpo,
          ]),
        );
      },
    );
  }
}
