import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'jornada_card.dart';

/// Equipo de la finca: miembros, alta de empleados, pago acordado y accesos (admin).
/// Cómo se le paga a un empleado: se acuerda por día, semana o mes (no por tarea ni por hora).
const camposPago = [
  FieldDef('tipopago', 'Cómo se le paga', type: FT.select, required: true, options: [
    MapEntry('dia', 'Por día'),
    MapEntry('semana', 'Por semana'),
    MapEntry('mes', 'Por mes'),
  ]),
  FieldDef('valorpago', 'Valor acordado (COP)', type: FT.number, required: true, min: 0,
      helper: 'Lo que se le paga por cada día, semana o mes, según lo elegido'),
];

class EquipoPage extends StatelessWidget {
  const EquipoPage({super.key});

  Future<void> _pago(BuildContext c, Map<String, dynamic> m, VoidCallback reload) async {
    final id = (m['idusuario'] as num).toInt();
    final actual = await fincaService.empleado(id) ?? const {};
    if (!c.mounted) return;
    final d = await showForm(c, 'Pago de ${s(m['primernombre'])}', camposPago, initial: actual, edit: true);
    if (d == null || !c.mounted) return;
    if (await run(c, () => fincaService.actualizarPago(id, d), ok: 'Pago actualizado')) reload();
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
      header: esAdmin ? const JornadaCard() : null,
      loader: () => fincaService.miembros().then((l) => l.map((e) => e.toMap()).toList()),
      empty: 'Aún no hay miembros en la finca',
      emptyIcon: Icons.group_outlined,
      addLabel: 'Nuevo empleado',
      onAdd: (reload) async {
        final d = await showForm(context, 'Registrar empleado', [
          FieldDef('primernombre', 'Primer nombre', required: true, minLength: 2),
          FieldDef('primerapellido', 'Primer apellido', required: true, minLength: 2),
          FieldDef('cedula', 'Cédula', required: true, minLength: 5),
          FieldDef('email', 'Correo', type: FT.email, required: true),
          FieldDef('contrasena', 'Contraseña inicial', type: FT.password, required: true, minLength: 6,
              helper: 'El empleado la usará para ingresar'),
          FieldDef('telefono', 'Teléfono', type: FT.phone),
          ...camposPago,
        ], okLabel: 'Registrar', initial: const {'tipopago': 'dia'});
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
                    if (empleado) RowAction('Pago acordado', (ctx, it, r) => _pago(ctx, it, r), icon: Icons.payments_outlined),
                    RowAction('Quitar de la finca', (ctx, it, r) => _quitar(ctx, it, r), icon: Icons.person_remove_outlined, destructive: true),
                  ]),
                ]),
        );
      },
    );
  }
}
