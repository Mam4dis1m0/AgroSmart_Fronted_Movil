import 'package:flutter/material.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/imagen.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'tarea_detalle_view.dart';

const _etiquetaEstado = {
  'Pendiente': 'Pendientes',
  'Asignado': 'Asignadas',
  'En progreso': 'En progreso',
  'Completado': 'Completadas'
};

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
      FieldDef('idcultivo', 'Cultivo',
          type: FT.select,
          options: await operacionService.cultivosOpc(),
          helper:
              'Obligatorio en tareas de cosecha: ahí queda registrado lo recolectado'),
      const FieldDef('costototal', 'Costo estimado (COP)',
          type: FT.number, min: 0, vaciable: true),
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

    // El sistema propone a quién asignar; si no hay red o falla, se elige a mano como siempre
    var lista = <Map<String, dynamic>>[];
    var personas = 1;
    try {
      final sug = await operacionService.sugerenciasAsignacion(t.idtarea);
      personas = (sug['numpersonas'] as num?)?.toInt() ?? 1;
      lista = [
        for (final x in (sug['sugerencias'] as List? ?? const []))
          (x as Map).cast<String, dynamic>()
      ];
    } catch (_) {}
    if (!c.mounted) return false;

    var elegidos = <int>[];
    if (lista.isNotEmpty) {
      final r = await showModalBottomSheet<List<int>>(
        context: c,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            SelectorSugerido(sugerencias: lista, personas: personas),
      );
      if (r == null || !c.mounted) return false; // cerró la hoja sin decidir
      elegidos = r; // vacío = "elegir a otra persona"
    }
    final sugerida = elegidos.isNotEmpty;

    // Con una sugerencia aceptada no hay nada más que preguntar; si no, se elige a quién asignar
    int? elegidoAMano;
    if (!sugerida) {
      final d = await showForm(
        c,
        t.asignacion == null ? 'Asignar tarea' : 'Reasignar tarea',
        [
          FieldDef('idempleado', 'Empleado',
              type: FT.select, required: true, options: emps)
        ],
        okLabel: 'Asignar',
        edit: false,
      );
      if (d == null || !c.mounted) return false;
      elegidoAMano = (d['idempleado'] as num).toInt();
    }

    final ids = sugerida ? elegidos : [elegidoAMano!];
    // Reasignar cierra la asignación anterior (queda en el historial) para no dejar la tarea esperando a otra persona
    return run(
      c,
      () async {
        for (var i = 0; i < ids.length; i++) {
          await operacionService.asignarTarea(t.idtarea, {
            'idempleado': ids[i],
            'origenasignacion': sugerida ? 'sugerida' : 'manual',
            if (i == 0 && t.asignacion != null) 'reemplazar': true,
          });
        }
      },
      ok: ids.length > 1
          ? 'Tarea asignada a ${ids.length} personas'
          : 'Tarea asignada; se notificó al empleado por correo',
    );
  }

  /// Con asignación se guarda la hora de inicio (cronómetro); sin asignación solo cambia el estado.
  static Future<bool> iniciar(BuildContext c, Tarea t) {
    final asig = t.asignacion;
    return run(
      c,
      () => asig != null
          ? operacionService
              .iniciarAsignacion((asig['idasigtarea'] as num).toInt())
          : operacionService
              .actualizarTarea(t.idtarea, {'estado': 'En progreso'}),
      ok: 'Tarea en progreso',
    );
  }

  /// En una tarea de cosecha pregunta cuánto se recolectó. null = cancelado; vacío = no aplica.
  static Future<Map<String, dynamic>?> pedirCosecha(
      BuildContext c, Tarea t) async {
    if (!t.esCosecha || t.asignacion == null) return const {};
    if (!t.tieneCultivo) {
      // Sin cultivo no hay a qué cosecha pertenezca lo recolectado: se avisa en vez de perderlo en silencio
      final seguir = await confirmar(
        c,
        'Esta tarea de cosecha no tiene cultivo, así que lo recolectado no quedará en Cosechas. Edítala y elige el cultivo para poder registrarlo.',
        titulo: 'Tarea sin cultivo',
        ok: 'Completar igual',
      );
      return seguir ? const {} : null;
    }
    return showForm(
      c,
      'Lo recolectado',
      const [
        FieldDef('cantidad', 'Cantidad recolectada',
            type: FT.number,
            required: true,
            min: 0.01,
            helper:
                'Queda registrada en Producción › Cosechas, ligada a esta tarea'),
        FieldDef('unidad', 'Unidad',
            type: FT.selectOther,
            required: true,
            options: [
              MapEntry('Kilo', 'Kilo'),
              MapEntry('Libra', 'Libra'),
              MapEntry('Caja', 'Caja'),
              MapEntry('Canasta', 'Canasta'),
              MapEntry('Racimo', 'Racimo'),
              MapEntry('Bulto', 'Bulto'),
              MapEntry('Tonelada', 'Tonelada'),
            ]),
        FieldDef('calidad', 'Calidad (opcional)'),
      ],
      initial: const {'unidad': 'Kilo'},
      okLabel: 'Continuar',
      edit: false,
    );
  }

  static Future<bool> completar(BuildContext c, Tarea t) async {
    if (!await confirmar(c, 'Se avisará por correo al administrador.',
        titulo: '¿Marcar «${t.actividad}» como completada?', ok: 'Completar')) {
      return false;
    }
    if (!c.mounted) return false;
    final cosecha = await pedirCosecha(c, t);
    if (cosecha == null || !c.mounted) return false;
    final asig = t.asignacion;
    return run(
      c,
      () => asig != null
          ? operacionService.completarAsignacion(
              (asig['idasigtarea'] as num).toInt(),
              cosecha: cosecha.isEmpty ? null : cosecha)
          : operacionService
              .actualizarTarea(t.idtarea, {'estado': 'Completado'}),
      ok: cosecha.isEmpty
          ? 'Tarea completada'
          : 'Tarea completada y cosecha registrada',
    );
  }

  static Future<bool> completarConFoto(BuildContext c, Tarea t) async {
    final inicial = await elegirImagen(
      c,
      maxWidth: 1400,
      evidenciaTarea: t.idtarea,
      scope: Api.i.cacheScope,
      maxBytes: 10 * 1024 * 1024,
    );
    if (inicial == null || !c.mounted) return false;
    var img = inicial;
    EvidenciaPendiente.poner(t.idtarea, img);
    while (c.mounted) {
      final op = await _previsualizarEvidencia(c, img);
      if (op != 'otra') {
        // 'usar' continúa; cerrar la vista previa cancela (la foto queda pendiente)
        if (op != 'usar') return false;
        break;
      }
      if (!c.mounted) return false;
      final otra = await elegirImagen(
        c,
        maxWidth: 1400,
        evidenciaTarea: t.idtarea,
        scope: Api.i.cacheScope,
        maxBytes: 10 * 1024 * 1024,
      );
      if (otra == null || !c.mounted) return false;
      img = otra;
      EvidenciaPendiente.poner(t.idtarea, img);
    }
    final obs = await showForm(
        c,
        'Evidencia de la tarea',
        const [
          FieldDef('observaciones', 'Observaciones (opcional)',
              type: FT.multiline),
        ],
        okLabel: 'Enviar y completar',
        edit: false);
    if (obs == null || !c.mounted) return false;
    final cosecha = await pedirCosecha(c, t);
    if (cosecha == null || !c.mounted) return false;
    var enCola = false;
    final ok = await run(c, () async {
      enCola = await operacionService.completarConEvidencia(
        tarea: t,
        foto: img.bytes,
        nombreArchivo: img.nombre,
        observaciones: s(obs['observaciones']),
        cosecha: cosecha.isEmpty ? null : cosecha,
      );
    });
    if (ok) EvidenciaPendiente.quitar(t.idtarea);
    if (ok && c.mounted) {
      snack(
          c,
          enCola
              ? 'Sin conexión: la tarea quedó completada en tu celular y se enviará con la foto al volver la red'
              : 'Tarea completada; el administrador recibió el PDF de evidencia');
    }
    return ok;
  }

  /// Muestra la foto elegida antes de enviarla: 'usar' continúa, 'otra' la reemplaza, null cierra.
  static Future<String?> _previsualizarEvidencia(
      BuildContext c, ImagenElegida img) {
    return showDialog<String>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: const Text('Vista previa de la evidencia'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(img.bytes, height: 280, fit: BoxFit.contain),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'otra'),
              child: const Text('Elegir otra')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'usar'),
              child: const Text('Usar esta foto')),
        ],
      ),
    );
  }

  static Future<bool> editar(BuildContext c, Tarea t) async {
    final f = await cargar(c, camposTarea);
    if (f == null || !c.mounted) return false;
    final d = await showForm(
        c,
        'Editar tarea',
        [
          ...f,
          FieldDef('estado', 'Estado',
              type: FT.select,
              options: [for (final e in Tarea.estados) MapEntry(e, e)]),
        ],
        initial: t.toForm(),
        edit: true);
    if (d == null || !c.mounted) return false;
    return run(c, () => operacionService.actualizarTarea(t.idtarea, d),
        ok: 'Cambios guardados');
  }

  static Future<bool> eliminar(BuildContext c, Tarea t) async {
    if (!await confirmar(
        c, '«${t.actividad}» se eliminará de forma permanente.',
        titulo: '¿Eliminar tarea?', ok: 'Eliminar', destructivo: true)) {
      return false;
    }
    if (!c.mounted) return false;
    return run(c, () => operacionService.eliminarTarea(t.idtarea),
        ok: 'Tarea eliminada');
  }

  /// Acciones válidas según el rol y el estado de la tarea.
  static List<RowAction> para(Tarea t) {
    final done = t.completada;
    Future<void> Function(BuildContext, Map<String, dynamic>, VoidCallback) w(
            Future<bool> Function(BuildContext, Tarea) f) =>
        (ctx, _, reload) async {
          if (await f(ctx, t)) reload();
        };
    return [
      if (!done &&
          !t.estado.toLowerCase().startsWith('en progreso') &&
          (esAdmin || t.asignacion != null))
        RowAction('Iniciar', w(iniciar), icon: Icons.play_arrow_outlined),
      if (!done)
        RowAction('Completar', w(completar), icon: Icons.check_circle_outline),
      if (!done && session.esEmpleado && t.asignacion != null)
        RowAction('Completar con foto', w(completarConFoto),
            icon: Icons.photo_camera_outlined),
      if (esAdmin && !done)
        RowAction(t.asignacion == null ? 'Asignar a empleado' : 'Reasignar',
            w(asignar),
            icon: Icons.person_add_alt),
      if (esAdmin) RowAction('Editar', w(editar), icon: Icons.edit_outlined),
      if (esAdmin)
        RowAction('Eliminar', w(eliminar),
            icon: Icons.delete_outline, destructive: true),
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
    return _estado == 'Completado'
        ? e.startsWith('completad')
        : e == _estado!.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => operacionService
          .tareas()
          .then((l) => l.map((e) => e.toMap()).toList()),
      filter: _estado == null ? null : _coincide,
      header: FilterChips(
        options: _etiquetaEstado.values.toList(),
        selected: _estado == null ? null : _etiquetaEstado[_estado],
        onSelected: (v) => setState(() => _estado = v == null
            ? null
            : _etiquetaEstado.entries.firstWhere((e) => e.value == v).key),
      ),
      empty: _estado != null
          ? 'No hay tareas en este estado'
          : (esAdmin
              ? 'Aún no hay tareas.\nCrea una y asígnala a tu equipo.'
              : 'No tienes tareas asignadas'),
      emptyIcon: Icons.checklist_rtl,
      addLabel: 'Nueva tarea',
      onAdd: esAdmin
          ? (reload) async {
              final f = await cargar(context, camposTarea);
              if (f == null || !context.mounted) return;
              final d = await showForm(context, 'Nueva tarea', f, edit: false);
              if (d == null || !context.mounted) return;
              if (await run(context, () => operacionService.crearTarea(d),
                  ok: 'Tarea creada')) reload();
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
            await Navigator.of(c).push(MaterialPageRoute(
                builder: (_) => TareaDetallePage(idtarea: t.idtarea)));
            reload();
          },
          leading: AgroIconTile(
            icon: done
                ? Icons.check
                : (enProgreso ? Icons.autorenew : Icons.pending_actions),
            color: done ? AgroColors.primary : AgroColors.warning,
            bg: done ? AgroColors.surfaceGreen : AgroColors.warningBg,
          ),
          title: Text(t.actividad.isEmpty ? 'Tarea #${t.idtarea}' : t.actividad,
              style: AgroText.title),
          subtitle: Text(
            juntar([
              if (t.fechaprogramada.isNotEmpty) fecha(t.fechaprogramada),
              t.cultivoNombre,
              if (esAdmin)
                t.empleadoNombre.isEmpty ? 'Sin asignar' : t.empleadoNombre,
              if (n(m['costototal']) > 0) money(m['costototal']),
            ]),
            style: AgroText.muted,
          ),
          badges: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (t.estado.isNotEmpty) StatusBadge(t.estado),
              if (t.atrasada) const StatusBadge('Atrasada'),
              if (t.evidencias > 0)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_camera_outlined,
                      size: 16, color: AgroColors.primary),
                  const SizedBox(width: 2),
                  Text('${t.evidencias}', style: AgroText.muted),
                ]),
            ],
          ),
          trailing:
              RowMenu(item: m, reload: reload, actions: AccionesTarea.para(t)),
        );
      },
    );
  }
}

/// Hoja con las personas que el sistema recomienda para una tarea y por qué.
class SelectorSugerido extends StatefulWidget {
  final List<Map<String, dynamic>> sugerencias;
  final int personas;
  const SelectorSugerido(
      {super.key, required this.sugerencias, this.personas = 1});
  @override
  State<SelectorSugerido> createState() => _SelectorSugeridoState();
}

class _SelectorSugeridoState extends State<SelectorSugerido> {
  late final Set<int> _sel = {
    for (final x in widget.sugerencias.take(widget.personas))
      (x['idusuario'] as num).toInt(),
  };

  void _alternar(int id, bool on) => setState(() {
        if (widget.personas == 1) _sel.clear();
        on ? _sel.add(id) : _sel.remove(id);
      });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  widget.personas > 1
                      ? 'Sugerencias · se necesitan ${widget.personas} personas'
                      : 'Sugerencias del sistema',
                  style: AgroText.title),
              const SizedBox(height: 2),
              const Text(
                  'Según carga de trabajo, experiencia en la labor y disponibilidad.',
                  style: AgroText.muted),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final x in widget.sugerencias)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _sel.contains((x['idusuario'] as num).toInt()),
                      onChanged: (v) =>
                          _alternar((x['idusuario'] as num).toInt(), v == true),
                      secondary: AgroAvatar(
                          url: s(x['foto']),
                          nombre: s(x['nombre']),
                          radius: 18),
                      title: Text(s(x['nombre']), style: AgroText.title),
                      subtitle: Text(
                        ((x['motivos'] as List?) ?? const [])
                            .map((m) => '$m')
                            .join(' · '),
                        style: AgroText.muted,
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sel.isEmpty
                      ? null
                      : () => Navigator.pop(context, _sel.toList()),
                  child: Text(_sel.length > 1
                      ? 'Asignar a ${_sel.length} personas'
                      : 'Asignar'),
                ),
              ),
              Center(
                  child: TextButton(
                      onPressed: () => Navigator.pop(context, <int>[]),
                      child: const Text('Elegir a otra persona'))),
            ]),
      ),
    );
  }
}
