import 'package:flutter/material.dart';
import 'package:agrosmart_proto/views/voz/voz_asistente_view.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'agenda_view.dart';
import 'insumos_tab.dart';
import 'plantillas_tab.dart';
import 'tareas_view.dart';

/// Operación diaria: tareas de campo e inventario de insumos.
class OperacionPage extends StatelessWidget {
  final int initialIndex;
  const OperacionPage({super.key, this.initialIndex = 0});
  @override
  Widget build(BuildContext context) => ConVoz(child: _tabs(context));

  Widget _tabs(BuildContext context) {
    return TabsPage(initialIndex: initialIndex, tabs: {
      'Tareas': const TareasPage(),
      'Insumos': const InsumosTab(),
      'Agenda': const AgendaPage(),
      if (esAdmin) 'Plantillas': const PlantillasTab(),
    });
  }
}
