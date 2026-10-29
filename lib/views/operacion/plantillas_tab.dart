import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

const _etapas = ['Preparación', 'Siembra', 'Crecimiento', 'Mantenimiento', 'Cosecha', 'Postcosecha'];

const _bases = {'siembra': 'La siembra', 'cosecha_estimada': 'La cosecha estimada', 'inicio': 'El inicio del cultivo'};

/// Plantillas de labores de la finca: el administrador ajusta cuándo se hace cada labor de un tipo de cultivo,
/// cuántas personas por hectárea y cuántas horas tarda el grupo en terminarla. Con ellas se arma el plan de cada cultivo.
class PlantillasTab extends StatelessWidget {
  const PlantillasTab({super.key});

  /// Campos de una labor. El orden importa: primero cuántas personas por hectárea y luego cuántas horas
  /// tarda ese grupo en terminar la tarea. [categorias] solo se pasa al crear una labor propia.
  List<FieldDef> _campos({List<MapEntry<dynamic, String>>? categorias}) => [
        if (categorias != null) FieldDef('categoria', 'Categoría de cultivo', type: FT.select, required: true, options: categorias),
        const FieldDef('actividad', 'Labor', required: true, minLength: 3),
        FieldDef('etapa', 'Etapa', type: FT.select, options: [for (final e in _etapas) MapEntry(e, e)],
            helper: 'En qué momento del ciclo del cultivo se hace. «Cosecha» pide registrar lo recolectado al completarla'),
        FieldDef('base', 'Se cuenta desde', type: FT.select, options: [for (final e in _bases.entries) MapEntry(e.key, e.value)]),
        const FieldDef('diasoffset', 'Días desde esa fecha (negativo = antes)', type: FT.number),
        const FieldDef('personasporhectarea', 'Personas sugeridas por hectárea', type: FT.number, required: true, min: 0.1,
            helper: 'Se multiplican por las hectáreas del lote: con 2 por hectárea, un lote de 3 ha necesita 6 personas'),
        const FieldDef('horasestimadas', 'Horas esperadas para terminar la tarea', type: FT.number, required: true, min: 0.5,
            helper: 'Lo que tarda ese grupo en terminarla. No cambia con el tamaño del lote: a más hectáreas se sugieren más personas'),
        const FieldDef('prioridad', 'Prioridad', type: FT.select, options: [
          MapEntry('Alta', 'Alta'), MapEntry('Media', 'Media'), MapEntry('Baja', 'Baja'),
        ]),
        const FieldDef('esrecurrente', '¿Se repite?', type: FT.select, options: [MapEntry(true, 'Sí'), MapEntry(false, 'No')]),
        const FieldDef('frecuenciadias', 'Repetir cada (días)', type: FT.number, min: 1, vaciable: true,
            helper: 'Obligatorio si la labor se repite; sin este dato no se repite'),
        const FieldDef('diasfin', 'Repetir hasta (días desde esa fecha)', type: FT.number, min: 0, vaciable: true,
            helper: 'Vacío = hasta la cosecha estimada del cultivo'),
        const FieldDef('activa', 'Estado', type: FT.select, onlyEdit: true, options: [MapEntry(true, 'Activa'), MapEntry(false, 'Desactivada')]),
      ];

  /// Qué quiere agregar el administrador: todo el catálogo de una categoría o una labor propia.
  Future<String?> _queAgregar(BuildContext c) => showModalBottomSheet<String>(
        context: c,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: const Text('Cargar el catálogo de un tipo de cultivo'),
              subtitle: const Text('Trae todas las labores de la categoría para que las ajustes'),
              onTap: () => Navigator.pop(ctx, 'catalogo'),
            ),
            ListTile(
              leading: const Icon(Icons.add_task_outlined),
              title: const Text('Crear una labor propia'),
              subtitle: const Text('Una labor que no está en el catálogo'),
              onTap: () => Navigator.pop(ctx, 'propia'),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListPage(
      header: const _ModoAsignacion(),
      loader: operacionService.plantillas,
      empty: 'Aún no tienes plantillas.\nCarga el catálogo base de un tipo de cultivo para empezar.',
      emptyIcon: Icons.event_note_outlined,
      addLabel: 'Agregar labores',
      onAdd: (reload) async {
        final queHacer = await _queAgregar(context);
        if (queHacer == null || !context.mounted) return;
        final cats = await cargar(context, operacionService.categoriasOpc);
        if (cats == null || !context.mounted) return;

        if (queHacer == 'catalogo') {
          final d = await showForm(context, 'Cargar catálogo', [
            FieldDef('categoria', 'Categoría de cultivo', type: FT.select, required: true, options: cats),
          ], okLabel: 'Cargar', edit: false);
          if (d == null || !context.mounted) return;
          if (await run(context, () => operacionService.adoptarCategoria(s(d['categoria'])), ok: 'Catálogo cargado')) reload();
          return;
        }

        final d = await showForm(
          context,
          'Nueva labor',
          _campos(categorias: cats),
          initial: const {'base': 'siembra', 'diasoffset': 0, 'prioridad': 'Media', 'esrecurrente': false},
          okLabel: 'Registrar',
          edit: false,
        );
        if (d == null || !context.mounted) return;
        if (await run(context, () => operacionService.crearPlantilla(d), ok: 'Labor creada')) reload();
      },
      itemBuilder: (c, p, reload) {
        final activa = p['activa'] != false;
        final recurrente = p['esrecurrente'] == true;
        final dias = n(p['diasoffset']).toInt();
        return AgroListCard(
          leading: AgroIconTile(
            icon: recurrente ? Icons.repeat : Icons.event_available_outlined,
            color: activa ? AgroColors.primary : AgroColors.textMuted,
            bg: activa ? AgroColors.surfaceGreen : AgroColors.neutralBg,
          ),
          title: Text(s(p['actividad']), style: AgroText.title),
          subtitle: Text(
            juntar([
              s(p['categoria']).replaceAll('_', ' '),
              '${dias >= 0 ? '+' : ''}$dias d desde ${(_bases[s(p['base'])] ?? s(p['base'])).toLowerCase()}',
              if (s(p['etapa']).isNotEmpty) s(p['etapa']),
              '${cant(p['personasporhectarea'])} ${n(p['personasporhectarea']) == 1 ? 'persona' : 'personas'}/ha',
              if (n(p['horasestimadas']) > 0) '${cant(p['horasestimadas'])} h',
              if (recurrente) 'cada ${n(p['frecuenciadias']).toInt()} d',
            ]),
            style: AgroText.muted,
          ),
          badges: activa ? null : const StatusBadge('Inactivo'),
          trailing: RowMenu(item: p, reload: reload, actions: [
            RowAction('Editar', (ctx, it, rel) async {
              final d = await showForm(ctx, 'Editar labor', _campos(), initial: it, edit: true);
              if (d == null || !ctx.mounted) return;
              if (await run(ctx, () => operacionService.actualizarPlantilla((it['idplantilla'] as num).toInt(), d), ok: 'Cambios guardados')) rel();
            }, icon: Icons.edit_outlined),
            RowAction(activa ? 'Desactivar' : 'Activar', (ctx, it, rel) async {
              if (await run(ctx, () => operacionService.actualizarPlantilla((it['idplantilla'] as num).toInt(), {'activa': !activa}))) rel();
            }, icon: activa ? Icons.pause_circle_outline : Icons.play_circle_outline),
          ]),
        );
      },
    );
  }
}

const _modos = {
  'manual': ('Manual', 'Tú eliges a quién asignar cada tarea.'),
  'sugerida': ('Sugerida', 'El sistema propone a quién asignar y tú aceptas con un toque.'),
  'automatica': ('Automática', 'Las tareas nuevas se asignan solas según carga y experiencia.'),
};

/// Cómo se asignan las tareas en esta finca.
class _ModoAsignacion extends StatefulWidget {
  const _ModoAsignacion();
  @override
  State<_ModoAsignacion> createState() => _ModoAsignacionState();
}

class _ModoAsignacionState extends State<_ModoAsignacion> {
  String? _modo;

  @override
  void initState() {
    super.initState();
    operacionService.modoAsignacion().then((m) {
      if (mounted) setState(() => _modo = m);
    }).catchError((_) {});
  }

  Future<void> _cambiar() async {
    final d = await showForm(context, 'Asignación de tareas', [
      FieldDef('modo', 'Modo', type: FT.select, required: true, options: [
        for (final e in _modos.entries) MapEntry(e.key, '${e.value.$1} · ${e.value.$2}'),
      ]),
    ], initial: {'modo': _modo}, edit: true);
    if (d == null || !mounted) return;
    final nuevo = s(d['modo']);
    if (await run(context, () => operacionService.cambiarModoAsignacion(nuevo), ok: 'Modo de asignación actualizado')) {
      setState(() => _modo = nuevo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _modos[_modo];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: AgroCard(
        onTap: m == null ? null : _cambiar,
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: AgroColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Asignación ${m?.$1.toLowerCase() ?? '…'}', style: AgroText.title),
              Text(m?.$2 ?? 'Cargando…', style: AgroText.muted),
            ]),
          ),
          if (m != null) const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}
