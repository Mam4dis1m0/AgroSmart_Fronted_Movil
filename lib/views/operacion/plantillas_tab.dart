import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

const _bases = {'siembra': 'La siembra', 'cosecha_estimada': 'La cosecha estimada', 'inicio': 'El inicio del cultivo'};

/// Plantillas de labores de la finca: el administrador ajusta cuándo, cuánto y con cuántas personas
/// se hace cada labor de un tipo de cultivo. Con ellas se arma el plan de cada cultivo.
class PlantillasTab extends StatelessWidget {
  const PlantillasTab({super.key});

  Future<List<FieldDef>> _campos() async => [
        const FieldDef('actividad', 'Labor', required: true, minLength: 3),
        const FieldDef('etapa', 'Etapa (siembra, crecimiento, cosecha…)'),
        FieldDef('base', 'Se cuenta desde', type: FT.select, options: [for (final e in _bases.entries) MapEntry(e.key, e.value)]),
        const FieldDef('diasoffset', 'Días desde esa fecha (negativo = antes)', type: FT.number),
        const FieldDef('horasestimadas', 'Horas estimadas', type: FT.number, min: 0),
        const FieldDef('numpersonas', 'Personas necesarias', type: FT.number, min: 1),
        const FieldDef('prioridad', 'Prioridad', type: FT.select, options: [
          MapEntry('Alta', 'Alta'), MapEntry('Media', 'Media'), MapEntry('Baja', 'Baja'),
        ]),
        const FieldDef('esrecurrente', '¿Se repite?', type: FT.select, options: [MapEntry(true, 'Sí'), MapEntry(false, 'No')]),
        const FieldDef('frecuenciadias', 'Repetir cada (días)', type: FT.number, min: 1),
        const FieldDef('diasfin', 'Repetir hasta (días desde esa fecha)', type: FT.number, min: 0),
        const FieldDef('modalidadpago', 'Cómo se paga', type: FT.select, options: [
          MapEntry('tiempo', 'Por tiempo trabajado'), MapEntry('fijo', 'Valor acordado (destajo)'),
        ]),
        const FieldDef('activa', 'Estado', type: FT.select, options: [MapEntry(true, 'Activa'), MapEntry(false, 'Desactivada')]),
      ];

  @override
  Widget build(BuildContext context) {
    return ListPage(
      header: const _ModoAsignacion(),
      loader: operacionService.plantillas,
      empty: 'Aún no tienes plantillas.\nCarga el catálogo base de un tipo de cultivo para empezar.',
      emptyIcon: Icons.event_note_outlined,
      addLabel: 'Agregar labores',
      onAdd: (reload) async {
        final cats = await cargar(context, operacionService.categoriasOpc);
        if (cats == null || !context.mounted) return;
        final d = await showForm(context, 'Agregar labores', [
          FieldDef('categoria', 'Categoría de cultivo', type: FT.select, required: true, options: cats),
          const FieldDef('actividad', 'Nombre de una labor propia (opcional)',
              helper: 'Déjalo vacío para cargar todo el catálogo base de la categoría.'),
        ], okLabel: 'Agregar', edit: false);
        if (d == null || !context.mounted) return;
        final propia = s(d['actividad']).trim();
        final ok = await run(
          context,
          () => propia.isEmpty
              ? operacionService.adoptarCategoria(s(d['categoria']))
              : operacionService.crearPlantilla({'categoria': d['categoria'], 'actividad': propia}),
          ok: propia.isEmpty ? 'Catálogo cargado' : 'Labor creada',
        );
        if (ok) reload();
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
              if (n(p['horasestimadas']) > 0) '${cant(p['horasestimadas'])} h',
              if (n(p['numpersonas']) > 1) '${n(p['numpersonas']).toInt()} personas',
              if (recurrente) 'cada ${n(p['frecuenciadias']).toInt()} d',
            ]),
            style: AgroText.muted,
          ),
          badges: activa ? null : const StatusBadge('Inactivo'),
          trailing: RowMenu(item: p, reload: reload, actions: [
            RowAction('Editar', (ctx, it, rel) async {
              final f = await cargar(ctx, _campos);
              if (f == null || !ctx.mounted) return;
              final d = await showForm(ctx, 'Editar labor', f, initial: it, edit: true);
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
