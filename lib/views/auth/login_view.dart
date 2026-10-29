import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _sinRed = false;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  @override
  void initState() {
    super.initState();
    _info = session.aviso;
    session.aviso = null;
    _recordarCorreo();
    Api.i.sinRed().then((v) {
      if (mounted) setState(() => _sinRed = v);
    });
    _netSub = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) {
        setState(() => _sinRed = r.every((x) => x == ConnectivityResult.none));
      }
    });
  }

  /// Rellena el último correo con el que se ingresó.
  Future<void> _recordarCorreo() async {
    final p = await SharedPreferences.getInstance();
    final e = p.getString('ultimo_email');
    if (e != null && e.isNotEmpty && _email.text.isEmpty && mounted) {
      _email.text = e;
    }
  }

  @override
  void dispose() {
    _netSub?.cancel();
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
      SharedPreferences.getInstance()
          .then((p) => p.setString('ultimo_email', _email.text.trim()));
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
      final g = GoogleSignIn(
          scopes: const ['email'],
          serverClientId: kIsWeb ? null : _googleId,
          clientId: kIsWeb ? _googleId : null);
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
      final d = await showForm(
          context,
          'Crear cuenta',
          const [
            FieldDef('role', 'Tipo de cuenta',
                type: FT.select,
                required: true,
                options: [
                  MapEntry('admin', 'Dueño de finca'),
                  MapEntry('comprador', 'Comprador (Marketplace)'),
                ]),
            FieldDef('primernombre', 'Nombre', required: true, minLength: 2),
            FieldDef('primerapellido', 'Apellido',
                required: true, minLength: 2),
            FieldDef('email', 'Correo', type: FT.email, required: true),
            FieldDef('telefono', 'Teléfono', type: FT.phone),
            FieldDef('cedula', 'Cédula',
                helper: 'Obligatoria para dueños de finca'),
            FieldDef('contrasena', 'Contraseña',
                type: FT.password, required: true, minLength: 6),
            FieldDef('confirmar', 'Repite la contraseña',
                type: FT.password, required: true, matches: 'contrasena'),
          ],
          initial: previo,
          edit: false,
          okLabel: 'Registrarme');
      if (d == null || !mounted) return;
      if (d['role'] == 'admin' && s(d['cedula']).isEmpty) {
        snack(context, 'La cédula es obligatoria para dueños de finca');
        previo = d;
        continue;
      }
      final ok = await run(context, () => authService.registrar(d),
          ok: 'Cuenta creada. Ya puedes iniciar sesión.');
      if (ok) {
        _email.text = s(d['email']);
        _pass.clear();
        return;
      }
      previo = d;
    }
  }

  Future<void> _olvide() async {
    final d = await showForm(
        context,
        'Recuperar contraseña',
        const [
          FieldDef('email', 'Correo de tu cuenta',
              type: FT.email,
              required: true,
              helper:
                  'Te enviaremos un código de recuperación (válido 30 minutos)'),
        ],
        initial: {'email': _email.text.trim()},
        edit: false,
        okLabel: 'Enviar código');
    if (d == null || !mounted) return;
    if (!await run(context, () => authService.olvideContrasena(s(d['email'])),
        ok: 'Si el correo está registrado, recibirás un código.')) {
      return;
    }
    if (!mounted) return;
    final r = await showForm(
        context,
        'Nueva contraseña',
        const [
          FieldDef('token', 'Código recibido por correo',
              required: true,
              helper:
                  'Es el texto que aparece al final del enlace: …?token=ESTE_CÓDIGO'),
          FieldDef('nuevaContrasena', 'Nueva contraseña',
              type: FT.password, required: true, minLength: 6),
          FieldDef('confirmar', 'Repite la contraseña',
              type: FT.password, required: true, matches: 'nuevaContrasena'),
        ],
        okLabel: 'Cambiar contraseña');
    if (r == null || !mounted) return;
    await run(context, () => authService.resetContrasena(r),
        ok: 'Contraseña actualizada. Ya puedes ingresar.');
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
                  hintText: 'http://192.168.1.15:3000'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Celular por USB + adb reverse: http://127.0.0.1:3000\n'
              'Emulador Android: http://10.0.2.2:3000\n'
              'Celular por Wi-Fi: http://IP-de-tu-PC:3000',
              style: AgroText.muted,
            ),
            if (estado != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(estado!, style: AgroText.title)),
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
          Icon(error ? Icons.error_outline : Icons.info_outline,
              size: 18, color: error ? AgroColors.danger : AgroColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t,
                style: TextStyle(
                    color:
                        error ? AgroColors.dangerText : AgroColors.warningText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final backgroundWidth = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight * 0.475,
                  );
                  return Align(
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(
                      child: Image.asset(
                        'assets/images/login_botanical_background.png',
                        width: backgroundWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.fill,
                      ),
                    ),
                  );
                },
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.asset(
                                    'assets/agrosmart_logo.png',
                                    width: 44,
                                    height: 44,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AgroSmart',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AgroColors.primary,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        'GESTIÓN INTELIGENTE DEL CAMPO',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: AgroColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AgroColors.grayBase,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: AgroColors.slateBorder,
                                    ),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Configurar servidor',
                                    onPressed: _servidor,
                                    icon: const Icon(
                                      Icons.tune_rounded,
                                      color: AgroColors.textMuted,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.spa_outlined,
                                  size: 20,
                                  color: AgroColors.primaryLight,
                                ),
                                SizedBox(width: 9),
                                Text(
                                  'HECHO PARA EL CAMPO',
                                  style: TextStyle(
                                    fontFamily: kAgroFont,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: AgroColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            const Text(
                              'Qué bueno verte',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AgroColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Inicia sesión para continuar.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AgroColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (_sinRed)
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: AgroColors.warningSoft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AgroColors.warningBorder,
                                  ),
                                ),
                                child: const Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.wifi_off,
                                          size: 18,
                                          color: AgroColors.warningText),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'El celular no detecta Wi-Fi ni datos. Se intentará conectar al servidor configurado; sin servidor, solo pueden entrar cuentas que ya iniciaron sesión aquí.',
                                          style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: AgroColors.warningText),
                                        ),
                                      ),
                                    ]),
                              ),
                            if (_info != null) _mensaje(_info!, error: false),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.email,
                                AutofillHints.username
                              ],
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return 'Ingresa tu correo';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(t)) {
                                  return 'Correo no válido';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: Icon(
                                  Icons.mail_outline_rounded,
                                  color: AgroColors.primaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(height: 13),
                            TextFormField(
                              controller: _pass,
                              obscureText: _hide,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _go(),
                              validator: (v) => (v ?? '').isEmpty
                                  ? 'Ingresa tu contraseña'
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AgroColors.primaryLight,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: _hide
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                  icon: Icon(
                                    _hide
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AgroColors.textMuted,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _hide = !_hide),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                  onPressed: _olvide,
                                  child: const Text('¿Olvidaste tu contraseña?',
                                      style: TextStyle(fontSize: 13))),
                            ),
                            if (_error != null) _mensaje(_error!, error: true),
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                onPressed: _loading ? null : _go,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('Ingresar'),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 18),
                                        ],
                                      ),
                              ),
                            ),
                            if (_googleId.isNotEmpty) ...[
                              const SizedBox(height: 17),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'O TAMBIÉN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: AgroColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AgroColors.textDark,
                                    side: const BorderSide(
                                      color: AgroColors.slateBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _loading ? null : _google,
                                  icon: const Text('G',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AgroColors.primary)),
                                  label: const Text('Continuar con Google'),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('¿No tienes cuenta?',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AgroColors.textMuted)),
                                  TextButton(
                                      onPressed: _registro,
                                      child: const Text('Regístrate')),
                                ]),
                            if (kDebugMode) ...[
                              const SizedBox(height: 8),
                              Text('Servidor: ${Api.i.baseUrl}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AgroColors.textMuted)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
