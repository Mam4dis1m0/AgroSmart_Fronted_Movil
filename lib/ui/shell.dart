import 'package:flutter/material.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/views/inicio/inicio_view.dart';
import 'package:agrosmart_proto/views/mercado/mercado_view.dart';
import 'package:agrosmart_proto/views/operacion/operacion_view.dart';
import 'package:agrosmart_proto/views/perfil/mas_view.dart';
import 'package:agrosmart_proto/views/produccion/produccion_view.dart';

class _Tab {
  final String label;
  final IconData icon;
  final Widget page;
  _Tab(this.label, this.icon, this.page);
}

/// Contenedor principal de la app una vez hay sesión + finca: header, drawer y
/// navegación inferior (Inicio · Cultivos · Tareas · Mercado · Perfil).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic> _fincaActiva() {
    for (final f in session.fincas) {
      if (f['idfinca'] == session.idfinca) return f;
    }
    return const {};
  }

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
            _Tab('Inicio', Icons.home_rounded, const InicioPage()),
            _Tab('Cultivos', Icons.grass, const ProduccionPage()),
            _Tab('Tareas', Icons.checklist_rtl, const OperacionPage()),
            _Tab('Mercado', Icons.storefront, const MercadoPage()),
            _Tab('Perfil', Icons.person, const MasPage()),
          ];
    if (_i >= tabs.length) _i = 0;

    final finca = _fincaActiva();
    final titulo = session.esComprador
        ? (session.nombre.isEmpty ? 'AgroSmart' : session.nombre)
        : (finca['nombre']?.toString() ?? 'Mi finca');
    final ubicacion = finca['ubicacion']?.toString();
    final subtitulo = session.esComprador
        ? 'Marketplace'
        : (ubicacion == null || ubicacion.isEmpty ? '${session.rol} · plan ${finca['plan'] ?? '—'}' : ubicacion);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AgroColors.surfaceGreen,
      drawer: const _AgroDrawer(),
      body: Column(children: [
        ValueListenableBuilder<bool>(
          valueListenable: Api.i.offline,
          builder: (_, off, __) => AgroHeader(
            title: titulo,
            subtitle: subtitulo,
            offline: off,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onToggleStatus: () => Api.i.ping(),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: Api.i.offline,
          builder: (_, off, __) => OfflineBanner(
            offline: off,
            onSync: () async {
              final ok = await Api.i.ping();
              if (!ok) Api.i.offline.value = true;
            },
          ),
        ),
        Expanded(child: IndexedStack(index: _i, children: [for (final t in tabs) t.page])),
      ]),
      bottomNavigationBar: AgroBottomNav(
        index: _i,
        onTap: (v) => setState(() => _i = v),
        items: [for (final t in tabs) AgroNavItem(t.label, t.icon)],
      ),
    );
  }
}

/// Cajón lateral (drawer) con identidad de usuario, cambio de finca y cierre de sesión.
class _AgroDrawer extends StatelessWidget {
  const _AgroDrawer();

  @override
  Widget build(BuildContext context) {
    final usuario = session.usuario ?? const {};
    final finca = session.fincas.firstWhere(
      (f) => f['idfinca'] == session.idfinca,
      orElse: () => const <String, dynamic>{},
    );
    return Drawer(
      backgroundColor: AgroColors.surfaceGreen,
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            color: AgroColors.forest,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AgroColors.primaryLight,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                '${usuario['nombre'] ?? ''} ${usuario['apellido'] ?? ''}'.trim().isEmpty
                    ? 'Usuario AgroSmart'
                    : '${usuario['nombre'] ?? ''} ${usuario['apellido'] ?? ''}'.trim(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text('${usuario['email'] ?? ''}', style: const TextStyle(color: Color(0xFFA3E5BC), fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                StatusBadge(session.rol),
                if (finca.isNotEmpty) CropBadge(finca['nombre']?.toString() ?? '', showIcon: false),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          if (session.fincas.length > 1)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Cambiar de finca'),
              onTap: () {
                Navigator.of(context).pop();
                session.cambiarFinca();
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              Navigator.of(context).pop();
              session.logout();
            },
          ),
        ]),
      ),
    );
  }
}
