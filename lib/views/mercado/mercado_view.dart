import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'carrito_tab.dart';
import 'catalogo_tab.dart';
import 'compras_tab.dart';
import 'favoritos_tab.dart';
import 'ofertas_tab.dart';
import 'ventas_tab.dart';

/// Categorías del catálogo (el backend filtra por coincidencia exacta).
const kCategorias = ['Palma', 'Café', 'Cacao', 'Maíz', 'Arroz', 'Caña', 'Frutas', 'Hortalizas', 'Otro'];

/// Marketplace: catálogo + pestañas según el rol (comprador o vendedor).
class MercadoPage extends StatelessWidget {
  final int initialIndex;
  const MercadoPage({super.key, this.initialIndex = 0});
  @override
  Widget build(BuildContext context) {
    return TabsPage(initialIndex: initialIndex, tabs: {
      'Catálogo': const CatalogoTab(),
      if (session.esComprador) ...{
        'Mis compras': const ComprasTab(),
        'Carrito': const CarritoTab(),
        'Favoritos': const FavoritosTab(),
      },
      if (esAdmin) ...{
        'Mis ofertas': const MisOfertasTab(),
        'Ventas': const VentasTab(),
      },
    });
  }
}
