import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/views/auth/login_view.dart';
import 'package:agrosmart_proto/views/finca/finca_picker_view.dart';
import 'shell.dart';

/// Raíz de la app: tema + enrutado por estado de sesión.
class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroSmart',
      debugShowCheckedModeBanner: false,
      theme: buildAgroTheme(),
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
    session.restore();
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
        return const HomeShell();
      },
    );
  }
}
