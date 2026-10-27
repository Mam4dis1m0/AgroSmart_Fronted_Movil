import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/imagen.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'mercado_view.dart';

const _mkt = '/api/v1/marketplace';

/// Ofertas publicadas por la finca (vendedor = administrador).
class MisOfertasTab extends StatelessWidget {
  const MisOfertasTab({super.key});

  static List<String> _fotos(Map<String, dynamic> it) => [for (final f in (it['fotos'] as List?) ?? const []) s(f)];

  /// Hora a la que la oferta aparecerá en el catálogo (vendedor Freemium); null si ya es visible.
  static DateTime? _visibleDesde(Map<String, dynamic> l) {
    if (s(l['estado']).toUpperCase() != 'PUBLICADO') return null;
    final t = DateTime.tryParse(s(l['earlyaccesshasta']))?.toLocal();
    return t != null && t.isAfter(DateTime.now()) ? t : null;
  }

  Future<void> _agregarFoto(BuildContext ctx, Map<String, dynamic> item, VoidCallback reload) async {
    final actuales = _fotos(item);
    if (actuales.length >= 6) return snack(ctx, 'Máximo 6 fotos por oferta');
    final img = await elegirImagen(ctx);
    if (img == null || !ctx.mounted) return;
    final m = ScaffoldMessenger.of(ctx);
    m.showSnackBar(const SnackBar(content: Text('Subiendo foto…'), duration: Duration(seconds: 30)));
    try {
      final url = await marketplaceService.subirFoto(img.dataUrl);
      await marketplaceService.actualizarListado(item['idlistado'], {'fotos': [...actuales, url]});
      m
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Foto agregada')));
      reload();
    } catch (e) {
      m
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Api.errorMsg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CrudList(
      path: '$_mkt/listados',
      listPath: '$_mkt/listados/mios',
      idKey: 'idlistado',
      singular: 'oferta',
      femenino: true,
      icon: Icons.sell,
      canEdit: true,
      empty: 'Aún no publicas ofertas.\nVende tu cosecha a compradores de la región.',
      fields: () async => [
        const FieldDef('titulo', 'Título', required: true, minLength: 3, helper: 'Ej. Café pergamino seco'),
        const FieldDef('descripcion', 'Descripción', type: FT.multiline),
        FieldDef('categoria', 'Categoría', type: FT.select, options: [for (final c in kCategorias) MapEntry(c, c)]),
        const FieldDef('volumen', 'Cantidad disponible', type: FT.number, required: true, min: 0),
        const FieldDef('unidad', 'Unidad (kg, t, bultos…)'),
        const FieldDef('preciounitario', 'Precio por unidad (COP)', type: FT.number, required: true, min: 0),
        const FieldDef('ubicacion', 'Ubicación de entrega'),
        const FieldDef('estado', 'Estado', type: FT.select, onlyEdit: true, options: [
          MapEntry('BORRADOR', 'Borrador (no visible)'),
          MapEntry('PUBLICADO', 'Publicado'),
          MapEntry('PAUSADO', 'Pausado'),
        ]),
      ],
      normalize: (l) => {...l, 'volumen': l['volumen'] ?? l['volumendisponible']},
      title: (l) => s(l['titulo']),
      subtitle: (l) => juntar([
        '${cant(l['volumendisponible'] ?? l['volumen'])} ${s(l['unidad'])} disp.',
        '${money(l['preciounitario'])}/${s(l['unidad']).isEmpty ? 'u' : s(l['unidad'])}',
        '${_fotos(l).length} foto(s)',
      ]),
      tint: (l) => _visibleDesde(l) != null ? AgroColors.warningSoft : null,
      badge: (l) {
        final espera = _visibleDesde(l);
        return Wrap(spacing: 6, runSpacing: 6, children: [
          // Plan Freemium: la oferta publicada aparece en el catálogo después de la espera.
          if (espera != null)
            StatusBadge('En espera · visible ${DateFormat('h:mm a', 'es').format(espera)}')
          else
            StatusBadge(s(l['estado'])),
          if (s(l['categoria']).isNotEmpty) CropBadge(s(l['categoria']), showIcon: false),
          if (l['destacado'] == true) const StatusBadge('destacado'),
        ]);
      },
      extra: (l) {
        final est = s(l['estado']).toUpperCase();
        return [
          if (est != 'PUBLICADO')
            RowAction('Publicar', (ctx, item, reload) async {
              if (await run(ctx, () => marketplaceService.actualizarListado(item['idlistado'], {'estado': 'PUBLICADO'}), ok: 'Oferta publicada')) reload();
            }, icon: Icons.public),
          if (est == 'PUBLICADO')
            RowAction('Pausar', (ctx, item, reload) async {
              if (await run(ctx, () => marketplaceService.actualizarListado(item['idlistado'], {'estado': 'PAUSADO'}), ok: 'Oferta pausada')) reload();
            }, icon: Icons.pause_circle_outline),
          RowAction('Agregar foto', _agregarFoto, icon: Icons.add_a_photo_outlined),
          if (_fotos(l).isNotEmpty)
            RowAction('Quitar todas las fotos', (ctx, item, reload) async {
              if (!await confirmar(ctx, 'Se quitarán las ${_fotos(item).length} fotos de esta oferta.',
                  titulo: '¿Quitar fotos?', ok: 'Quitar', destructivo: true)) {
                return;
              }
              if (!ctx.mounted) return;
              if (await run(ctx, () => marketplaceService.actualizarListado(item['idlistado'], {'fotos': <String>[]}), ok: 'Fotos eliminadas')) reload();
            }, icon: Icons.hide_image_outlined, destructive: true),
          if (l['destacado'] != true && est == 'PUBLICADO')
            RowAction('Destacar (Premium)', (ctx, item, reload) async {
              if (!await confirmar(ctx, 'La oferta aparecerá primero en el catálogo. Costo: \$ 9.900 (pago simulado).',
                  titulo: '¿Destacar oferta?', ok: 'Destacar')) {
                return;
              }
              if (!ctx.mounted) return;
              if (await run(ctx, () => marketplaceService.destacarListado(item['idlistado']), ok: 'Oferta destacada')) reload();
            }, icon: Icons.star_outline),
        ];
      },
    );
  }
}
