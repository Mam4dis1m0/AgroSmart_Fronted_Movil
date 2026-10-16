import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Las relaciones pueden venir como objeto anidado; el formulario necesita el id.
Map<String, dynamic> aplanarIds(Map<String, dynamic> m, List<String> keys) {
  final out = Map<String, dynamic>.from(m);
  for (final k in keys) {
    if (out[k] is Map) out[k] = (out[k] as Map)[k];
  }
  return out;
}

/// Producción: lotes, cultivos, cosechas y palma.
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
          return [
            const FieldDef('tipo', 'Tipo (maíz, café, palma…)', required: true),
            const FieldDef('nombrelote', 'Nombre / referencia'),
            FieldDef('idlote', 'Lote', type: FT.select, options: await produccionService.lotesOpc()),
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
        badge: (c) => CropBadge(s(c['tipo'])),
      ),
      'Cosechas': CrudList(
        path: '/api/v1/cosechas',
        idKey: 'idcosecha',
        singular: 'cosecha',
        icon: Icons.agriculture,
        canEdit: esAdmin,
        fields: () async {
          return [
            FieldDef('idcultivo', 'Cultivo', type: FT.select, required: true, onlyCreate: true, options: await produccionService.cultivosOpc()),
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
      'Palmas': CrudList(
        path: '/palmas',
        idKey: 'idpalma',
        singular: 'palma',
        icon: Icons.park,
        canEdit: esAdmin,
        fields: () async => [
          const FieldDef('codigo', 'Código', required: true),
          const FieldDef('variedad', 'Variedad'),
          const FieldDef('fechasiembra', 'Fecha de siembra', type: FT.date),
          FieldDef('estadosanitario', 'Estado sanitario', type: FT.select, options: [
            for (final e in ['Sano', 'En observación', 'Enfermo', 'Tratamiento']) MapEntry(e, e),
          ]),
          FieldDef('idlote', 'Lote', type: FT.select, options: await produccionService.lotesOpc()),
          const FieldDef('observaciones', 'Observaciones', type: FT.multiline),
        ],
        normalize: (p) => aplanarIds(p, ['idlote']),
        title: (p) => s(p['codigo']).isEmpty ? 'Palma #${p['idpalma']}' : s(p['codigo']),
        subtitle: (p) => '${s(p['variedad'])}${s(p['variedad']).isEmpty ? '' : ' · '}Siembra: ${d10(p['fechasiembra'])}',
        badge: (p) => StatusBadge(s(p['estadosanitario'])),
      ),
      'Prod. palma': CrudList(
        path: '/produccion-palma',
        idKey: 'idproduccionpalma',
        singular: 'registro de producción',
        icon: Icons.scale,
        canEdit: esAdmin,
        fields: () async => [
          const FieldDef('fecharegistro', 'Fecha', type: FT.date, required: true),
          const FieldDef('cantidadracimos', 'Cantidad de racimos', type: FT.number),
          const FieldDef('pesokg', 'Peso (kg)', type: FT.number),
          const FieldDef('calidad', 'Calidad'),
          FieldDef('idlote', 'Lote', type: FT.select, options: await produccionService.lotesOpc()),
          FieldDef('idpalma', 'Palma (opcional)', type: FT.select, options: await produccionService.palmasOpc()),
          const FieldDef('observaciones', 'Observaciones', type: FT.multiline),
        ],
        normalize: (p) => aplanarIds(p, ['idlote', 'idpalma']),
        title: (p) => '${n(p['pesokg'])} kg · ${n(p['cantidadracimos']).round()} racimos',
        subtitle: (p) => '${d10(p['fecharegistro'])}${s(p['calidad']).isEmpty ? '' : ' · ${s(p['calidad'])}'}',
      ),
    });
  }
}
