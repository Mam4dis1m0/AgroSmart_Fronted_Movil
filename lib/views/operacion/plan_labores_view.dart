import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Plan de labores de un cultivo: el sistema propone las tareas según el tipo de cultivo y sus fechas;
/// el administrador revisa, desmarca lo que no quiera y las crea de una vez.
class PlanLaboresPage extends StatefulWidget {
  final int idcultivo;
  final String nombre;
  const PlanLaboresPage({super.key, required this.idcultivo, this.nombre = ''});
  @override
  State<PlanLaboresPage> createState() => _PlanLaboresPageState();
}

class _PlanLaboresPageState extends State<PlanLaboresPage> {
  late Future<Map<String, dynamic>> _f = _cargar();
  final Set<int> _marcadas = {};
  bool _enviando = false;

  Future<Map<String, dynamic>> _cargar() async {
    final plan = await operacionService.planLabores(widget.idcultivo);
    _marcadas
      ..clear()
      ..addAll([
        for (final i in _items(plan))
          if (_seleccionable(i) && i['pasada'] != true) (i['idplantilla'] as num).toInt(),
      ]);
    return plan;
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> plan) =>
      [for (final i in (plan['items'] as List? ?? const [])) (i as Map).cast<String, dynamic>()];

  bool _seleccionable(Map<String, dynamic> i) => i['omitida'] == null && i['yaCreada'] != true;

  Future<void> _crear() async {
    setState(() => _enviando = true);
    final ok = await run(context, () async {
      final n = await operacionService.generarPlan(widget.idcultivo, _marcadas.toList());
      if (mounted) {
        snack(context, n < 0 ? 'Sin conexión: las tareas se crearán al volver la red' : (n == 0 ? 'No se creó ninguna tarea nueva' : 'Se crearon $n tareas'));
      }
    });
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) Navigator.pop(context, true);
  }

  String _detalle(Map<String, dynamic> i) {
    final horas = n(i['horasestimadas']);
    final personas = n(i['numpersonas']).toInt();
    final costo = n(i['costoestimado']);
    return juntar([
      if (i['fecha'] != null) fecha(i['fecha']),
      if (horas > 0) '${cant(horas)} h',
      if (personas > 1) '$personas personas',
      if (costo > 0) 'aprox. ${money(costo)}',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nombre.isEmpty ? 'Plan de labores' : 'Plan de labores · ${widget.nombre}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return AgroError(message: Api.errorMsg(snap.error!), onRetry: () => setState(() {
                  _f = _cargar();
                }));
          }
          final plan = snap.data!;
          final items = _items(plan);
          if (items.isEmpty) {
            return const AgroEmpty(icon: Icons.event_note_outlined, message: 'No hay labores para esta categoría de cultivo');
          }
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(14), children: [
                AgroCard(
                  color: AgroColors.surfaceGreen,
                  child: Text(
                    plan['desdeBase'] == true
                        ? 'Estas labores salen del catálogo base de AgroSmart. Al crearlas, tu finca guarda su propia copia para que la personalices en Operación › Plantillas.'
                        : 'Estas labores salen de las plantillas de tu finca. Desmarca las que no necesites.',
                    style: AgroText.muted,
                  ),
                ),
                const SizedBox(height: 12),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AgroCard(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _marcadas.contains((i['idplantilla'] as num).toInt()),
                        onChanged: _seleccionable(i)
                            ? (v) => setState(() {
                                  final id = (i['idplantilla'] as num).toInt();
                                  v == true ? _marcadas.add(id) : _marcadas.remove(id);
                                })
                            : null,
                        title: Text(s(i['actividad']), style: AgroText.title),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (_detalle(i).isNotEmpty) Text(_detalle(i), style: AgroText.muted),
                          if (i['esrecurrente'] == true)
                            Text('Se repite cada ${n(i['frecuenciadias']).toInt()} días', style: AgroText.muted),
                          if (i['omitida'] != null) Text(s(i['omitida']), style: AgroText.muted),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, children: [
                            if (s(i['etapa']).isNotEmpty) StatusBadge(s(i['etapa'])),
                            if (i['yaCreada'] == true) const StatusBadge('Sincronizado'),
                            if (i['pasada'] == true && i['yaCreada'] != true) const StatusBadge('Vencida'),
                          ]),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _marcadas.isEmpty || _enviando ? null : _crear,
                    icon: const Icon(Icons.playlist_add_check),
                    label: Text(_marcadas.isEmpty ? 'Selecciona labores' : 'Crear ${_marcadas.length} tareas'),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
