import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/models/operacion.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/imagen.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'tareas_view.dart';

/// Detalle de una tarea: datos, asignación, horas trabajadas e insumos usados.
class TareaDetallePage extends StatefulWidget {
  final int idtarea;
  const TareaDetallePage({super.key, required this.idtarea});
  @override
  State<TareaDetallePage> createState() => _TareaDetallePageState();
}

/// Tiempo transcurrido como `2 h 05 min` (o `35 min` si es menos de una hora).
String _duracion(Duration d) {
  final h = d.inHours, m = d.inMinutes.remainder(60);
  return h > 0 ? '$h h ${m.toString().padLeft(2, '0')} min' : '$m min';
}

/// Cronómetro de la asignación en curso: se actualiza cada segundo mientras está visible.
class _Cronometro extends StatefulWidget {
  final DateTime inicio;
  const _Cronometro(this.inicio);
  @override
  State<_Cronometro> createState() => _CronometroState();
}

class _CronometroState extends State<_Cronometro> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.inicio);
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    String dos(int v) => v.toString().padLeft(2, '0');
    return Text('${dos(s ~/ 3600)}:${dos((s % 3600) ~/ 60)}:${dos(s % 60)}',
        style: AgroText.title.copyWith(
            fontSize: 22, fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

class _TareaDetallePageState extends State<TareaDetallePage> {
  late Future<(Tarea, List<Map<String, dynamic>>)> _f = _load();

  /// Propuestas del sistema (sin red o si fallan, simplemente no se muestran).
  List<Map<String, dynamic>> _sugeridos = const [];
  Map<String, dynamic>? _costos;
  List<Map<String, dynamic>> _evidencias = const [];

  Future<(Tarea, List<Map<String, dynamic>>)> _load() async {
    final r = await Future.wait<dynamic>([
      operacionService.tarea(widget.idtarea),
      operacionService
          .insumosDeTarea(widget.idtarea)
          .catchError((_) => <Map<String, dynamic>>[]),
      operacionService
          .insumosSugeridos(widget.idtarea)
          .catchError((_) => <Map<String, dynamic>>[]),
      operacionService
          .evidencias(widget.idtarea)
          .catchError((_) => <Map<String, dynamic>>[]),
      if (esAdmin)
        operacionService
            .costosTarea(widget.idtarea)
            .then<Map<String, dynamic>?>((m) => m)
            .catchError((_) => null),
    ]);
    _sugeridos = (r[2] as List).cast<Map<String, dynamic>>();
    _evidencias = (r[3] as List).cast<Map<String, dynamic>>();
    _costos = esAdmin ? r[4] as Map<String, dynamic>? : null;
    return (r[0] as Tarea, (r[1] as List).cast<Map<String, dynamic>>());
  }

  Future<void> _agregarFoto() async {
    final img = await elegirImagen(
      context,
      maxWidth: 1400,
      evidenciaTarea: widget.idtarea,
      scope: Api.i.cacheScope,
      maxBytes: 10 * 1024 * 1024,
    );
    if (img == null || !mounted) return;
    final obs = await showForm(
        context,
        'Foto de la tarea',
        const [
          FieldDef('observaciones', 'Nota (opcional)', type: FT.multiline),
        ],
        okLabel: 'Guardar foto',
        edit: false);
    if (obs == null || !mounted) return;
    var enCola = false;
    final ok = await run(context, () async {
      enCola = await operacionService.agregarEvidencia(widget.idtarea,
          foto: img.bytes,
          nombreArchivo: img.nombre,
          observaciones: s(obs['observaciones']));
    });
    if (!ok || !mounted) return;
    snack(
        context,
        enCola
            ? 'Sin conexión: la foto se subirá al volver la red'
            : 'Foto guardada');
    _recargar();
  }

  void _verFoto(Map<String, dynamic> e) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          InteractiveViewer(
              child: Image.network(s(e['url']), fit: BoxFit.contain)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              juntar([
                fecha(e['fecha'], hora: true),
                s(e['autor']),
                s(e['observaciones'])
              ]),
              style: AgroText.muted,
            ),
          ),
        ]),
      ),
    );
  }

  /// Miniatura de la foto elegida para completar la tarea, aún no enviada al servidor.
  Widget _fotoPendiente(ImagenElegida pend) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            InteractiveViewer(
                child: Image.memory(pend.bytes, fit: BoxFit.contain)),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Foto elegida, pendiente de enviar',
                  style: AgroText.muted),
            ),
          ]),
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(pend.bytes,
                width: 96, height: 96, fit: BoxFit.cover),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: Colors.black.withValues(alpha: 0.55),
              child: const Text(
                'Pendiente',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () =>
                  setState(() => EvidenciaPendiente.quitar(widget.idtarea)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Miniatura de una foto ya subida; el admin o quien la subió pueden eliminarla.
  Widget _fotoSubida(Map<String, dynamic> e) {
    final mio = esAdmin || n(e['idusuario']) == n(session.usuario?['id']);
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _verFoto(e),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              s(e['url']),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: AgroColors.neutralBg,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        if (mio)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _eliminarFoto(e),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _eliminarFoto(Map<String, dynamic> e) async {
    if (!await confirmar(context, 'La foto se quitará de esta tarea.',
        titulo: '¿Eliminar la foto?', ok: 'Eliminar', destructivo: true)) {
      return;
    }
    if (!mounted) return;
    if (await run(
        context,
        () => operacionService.eliminarEvidencia(
            widget.idtarea, (e['idevidencia'] as num).toInt()),
        ok: 'Foto eliminada')) {
      _recargar();
    }
  }

  /// Un toque confirma la cantidad propuesta; si falta el insumo o la cantidad, o se quiere cambiar, se edita antes.
  Future<void> _usarSugerido(Map<String, dynamic> sug,
      {bool editar = false}) async {
    var datos = <String, dynamic>{
      'idinsumo': sug['idinsumo'],
      'cantidadusada': sug['cantidad']
    };
    if (editar || sug['idinsumo'] == null || sug['cantidad'] == null) {
      final cands = [
        for (final c in (sug['candidatos'] as List? ?? const []))
          (c as Map).cast<String, dynamic>()
      ];
      List<MapEntry<dynamic, String>> opc;
      Map<dynamic, String> unidades;
      if (cands.isNotEmpty) {
        opc = [
          for (final c in cands)
            MapEntry(
                c['idinsumo'],
                '${c['nombre']} (${cant(c['stockactual'])} ${s(c['unidadmedida'])} disp.)'
                    .trim())
        ];
        unidades = {
          for (final c in cands)
            if (s(c['unidadmedida']).trim().isNotEmpty)
              c['idinsumo']: s(c['unidadmedida']).trim()
        };
      } else {
        final ins = await cargar(context, operacionService.insumosConUnidad);
        if (ins == null || !mounted) return;
        opc = ins.opciones;
        unidades = ins.unidades;
      }
      final d = await showForm(
          context,
          'Insumo usado',
          [
            FieldDef('idinsumo', 'Insumo',
                type: FT.select, required: true, options: opc),
            FieldDef('cantidadusada', 'Cantidad usada',
                type: FT.number,
                required: true,
                min: 0,
                unidadDe: 'idinsumo',
                unidades: unidades),
          ],
          initial: datos,
          okLabel: 'Registrar',
          edit: false);
      if (d == null || !mounted) return;
      datos = d;
    }
    if (await run(
        context,
        () => operacionService.registrarInsumoUsado(widget.idtarea, datos,
            nombre: s(sug['nombre']), unidad: s(sug['unidad'])),
        ok: 'Insumo registrado y descontado del stock')) {
      _recargar();
    }
  }

  void _recargar() {
    if (!mounted) return;
    setState(() {
      _f =
          _load(); // sin devolver el Future: setState no admite callbacks asíncronos
    });
  }

  Future<void> _registrarInsumo() async {
    final ins = await cargar(context, operacionService.insumosConUnidad);
    if (ins == null || !mounted) return;
    if (ins.opciones.isEmpty)
      return snack(context, 'No hay insumos registrados en la finca');
    final d = await showForm(
        context,
        'Registrar insumo usado',
        [
          FieldDef('idinsumo', 'Insumo',
              type: FT.select, required: true, options: ins.opciones),
          FieldDef('cantidadusada', 'Cantidad usada',
              type: FT.number,
              required: true,
              min: 0,
              unidadDe: 'idinsumo',
              unidades: ins.unidades),
        ],
        okLabel: 'Registrar',
        edit: false);
    if (d == null || !mounted) return;
    if (await run(
        context, () => operacionService.registrarInsumoUsado(widget.idtarea, d),
        ok: 'Insumo registrado y descontado del stock')) {
      _recargar();
    }
  }

  Future<void> _horas(Map<String, dynamic> asig) async {
    final d = await showForm(
        context,
        'Tiempo trabajado',
        const [
          FieldDef('horastrabajadas', 'Horas trabajadas',
              type: FT.number,
              min: 0,
              vaciable: true,
              helper:
                  'Si lo dejas vacío se usa el tiempo del cronómetro. Solo sirve para repartir el costo entre las tareas; no cambia lo que se te paga'),
        ],
        initial: asig,
        edit: true);
    if (d == null || !mounted) return;
    if (await run(
        context,
        () => operacionService.actualizarAsignacion(
            (asig['idasigtarea'] as num).toInt(), d),
        ok: 'Tiempo registrado')) {
      _recargar();
    }
  }

  Future<void> _quitarInsumo(Map<String, dynamic> d) async {
    if (!await confirmar(context, 'El registro se eliminará.',
        titulo: '¿Quitar este insumo de la tarea?',
        ok: 'Quitar',
        destructivo: true)) {
      return;
    }
    if (!mounted) return;
    if (await run(
        context,
        () => operacionService
            .eliminarInsumoUsado((d['iddetalletarea'] as num).toInt()),
        ok: 'Registro eliminado')) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Tarea, List<Map<String, dynamic>>)>(
      future: _f,
      builder: (c, snap) {
        final t = snap.data?.$1;
        return Scaffold(
          appBar: AppBar(
            title:
                Text(t == null || t.actividad.isEmpty ? 'Tarea' : t.actividad),
            actions: [
              if (t != null)
                RowMenu(item: t.raw, reload: _recargar, actions: [
                  for (final a in AccionesTarea.para(t))
                    if (a.label != 'Eliminar')
                      a
                    else
                      RowAction(a.label, (ctx, it, _) async {
                        if (await AccionesTarea.eliminar(ctx, t) && ctx.mounted)
                          Navigator.pop(ctx);
                      }, icon: a.icon, destructive: true),
                ]),
            ],
          ),
          body: () {
            if (t == null && snap.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            if (snap.hasError)
              return AgroError(
                  message: Api.errorMsg(snap.error!), onRetry: _recargar);
            final insumos = snap.data!.$2;
            final asig = t!.asignacion;
            final pend = EvidenciaPendiente.de(widget.idtarea);
            final costoInsumos = insumos.fold<double>(0, (a, d) {
              final i = d['idinsumo'];
              return a +
                  n(d['cantidadusada']) * n(i is Map ? i['costounitario'] : 0);
            });
            return RefreshIndicator(
              onRefresh: () async {
                _recargar();
                await _f;
              },
              child: ListView(padding: const EdgeInsets.all(14), children: [
                AgroCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(t.actividad,
                                  style:
                                      AgroText.title.copyWith(fontSize: 17))),
                          if (t.estado.isNotEmpty) StatusBadge(t.estado),
                          if (t.atrasada) ...[
                            const SizedBox(width: 6),
                            const StatusBadge('Atrasada')
                          ],
                        ]),
                        const SizedBox(height: 10),
                        InfoRow('Fecha programada', fecha(t.fechaprogramada)),
                        InfoRow('Cultivo', t.cultivoNombre),
                        InfoRow('Prioridad', t.prioridad),
                        if (n(t.raw['horasestimadas']) > 0)
                          InfoRow('Tiempo estimado',
                              '${cant(t.raw['horasestimadas'])} h'),
                        if (n(t.raw['costototal']) > 0)
                          InfoRow('Costo estimado', money(t.raw['costototal'])),
                        if (t.costoReal > 0)
                          InfoRow('Costo real', money(t.costoReal),
                              strong: true),
                      ]),
                ),
                if (t.enCurso && t.inicioReal != null) ...[
                  const SizedBox(height: 14),
                  AgroCard(
                    color: AgroColors.surfaceGreen,
                    child: Row(children: [
                      const Icon(Icons.timer_outlined,
                          color: AgroColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('En curso', style: AgroText.muted),
                              _Cronometro(t.inicioReal!),
                            ]),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                const AgroSectionHeader('Asignación'),
                const SizedBox(height: 8),
                AgroCard(
                  child: asig == null
                      ? Row(children: [
                          const Expanded(
                              child: Text('Sin asignar todavía',
                                  style: AgroText.muted)),
                          if (esAdmin)
                            FilledButton.icon(
                              onPressed: () async {
                                if (await AccionesTarea.asignar(context, t))
                                  _recargar();
                              },
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Asignar'),
                            ),
                        ])
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Row(children: [
                                AgroAvatar(
                                    url: t.empleadoFoto,
                                    nombre: t.empleadoNombre,
                                    radius: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        t.empleadoNombre.isEmpty
                                            ? (esAdmin ? 'Empleado' : 'Tú')
                                            : t.empleadoNombre,
                                        style: AgroText.title)),
                                if (s(asig['estado']).isNotEmpty)
                                  StatusBadge(s(asig['estado'])),
                              ]),
                              const SizedBox(height: 8),
                              InfoRow('Asignada el',
                                  fecha(asig['fechaasignacion'])),
                              if (t.inicioReal != null)
                                InfoRow('Inicio real',
                                    fecha(t.inicioReal, hora: true)),
                              if (asig['fechafin'] != null &&
                                  t.inicioReal != null)
                                InfoRow(
                                    'Duración',
                                    _duracion(
                                        DateTime.parse('${asig['fechafin']}')
                                            .toLocal()
                                            .difference(t.inicioReal!))),
                              InfoRow('Horas trabajadas',
                                  cant(asig['horastrabajadas'])),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _horas(asig),
                                  icon: const Icon(Icons.timer_outlined),
                                  label: const Text('Registrar tiempo'),
                                ),
                              ),
                            ]),
                ),
                const SizedBox(height: 14),
                AgroSectionHeader(
                  'Evidencia',
                  action: session.esEmpleado ? 'Agregar foto' : null,
                  onAction: session.esEmpleado ? _agregarFoto : null,
                ),
                const SizedBox(height: 8),
                if (_evidencias.isEmpty && pend == null)
                  const AgroEmpty(
                      icon: Icons.photo_library_outlined,
                      message: 'Aún no hay fotos de esta tarea')
                else
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (pend != null) ...[
                          _fotoPendiente(pend),
                          const SizedBox(width: 8),
                        ],
                        for (var i = 0; i < _evidencias.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _fotoSubida(_evidencias[i]),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (!t.completada && _sugeridos.isNotEmpty) ...[
                  const AgroSectionHeader('Sugeridos para esta labor'),
                  const SizedBox(height: 8),
                  for (final sug in _sugeridos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AgroListCard(
                        onTap: () => _usarSugerido(sug, editar: true),
                        leading: const AgroIconTile(icon: Icons.auto_awesome),
                        title: Text(s(sug['nombre']), style: AgroText.title),
                        subtitle: Text(
                          juntar([
                            sug['cantidad'] == null
                                ? 'Indica la cantidad'
                                : 'Sugerido: ${cant(sug['cantidad'])} ${s(sug['unidad'])}${sug['hectareas'] != null ? ' (${cant(sug['hectareas'])} ha)' : ''}'
                                    .trim(),
                            if (sug['stockactual'] != null)
                              'Disponible ${cant(sug['stockactual'])}',
                            if (sug['idinsumo'] == null) 'Elige un insumo',
                          ]),
                          style: AgroText.muted,
                        ),
                        trailing: IconButton(
                          tooltip: 'Confirmar',
                          icon: const Icon(Icons.check_circle_outline,
                              color: AgroColors.primary),
                          onPressed: () => _usarSugerido(sug),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
                AgroSectionHeader('Insumos usados',
                    action: t.completada ? null : 'Registrar',
                    onAction: _registrarInsumo),
                const SizedBox(height: 8),
                if (insumos.isEmpty)
                  const AgroEmpty(
                      icon: Icons.inventory_2_outlined,
                      message: 'No se han registrado insumos en esta tarea')
                else ...[
                  for (final d in insumos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AgroListCard(
                        leading: const AgroIconTile(icon: Icons.inventory_2),
                        title: Text(
                            s(d['idinsumo'] is Map
                                ? d['idinsumo']['nombre']
                                : 'Insumo'),
                            style: AgroText.title),
                        subtitle: Text(
                          '${cant(d['cantidadusada'])} ${s(d['idinsumo'] is Map ? d['idinsumo']['unidadmedida'] : '')}'
                              .trim(),
                          style: AgroText.muted,
                        ),
                        trailing: esAdmin
                            ? IconButton(
                                tooltip: 'Quitar registro',
                                icon: const Icon(Icons.delete_outline,
                                    color: AgroColors.danger),
                                onPressed: () => _quitarInsumo(d),
                              )
                            : null,
                      ),
                    ),
                  if (costoInsumos > 0 && _costos == null)
                    AgroCard(
                        color: AgroColors.surfaceGreen,
                        child: InfoRow('Costo de insumos', money(costoInsumos),
                            strong: true)),
                ],
                if (_costos != null &&
                    (n(_costos!['total']) > 0 ||
                        n(_costos!['estimado']) > 0)) ...[
                  const SizedBox(height: 14),
                  const AgroSectionHeader('Costos'),
                  const SizedBox(height: 8),
                  AgroCard(
                    child: Column(children: [
                      if (n(_costos!['estimado']) > 0)
                        InfoRow('Estimado', money(_costos!['estimado'])),
                      InfoRow('Insumos', money(_costos!['insumos'])),
                      InfoRow('Mano de obra', money(_costos!['manoObra'])),
                      if (n(_costos!['horas']) > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              n(_costos!['costoHora']) > 0
                                  ? '${cant(_costos!['horas'])} h trabajadas × ${money(_costos!['costoHora'])} por hora'
                                  : 'Configura el pago de tus empleados en Equipo para calcular la mano de obra',
                              style: AgroText.muted,
                            ),
                          ),
                        ),
                      if (n(_costos!['transporte']) > 0)
                        InfoRow('Transporte', money(_costos!['transporte'])),
                      InfoRow(t.completada ? 'Costo real' : 'Costo hasta ahora',
                          money(_costos!['total']),
                          strong: true),
                    ]),
                  ),
                ],
                if (!t.completada && (session.esEmpleado || esAdmin)) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      await AccionesTarea.completarConFoto(context, t);
                      if (mounted) _recargar();
                    },
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Completar con foto de evidencia'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await AccionesTarea.completar(context, t))
                        _recargar();
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marcar como completada'),
                  ),
                ],
              ]),
            );
          }(),
        );
      },
    );
  }
}
