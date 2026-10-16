import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/shell.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// CU-36 · Selector de finca (y CU-35 · crear finca si aún no tiene).
class FincaPickerScreen extends StatefulWidget {
  const FincaPickerScreen({super.key});
  @override
  State<FincaPickerScreen> createState() => _FincaPickerScreenState();
}

class _FincaPickerScreenState extends State<FincaPickerScreen> {
  bool _busy = false;

  Future<void> _pick(int id) async {
    setState(() => _busy = true);
    await run(context, () => session.seleccionarFinca(id));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _crear() async {
    final d = await showForm(context, 'Registrar finca', const [
      FieldDef('nombre', 'Nombre de la finca', required: true, minLength: 2),
      FieldDef('ubicacion', 'Ubicación (municipio, departamento)'),
      FieldDef('tipoproduccion', 'Tipo de producción (café, palma, mixta…)'),
    ], okLabel: 'Crear finca');
    if (d == null || !mounted) return;
    setState(() => _busy = true);
    await run(context, () => session.crearFinca(d), ok: 'Finca creada');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    // Puede crear fincas quien ya administra alguna o quien se registró como dueño.
    final puedeCrear = session.rol == 'admin' || session.fincas.any((f) => f['rol'] == 'admin');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && session.puedeVolverAFinca) session.volverAFinca();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: session.puedeVolverAFinca
              ? IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back), onPressed: session.volverAFinca)
              : null,
          automaticallyImplyLeading: false,
          title: const Text('Elige tu finca'),
          actions: [IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: () => cerrarSesion(context))],
          bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
        ),
        floatingActionButton: puedeCrear
            ? FloatingActionButton.extended(onPressed: _busy ? null : _crear, icon: const Icon(Icons.add), label: const Text('Nueva finca'))
            : null,
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(padding: const EdgeInsets.all(14), children: [
            if (session.fincas.isEmpty)
              AgroEmpty(
                icon: Icons.agriculture,
                message: puedeCrear
                    ? 'Aún no tienes fincas.\nCrea la primera para empezar.'
                    : 'Aún no perteneces a ninguna finca.\nPide al administrador que te registre.',
              ),
            for (final f in session.fincas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AgroListCard(
                  leading: const AgroIconTile(icon: Icons.agriculture),
                  title: Text(s(f['nombre']), style: AgroText.title),
                  subtitle: s(f['ubicacion']).isEmpty ? null : Text(s(f['ubicacion']), style: AgroText.muted),
                  badges: Wrap(spacing: 6, runSpacing: 6, children: [
                    if (s(f['rol']).isNotEmpty) StatusBadge(s(f['rol'])),
                    if (s(f['plan']).isNotEmpty) StatusBadge(s(f['plan'])),
                  ]),
                  trailing: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right, color: AgroColors.textMuted)),
                  onTap: () => _pick((f['idfinca'] as num).toInt()),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
