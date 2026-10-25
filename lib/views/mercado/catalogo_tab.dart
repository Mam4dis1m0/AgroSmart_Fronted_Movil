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

class _CatalogoTabState extends State<CatalogoTab> with AutomaticKeepAliveClientMixin {
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _cargar();
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

  Future<void> _reiniciar() async {
    _items.clear();
    _hayMas = true;
    _error = null;
    await _cargar(forzar: true);
  }

  Future<void> _cargar({bool forzar = false}) async {
    if ((_cargando && !forzar) || !_hayMas) return;
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
      if (!mounted) return;
      setState(() {
        _items.addAll(l);
        _hayMas = l.length >= _pagina;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
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
      if (mounted) snack(context, 'Configura tu latitud y longitud en Perfil › Alertas de ofertas cercanas');
      return;
    }
    setState(() => _cerca = true);
    _reiniciar();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _query = v.trim();
            _reiniciar();
          },
          decoration: InputDecoration(
            hintText: 'Buscar productos agrícolas…',
            prefixIcon: const Icon(Icons.search),
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
          ),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          if (session.esComprador)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(Icons.near_me, size: 16, color: _cerca ? Colors.white : AgroColors.primary),
                label: Text(_cerca ? 'A $_radio km' : 'Cerca de mí'),
                selected: _cerca,
                showCheckmark: false,
                onSelected: (_) => _toggleCerca(),
              ),
            ),
          for (final c in kCategorias)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c),
                selected: _categoria == c,
                onSelected: (_) {
                  setState(() => _categoria = _categoria == c ? null : c);
                  _reiniciar();
                },
              ),
            ),
        ]),
      ),
      if (_cargando && _items.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
      Expanded(child: _lista()),
    ]);
  }

  Widget _lista() {
    if (_items.isEmpty) {
      if (_cargando) return const Center(child: CircularProgressIndicator());
      if (_error != null) return AgroError(message: Api.errorMsg(_error!), onRetry: _reiniciar);
      return RefreshIndicator(
        onRefresh: _reiniciar,
        child: ListView(children: [
          AgroEmpty(
            icon: Icons.storefront,
            message: _query.isEmpty && _categoria == null && !_cerca
                ? 'Aún no hay ofertas publicadas'
                : 'No encontramos ofertas con esos filtros',
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _reiniciar,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _items.length + (_hayMas ? 1 : 0),
        itemBuilder: (c, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _error != null
                    ? TextButton(onPressed: _cargar, child: const Text('Reintentar'))
                    : const CircularProgressIndicator(),
              ),
            );
          }
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: ListadoCard(l: _items[i]));
        },
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
    final cat = s(l['categoria']);
    final distancia = l['distanciaKm'] ?? l['distancia'];
    return AgroCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleListadoPage(id: (l['idlistado'] as num).toInt()))),
      child: Row(children: [
        SizedBox(
          width: 104,
          height: 116,
          child: fotos.isNotEmpty
              ? Image(
                  image: CachedNetworkImageProvider(s(fotos.first is Map ? (fotos.first as Map)['url'] : fotos.first)),
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, p) => p == null ? child : const ColoredBox(color: AgroColors.surfaceGreen),
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AgroColors.surfaceGreen,
                    child: Icon(Icons.image_not_supported_outlined, color: AgroColors.textMuted),
                  ),
                )
              : const ColoredBox(color: AgroColors.surfaceGreen, child: Icon(Icons.eco, color: AgroColors.primary, size: 32)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s(l['titulo']), maxLines: 1, overflow: TextOverflow.ellipsis, style: AgroText.title)),
                if (l['destacado'] == true) const Icon(Icons.star, size: 18, color: AgroColors.amber, semanticLabel: 'Destacada'),
              ]),
              const SizedBox(height: 2),
              Text(juntar([s(l['finca']), s(l['ubicacion']), if (distancia != null) '${cant(distancia)} km']),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (cat.isNotEmpty) CropBadge(cat, showIcon: false),
              const SizedBox(height: 6),
              Text('${money(l['preciounitario'])} / ${s(l['unidad']).isEmpty ? 'unidad' : s(l['unidad'])}', style: AgroText.amount),
              Text('Disponible: ${cant(l['volumendisponible'])} ${s(l['unidad'])}',
                  style: const TextStyle(fontSize: 12, color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}
