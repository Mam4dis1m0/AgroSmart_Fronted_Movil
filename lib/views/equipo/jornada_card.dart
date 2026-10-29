import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Jornada de un día normal de la finca. Con ella y el pago de los empleados se obtiene el costo
/// promedio de una hora de mano de obra, que es lo que se usa para costear cada tarea.
class JornadaCard extends StatefulWidget {
  const JornadaCard({super.key});
  @override
  State<JornadaCard> createState() => _JornadaCardState();
}

class _JornadaCardState extends State<JornadaCard> {
  Map<String, dynamic>? _j;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final j = await operacionService.jornada();
      if (mounted) setState(() => _j = j);
    } catch (_) {}
  }

  Future<void> _editar() async {
    final j = _j!;
    final d = await showForm(
      context,
      'Jornada de la finca',
      const [
        FieldDef('jornadainicio', 'Hora de entrada', type: FT.time, required: true),
        FieldDef('jornadafin', 'Hora de salida', type: FT.time, required: true),
        FieldDef('jornadadescanso', 'Descanso al día (minutos)', type: FT.number, required: true, min: 0),
        FieldDef('jornadapersonas', 'Personas que trabajan en un día normal',
            type: FT.number,
            min: 1,
            helper: 'Si lo dejas vacío se cuentan todos los empleados activos'),
      ],
      initial: {
        'jornadainicio': j['inicio'],
        'jornadafin': j['fin'],
        'jornadadescanso': j['descanso'],
        'jornadapersonas': j['personasIndicadas'],
      },
      okLabel: 'Guardar',
      edit: true,
    );
    if (d == null || !mounted) return;
    final ok = await run(
      context,
      () => operacionService.guardarJornada({
        'jornadainicio': d['jornadainicio'],
        'jornadafin': d['jornadafin'],
        'jornadadescanso': (d['jornadadescanso'] as num).toInt(),
        'jornadapersonas': (d['jornadapersonas'] as num?)?.toInt(),
      }),
      ok: 'Jornada guardada',
    );
    if (ok) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final j = _j;
    final costoHora = n(j?['costoHora']);
    final sinPago = n(j?['empleadosSinPago']).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: AgroCard(
        onTap: j == null ? null : _editar,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.schedule, color: AgroColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: j == null
                  ? const Text('Jornada de la finca…', style: AgroText.muted)
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Jornada ${s(j['inicio'])} – ${s(j['fin'])} · ${cant(j['horasJornada'])} h', style: AgroText.title),
                      Text(
                        juntar([
                          '${n(j['personas']).toInt()} personas',
                          'Pago diario del equipo ${money(j['pagoDiarioEquipo'])}',
                        ]),
                        style: AgroText.muted,
                      ),
                    ]),
            ),
            if (j != null) const Icon(Icons.edit_outlined, size: 18, color: AgroColors.textMuted),
          ]),
          if (j != null) ...[
            const SizedBox(height: 8),
            InfoRow('Costo promedio por hora de mano de obra', money(costoHora), strong: true),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                costoHora <= 0
                    ? 'Configura el pago de tus empleados (en su menú ⋮ › Pago acordado) para costear las tareas.'
                    : 'Se usa para calcular el costo de mano de obra de cada tarea: horas trabajadas × este valor. No afecta lo que se le paga a nadie.',
                style: AgroText.muted,
              ),
            ),
            if (sinPago > 0 && costoHora > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$sinPago ${sinPago == 1 ? 'empleado no tiene' : 'empleados no tienen'} pago configurado y no se cuentan en el promedio.',
                  style: AgroText.muted.copyWith(color: AgroColors.warning),
                ),
              ),
          ],
        ]),
      ),
    );
  }
}
