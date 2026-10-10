import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'ui.dart';

bool get esAdmin => session.rol == 'admin';

/// Producción: lotes, cultivos y cosechas.
class ProduccionPage extends StatelessWidget {
  const ProduccionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return TabsPage(tabs: {
      'Lotes': CrudList(
        path: '/lotes',
        idKey: 'idlote',
        singular: 'lote',
        icon: Icons.landscape,
        canEdit: esAdmin,
        fields: () async => const [
          FieldDef('nombre', 'Nombre', required: true),
          FieldDef('areahectareas', 'Área (hectáreas)', type: FT.number),
          FieldDef('ubicacion', 'Ubicación'),
          FieldDef('descripcion', 'Descripción', type: FT.multiline),
        ],
        title: (l) => s(l['nombre']).isEmpty ? 'Lote #${l['idlote']}' : s(l['nombre']),
        subtitle: (l) {
          final cs = (l['cultivos'] as List?) ?? [];
          return '${n(l['areahectareas'])} ha · ${s(l['ubicacion'])}'
              '${cs.isNotEmpty ? '\nCultivos: ${cs.map((x) => x['tipo']).join(', ')}' : ''}';
        },
      ),
      'Cultivos': CrudList(
        path: '/cultivos',
        idKey: 'idcultivo',
        singular: 'cultivo',
        icon: Icons.grass,
        canEdit: esAdmin,
        fields: () async {
          final lotes = await Api.i.getList('/lotes');
          return [
            const FieldDef('tipo', 'Tipo (maíz, café, palma…)', required: true),
            const FieldDef('nombrelote', 'Nombre / referencia'),
            FieldDef('idlote', 'Lote', type: FT.select, options: [
              for (final l in lotes) MapEntry(l['idlote'], s(l['nombre']).isEmpty ? 'Lote #${l['idlote']}' : s(l['nombre'])),
            ]),
            const FieldDef('fechasiembra', 'Fecha de siembra', type: FT.date),
            const FieldDef('fechacosechaestimada', 'Cosecha estimada', type: FT.date),
          ];
        },
        normalize: (c) {
          final m = Map<String, dynamic>.from(c);
          if (m['idlote'] is Map) m['idlote'] = (m['idlote'] as Map)['idlote'];
          return m;
        },
        title: (c) => s(c['tipo']).isEmpty ? 'Cultivo #${c['idcultivo']}' : s(c['tipo']),
        subtitle: (c) {
          final lote = c['idlote'] is Map ? s((c['idlote'] as Map)['nombre']) : s(c['nombrelote']);
          return 'Lote: ${lote.isEmpty ? '—' : lote}\nSiembra: ${d10(c['fechasiembra'])} · Cosecha est.: ${d10(c['fechacosechaestimada'])}';
        },
      ),
      'Cosechas': CrudList(
        path: '/api/v1/cosechas',
        idKey: 'idcosecha',
        singular: 'cosecha',
        icon: Icons.agriculture,
        canEdit: esAdmin,
        fields: () async {
          final cultivos = await Api.i.getList('/cultivos');
          return [
            FieldDef('idcultivo', 'Cultivo', type: FT.select, required: true, onlyCreate: true, options: [
              for (final c in cultivos) MapEntry(c['idcultivo'], s(c['tipo']).isEmpty ? 'Cultivo #${c['idcultivo']}' : s(c['tipo'])),
            ]),
            const FieldDef('fechacosecha', 'Fecha', type: FT.date, required: true),
            const FieldDef('cantidad', 'Cantidad', type: FT.number, required: true),
            const FieldDef('unidad', 'Unidad (kg, t, bultos…)'),
            const FieldDef('calidad', 'Calidad'),
            const FieldDef('observaciones', 'Observaciones', type: FT.multiline),
          ];
        },
        title: (c) => '${n(c['cantidad'])} ${s(c['unidad']).isEmpty ? 'kg' : s(c['unidad'])}',
        subtitle: (c) => 'Cultivo #${c['idcultivo']} · ${d10(c['fechacosecha'])}${s(c['calidad']).isEmpty ? '' : ' · ${s(c['calidad'])}'}',
      ),
    });
  }
}
