import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/avisos/avisos_view.dart';
import 'package:agrosmart_proto/views/equipo/equipo_view.dart';
import 'package:agrosmart_proto/views/inicio/inicio_view.dart';
import 'package:agrosmart_proto/views/mas/mas_view.dart';
import 'package:agrosmart_proto/views/mensajes/bandeja_view.dart';
import 'package:agrosmart_proto/views/mercado/mercado_view.dart';
import 'package:agrosmart_proto/views/operacion/operacion_view.dart';
import 'package:agrosmart_proto/views/perfil/perfil_view.dart';
import 'package:agrosmart_proto/views/produccion/produccion_view.dart';

/// Pestañas de la navegación inferior.
enum ShellTab { inicio, cultivos, tareas, mercado, equipo, avisos, mas }

class _Tab {
  final ShellTab id;
  final String label;
  final IconData icon;
  final Widget Function(int sub) page;
  final ValueNotifier<int>? badge;
  final bool prominent;
  _Tab(this.id, this.label, this.icon, this.page,
      {this.badge, this.prominent = false});
}

/// Contenedor principal de la app una vez hay sesión + finca: header, drawer y
/// navegación inferior según el rol.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Cambia de pestaña desde cualquier pantalla dentro del shell.
  static void irA(BuildContext c, ShellTab tab, {int sub = 0}) =>
      c.findAncestorStateOfType<_HomeShellState>()?._irA(tab, sub);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _i = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _sub = <ShellTab, int>{};
  Timer? _poll;
  late final List<_Tab> _tabs = _crearTabs();

  List<_Tab> _crearTabs() {
    if (session.esComprador) {
      // El comprador del Marketplace solo ve Mercado, Avisos y su Perfil (RNF-20 del backend).
      return [
        _Tab(ShellTab.mercado, 'Mercado', Icons.storefront,
            (s) => MercadoPage(initialIndex: s),
            badge: contadores.mensajes),
        _Tab(ShellTab.avisos, 'Avisos', Icons.notifications,
            (_) => const AvisosPage(),
            badge: contadores.avisos),
        _Tab(ShellTab.mas, 'Perfil', Icons.person, (_) => const PerfilPage()),
      ];
    }
    return [
      _Tab(ShellTab.inicio, 'Inicio', Icons.home_rounded,
          (_) => const InicioPage()),
      _Tab(ShellTab.cultivos, 'Cultivos', Icons.grass,
          (s) => ProduccionPage(initialIndex: s)),
      if (esAdmin)
        _Tab(ShellTab.mercado, 'Mercado', Icons.storefront,
            (s) => MercadoPage(initialIndex: s),
            badge: contadores.mensajes, prominent: true),
      _Tab(ShellTab.tareas, 'Tareas', Icons.checklist_rtl,
          (s) => OperacionPage(initialIndex: s)),
      if (esAdmin)
        _Tab(ShellTab.equipo, 'Equipo', Icons.groups_outlined,
            (_) => const EquipoPage()),
    ];
  }

  /// Insignia del menú: avisos + mensajes sin leer.
  final ValueNotifier<int> _badgeMas = ValueNotifier(0);

  void _sumarMas() => _badgeMas.value =
      contadores.avisos.value + (esAdmin ? contadores.mensajes.value : 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    contadores.avisos.addListener(_sumarMas);
    contadores.mensajes.addListener(_sumarMas);
    contadores.refrescar();
    _poll = Timer.periodic(
        const Duration(seconds: 60), (_) => contadores.refrescar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    contadores.avisos.removeListener(_sumarMas);
    contadores.mensajes.removeListener(_sumarMas);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      contadores.refrescar();
      Api.i.sincronizar(); // envía los cambios hechos sin internet
    }
  }

  void _irA(ShellTab tab, int sub) {
    final i = _tabs.indexWhere((t) => t.id == tab);
    if (i < 0) return;
    setState(() {
      _i = i;
      _sub[tab] = sub;
    });
  }

  Future<void> _probarConexion() async {
    final m = ScaffoldMessenger.of(context);
    final ok = await Api.i.ping();
    if (!ok) Api.i.offline.value = true;
    m.showSnackBar(SnackBar(
        content: Text(ok
            ? 'Conectado con el servidor'
            : 'Sin conexión con el servidor')));
  }

  @override
  Widget build(BuildContext context) {
    final finca = session.fincaActiva;
    final titulo = session.esComprador
        ? (session.nombre.isEmpty ? 'AgroSmart' : 'Hola, ${session.nombre}')
        : (finca['nombre']?.toString() ?? 'Mi finca');
    final ubicacion = s(finca['ubicacion']);
    final subtitulo = session.esComprador
        ? 'Marketplace AgroSmart'
        : (ubicacion.isNotEmpty ? ubicacion : null);
    final puedeChatear = session.esComprador || esAdmin;

    return PopScope(
      // Atrás en otra pestaña vuelve a la primera antes de salir de la app.
      canPop: _i == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _i != 0) setState(() => _i = 0);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawer: const _AgroDrawer(),
        body: Column(children: [
          ValueListenableBuilder<bool>(
            valueListenable: Api.i.offline,
            builder: (_, off, __) => Column(children: [
              AgroHeader(
                title: titulo,
                subtitle: subtitulo,
                offline: off,
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                menuBadge: _badgeMas,
                onStatus: _probarConexion,
                actions: [
                  if (puedeChatear)
                    ValueListenableBuilder<int>(
                      valueListenable: contadores.mensajes,
                      builder: (_, nMsj, __) => IconButton(
                        tooltip: 'Mensajes',
                        onPressed: () => abrirBandeja(context),
                        icon: Badge(
                          isLabelVisible: nMsj > 0,
                          backgroundColor: AgroColors.amber,
                          textColor: AgroColors.forestDeep,
                          label: Text('$nMsj'),
                          child: const Icon(Icons.chat_bubble_outline,
                              color: AgroColors.mintPale),
                        ),
                      ),
                    ),
                ],
              ),
              OfflineBanner(offline: off, onRetry: _probarConexion),
              ValueListenableBuilder<int>(
                valueListenable: Api.i.cola.pendientes,
                builder: (_, n, __) => n == 0
                    ? const SizedBox.shrink()
                    : Container(
                        width: double.infinity,
                        color: AgroColors.warningBg,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Text(
                            '$n cambio${n == 1 ? '' : 's'} pendiente${n == 1 ? '' : 's'} de enviar. Se enviará${n == 1 ? '' : 'n'} al volver el internet.',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AgroColors.warningText)),
                      ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: Api.i.cola.rechazadas,
                builder: (_, n, __) => n == 0
                    ? const SizedBox.shrink()
                    : InkWell(
                        onTap: () => Api.i.cola.rechazadas.value = 0,
                        child: Container(
                          width: double.infinity,
                          color: AgroColors.warningBg,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Text(
                              '$n cambio${n == 1 ? '' : 's'} hecho${n == 1 ? '' : 's'} sin internet no se pudo guardar. Toca para cerrar.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AgroColors.warningText)),
                        ),
                      ),
              ),
            ]),
          ),
          Expanded(
            child: IndexedStack(index: _i, children: [
              for (final t in _tabs)
                KeyedSubtree(
                    key: ValueKey('${t.id}_${_sub[t.id] ?? 0}'),
                    child: t.page(_sub[t.id] ?? 0)),
            ]),
          ),
        ]),
        bottomNavigationBar: ListenableBuilder(
          listenable: Listenable.merge([
            for (final t in _tabs)
              if (t.badge != null) t.badge!
          ]),
          builder: (_, __) => AgroBottomNav(
            index: _i,
            onTap: (v) {
              setState(() => _i = v);
              contadores.refrescar();
            },
            items: [
              for (final t in _tabs)
                AgroNavItem(t.label, t.icon,
                    badge: t.badge?.value, prominent: t.prominent)
            ],
          ),
        ),
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
    final finca = session.fincaActiva;
    final nombre = session.nombreCompleto;
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AgroColors.forest, AgroColors.heroMid, AgroColors.heroEnd],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 20, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AgroAvatar(url: session.foto, nombre: nombre, radius: 28),
            const SizedBox(height: 12),
            Text(
              nombre.isEmpty ? 'Usuario AgroSmart' : nombre,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(s(usuario['email']),
                style:
                    const TextStyle(color: AgroColors.mintPale, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              StatusBadge(session.rol),
              if (s(finca['plan']).isNotEmpty) StatusBadge(s(finca['plan'])),
            ]),
            if (finca.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.agriculture,
                    size: 16, color: AgroColors.mintPale),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(s(finca['nombre']),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))),
              ]),
            ],
          ]),
        ),
        const Expanded(child: MasPage()),
      ]),
    );
  }
}

/// Confirma y cierra la sesión.
Future<void> cerrarSesion(BuildContext c) async {
  if (!await confirmar(
      c, 'Tendrás que volver a ingresar tu correo y contraseña.',
      titulo: '¿Cerrar sesión?', ok: 'Cerrar sesión')) {
    return;
  }
  contadores.limpiar();
  await session.logout();
}
