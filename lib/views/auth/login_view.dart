import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  bool _hide = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _info = session.aviso;
    session.aviso = null;
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await session.login(_email.text.trim(), _pass.text);
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) setState(() => _error = Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Client ID *web* de Google Cloud: flutter run --dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const _googleId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  Future<void> _google() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final g = GoogleSignIn(scopes: const ['email'], serverClientId: kIsWeb ? null : _googleId, clientId: kIsWeb ? _googleId : null);
      final acc = await g.signIn();
      if (acc == null) return; // canceló
      final auth = await acc.authentication;
      final t = auth.idToken;
      if (t == null) throw 'Google no devolvió credencial';
      await session.loginGoogle(t);
    } catch (e) {
      if (mounted) setState(() => _error = Api.errorMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registro() async {
    Map<String, dynamic>? previo;
    while (true) {
      if (!mounted) return;
      final d = await showForm(context, 'Crear cuenta', const [
        FieldDef('role', 'Tipo de cuenta', type: FT.select, required: true, options: [
          MapEntry('admin', 'Dueño de finca'),
          MapEntry('comprador', 'Comprador (Marketplace)'),
        ]),
        FieldDef('primernombre', 'Nombre', required: true, minLength: 2),
        FieldDef('primerapellido', 'Apellido', required: true, minLength: 2),
        FieldDef('email', 'Correo', type: FT.email, required: true),
        FieldDef('telefono', 'Teléfono', type: FT.phone),
        FieldDef('cedula', 'Cédula', helper: 'Obligatoria para dueños de finca'),
        FieldDef('contrasena', 'Contraseña', type: FT.password, required: true, minLength: 6),
        FieldDef('confirmar', 'Repite la contraseña', type: FT.password, required: true, matches: 'contrasena'),
      ], initial: previo, edit: false, okLabel: 'Registrarme');
      if (d == null || !mounted) return;
      if (d['role'] == 'admin' && s(d['cedula']).isEmpty) {
        snack(context, 'La cédula es obligatoria para dueños de finca');
        previo = d;
        continue;
      }
      final ok = await run(context, () => authService.registrar(d), ok: 'Cuenta creada. Ya puedes iniciar sesión.');
      if (ok) {
        _email.text = s(d['email']);
        _pass.clear();
        return;
      }
      previo = d;
    }
  }

  Future<void> _olvide() async {
    final d = await showForm(context, 'Recuperar contraseña', const [
      FieldDef('email', 'Correo de tu cuenta', type: FT.email, required: true,
          helper: 'Te enviaremos un código de recuperación (válido 30 minutos)'),
    ], initial: {'email': _email.text.trim()}, edit: false, okLabel: 'Enviar código');
    if (d == null || !mounted) return;
    if (!await run(context, () => authService.olvideContrasena(s(d['email'])), ok: 'Si el correo está registrado, recibirás un código.')) return;
    if (!mounted) return;
    final r = await showForm(context, 'Nueva contraseña', const [
      FieldDef('token', 'Código recibido por correo', required: true,
          helper: 'Es el texto que aparece al final del enlace: …?token=ESTE_CÓDIGO'),
      FieldDef('nuevaContrasena', 'Nueva contraseña', type: FT.password, required: true, minLength: 6),
      FieldDef('confirmar', 'Repite la contraseña', type: FT.password, required: true, matches: 'nuevaContrasena'),
    ], okLabel: 'Cambiar contraseña');
    if (r == null || !mounted) return;
    await run(context, () => authService.resetContrasena(r), ok: 'Contraseña actualizada. Ya puedes ingresar.');
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
              decoration: const InputDecoration(labelText: 'URL del backend', hintText: 'http://192.168.1.15:3000'),
            ),
            const SizedBox(height: 8),
            const Text('Emulador Android: http://10.0.2.2:3000\nCelular físico: http://IP-de-tu-PC:3000', style: AgroText.muted),
            if (estado != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(estado!, style: AgroText.title)),
          ]),
          actions: [
            TextButton(
              onPressed: () async {
                await Api.i.setBaseUrl(c.text);
                setD(() => estado = 'Probando…');
                final ok = await Api.i.ping();
                setD(() => estado = ok ? 'Conectado' : 'No responde');
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
    c.dispose();
    if (mounted) setState(() {});
  }

  Widget _mensaje(String t, {required bool error}) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: error ? AgroColors.dangerBg : AgroColors.warningBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(error ? Icons.error_outline : Icons.info_outline, size: 18, color: error ? AgroColors.danger : AgroColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: TextStyle(color: error ? AgroColors.dangerText : AgroColors.warningText, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Icon(Icons.eco, size: 28, color: AgroColors.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('AgroSmart',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AgroColors.primary, letterSpacing: -0.3)),
                          ),
                          IconButton(
                            tooltip: 'Configurar servidor',
                            onPressed: _servidor,
                            icon: const Icon(Icons.settings_ethernet, color: AgroColors.textMuted),
                          ),
                        ]),
                        const SizedBox(height: 28),
                        const Text('¡Bienvenido!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
                        const SizedBox(height: 4),
                        const Text('Ingresa para gestionar tu finca o comprar en el Marketplace.',
                            style: TextStyle(fontSize: 14, color: AgroColors.textMuted)),
                        const SizedBox(height: 24),
                        if (_info != null) _mensaje(_info!, error: false),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email, AutofillHints.username],
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresa tu correo' : null,
                          decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass,
                          obscureText: _hide,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _go(),
                          validator: (v) => (v ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hide ? 'Mostrar contraseña' : 'Ocultar contraseña',
                              icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _olvide, child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 13))),
                        ),
                        if (_error != null) _mensaje(_error!, error: true),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _loading ? null : _go,
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Ingresar'),
                          ),
                        ),
                        if (_googleId.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _google,
                              icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              label: const Text('Continuar con Google'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('¿No tienes cuenta?', style: TextStyle(fontSize: 14, color: AgroColors.textMuted)),
                          TextButton(onPressed: _registro, child: const Text('Regístrate')),
                        ]),
                        if (kDebugMode) ...[
                          const SizedBox(height: 12),
                          Text('Servidor: ${Api.i.baseUrl}',
                              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AgroColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
