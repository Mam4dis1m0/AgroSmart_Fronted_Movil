import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'detalle_listado_view.dart';
import 'mercado_view.dart';

/// Catálogo de ofertas publicadas con búsqueda, categorías, cercanía y paginación.
class CatalogoTab extends StatefulWidget {
  const CatalogoTab({super.key});
  @override
  State<CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<CatalogoTab>
    with AutomaticKeepAliveClientMixin {
  static const _pagina = 20;
  final _q = TextEditingController();
  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  String _query = '';
  String? _categoria;
  bool _cerca = false;
  double? _lat, _lng;
  int _radio = 50;
  bool _cargando = false;
  bool _hayMas = true;
  Object? _error;
  int _generacion = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _cargar();
      }
    });
    _q.addListener(() => setState(() {}));
    _reiniciar();
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reiniciar() {
    _generacion++;
    setState(() {
      _items.clear();
      _hayMas = true;
      _error = null;
      _cargando = false;
    });
    return _cargar(forzar: true);
  }

  Future<void> _cargar({bool forzar = false}) async {
    if ((_cargando && !forzar) || !_hayMas) return;
    final generacion = _generacion;
    setState(() => _cargando = true);
    try {
      final l = await marketplaceService.listados(
        q: _query,
        categoria: _categoria,
        lat: _cerca ? _lat : null,
        lng: _cerca ? _lng : null,
        radioKm: _radio,
        limit: _pagina,
        offset: _items.length,
      );
      if (!mounted || generacion != _generacion) return;
      setState(() {
        _items.addAll(l);
        _hayMas = l.length >= _pagina;
        _error = null;
      });
    } catch (e) {
      if (mounted && generacion == _generacion) setState(() => _error = e);
    } finally {
      if (mounted && generacion == _generacion) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _toggleCerca() async {
    if (_cerca) {
      setState(() => _cerca = false);
      return _reiniciar();
    }
    if (_lat == null) {
      final p = await cargar(context, authService.perfilComprador);
      if (!mounted) return;
      _lat = n(p?['latitud']) == 0 ? null : n(p?['latitud']);
      _lng = n(p?['longitud']) == 0 ? null : n(p?['longitud']);
      _radio = n(p?['radioalertaskm']).round().clamp(1, 1000);
      if (_radio == 0) _radio = 50;
    }
    if (_lat == null || _lng == null) {
      if (mounted) {
        snack(context,
            'Configura tu latitud y longitud en Perfil › Alertas de ofertas cercanas');
      }
      return;
    }
    setState(() => _cerca = true);
    _reiniciar();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Container(
          color: AgroColors.page,
          child: Column(children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reiniciar,
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: _MarketplaceHero(
                            onPublish: esAdmin
                                ? () => DefaultTabController.of(context)
                                    .animateTo(1)
                                : null),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 1,
                          shadowColor:
                              AgroColors.forest.withValues(alpha: 0.08),
                          child: TextField(
                            controller: _q,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (v) {
                              _query = v.trim();
                              _reiniciar();
                            },
                            decoration: InputDecoration(
                              hintText: '¿Qué producto estás buscando?',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _q.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpiar búsqueda',
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _q.clear();
                                        _query = '';
                                        _reiniciar();
                                      },
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AgroColors.slateBorder),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 42,
                        child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (session.esComprador)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    avatar: Icon(Icons.near_me_rounded,
                                        size: 16,
                                        color: _cerca
                                            ? Colors.white
                                            : AgroColors.primary),
                                    label: Text(_cerca
                                        ? 'A $_radio km'
                                        : 'Cerca de mí'),
                                    selected: _cerca,
                                    showCheckmark: false,
                                    onSelected: (_) => _toggleCerca(),
                                  ),
                                ),
                              for (final c in ['Todo', ...kCategorias])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      c == 'Todo'
                                          ? Icons.storefront_outlined
                                          : _iconoCategoria(c),
                                      size: 15,
                                      color: (_categoria ==
                                              (c == 'Todo' ? null : c))
                                          ? Colors.white
                                          : AgroColors.primary,
                                    ),
                                    label: Text(c),
                                    selected:
                                        _categoria == (c == 'Todo' ? null : c),
                                    onSelected: (_) {
                                      if (c == 'Todo') {
                                        _query = '';
                                        _q.clear();
                                        setState(() {
                                          _categoria = null;
                                          _cerca = false;
                                        });
                                      } else {
                                        setState(() => _categoria =
                                            _categoria == c ? null : c);
                                      }
                                      _reiniciar();
                                    },
                                  ),
                                ),
                            ]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 19, 16, 11),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _query.isEmpty && _categoria == null
                                        ? 'Productos frescos'
                                        : 'Resultados para ti',
                                    style: const TextStyle(
                                      color: AgroColors.forest,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _items.isEmpty
                                        ? 'Directo de las fincas de la región'
                                        : '${_items.length} productos para descubrir',
                                    style: const TextStyle(
                                      color: AgroColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AgroColors.surfaceLime,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.eco_rounded,
                                      size: 15, color: AgroColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Compra local',
                                    style: TextStyle(
                                        color: AgroColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_cargando && _items.isNotEmpty)
                      const SliverToBoxAdapter(
                          child: LinearProgressIndicator(minHeight: 2)),
                    ..._catalogoSlivers(),
                  ],
                ),
              ),
            ),
          ]),
        ),
        if (session.esComprador || esAdmin)
          Positioned(
            right: 16,
            bottom: 20,
            child: FloatingActionButton.extended(
              heroTag: 'mercado-carrito',
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Carrito'),
              onPressed: () => DefaultTabController.of(context)
                  .animateTo(mercadoCarritoTabIndex),
            ),
          ),
      ],
    );
  }

  IconData _iconoCategoria(String categoria) => switch (categoria) {
        'Café' => Icons.coffee_rounded,
        'Cacao' => Icons.park_rounded,
        'Maíz' => Icons.grain_rounded,
        'Arroz' => Icons.rice_bowl_rounded,
        'Palma' || 'Caña' => Icons.grass_rounded,
        'Frutas' => Icons.eco_rounded,
        'Hortalizas' => Icons.spa_rounded,
        _ => Icons.category_outlined,
      };

  List<Widget> _catalogoSlivers() {
    if (_items.isEmpty) {
      if (_cargando) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        ];
      }
      if (_error != null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child:
                AgroError(message: Api.errorMsg(_error!), onRetry: _reiniciar),
          )
        ];
      }
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AgroEmpty(
            icon: Icons.storefront_rounded,
            message: _query.isEmpty && _categoria == null && !_cerca
                ? 'Pronto encontrarás aquí productos frescos de fincas cercanas.'
                : 'No encontramos productos con esos filtros. Prueba otra búsqueda.',
          ),
        )
      ];
    }
    final columns = MediaQuery.sizeOf(context).width >= 680 ? 3 : 2;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final itemWidth =
                (constraints.crossAxisExtent - (columns - 1) * 12) / columns;
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: itemWidth * 1.55,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _items.length) {
                    return Center(
                      child: _error != null
                          ? TextButton(
                              onPressed: _cargar,
                              child: const Text('Reintentar'),
                            )
                          : const CircularProgressIndicator(),
                    );
                  }
                  return ListadoCard(l: _items[index]);
                },
                childCount: _items.length + (_hayMas ? 1 : 0),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _MarketplaceHero extends StatelessWidget {
  final VoidCallback? onPublish;
  const _MarketplaceHero({this.onPublish});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 162),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AgroColors.forest, AgroColors.heroMid, AgroColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AgroColors.forest.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AgroColors.brightGreen.withValues(alpha: 0.20),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: -55,
            child: Icon(Icons.eco_rounded,
                size: 145, color: Colors.white.withValues(alpha: 0.09)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.wb_sunny_rounded,
                              color: AgroColors.lime, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            onPublish == null
                                ? 'MERCADO AGROSMART'
                                : 'TU COSECHA TIENE VALOR',
                            style: const TextStyle(
                              color: AgroColors.mintPale,
                              fontSize: 9,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        onPublish == null
                            ? 'Lo mejor del campo, cerca de ti'
                            : 'Lleva tus productos más lejos',
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        onPublish == null
                            ? 'Compra directo a productores locales'
                            : 'Publica tu oferta y conecta con compradores',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AgroColors.mintPale,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (onPublish != null) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: onPublish,
                          style: FilledButton.styleFrom(
                            backgroundColor: AgroColors.lime,
                            foregroundColor: AgroColors.forest,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          icon:
                              const Icon(Icons.add_a_photo_outlined, size: 15),
                          label: const Text('Publicar producto'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(Icons.shopping_basket_rounded,
                      size: 33, color: AgroColors.lime),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de oferta en el catálogo.
class ListadoCard extends StatelessWidget {
  final Map<String, dynamic> l;
  const ListadoCard({super.key, required this.l});

  @override
  Widget build(BuildContext context) {
    final fotos = (l['fotos'] as List?) ?? [];
    final foto = fotos.isEmpty
        ? ''
        : s(fotos.first is Map ? (fotos.first as Map)['url'] : fotos.first);
    final cat = s(l['categoria']);
    final distancia = l['distanciaKm'] ?? l['distancia'];
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AgroColors.slateBorder),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                DetalleListadoPage(id: (l['idlistado'] as num).toInt()))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (foto.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: foto,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _ProductPlaceholder(),
                      errorWidget: (_, __, ___) => const _ProductPlaceholder(),
                    )
                  else
                    const _ProductPlaceholder(),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.eco_rounded,
                              size: 12, color: AgroColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            cat.isEmpty ? 'Del campo' : cat,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AgroColors.forest,
                                fontSize: 9,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (l['destacado'] == true)
                    Positioned(
                      right: 9,
                      top: 9,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: AgroColors.amber, shape: BoxShape.circle),
                        child: const Icon(Icons.star_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    right: 9,
                    bottom: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AgroColors.forest.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            '${cant(l['volumendisponible'])} ${s(l['unidad'])}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s(l['titulo']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AgroColors.forestDeep,
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AgroColors.primaryLight),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            juntar([
                              s(l['finca']),
                              s(l['ubicacion']),
                              if (distancia != null) '${cant(distancia)} km',
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AgroColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      money(l['preciounitario']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AgroColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'por ${s(l['unidad']).isEmpty ? 'unidad' : s(l['unidad'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AgroColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AgroColors.surfaceLime,
      child: Center(
        child: Icon(Icons.agriculture_rounded,
            color: AgroColors.primaryLight, size: 42),
      ),
    );
  }
}
