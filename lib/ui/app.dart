import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/services/mensajeria_service.dart';
import 'package:agrosmart_proto/services/socket_service.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/views/auth/login_view.dart';
import 'package:agrosmart_proto/views/finca/finca_picker_view.dart';
import 'shell.dart';

/// Raíz de la app: tema + idioma + enrutado por estado de sesión.
class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroSmart',
      debugShowCheckedModeBanner: false,
      theme: buildAgroTheme(),
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  @override
  void initState() {
    super.initState();
    // Sin internet: vigila la red, guarda teléfonos para SMS y sube lo pendiente al volver.
    Api.i.iniciarMonitor();
    MensajeriaService.guardarTelefono = smsService.guardarTelefono;
    Api.i.alVolverRed.add(() async {
      await smsService.flushPendientes();
      if (session.esComprador || esAdmin) await mensajeriaService.precargar();
    });
    session.addListener(_alCambiarSesion);
    session.restore();
  }

  void _alCambiarSesion() {
    socketService.sync();
    if (session.logged) {
      Api.i.cola.cargar(Api.i.cacheScope);
      smsService.iniciar(); // escucha SMS entrantes si el permiso ya fue concedido
      Api.i.sincronizar();
      // Con internet, deja los chats listos para verlos después sin conexión.
      if (session.esComprador || esAdmin) mensajeriaService.precargar();
    }
  }

  @override
  void dispose() {
    session.removeListener(_alCambiarSesion);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (_, __) {
        if (!session.ready) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!session.logged) return const LoginScreen();
        if (session.necesitaFinca) return const FincaPickerScreen();
        // La key fuerza a reconstruir las pestañas al cambiar de finca o de rol.
        return HomeShell(key: ValueKey('${session.usuario?['id']}_${session.idfinca}_${session.rol}'));
      },
    );
  }
}
