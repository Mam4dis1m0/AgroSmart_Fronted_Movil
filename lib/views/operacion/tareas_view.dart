import 'package:flutter/material.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/imagen.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'tarea_detalle_view.dart';

const _etiquetaEstado = {'Pendiente': 'Pendientes', 'Asignado': 'Asignadas', 'En progreso': 'En progreso', 'Completado': 'Completadas'};

Future<List<FieldDef>> camposTarea() async => [
      const FieldDef(
        'tipoactividad',
        'Actividad',
        type: FT.selectOther,
        required: true,
        minLength: 3,
        options: [
          MapEntry('Riego', 'Riego'),
          MapEntry('Siembra', 'Siembra'),
          MapEntry('Fertilización', 'Fertilización'),
          MapEntry('Control de plagas', 'Control de plagas'),
          MapEntry('Poda', 'Poda'),
          MapEntry('Cosecha', 'Cosecha'),
          MapEntry('Deshierbe', 'Deshierbe'),
          MapEntry('Preparación del terreno', 'Preparación del terreno'),
          MapEntry('Mantenimiento', 'Mantenimiento'),
        ],
      ),
      const FieldDef('fechaprogramada', 'Fecha programada', type: FT.date),
      FieldDef('idcultivo', 'Cultivo', type: FT.select, options: await operacionService.cultivosOpc()),
      const FieldDef('costototal', 'Costo estimado (COP)', type: FT.number, min: 0),
    ];

/// Acciones de una tarea compartidas por la lista y el detalle.
class AccionesTarea {
  static Future<bool> asignar(BuildContext c, Tarea t) async {
    final emps = await cargar(c, operacionService.empleadosOpciones);
    if (emps == null || !c.mounted) return false;
    if (emps.isEmpty) {
      snack(c, 'No hay empleados activos. Regístralos en Más › Equipo.');
      return false;
    }
    final d = await showForm(c, t.asignacion == null ? 'Asignar tarea' : 'Reasignar tarea', [
      FieldDef('idempleado', 'Empleado', type: FT.select, required: true, options: emps),
      const FieldDef('pagoacordado', 'Pago acordado (COP)', type: FT.number, min: 0),
    ], okLabel: 'Asignar', edit: false);
    if (d == null || !c.mounted) return false;
    return run(c, () => operacionService.asignarTarea(t.idtarea, d), ok: 'Tarea asignada; se notificó al empleado por correo');
  }

  static Future<bool> iniciar(BuildContext c, Tarea t) =>
      run(c, () => operacionService.actualizarTarea(t.idtarea, {'estado': 'En progreso'}), ok: 'Tarea en progreso');

  static Future<bool> completar(BuildContext c, Tarea t) async {
    if (!await confirmar(c, 'Se avisará por correo al administrador.', titulo: '¿Marcar «${t.actividad}» como completada?', ok: 'Completar')) {
      return false;
    }
    if (!c.mounted) return false;
    final asig = t.asignacion;
    return run(
      c,
      () => asig != null
          ? operacionService.completarAsignacion((asig['idasigtarea'] as num).toInt())
          : operacionService.actualizarTarea(t.idtarea, {'estado': 'Completado'}),
      ok: 'Tarea completada',
    );
  }

  static Future<bool> completarConFoto(BuildContext c, Tarea t) async {
    final img = await elegirImagen(c, maxWidth: 1400);
    if (img == null || !c.mounted) return false;
    final obs = await showForm(c, 'Evidencia de la tarea', const [
      FieldDef('observaciones', 'Observaciones (opcional)', type: FT.multiline),
    ], okLabel: 'Enviar y completar', edit: false);
    if (obs == null || !c.mounted) return false;
    return run(
      c,
      () => operacionService.completarConEvidencia(
        tarea: t,
        foto: img.bytes,
        nombreArchivo: img.nombre,
        observaciones: s(obs['observaciones']),
        nombreEmpleado: session.nombreCompleto,
      ),
      ok: 'Tarea completada; el administrador recibió el PDF de evidencia',
    );
  }

  static Future<bool> editar(BuildContext c, Tarea t) async {
    final f = await cargar(c, camposTarea);
    if (f == null || !c.mounted) return false;
    final d = await showForm(c, 'Editar tarea', [
      ...f,
      FieldDef('estado', 'Estado', type: FT.select, options: [for (final e in Tarea.estados) MapEntry(e, e)]),
    ], initial: t.toForm(), edit: true);
    if (d == null || !c.mounted) return false;
    return run(c, () => operacionService.actualizarTarea(t.idtarea, d), ok: 'Cambios guardados');
  }

  static Future<bool> eliminar(BuildContext c, Tarea t) async {
    if (!await confirmar(c, '«${t.actividad}» se eliminará de forma permanente.',
        titulo: '¿Eliminar tarea?', ok: 'Eliminar', destructivo: true)) {
      return false;
    }
    if (!c.mounted) return false;
    return run(c, () => operacionService.eliminarTarea(t.idtarea), ok: 'Tarea eliminada');
  }

  /// Acciones válidas según el rol y el estado de la tarea.
  static List<RowAction> para(Tarea t) {
    final done = t.completada;
    Future<void> Function(BuildContext, Map<String, dynamic>, VoidCallback) w(Future<bool> Function(BuildContext, Tarea) f) =>
        (ctx, _, reload) async {
          if (await f(ctx, t)) reload();
        };
    return [
      if (!done && !t.estado.toLowerCase().startsWith('en progreso') && (esAdmin || t.asignacion != null))
        RowAction('Iniciar', w(iniciar), icon: Icons.play_arrow_outlined),
      if (!done) RowAction('Completar', w(completar), icon: Icons.check_circle_outline),
      if (!done) RowAction('Completar con foto', w(completarConFoto), icon: Icons.photo_camera_outlined),
      if (esAdmin && !done) RowAction(t.asignacion == null ? 'Asignar a empleado' : 'Reasignar', w(asignar), icon: Icons.person_add_alt),
      if (esAdmin) RowAction('Editar', w(editar), icon: Icons.edit_outlined),
      if (esAdmin) RowAction('Eliminar', w(eliminar), icon: Icons.delete_outline, destructive: true),
    ];
  }
}

/// Lista de tareas: el admin ve todas; el empleado solo las que le asignaron.
class TareasPage extends StatefulWidget {
  const TareasPage({super.key});
  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  String? _estado;

  bool _coincide(Map<String, dynamic> t) {
    if (_estado == null) return true;
    final e = s(t['estado']).toLowerCase();
    return _estado == 'Completado' ? e.startsWith('completad') : e == _estado!.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => operacionService.tareas().then((l) => l.map((e) => e.toMap()).toList()),
      filter: _estado == null ? null : _coincide,
      header: FilterChips(
        options: _etiquetaEstado.values.toList(),
        selected: _estado == null ? null : _etiquetaEstado[_estado],
        onSelected: (v) => setState(() => _estado = v == null ? null : _etiquetaEstado.entries.firstWhere((e) => e.value == v).key),
      ),
      empty: _estado != null
          ? 'No hay tareas en este estado'
          : (esAdmin ? 'Aún no hay tareas.\nCrea una y asígnala a tu equipo.' : 'No tienes tareas asignadas'),
      emptyIcon: Icons.checklist_rtl,
      addLabel: 'Nueva tarea',
      onAdd: esAdmin
          ? (reload) async {
              final f = await cargar(context, camposTarea);
              if (f == null || !context.mounted) return;
              final d = await showForm(context, 'Nueva tarea', f, edit: false);
              if (d == null || !context.mounted) return;
              if (await run(context, () => operacionService.crearTarea(d), ok: 'Tarea creada')) reload();
            }
          : null,
      itemBuilder: (c, m, reload) {
        final t = Tarea(m);
        final done = t.completada;
        final enProgreso = t.estado.toLowerCase().startsWith('en progreso');
        return AgroListCard(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: done
                ? const [Color(0xFFDDF7E7), Color(0xFFF7FCF8), Colors.white]
                : enProgreso
                    ? const [AgroColors.surfaceBlue, Color(0xFFF8FCFE)]
                    : const [AgroColors.surfaceAmber, Color(0xFFFFFCF4)],
          ),
          onTap: () async {
            await Navigator.of(c).push(MaterialPageRoute(builder: (_) => TareaDetallePage(idtarea: t.idtarea)));
            reload();
          },
          leading: AgroIconTile(
            icon: done ? Icons.check : (enProgreso ? Icons.autorenew : Icons.pending_actions),
            color: done ? AgroColors.primary : AgroColors.warning,
            bg: done ? AgroColors.surfaceGreen : AgroColors.warningBg,
          ),
          title: Text(t.actividad.isEmpty ? 'Tarea #${t.idtarea}' : t.actividad, style: AgroText.title),
          subtitle: Text(
            juntar([
              if (t.fechaprogramada.isNotEmpty) fecha(t.fechaprogramada),
              t.cultivoNombre,
              if (esAdmin) t.empleadoNombre.isEmpty ? 'Sin asignar' : t.empleadoNombre,
              if (n(m['costototal']) > 0) money(m['costototal']),
            ]),
            style: AgroText.muted,
          ),
          badges: t.estado.isEmpty ? null : StatusBadge(t.estado),
          trailing: RowMenu(item: m, reload: reload, actions: AccionesTarea.para(t)),
        );
      },
    );
  }
}
