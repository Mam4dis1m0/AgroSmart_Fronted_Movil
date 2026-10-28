import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/demo/demo_data.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/operacion/plan_labores_view.dart';

/// Las relaciones pueden venir como objeto anidado; el formulario necesita el id.
Map<String, dynamic> aplanarIds(Map<String, dynamic> m, List<String> keys) {
  final out = Map<String, dynamic>.from(m);
  for (final k in keys) {
    if (out[k] is Map) out[k] = (out[k] as Map)[k];
  }
  return out;
}

String _relNombre(dynamic v, String campo) => v is Map ? s(v[campo]) : '';

/// Producción: lotes, cultivos y cosechas.
class ProduccionPage extends StatelessWidget {
  final int initialIndex;
  const ProduccionPage({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return TabsPage(initialIndex: initialIndex, tabs: {
      'Guía': const GuiaCultivosPage(),
      'Lotes': CrudList(
        path: '/lotes',
        idKey: 'idlote',
        singular: 'lote',
        icon: Icons.landscape,
        canEdit: esAdmin,
        empty:
            'Aún no hay lotes.\nDivide tu finca en lotes para organizar los cultivos.',
        header: _demoHeader,
        fields: () async => const [
          FieldDef('nombre', 'Nombre', required: true, minLength: 2),
          FieldDef('areahectareas', 'Área (hectáreas)',
              type: FT.number, min: 0),
          FieldDef('ubicacion', 'Ubicación (referencia dentro de la finca)'),
          FieldDef('descripcion', 'Descripción', type: FT.multiline),
          FieldDef(
            'imagenurl',
            'Foto del lote',
            type: FT.image,
            helper: 'Puedes tomar una foto o elegirla. Máximo 5 MB.',
          ),
        ],
        prepareData: (data) async {
          final payload = Map<String, dynamic>.from(data);
          final foto = s(payload['imagenurl']);
          if (foto.startsWith('data:image/')) {
            final response = await Api.i.dio.post(
              '/lotes/foto',
              data: {'imagen': foto},
            );
            final url =
                response.data is Map ? s(response.data['imagenurl']) : '';
            if (url.isEmpty) {
              throw StateError(
                  'El servidor no devolvió la dirección de la foto');
            }
            payload['imagenurl'] = url;
          }
          return payload;
        },
        leadingBuilder: (lote) {
          final url = s(lote['imagenurl']);
          if (url.isEmpty) return const AgroIconTile(icon: Icons.landscape);
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              url,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const AgroIconTile(icon: Icons.landscape),
            ),
          );
        },
        title: (l) =>
            s(l['nombre']).isEmpty ? 'Lote #${l['idlote']}' : s(l['nombre']),
        subtitle: (l) {
          final cs = (l['cultivos'] as List?) ?? [];
          return juntar([
                if (n(l['areahectareas']) > 0) '${cant(l['areahectareas'])} ha',
                s(l['ubicacion']),
              ]) +
              (cs.isNotEmpty
                  ? '\nCultivos: ${cs.map((x) => x['tipo']).join(', ')}'
                  : '');
        },
      ),
      'Cultivos': CrudList(
        path: '/cultivos',
        idKey: 'idcultivo',
        singular: 'cultivo',
        icon: Icons.grass,
        canEdit: esAdmin,
        empty: 'Aún no hay cultivos registrados',
        header: _demoHeader,
        gradientBuilder: (_) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7F8D8), Color(0xFFF9FCEC), Colors.white],
        ),
        fields: () async => [
          FieldDef(
            'tipo',
            'Tipo de cultivo',
            type: FT.selectOther,
            required: true,
            minLength: 2,
            helper:
                'Registra el cultivo una sola vez. Para mango, café o palma, añade cada recolección como una cosecha del mismo cultivo.',
            options: [
              for (final cultivo in [
                'Maíz',
                'Café',
                'Cacao',
                'Arroz',
                'Fríjol',
                'Plátano',
                'Yuca',
                'Aguacate',
                'Mango',
                'Cítricos',
                'Palma de aceite',
                'Caña de azúcar',
                'Hortalizas',
                'Pastos',
              ])
                MapEntry(cultivo, cultivo),
            ],
          ),
          const FieldDef(
            'nombrelote',
            'Referencia para distinguirlo (opcional)',
            helper:
                'Solo si necesitas diferenciar cultivos del mismo tipo, por ejemplo “Mango de la entrada”.',
          ),
          FieldDef('idlote', 'Lote',
              type: FT.select, options: await produccionService.lotesOpc()),
          const FieldDef('fechasiembra', 'Fecha de siembra', type: FT.date),
          const FieldDef('fechacosechaestimada', 'Cosecha estimada (opcional)',
              type: FT.date,
              after: 'fechasiembra',
              helper:
                  'Con esta fecha el sistema programa las labores de cosecha y postcosecha.'),
          FieldDef('categoria', 'Categoría de manejo (opcional)',
              type: FT.select,
              options: await operacionService.categoriasOpc(),
              helper:
                  'Define qué labores se sugieren. Si lo dejas vacío se deduce del tipo de cultivo.'),
        ],
        extra: (c) => [
          if (esAdmin)
            RowAction('Plan de labores', (ctx, it, reload) async {
              await Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => PlanLaboresPage(
                      idcultivo: (c['idcultivo'] as num).toInt(),
                      nombre: s(c['tipo']))));
            }, icon: Icons.event_note_outlined),
        ],
        normalize: (c) => aplanarIds(c, ['idlote']),
        title: (c) =>
            s(c['tipo']).isEmpty ? 'Cultivo #${c['idcultivo']}' : s(c['tipo']),
        subtitle: (c) {
          final lote = _relNombre(c['idlote'], 'nombre');
          return [
            juntar([s(c['nombrelote']), if (lote.isNotEmpty) 'Lote $lote']),
            juntar([
              if (s(c['fechasiembra']).isNotEmpty)
                'Siembra ${fecha(c['fechasiembra'])}',
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
        header: _demoHeader,
        createDefaults: {'fechacosecha': ymd(DateTime.now())},
        fields: () async => [
          FieldDef(
            'idcultivo',
            'Cultivo',
            type: FT.select,
            required: true,
            onlyCreate: true,
            helper:
                'Puedes registrar varias recolecciones para el mismo cultivo.',
            options: await produccionService.cultivosOpc(),
          ),
          const FieldDef('fechacosecha', 'Fecha',
              type: FT.date,
              required: true,
              helper: 'Aparece la fecha de hoy; cámbiala si fue otro día.'),
          const FieldDef('cantidad', 'Cantidad',
              type: FT.number, required: true, min: 0),
          const FieldDef(
            'unidad',
            'Unidad',
            type: FT.selectOther,
            required: true,
            helper:
                'Elige cómo mediste esta cosecha. No se convierte a otra unidad.',
            options: [
              MapEntry('Caja', 'Caja'),
              MapEntry('Kilo', 'Kilo'),
              MapEntry('Canasta', 'Canasta'),
              MapEntry('Libra', 'Libra'),
              MapEntry('Racimo', 'Racimo'),
            ],
          ),
          const FieldDef('calidad', 'Calidad', type: FT.selectOther, options: [
            MapEntry('Excelente', 'Excelente'),
            MapEntry('Buena', 'Buena'),
            MapEntry('Regular', 'Regular'),
          ]),
          const FieldDef('observaciones', 'Observaciones', type: FT.multiline),
        ],
        title: (c) => [
          cant(c['cantidad']),
          s(c['unidad']),
        ].where((part) => part.isNotEmpty).join(' '),
        subtitle: (c) {
          final cult =
              c['idcultivo'] is Map ? s((c['idcultivo'] as Map)['tipo']) : '';
          return juntar([
            cult.isEmpty
                ? 'Cultivo #${c['idcultivo'] is Map ? (c['idcultivo'] as Map)['idcultivo'] : c['idcultivo']}'
                : cult,
            fecha(c['fechacosecha']),
            s(c['calidad']),
          ]);
        },
      ),
    }, tabIcons: const {
      'Guía': Icons.help_outline
    });
  }
}

Widget? get _demoHeader => kDemoMode
    ? const AgroAlert(
        icon: Icons.science_outlined,
        message:
            'Datos de ejemplo para ver la app. Las acciones de demostración no se guardan en la finca real.',
      )
    : null;

class GuiaCultivosPage extends StatelessWidget {
  const GuiaCultivosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'Conoce tus cultivos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AgroColors.textDark,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Una guía sencilla para organizar las siembras y registrar cada cosecha.',
          style: AgroText.muted,
        ),
        const SizedBox(height: 16),
        const AgroCard(
          color: AgroColors.surfaceGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.lightbulb_outline, color: AgroColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Cómo se organiza?',
                    style: TextStyle(
                      color: AgroColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 10),
              Text(
                'Registra cada siembra como un cultivo. Cuando recojas producto, añade una cosecha con la fecha y la cantidad real. Si vuelves a cosechar una planta permanente, registra otra cosecha para el mismo cultivo.',
                style: TextStyle(
                  color: AgroColors.textDark,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const AgroSectionHeader('Cultivos de ciclo de siembra'),
        const SizedBox(height: 4),
        const Text(
          'Cada nueva siembra se registra como un nuevo cultivo.',
          style: AgroText.muted,
        ),
        const SizedBox(height: 10),
        const _GuiaCultivoCard(
          icon: Icons.grain,
          title: 'Maíz',
          description:
              'Registra el lote y la fecha de siembra si la conoces. Al recolectar, guarda la cantidad obtenida y su unidad.',
          tag: 'Una siembra',
          color: AgroColors.warningText,
          background: AgroColors.warningBg,
        ),
        const SizedBox(height: 8),
        const _GuiaCultivoCard(
          icon: Icons.rice_bowl_outlined,
          title: 'Arroz',
          description:
              'Abre un registro para cada nueva siembra y registra la cosecha cuando ocurra, no como una fecha estimada.',
          tag: 'Una siembra',
          color: AgroColors.primary,
          background: AgroColors.surfaceGreen,
        ),
        const SizedBox(height: 8),
        const _GuiaCultivoCard(
          icon: Icons.spa_outlined,
          title: 'Fríjol',
          description:
              'Puedes usar el nombre del lote o una referencia para distinguir siembras del mismo tipo.',
          tag: 'Una siembra',
          color: AgroColors.info,
          background: AgroColors.infoBg,
        ),
        const SizedBox(height: 20),
        const AgroSectionHeader('Cultivos permanentes'),
        const SizedBox(height: 4),
        const Text(
          'La planta puede seguir en el lote después de una recolección. Conserva el cultivo y añade cada cosecha por separado.',
          style: AgroText.muted,
        ),
        const SizedBox(height: 10),
        const _GuiaCultivoCard(
          icon: Icons.coffee_outlined,
          title: 'Café y cacao',
          description:
              'Mantén un registro del cultivo. Cada recolección se guarda como una nueva cosecha, con su fecha y cantidad real.',
          tag: 'Varias cosechas',
          color: AgroColors.indigo,
          background: Color(0xFFEDE9FE),
        ),
        const SizedBox(height: 8),
        const _GuiaCultivoCard(
          icon: Icons.park_outlined,
          title: 'Mango y cítricos',
          description:
              'No hace falta volver a crear el árbol tras cada recolección. Registra las cosechas en el mismo cultivo y lote.',
          tag: 'Varias cosechas',
          color: AgroColors.primary,
          background: AgroColors.surfaceGreen,
        ),
        const SizedBox(height: 8),
        const _GuiaCultivoCard(
          icon: Icons.eco_outlined,
          title: 'Palma de aceite',
          description:
              'Registra la palma de aceite como cultivo del lote. Anota cada recolección usando el registro general de cosechas.',
          tag: 'Varias cosechas',
          color: AgroColors.teal,
          background: Color(0xFFCCFBF1),
        ),
        const SizedBox(height: 20),
        const AgroSectionHeader('Consejos para llevar el registro'),
        const SizedBox(height: 8),
        const _GuiaConsejo(
          icon: Icons.location_on_outlined,
          text: 'Asocia el cultivo a un lote para ubicarlo fácilmente.',
        ),
        const _GuiaConsejo(
          icon: Icons.event_available_outlined,
          text:
              'La fecha de siembra es opcional; registra solo la que conozcas.',
        ),
        const _GuiaConsejo(
          icon: Icons.scale_outlined,
          text: 'Usa una unidad clara y consistente, por ejemplo kg o bultos.',
        ),
        const _GuiaConsejo(
          icon: Icons.notes_outlined,
          text:
              'Agrega observaciones para recordar detalles de cada recolección.',
        ),
      ],
    );
  }
}

class _GuiaCultivoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String tag;
  final Color color;
  final Color background;

  const _GuiaCultivoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AgroIconTile(icon: icon, color: color, bg: background, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AgroColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: AgroColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuiaConsejo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuiaConsejo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AgroColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AgroColors.textDark,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
