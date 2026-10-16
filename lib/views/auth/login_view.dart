import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _hide = true;
  String? _error;

  Future<void> _go() async {
    setState(() { _loading = true; _error = null; });
    try {
      await session.login(_email.text.trim(), _pass.text);
    } catch (e) {
      setState(() => _error = Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Client ID *web* de Google Cloud: flutter run --dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const _googleId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  Future<void> _google() async {
    setState(() { _loading = true; _error = null; });
    try {
      final g = GoogleSignIn(scopes: const ['email'], serverClientId: _googleId);
      final acc = await g.signIn();
      if (acc == null) return; // canceló
      final auth = await acc.authentication;
      final t = auth.idToken;
      if (t == null) throw 'Google no devolvió credencial';
      await session.loginGoogle(t);
    } catch (e) {
      setState(() => _error = Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registro() async {
    final d = await showForm(context, 'Crear cuenta', [
      const FieldDef('primernombre', 'Nombre', required: true),
      const FieldDef('primerapellido', 'Apellido', required: true),
      const FieldDef('email', 'Correo', type: FT.email, required: true),
      const FieldDef('contrasena', 'Contraseña (mín. 6)', type: FT.password, required: true),
      const FieldDef('telefono', 'Teléfono'),
      const FieldDef('cedula', 'Cédula (obligatoria para dueños de finca)'),
      FieldDef('role', 'Tipo de cuenta', type: FT.select, required: true, options: [
        MapEntry('admin', 'Dueño de finca'),
        MapEntry('comprador', 'Comprador (Marketplace)'),
      ]),
    ], okLabel: 'Registrarme');
    if (d == null || !mounted) return;
    final ok = await run(context, () => authService.registrar(d), ok: 'Cuenta creada. Ya puedes iniciar sesión.');
    if (ok) _email.text = s(d['email']);
  }

  Future<void> _olvide() async {
    final d = await showForm(context, 'Recuperar contraseña', const [
      FieldDef('email', 'Correo de tu cuenta', type: FT.email, required: true),
    ], okLabel: 'Enviar enlace');
    if (d == null || !mounted) return;
    if (!await run(context, () => authService.olvideContrasena(s(d['email'])), ok: 'Si el correo existe, recibirás un token.')) return;
    if (!mounted) return;
    final r = await showForm(context, 'Nueva contraseña', const [
      FieldDef('token', 'Token recibido por correo', required: true),
      FieldDef('nuevaContrasena', 'Nueva contraseña (mín. 6)', type: FT.password, required: true),
    ], okLabel: 'Cambiar');
    if (r == null || !mounted) return;
    await run(context, () => authService.resetContrasena(r), ok: 'Contraseña actualizada');
  }

  Future<void> _servidor() async {
    final c = TextEditingController(text: Api.i.baseUrl);
    String? estado;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Servidor'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL del backend',
                hintText: 'http://192.168.1.15:3000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Emulador Android: http://10.0.2.2:3000\nCelular físico: http://IP-de-tu-PC:3000',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (estado != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(estado!)),
          ]),
          actions: [
            TextButton(
              onPressed: () async {
                await Api.i.setBaseUrl(c.text);
                setD(() => estado = 'Probando...');
                final ok = await Api.i.ping();
                setD(() => estado = ok ? '✅ Conectado' : '❌ No responde');
              },
              child: const Text('Probar'),
            ),
            FilledButton(
              onPressed: () async {
                await Api.i.setBaseUrl(c.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(children: [
                        Icon(Icons.eco, size: 28, color: AgroColors.primary),
                        SizedBox(width: 8),
                        Text('AgroSmart',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AgroColors.primary,
                                letterSpacing: -0.3)),
                      ]),
                      TextButton.icon(
                        onPressed: _servidor,
                        icon: const Icon(Icons.dns_outlined, size: 16),
                        label: const Text('Servidor', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text('¡Bienvenido de nuevo!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
                  const SizedBox(height: 4),
                  const Text('Ingresa tus credenciales para acceder a la app.',
                      style: TextStyle(fontSize: 13, color: AgroColors.textMuted)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    onSubmitted: (_) => _go(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _olvide,
                      child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
                          textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _go,
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Ingresar a AgroSmart'),
                    ),
                  ),
                  if (_googleId.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _google,
                        icon: const Icon(Icons.g_mobiledata, size: 26),
                        label: const Text('Continuar con Google'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('¿Sin cuenta? ', style: TextStyle(fontSize: 13, color: AgroColors.textMuted)),
                    GestureDetector(
                      onTap: _registro,
                      child: const Text('Regístrate',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AgroColors.primary,
                              decoration: TextDecoration.underline)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text('Conectando a: ${Api.i.baseUrl}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AgroColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
