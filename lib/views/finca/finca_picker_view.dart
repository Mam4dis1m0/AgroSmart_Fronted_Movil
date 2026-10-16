import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
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
      FieldDef('nombre', 'Nombre de la finca', required: true),
      FieldDef('ubicacion', 'Ubicación'),
      FieldDef('tipoproduccion', 'Tipo de producción (café, palma, mixta…)'),
    ], okLabel: 'Crear');
    if (d == null || !mounted) return;
    setState(() => _busy = true);
    await run(context, () => session.crearFinca(d));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige tu finca'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: session.logout)],
      ),
      floatingActionButton: session.rol == 'admin'
          ? FloatingActionButton.extended(onPressed: _crear, icon: const Icon(Icons.add), label: const Text('Nueva finca'))
          : null,
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              if (session.fincas.isEmpty)
                const AgroEmpty(icon: Icons.agriculture, message: 'Aún no perteneces a ninguna finca.\nCrea una para empezar.'),
              for (final f in session.fincas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AgroListCard(
                    leading: const AgroIconTile(icon: Icons.agriculture),
                    title: Text('${f['nombre']}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
                    subtitle: Text('${f['ubicacion'] ?? ''} · ${f['rol']} · plan ${f['plan']}',
                        style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, color: AgroColors.textMuted),
                    onTap: () => _pick(f['idfinca'] as int),
                  ),
                ),
            ]),
    );
  }
}
