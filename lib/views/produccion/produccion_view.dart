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

String _relNombre(dynamic v, String campo) => v is Map ? s(v[campo]) : '';

/// Producción: lotes, cultivos, cosechas y palma.
class ProduccionPage extends StatelessWidget {
  final int initialIndex;
  const ProduccionPage({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return TabsPage(initialIndex: initialIndex, tabs: {
      'Lotes': CrudList(
        path: '/lotes',
        idKey: 'idlote',
        singular: 'lote',
        icon: Icons.landscape,
        canEdit: esAdmin,
        empty: 'Aún no hay lotes.\nDivide tu finca en lotes para organizar los cultivos.',
        fields: () async => const [
          FieldDef('nombre', 'Nombre', required: true, minLength: 2),
          FieldDef('areahectareas', 'Área (hectáreas)', type: FT.number, min: 0),
          FieldDef('ubicacion', 'Ubicación'),
          FieldDef('descripcion', 'Descripción', type: FT.multiline),
        ],
        title: (l) => s(l['nombre']).isEmpty ? 'Lote #${l['idlote']}' : s(l['nombre']),
        subtitle: (l) {
          final cs = (l['cultivos'] as List?) ?? [];
          return juntar([
            if (n(l['areahectareas']) > 0) '${cant(l['areahectareas'])} ha',
            s(l['ubicacion']),
          ]) + (cs.isNotEmpty ? '\nCultivos: ${cs.map((x) => x['tipo']).join(', ')}' : '');
        },
      ),
      'Cultivos': CrudList(
        path: '/cultivos',
        idKey: 'idcultivo',
        singular: 'cultivo',
        icon: Icons.grass,
        canEdit: esAdmin,
        empty: 'Aún no hay cultivos registrados',
        fields: () async => [
          const FieldDef('tipo', 'Tipo (maíz, café, palma…)', required: true, minLength: 2),
          const FieldDef('nombrelote', 'Nombre / referencia'),
          FieldDef('idlote', 'Lote', type: FT.select, options: await produccionService.lotesOpc()),
          const FieldDef('fechasiembra', 'Fecha de siembra', type: FT.date),
          const FieldDef('fechacosechaestimada', 'Cosecha estimada', type: FT.date, after: 'fechasiembra'),
        ],
        normalize: (c) => aplanarIds(c, ['idlote']),
        title: (c) => s(c['tipo']).isEmpty ? 'Cultivo #${c['idcultivo']}' : s(c['tipo']),
        subtitle: (c) {
          final lote = _relNombre(c['idlote'], 'nombre');
          return [
            juntar([s(c['nombrelote']), if (lote.isNotEmpty) 'Lote $lote']),
            juntar([
              if (s(c['fechasiembra']).isNotEmpty) 'Siembra ${fecha(c['fechasiembra'])}',
              if (s(c['fechacosechaestimada']).isNotEmpty) 'Cosecha est. ${fecha(c['fechacosechaestimada'])}',
            ]),
          ].where((x) => x.isNotEmpty).join('\n');
        },
        badge: (c) => CropBadge(s(c['tipo'])),
      ),
      'Cosechas': CrudList(
        path: '/api/v1/cosechas',
        idKey: 'idcosecha',
        singular: 'cosecha',
        femenino: true,
        icon: Icons.agriculture,
        canEdit: esAdmin,
        empty: 'Aún no registras cosechas',
        fields: () async => [
          FieldDef('idcultivo', 'Cultivo', type: FT.select, required: true, onlyCreate: true, options: await produccionService.cultivosOpc()),
          const FieldDef('fechacosecha', 'Fecha', type: FT.date, required: true),
          const FieldDef('cantidad', 'Cantidad', type: FT.number, required: true, min: 0),
          const FieldDef('unidad', 'Unidad (kg, t, bultos…)'),
          const FieldDef('calidad', 'Calidad'),
          const FieldDef('observaciones', 'Observaciones', type: FT.multiline),
        ],
        title: (c) => '${cant(c['cantidad'])} ${s(c['unidad']).isEmpty ? 'kg' : s(c['unidad'])}',
        subtitle: (c) {
          final cult = c['idcultivo'] is Map ? s((c['idcultivo'] as Map)['tipo']) : '';
          return juntar([
            cult.isEmpty ? 'Cultivo #${c['idcultivo'] is Map ? (c['idcultivo'] as Map)['idcultivo'] : c['idcultivo']}' : cult,
            fecha(c['fechacosecha']),
            s(c['calidad']),
          ]);
        },
      ),
      'Palmas': CrudList(
        path: '/palmas',
        idKey: 'idpalma',
        singular: 'palma',
        femenino: true,
        icon: Icons.park,
        canEdit: esAdmin,
        empty: 'Aún no hay palmas registradas',
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
        subtitle: (p) => juntar([
          s(p['variedad']),
          _relNombre(p['idlote'], 'nombre').isEmpty ? '' : 'Lote ${_relNombre(p['idlote'], 'nombre')}',
          if (s(p['fechasiembra']).isNotEmpty) 'Siembra ${fecha(p['fechasiembra'])}',
        ]),
        badge: (p) => s(p['estadosanitario']).isEmpty ? null : StatusBadge(s(p['estadosanitario'])),
      ),
      'Producción de palma': CrudList(
        path: '/produccion-palma',
        idKey: 'idproduccionpalma',
        singular: 'registro de producción',
        icon: Icons.scale,
        canEdit: esAdmin,
        empty: 'Aún no hay registros de producción de palma',
        fields: () async => [
          const FieldDef('fecharegistro', 'Fecha', type: FT.date, required: true),
          const FieldDef('cantidadracimos', 'Cantidad de racimos', type: FT.number, min: 0),
          const FieldDef('pesokg', 'Peso (kg)', type: FT.number, min: 0),
          const FieldDef('calidad', 'Calidad'),
          FieldDef('idlote', 'Lote', type: FT.select, options: await produccionService.lotesOpc()),
          FieldDef('idpalma', 'Palma (opcional)', type: FT.select, options: await produccionService.palmasOpc()),
          const FieldDef('observaciones', 'Observaciones', type: FT.multiline),
        ],
        normalize: (p) => aplanarIds(p, ['idlote', 'idpalma']),
        title: (p) => '${cant(p['pesokg'])} kg · ${cant(n(p['cantidadracimos']).round())} racimos',
        subtitle: (p) => juntar([
          fecha(p['fecharegistro']),
          _relNombre(p['idlote'], 'nombre').isEmpty ? '' : 'Lote ${_relNombre(p['idlote'], 'nombre')}',
          s(p['calidad']),
        ]),
      ),
    });
  }
}
