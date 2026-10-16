import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/imagen.dart';
import 'package:agrosmart_proto/ui/shell.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Perfil del usuario: foto, datos, contraseña y (comprador) ubicación y alertas.
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late Future<Map<String, dynamic>> _f = _load();
  bool _subiendo = false;

  int get _id => (session.usuario?['id'] as num?)?.toInt() ?? 0;

  Future<Map<String, dynamic>> _load() async {
    final me = await authService.me();
    // El comprador no puede leer /usuarios/:id; admin y empleado obtienen el detalle completo.
    if (session.esComprador) {
      Map<String, dynamic>? comprador;
      try {
        comprador = await authService.perfilComprador();
      } catch (_) {}
      return {...me, 'comprador': comprador};
    }
    try {
      return {...me, ...await authService.usuario(_id)};
    } catch (_) {
      return me;
    }
  }

  void _recargar() => setState(() => _f = _load());

  Future<void> _foto() async {
    final img = await elegirImagen(context, maxWidth: 800);
    if (img == null || !mounted) return;
    if (img.bytes.lengthInBytes > 5 * 1024 * 1024) return snack(context, 'La imagen supera 5 MB');
    setState(() => _subiendo = true);
    String? url;
    final ok = await run(context, () async => url = await authService.subirFotoPerfil(_id, img.dataUrl), ok: 'Foto actualizada');
    if (ok && url != null) await session.actualizarUsuario({'fotoperfil': url});
    if (mounted) setState(() => _subiendo = false);
    if (ok) _recargar();
  }

  Future<void> _editar(Map<String, dynamic> u) async {
    final d = await showForm(context, 'Editar datos', const [
      FieldDef('primernombre', 'Primer nombre', required: true, minLength: 2),
      FieldDef('segundonombre', 'Segundo nombre'),
      FieldDef('primerapellido', 'Primer apellido', required: true, minLength: 2),
      FieldDef('segundoapellido', 'Segundo apellido'),
      FieldDef('telefono', 'Teléfono', type: FT.phone),
      FieldDef('cedula', 'Cédula'),
    ], initial: {
      ...u,
      'primernombre': u['primernombre'] ?? u['nombre'],
      'primerapellido': u['primerapellido'] ?? u['apellido'],
    }, edit: true);
    if (d == null || !mounted) return;
    d.removeWhere((_, v) => v == null);
    if (await run(context, () => authService.actualizarUsuario(_id, d), ok: 'Perfil actualizado')) {
      await session.actualizarUsuario({
        if (d['primernombre'] != null) 'nombre': d['primernombre'],
        if (d['primerapellido'] != null) 'apellido': d['primerapellido'],
      });
      _recargar();
    }
  }

  Future<void> _contrasena() async {
    final d = await showForm(context, 'Cambiar contraseña', const [
      FieldDef('contrasenaActual', 'Contraseña actual', type: FT.password, required: true),
      FieldDef('contrasenaNueva', 'Contraseña nueva', type: FT.password, required: true, minLength: 6),
      FieldDef('confirmar', 'Repite la contraseña nueva', type: FT.password, required: true, matches: 'contrasenaNueva'),
    ], okLabel: 'Cambiar contraseña');
    if (d == null || !mounted) return;
    await run(context, () => authService.cambiarContrasena(_id, d), ok: 'Contraseña actualizada');
  }

  Future<void> _ubicacion(Map<String, dynamic>? c) async {
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _UbicacionSheet(inicial: c ?? const {}),
    );
    if (r == null || !mounted) return;
    if (await run(context, () => authService.actualizarUbicacionComprador(r), ok: 'Preferencias guardadas')) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (c, snap) {
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return AgroError(message: Api.errorMsg(snap.error!), onRetry: _recargar);
        final u = snap.data!;
        final nombre = juntar([
          s(u['primernombre'] ?? u['nombre']),
          s(u['segundonombre']),
          s(u['primerapellido'] ?? u['apellido']),
          s(u['segundoapellido']),
        ]).replaceAll(' · ', ' ');
        final foto = s(u['fotoperfil']).isEmpty ? session.foto : s(u['fotoperfil']);
        final comprador = (u['comprador'] as Map?)?.cast<String, dynamic>();
        return RefreshIndicator(
          onRefresh: () async {
            _recargar();
            await _f;
          },
          child: ListView(padding: const EdgeInsets.all(14), children: [
            AgroHeroCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Stack(clipBehavior: Clip.none, children: [
                  AgroAvatar(url: foto, nombre: nombre, radius: 32),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Material(
                      color: AgroColors.mint,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Cambiar foto',
                        visualDensity: VisualDensity.compact,
                        onPressed: _subiendo ? null : _foto,
                        icon: _subiendo
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.photo_camera, size: 18, color: AgroColors.forestDeep),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre.isEmpty ? 'Usuario' : nombre,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(s(u['email']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AgroColors.mintPale, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    StatusBadge(session.rol),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            AgroCard(
              child: Column(children: [
                InfoRow('Teléfono', s(u['telefono'])),
                if (!session.esComprador) InfoRow('Cédula', s(u['cedula'])),
                if (!session.esComprador) InfoRow('Finca activa', s(session.fincaActiva['nombre'])),
              ]),
            ),
            const SizedBox(height: 18),
            const AgroSectionHeader('Cuenta'),
            const SizedBox(height: 8),
            _accion(Icons.edit, 'Editar datos', 'Nombre, teléfono y cédula', () => _editar(u)),
            _accion(Icons.lock, 'Cambiar contraseña', 'Usa al menos 6 caracteres', _contrasena),
            if (session.esComprador) ...[
              const SizedBox(height: 10),
              const AgroSectionHeader('Alertas de ofertas cercanas'),
              const SizedBox(height: 8),
              _accion(
                Icons.place,
                comprador == null || s(comprador['ubicacion']).isEmpty ? 'Configura tu ubicación' : s(comprador['ubicacion']),
                comprador == null
                    ? 'Recibe avisos de ofertas cerca de ti'
                    : (comprador['notificaciones'] == false
                        ? 'Alertas desactivadas'
                        : 'Radio de ${cant(comprador['radioalertaskm'] ?? 50)} km'),
                () => _ubicacion(comprador),
              ),
              const SizedBox(height: 10),
              _accion(Icons.logout, 'Cerrar sesión', null, () => cerrarSesion(context), peligro: true),
            ],
          ]),
        );
      },
    );
  }

  Widget _accion(IconData icon, String titulo, String? sub, VoidCallback onTap, {bool peligro = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AgroListCard(
          leading: AgroIconTile(
            icon: icon,
            color: peligro ? AgroColors.danger : AgroColors.primary,
            bg: peligro ? AgroColors.dangerBg : AgroColors.surfaceGreen,
          ),
          title: Text(titulo, style: AgroText.title.copyWith(color: peligro ? AgroColors.danger : null)),
          subtitle: sub == null ? null : Text(sub, style: AgroText.muted),
          trailing: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right, color: AgroColors.textMuted)),
          onTap: onTap,
        ),
      );
}

/// Ubicación del comprador, radio de alertas y activación de notificaciones.
class _UbicacionSheet extends StatefulWidget {
  final Map<String, dynamic> inicial;
  const _UbicacionSheet({required this.inicial});
  @override
  State<_UbicacionSheet> createState() => _UbicacionSheetState();
}

class _UbicacionSheetState extends State<_UbicacionSheet> {
  late final _ubic = TextEditingController(text: s(widget.inicial['ubicacion']));
  late final _lat = TextEditingController(text: s(widget.inicial['latitud']));
  late final _lng = TextEditingController(text: s(widget.inicial['longitud']));
  late double _radio = n(widget.inicial['radioalertaskm'] ?? 50).clamp(1, 500).toDouble();
  late bool _notif = widget.inicial['notificaciones'] != false;
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _ubic.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  String? _coord(String? v, double max) {
    if (v == null || v.trim().isEmpty) return null;
    final x = double.tryParse(v.replaceAll(',', '.'));
    if (x == null || x.abs() > max) return 'Valor entre -$max y $max';
    return null;
  }

  void _guardar() {
    if (!_key.currentState!.validate()) return;
    final lat = double.tryParse(_lat.text.replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.replaceAll(',', '.'));
    Navigator.pop(context, {
      if (_ubic.text.trim().isNotEmpty) 'ubicacion': _ubic.text.trim(),
      if (lat != null) 'latitud': lat,
      if (lng != null) 'longitud': lng,
      'radioalertaskm': _radio.round(),
      'notificaciones': _notif,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Ubicación y alertas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
            const SizedBox(height: 4),
            const Text('Te avisaremos cuando publiquen ofertas dentro de tu radio.', style: AgroText.muted),
            const SizedBox(height: 16),
            TextFormField(controller: _ubic, decoration: const InputDecoration(labelText: 'Municipio / departamento')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Latitud', helperText: 'Ej. 10.4631'),
                  validator: (v) => _coord(v, 90),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Longitud', helperText: 'Ej. -73.2532'),
                  validator: (v) => _coord(v, 180),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text('Radio de alertas: ${_radio.round()} km', style: AgroText.title),
            Slider(
              value: _radio,
              min: 1,
              max: 500,
              divisions: 99,
              label: '${_radio.round()} km',
              onChanged: (v) => setState(() => _radio = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recibir alertas de ofertas cercanas', style: AgroText.title),
              value: _notif,
              onChanged: (v) => setState(() => _notif = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      ),
    );
  }
}
