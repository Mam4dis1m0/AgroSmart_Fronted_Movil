import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'ui.dart';

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
    final ok = await run(context, () => Api.i.dio.post('/usuarios/register', data: d), ok: 'Cuenta creada. Ya puedes iniciar sesión.');
    if (ok) _email.text = s(d['email']);
  }

  Future<void> _olvide() async {
    final d = await showForm(context, 'Recuperar contraseña', const [
      FieldDef('email', 'Correo de tu cuenta', type: FT.email, required: true),
    ], okLabel: 'Enviar enlace');
    if (d == null || !mounted) return;
    if (!await run(context, () => Api.i.dio.post('/usuarios/forgot-password', data: d), ok: 'Si el correo existe, recibirás un token.')) return;
    if (!mounted) return;
    final r = await showForm(context, 'Nueva contraseña', const [
      FieldDef('token', 'Token recibido por correo', required: true),
      FieldDef('nuevaContrasena', 'Nueva contraseña (mín. 6)', type: FT.password, required: true),
    ], okLabel: 'Cambiar');
    if (r == null || !mounted) return;
    await run(context, () => Api.i.dio.post('/usuarios/reset-password', data: r), ok: 'Contraseña actualizada');
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _servidor,
            icon: const Icon(Icons.dns_outlined, size: 18),
            label: const Text('Servidor'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco, size: 72, color: cs.primary),
                  const SizedBox(height: 8),
                  Text('AgroSmart', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Gestión agrícola en tu bolsillo'),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    onSubmitted: (_) => _go(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _loading ? null : _go,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Iniciar sesión'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _olvide, child: const Text('¿Olvidaste tu contraseña?')),
                  TextButton(onPressed: _registro, child: const Text('Crear cuenta')),
                  Text('Conectando a: ${Api.i.baseUrl}',
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
