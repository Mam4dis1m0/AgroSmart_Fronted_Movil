import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Equipo de la finca: miembros, alta de empleados, tarifas y accesos (admin).
class EquipoPage extends StatelessWidget {
  const EquipoPage({super.key});

  Future<void> _tarifas(BuildContext c, Map<String, dynamic> m, VoidCallback reload) async {
    final id = (m['idusuario'] as num).toInt();
    final actual = await fincaService.empleado(id) ?? const {};
    if (!c.mounted) return;
    final d = await showForm(c, 'Tarifas de ${s(m['primernombre'])}', const [
      FieldDef('montoporhora', 'Pago por hora (COP)', type: FT.number, min: 0),
      FieldDef('montoporjornal', 'Pago por jornal (COP)', type: FT.number, min: 0),
    ], initial: actual, edit: true);
    if (d == null || !c.mounted) return;
    if (await run(c, () => fincaService.actualizarTarifas(id, d), ok: 'Tarifas actualizadas')) reload();
  }

  Future<void> _activo(BuildContext c, Map<String, dynamic> m, bool v, VoidCallback reload) async {
    final nombre = s(m['primernombre']);
    if (!v &&
        !await confirmar(c, '$nombre no podrá ingresar a esta finca hasta que lo reactives.',
            titulo: '¿Desactivar a $nombre?', ok: 'Desactivar', destructivo: true)) {
      return;
    }
    if (!c.mounted) return;
    if (await run(c, () => fincaService.setMiembroActivo((m['idusuario'] as num).toInt(), v),
        ok: v ? 'Acceso reactivado' : 'Acceso desactivado')) {
      reload();
    }
  }

  Future<void> _quitar(BuildContext c, Map<String, dynamic> m, VoidCallback reload) async {
    final nombre = '${s(m['primernombre'])} ${s(m['primerapellido'])}'.trim();
    if (!await confirmar(c, 'Se conserva su historial de tareas y pagos, pero dejará de pertenecer a esta finca.',
        titulo: '¿Quitar a $nombre del equipo?', ok: 'Quitar', destructivo: true)) {
      return;
    }
    if (!c.mounted) return;
    if (await run(c, () => fincaService.quitarMiembro((m['idusuario'] as num).toInt()), ok: 'Miembro retirado')) reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListPage(
      loader: () => fincaService.miembros().then((l) => l.map((e) => e.toMap()).toList()),
      empty: 'Aún no hay miembros en la finca',
      emptyIcon: Icons.group_outlined,
      addLabel: 'Nuevo empleado',
      onAdd: (reload) async {
        final d = await showForm(context, 'Registrar empleado', const [
          FieldDef('primernombre', 'Primer nombre', required: true, minLength: 2),
          FieldDef('primerapellido', 'Primer apellido', required: true, minLength: 2),
          FieldDef('cedula', 'Cédula', required: true, minLength: 5),
          FieldDef('email', 'Correo', type: FT.email, required: true),
          FieldDef('contrasena', 'Contraseña inicial', type: FT.password, required: true, minLength: 6,
              helper: 'El empleado la usará para ingresar'),
          FieldDef('telefono', 'Teléfono', type: FT.phone),
          FieldDef('montoporhora', 'Pago por hora (COP)', type: FT.number, min: 0),
          FieldDef('montoporjornal', 'Pago por jornal (COP)', type: FT.number, min: 0),
        ], okLabel: 'Registrar');
        if (d == null || !context.mounted) return;
        if (await run(context, () => fincaService.registrarEmpleado(d), ok: 'Empleado registrado')) reload();
      },
      itemBuilder: (c, m, reload) {
        final activo = m['activo'] != false;
        final propio = m['idusuario'] == session.usuario?['id'];
        final empleado = s(m['rol']) == 'empleado';
        final nombre = '${s(m['primernombre'])} ${s(m['primerapellido'])}'.trim();
        return AgroListCard(
          tint: activo ? null : AgroColors.neutralBg,
          leading: AgroAvatar(url: s(m['fotoperfil']), nombre: nombre),
          title: Text(propio ? '$nombre (tú)' : nombre, style: AgroText.title),
          subtitle: Text(juntar([s(m['email']), s(m['telefono'])]), style: AgroText.muted),
          badges: Wrap(spacing: 6, runSpacing: 6, children: [
            StatusBadge(s(m['rol'])),
            if (!activo) const StatusBadge('inactivo'),
          ]),
          trailing: propio
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Semantics(
                    label: activo ? 'Desactivar acceso' : 'Activar acceso',
                    child: Switch(value: activo, onChanged: (v) => _activo(c, m, v, reload)),
                  ),
                  RowMenu(item: m, reload: reload, actions: [
                    if (empleado) RowAction('Tarifas de pago', (ctx, it, r) => _tarifas(ctx, it, r), icon: Icons.payments_outlined),
                    RowAction('Quitar de la finca', (ctx, it, r) => _quitar(ctx, it, r), icon: Icons.person_remove_outlined, destructive: true),
                  ]),
                ]),
        );
      },
    );
  }
}
