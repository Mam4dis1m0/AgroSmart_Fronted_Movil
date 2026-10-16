import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';

/// Registro de actividad de la finca (admin).
class AuditoriaPage extends StatefulWidget {
  const AuditoriaPage({super.key});
  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> {
  String? _op;
  static const _ops = ['INSERT', 'UPDATE', 'DELETE', 'DENEGADO'];
  static const _etiquetas = {'INSERT': 'Creación', 'UPDATE': 'Edición', 'DELETE': 'Eliminación', 'DENEGADO': 'Denegado'};

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: FilterChips(
          options: [for (final o in _ops) _etiquetas[o]!],
          selected: _op == null ? null : _etiquetas[_op],
          allLabel: 'Todo',
          onSelected: (v) => setState(() => _op = v == null ? null : _etiquetas.entries.firstWhere((e) => e.value == v).key),
        ),
      ),
      Expanded(
        child: AsyncList(
          loader: () => avisoService.auditoria().then((l) => l.map((e) => e.toMap()).toList()),
          filter: _op == null ? null : (a) => s(a['operacion']).toUpperCase() == _op,
          empty: 'Sin eventos registrados',
          emptyIcon: Icons.history,
          itemBuilder: (c, a, _) {
            final op = s(a['operacion']).toUpperCase();
            final denegado = op == 'DENEGADO';
            final icon = switch (op) {
              'INSERT' => Icons.add_circle_outline,
              'DELETE' => Icons.delete_outline,
              'DENEGADO' => Icons.block,
              _ => Icons.edit_note,
            };
            return AgroListCard(
              leading: AgroIconTile(
                icon: icon,
                color: denegado || op == 'DELETE' ? AgroColors.danger : AgroColors.primary,
                bg: denegado || op == 'DELETE' ? AgroColors.dangerBg : AgroColors.surfaceGreen,
              ),
              title: Text(juntar([_etiquetas[op] ?? op, s(a['tablaNombre'] ?? a['tabla_nombre'])]), style: AgroText.title),
              subtitle: Text(
                juntar([s(a['descripcion']), fecha(a['fecha'] ?? a['created_at'] ?? a['fechahora'], hora: true)]).replaceFirst(' · ', '\n'),
                style: AgroText.muted,
              ),
            );
          },
        ),
      ),
    ]);
  }
}
