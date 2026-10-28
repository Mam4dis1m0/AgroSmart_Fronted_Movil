import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/shell.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/asistente/asistente_view.dart';
import 'package:agrosmart_proto/views/auditoria/auditoria_view.dart';
import 'package:agrosmart_proto/views/avisos/avisos_view.dart';
import 'package:agrosmart_proto/views/equipo/equipo_view.dart';
import 'package:agrosmart_proto/views/mensajes/bandeja_view.dart';
import 'package:agrosmart_proto/views/nomina/nomina_view.dart';
import 'package:agrosmart_proto/views/perfil/perfil_view.dart';
import 'package:agrosmart_proto/views/plan/plan_view.dart';
import 'package:agrosmart_proto/views/reportes/reportes_view.dart';

/// Menú lateral: cuenta, gestión de la finca, herramientas y sesión.
class MasPage extends StatelessWidget {
  const MasPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required IconData icon,
      required String title,
      String? sub,
      VoidCallback? onTap,
      Color? iconColor,
      Color? iconBg,
      Color? titleColor,
      ValueNotifier<int>? badge,
    }) {
      final trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        if (badge != null)
          ValueListenableBuilder<int>(
            valueListenable: badge,
            builder: (_, v, __) => v > 0
                ? Badge(
                    label: Text('$v'),
                    backgroundColor: AgroColors.amber,
                    textColor: AgroColors.forestDeep)
                : const SizedBox.shrink(),
          ),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.chevron_right, color: AgroColors.textMuted)),
      ]);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AgroListCard(
          leading: AgroIconTile(
              icon: icon,
              color: iconColor ?? AgroColors.primary,
              bg: iconBg ?? AgroColors.surfaceGreen),
          title: Text(title, style: AgroText.title.copyWith(color: titleColor)),
          subtitle: sub == null ? null : Text(sub, style: AgroText.muted),
          trailing: onTap == null ? null : trailing,
          onTap: onTap,
        ),
      );
    }

    Widget entry(IconData icon, String title, String sub, Widget page,
            {ValueNotifier<int>? badge}) =>
        tile(
          icon: icon,
          title: title,
          sub: sub,
          badge: badge,
          onTap: () async {
            await pushPage(context, title, page);
            contadores.refrescar();
          },
        );

    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: AgroSectionHeader(title)),
            ...children,
          ],
        );

    return ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          section('Cuenta', [
            entry(Icons.person_outline, 'Mi perfil',
                'Datos personales, foto y contraseña', const PerfilPage()),
          ]),
          if (esAdmin)
            section('Gestión de la finca', [
              tile(
                icon: Icons.agriculture,
                title: 'Datos de la finca',
                sub: 'Nombre, ubicación y tipo de producción',
                onTap: () => editarFinca(context),
              ),
              entry(Icons.group, 'Equipo', 'Empleados, tarifas y accesos',
                  const EquipoPage()),
              entry(Icons.payments, 'Nómina', 'Liquidación de jornales y horas',
                  const NominaPage()),
              entry(Icons.bar_chart, 'Reportes',
                  'Costos por cultivo y exportación CSV', const ReportesPage()),
              entry(Icons.workspace_premium, 'Plan y suscripción',
                  'Freemium o Premium, pagos', const PlanPage()),
            ]),
          section('Herramientas', [
            entry(Icons.notifications, 'Avisos',
                'Notificaciones de la finca y del mercado', const AvisosPage(),
                badge: contadores.avisos),
            if (esAdmin)
              tile(
                icon: Icons.chat_bubble_outline,
                title: 'Mensajes',
                sub: 'Conversaciones con compradores',
                badge: contadores.mensajes,
                onTap: () => abrirBandeja(context),
              ),
            entry(Icons.smart_toy, 'Asistente IA',
                'Consultas agrícolas (Premium)', const AsistentePage()),
            if (esAdmin)
              entry(Icons.history, 'Auditoría', 'Registro de actividad',
                  const AuditoriaPage()),
          ]),
          section('Sesión', [
            if (session.fincas.length > 1)
              tile(
                icon: Icons.swap_horiz,
                title: 'Cambiar de finca',
                sub: 'Selecciona otra finca',
                onTap: session.cambiarFinca,
              ),
            tile(
              icon: Icons.logout,
              title: 'Cerrar sesión',
              iconColor: AgroColors.danger,
              iconBg: AgroColors.dangerBg,
              titleColor: AgroColors.danger,
              onTap: () => cerrarSesion(context),
            ),
          ]),
        ]);
  }
}

/// Edita los datos de la finca activa (PUT /api/v1/fincas/activa).
Future<void> editarFinca(BuildContext c) async {
  final actual = await cargar(c, () => fincaService.activa());
  if (actual == null || !c.mounted) return;
  final d = await showForm(
      c,
      'Datos de la finca',
      const [
        FieldDef('nombre', 'Nombre de la finca', required: true, minLength: 2),
        FieldDef('ubicacion', 'Ubicación (municipio, departamento)'),
        FieldDef(
          'tipoproduccion',
          'Tipo de producción',
          type: FT.selectOther,
          options: [
            MapEntry('Café', 'Café'),
            MapEntry('Palma', 'Palma de aceite'),
            MapEntry('Cacao', 'Cacao'),
            MapEntry('Ganadería', 'Ganadería'),
            MapEntry('Frutales', 'Frutales'),
            MapEntry('Hortalizas', 'Hortalizas'),
            MapEntry('Agricultura mixta', 'Agricultura mixta'),
          ],
        ),
      ],
      initial: actual.toMap(),
      edit: true);
  if (d == null || !c.mounted) return;
  if (await run(c, () => fincaService.actualizarActiva(d),
      ok: 'Finca actualizada')) {
    await session.actualizarFincaActiva(d);
  }
}
