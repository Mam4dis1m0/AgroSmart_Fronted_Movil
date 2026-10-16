import 'package:flutter/material.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'insumos_tab.dart';
import 'tareas_view.dart';

/// Operación diaria: tareas de campo e inventario de insumos.
class OperacionPage extends StatelessWidget {
  final int initialIndex;
  const OperacionPage({super.key, this.initialIndex = 0});
  @override
  Widget build(BuildContext context) {
    return TabsPage(initialIndex: initialIndex, tabs: const {
      'Tareas': TareasPage(),
      'Insumos': InsumosTab(),
    });
  }
}
