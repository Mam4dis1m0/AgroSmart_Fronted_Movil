import 'package:flutter/material.dart';
import 'api.dart';

/// Lista genérica con carga, error, reintento y pull-to-refresh.
class AsyncList extends StatefulWidget {
  final Future<List<dynamic>> Function() loader;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback reload) itemBuilder;
  final String empty;
  final Widget? header;
  const AsyncList({
    super.key,
    required this.loader,
    required this.itemBuilder,
    this.empty = 'Sin registros',
    this.header,
  });
  @override
  State<AsyncList> createState() => AsyncListState();
}

class AsyncListState extends State<AsyncList> {
  late Future<List<dynamic>> _f = widget.loader();

  void reload() => setState(() => _f = widget.loader());

  @override
  void didUpdateWidget(covariant AsyncList old) {
    super.didUpdateWidget(old);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _f,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(Api.errorMsg(snap.error!), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: reload, child: const Text('Reintentar')),
              ]),
            ),
          );
        }
        final items = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: () async { reload(); await _f; },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              if (widget.header != null) widget.header!,
              if (items.isEmpty)
                Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(widget.empty))),
              for (final it in items)
                widget.itemBuilder(ctx, (it as Map).cast<String, dynamic>(), reload),
            ],
          ),
        );
      },
    );
  }
}

String _s(dynamic v) => v == null ? '' : v.toString();
double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse(_s(v)) ?? 0;
void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

// ── Lotes ───────────────────────────────────────────────────────────────────
class LotesList extends StatelessWidget {
  const LotesList({super.key});
  @override
  Widget build(BuildContext context) {
    return AsyncList(
      loader: () => Api.i.getList('/lotes'),
      empty: 'Aún no hay lotes',
      itemBuilder: (c, l, _) {
        final cultivos = (l['cultivos'] as List?) ?? [];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.landscape)),
            title: Text(_s(l['nombre']).isEmpty ? 'Lote #${l['idlote']}' : _s(l['nombre'])),
            subtitle: Text('${_n(l['areahectareas'])} ha · ${_s(l['ubicacion'])}'
                '${cultivos.isNotEmpty ? '\nCultivos: ${cultivos.map((x) => x['tipo']).join(', ')}' : ''}'),
            isThreeLine: cultivos.isNotEmpty,
          ),
        );
      },
    );
  }
}

// ── Insumos ─────────────────────────────────────────────────────────────────
class InsumosList extends StatelessWidget {
  const InsumosList({super.key});
  @override
  Widget build(BuildContext context) {
    return AsyncList(
      loader: () => Api.i.getList('/api/v1/insumos'),
      empty: 'Sin insumos registrados',
      itemBuilder: (c, i, _) {
        final stock = _n(i['stockactual']);
        final min = _n(i['stockminimo']);
        final bajo = stock <= min;
        return Card(
          color: bajo ? Colors.red.shade50 : null,
          child: ListTile(
            leading: Icon(bajo ? Icons.warning_amber : Icons.inventory_2,
                color: bajo ? Colors.red : Colors.green),
            title: Text(_s(i['nombre'])),
            subtitle: Text('${_s(i['tipo'])} · mínimo $min ${_s(i['unidadmedida'])}'),
            trailing: Text('$stock ${_s(i['unidadmedida'])}',
                style: TextStyle(fontWeight: FontWeight.bold, color: bajo ? Colors.red : null)),
          ),
        );
      },
    );
  }
}

// ── Tareas ──────────────────────────────────────────────────────────────────
class TareasList extends StatelessWidget {
  const TareasList({super.key});

  Color _color(String e) {
    final x = e.toLowerCase();
    if (x.contains('complet')) return Colors.green;
    if (x.contains('progreso') || x.contains('curso')) return Colors.orange;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return AsyncList(
      loader: () => Api.i.getList('/api/v1/tareas'),
      empty: 'No hay tareas',
      itemBuilder: (c, t, reload) {
        final estado = _s(t['estado']);
        final done = estado.toLowerCase().contains('complet');
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _color(estado).withOpacity(.15),
              child: Icon(done ? Icons.check : Icons.pending_actions, color: _color(estado)),
            ),
            title: Text(_s(t['tipoactividad']).isEmpty ? 'Tarea #${t['idtarea']}' : _s(t['tipoactividad'])),
            subtitle: Text('${_s(t['fechaprogramada'])} · $estado'),
            trailing: done
                ? null
                : IconButton(
                    tooltip: 'Marcar como completada',
                    icon: const Icon(Icons.done_all),
                    onPressed: () async {
                      try {
                        await Api.i.dio.patch('/api/v1/tareas/${t['idtarea']}/completar');
                        reload();
                      } catch (e) {
                        if (c.mounted) _snack(c, Api.errorMsg(e));
                      }
                    },
                  ),
          ),
        );
      },
    );
  }
}

// ── Mercado (catálogo del Marketplace) ─────────────────────────────────────
class MercadoList extends StatefulWidget {
  const MercadoList({super.key});
  @override
  State<MercadoList> createState() => _MercadoListState();
}

class _MercadoListState extends State<MercadoList> {
  final _q = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Buscar productos agrícolas...',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () { _q.clear(); setState(() => _query = ''); }),
          ),
        ),
      ),
      Expanded(
        child: AsyncList(
          key: ValueKey(_query),
          loader: () => Api.i.getList('/api/v1/marketplace/listados',
              query: {if (_query.isNotEmpty) 'q': _query, 'limit': 30}),
          empty: 'No hay ofertas publicadas',
          itemBuilder: (c, l, _) {
            final fotos = (l['fotos'] as List?) ?? [];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Row(children: [
                SizedBox(
                  width: 96, height: 96,
                  child: fotos.isNotEmpty
                      ? Image.network(_s(fotos.first), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))
                      : Container(color: Colors.green.shade50, child: const Icon(Icons.eco, color: Colors.green)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(l['titulo']), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_s(l['finca'])} · ${_s(l['ubicacion'])}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('${_s(l['moneda']).isEmpty ? 'COP' : _s(l['moneda'])} ${_n(l['preciounitario']).toStringAsFixed(0)} / ${_s(l['unidad'])}',
                          style: TextStyle(color: Theme.of(c).colorScheme.primary, fontWeight: FontWeight.w600)),
                      Text('Disponible: ${_n(l['volumendisponible'])} ${_s(l['unidad'])}',
                          style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
                if (l['destacado'] == true)
                  const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.star, color: Colors.amber)),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Notificaciones ──────────────────────────────────────────────────────────
class NotificacionesList extends StatelessWidget {
  const NotificacionesList({super.key});
  @override
  Widget build(BuildContext context) {
    return AsyncList(
      loader: () => Api.i.getList('/notificaciones'),
      empty: 'No tienes avisos',
      itemBuilder: (c, n, reload) {
        final leida = n['leida'] == true;
        return Card(
          child: ListTile(
            leading: Icon(leida ? Icons.notifications_none : Icons.notifications_active,
                color: leida ? Colors.grey : Colors.orange),
            title: Text(_s(n['titulo']), style: TextStyle(fontWeight: leida ? FontWeight.normal : FontWeight.bold)),
            subtitle: Text(_s(n['mensaje'])),
            onTap: leida
                ? null
                : () async {
                    try {
                      await Api.i.dio.put('/notificaciones/${n['idnotificacion']}/leer');
                      reload();
                    } catch (e) {
                      if (c.mounted) _snack(c, Api.errorMsg(e));
                    }
                  },
          ),
        );
      },
    );
  }
}
