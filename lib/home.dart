import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'mas.dart';
import 'mercado.dart';
import 'operacion.dart';
import 'produccion.dart';
import 'ui.dart';

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
          : ListView(padding: const EdgeInsets.all(12), children: [
              if (session.fincas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Aún no perteneces a ninguna finca.\nCrea una para empezar.', textAlign: TextAlign.center)),
                ),
              for (final f in session.fincas)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.agriculture)),
                    title: Text('${f['nombre']}'),
                    subtitle: Text('${f['ubicacion'] ?? ''} · ${f['rol']} · plan ${f['plan']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pick(f['idfinca'] as int),
                  ),
                ),
            ]),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final Widget page;
  _Tab(this.label, this.icon, this.page);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    // El comprador del Marketplace solo ve Mercado, Avisos y Perfil (RNF-20 del backend).
    final tabs = session.esComprador
        ? <_Tab>[
            _Tab('Mercado', Icons.storefront, const MercadoPage()),
            _Tab('Avisos', Icons.notifications, const NotificacionesList()),
            _Tab('Perfil', Icons.person, const PerfilPage()),
          ]
        : <_Tab>[
            _Tab('Inicio', Icons.dashboard, const InicioPage()),
            _Tab('Producción', Icons.grass, const ProduccionPage()),
            _Tab('Operación', Icons.task_alt, const OperacionPage()),
            _Tab('Mercado', Icons.storefront, const MercadoPage()),
            _Tab('Más', Icons.menu, const MasPage()),
          ];
    if (_i >= tabs.length) _i = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_i].label),
        actions: [
          if (session.esComprador) IconButton(tooltip: 'Salir', icon: const Icon(Icons.logout), onPressed: session.logout),
        ],
      ),
      body: IndexedStack(index: _i, children: [for (final t in tabs) t.page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label)],
      ),
    );
  }
}
