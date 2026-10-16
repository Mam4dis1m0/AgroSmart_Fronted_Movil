import 'package:flutter/material.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'design.dart';

// ── Helpers de formato ──────────────────────────────────────────────────────
String s(dynamic v) => v == null ? '' : v.toString();

double n(dynamic v) => v is num ? v.toDouble() : double.tryParse(s(v)) ?? 0;

String d10(dynamic v) {
  final x = s(v);
  return x.length >= 10 ? x.substring(0, 10) : x;
}

String money(dynamic v) {
  final neg = n(v) < 0;
  final x = n(v).abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < x.length; i++) {
    if (i > 0 && (x.length - i) % 3 == 0) b.write('.');
    b.write(x[i]);
  }
  return '${neg ? '-' : ''}\$ $b';
}

void snack(BuildContext c, String m) {
  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

Future<bool> confirmar(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aceptar')),
      ],
    ),
  );
  return r == true;
}

/// Ejecuta una llamada a la API mostrando el error o un mensaje de éxito.
Future<bool> run(BuildContext c, Future<dynamic> Function() f, {String? ok}) async {
  try {
    await f();
    if (ok != null) snack(c, ok);
    return true;
  } catch (e) {
    snack(c, Api.errorMsg(e));
    return false;
  }
}

Future<void> pushPage(BuildContext c, String title, Widget body, {List<Widget>? actions}) {
  return Navigator.of(c).push(MaterialPageRoute(
    builder: (_) => Scaffold(appBar: AppBar(title: Text(title), actions: actions), body: body),
  ));
}

// ── Formularios genéricos ───────────────────────────────────────────────────
enum FT { text, multiline, number, date, password, email, select }

class FieldDef {
  final String key;
  final String label;
  final FT type;
  final bool required;
  final bool onlyCreate;
  final bool onlyEdit;
  final List<MapEntry<dynamic, String>> options;
  const FieldDef(
    this.key,
    this.label, {
    this.type = FT.text,
    this.required = false,
    this.onlyCreate = false,
    this.onlyEdit = false,
    this.options = const [],
  });
}

Future<Map<String, dynamic>?> showForm(
  BuildContext c,
  String title,
  List<FieldDef> fields, {
  Map<String, dynamic>? initial,
  String okLabel = 'Guardar',
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: c,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormSheet(title: title, fields: fields, initial: initial ?? const {}, okLabel: okLabel),
  );
}

class _FormSheet extends StatefulWidget {
  final String title;
  final String okLabel;
  final List<FieldDef> fields;
  final Map<String, dynamic> initial;
  const _FormSheet({required this.title, required this.fields, required this.initial, required this.okLabel});
  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _ctrl = <String, TextEditingController>{};
  final _sel = <String, dynamic>{};
  final _key = GlobalKey<FormState>();
  late final List<FieldDef> _fields;
  late final bool _edit;

  @override
  void initState() {
    super.initState();
    _edit = widget.initial.isNotEmpty;
    _fields = widget.fields.where((f) => !(f.onlyCreate && _edit) && !(f.onlyEdit && !_edit)).toList();
    for (final f in _fields) {
      final v = widget.initial[f.key];
      if (f.type == FT.select) {
        _sel[f.key] = f.options.any((o) => o.key == v) ? v : null;
      } else {
        _ctrl[f.key] = TextEditingController(text: f.type == FT.date ? d10(v) : s(v));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _req(FieldDef f, String? v) => f.required && (v == null || v.trim().isEmpty) ? 'Requerido' : null;

  Widget _field(FieldDef f) {
    const border = OutlineInputBorder();
    switch (f.type) {
      case FT.select:
        return DropdownButtonFormField<dynamic>(
          value: _sel[f.key],
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label, border: border),
          items: [
            for (final o in f.options)
              DropdownMenuItem<dynamic>(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _sel[f.key] = v),
          validator: (v) => f.required && v == null ? 'Requerido' : null,
        );
      case FT.date:
        return TextFormField(
          controller: _ctrl[f.key],
          readOnly: true,
          decoration: InputDecoration(labelText: f.label, border: border, suffixIcon: const Icon(Icons.calendar_today)),
          validator: (v) => _req(f, v),
          onTap: () async {
            final init = DateTime.tryParse(_ctrl[f.key]!.text) ?? DateTime.now();
            final p = await showDatePicker(
              context: context,
              initialDate: init,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (p != null) {
              _ctrl[f.key]!.text =
                  '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';
            }
          },
        );
      default:
        return TextFormField(
          controller: _ctrl[f.key],
          obscureText: f.type == FT.password,
          maxLines: f.type == FT.multiline ? 3 : 1,
          keyboardType: f.type == FT.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : f.type == FT.email
                  ? TextInputType.emailAddress
                  : null,
          decoration: InputDecoration(labelText: f.label, border: border),
          validator: (v) => _req(f, v),
        );
    }
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    final out = <String, dynamic>{};
    for (final f in _fields) {
      if (f.type == FT.select) {
        if (_sel[f.key] != null) out[f.key] = _sel[f.key];
        continue;
      }
      final t = _ctrl[f.key]!.text.trim();
      if (t.isEmpty) continue;
      out[f.key] = f.type == FT.number ? (num.tryParse(t.replaceAll(',', '.')) ?? t) : t;
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AgroColors.textDark)),
            const SizedBox(height: 16),
            for (final f in _fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
            FilledButton(onPressed: _submit, child: Text(widget.okLabel)),
          ]),
        ),
      ),
    );
  }
}

// ── Listas ──────────────────────────────────────────────────────────────────
class AsyncList extends StatefulWidget {
  final Future<List<dynamic>> Function() loader;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback reload) itemBuilder;
  final String empty;
  final Widget? header;
  const AsyncList({super.key, required this.loader, required this.itemBuilder, this.empty = 'Sin registros', this.header});
  @override
  State<AsyncList> createState() => AsyncListState();
}

class AsyncListState extends State<AsyncList> {
  late Future<List<dynamic>> _f = widget.loader();

  void reload() => setState(() => _f = widget.loader());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _f,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return AgroError(message: Api.errorMsg(snap.error!), onRetry: reload);
        }
        final items = snap.data ?? [];
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await _f;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              if (widget.header != null) ...[widget.header!, const SizedBox(height: 12)],
              if (items.isEmpty) AgroEmpty(message: widget.empty),
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: widget.itemBuilder(ctx, (it as Map).cast<String, dynamic>(), reload),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Lista + botón "+" opcional.
class ListPage extends StatefulWidget {
  final Future<List<dynamic>> Function() loader;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback reload) itemBuilder;
  final String empty;
  final Future<void> Function(VoidCallback reload)? onAdd;
  final String addLabel;
  const ListPage({super.key, required this.loader, required this.itemBuilder, this.empty = 'Sin registros', this.onAdd, this.addLabel = 'Nuevo'});
  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _k = GlobalKey<AsyncListState>();
  void _reload() => _k.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncList(key: _k, loader: widget.loader, itemBuilder: widget.itemBuilder, empty: widget.empty),
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => widget.onAdd!(_reload),
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
    );
  }
}

class RowAction {
  final String label;
  final Future<void> Function(BuildContext ctx, Map<String, dynamic> item, VoidCallback reload) fn;
  const RowAction(this.label, this.fn);
}

/// CRUD genérico sobre un recurso REST del backend.
class CrudList extends StatefulWidget {
  final String path;
  final String? listPath;
  final String idKey;
  final String singular;
  final Future<List<FieldDef>> Function() fields;
  final String Function(Map<String, dynamic>) title;
  final String Function(Map<String, dynamic>) subtitle;
  final IconData icon;
  final bool canEdit;
  final Map<String, dynamic> Function(Map<String, dynamic>)? normalize;
  final Color? Function(Map<String, dynamic>)? tint;
  final String Function(Map<String, dynamic>)? trailingText;
  final Widget? Function(Map<String, dynamic>)? badge;
  final List<RowAction> Function(Map<String, dynamic>)? extra;
  const CrudList({
    super.key,
    required this.path,
    this.listPath,
    required this.idKey,
    required this.singular,
    required this.fields,
    required this.title,
    required this.subtitle,
    this.icon = Icons.circle,
    this.canEdit = false,
    this.normalize,
    this.tint,
    this.trailingText,
    this.badge,
    this.extra,
  });
  @override
  State<CrudList> createState() => _CrudListState();
}

class _CrudListState extends State<CrudList> {
  final _k = GlobalKey<AsyncListState>();
  void _reload() => _k.currentState?.reload();

  Future<void> _create() async {
    final f = await widget.fields();
    if (!mounted) return;
    final data = await showForm(context, 'Nuevo ${widget.singular}', f);
    if (data == null || !mounted) return;
    if (await run(context, () => Api.i.dio.post(widget.path, data: data), ok: 'Creado')) _reload();
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final f = await widget.fields();
    if (!mounted) return;
    final init = widget.normalize?.call(item) ?? item;
    final data = await showForm(context, 'Editar ${widget.singular}', f, initial: init);
    if (data == null || !mounted) return;
    if (await run(context, () => Api.i.dio.put('${widget.path}/${item[widget.idKey]}', data: data), ok: 'Guardado')) {
      _reload();
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    if (!await confirmar(context, '¿Eliminar este ${widget.singular}?')) return;
    if (!mounted) return;
    if (await run(context, () => Api.i.dio.delete('${widget.path}/${item[widget.idKey]}'), ok: 'Eliminado')) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncList(
        key: _k,
        loader: () => Api.i.getList(widget.listPath ?? widget.path),
        empty: 'Aún no hay registros',
        itemBuilder: (c, it, reload) {
          final extras = widget.extra?.call(it) ?? const <RowAction>[];
          final tt = widget.trailingText?.call(it);
          final sub = widget.subtitle(it);
          return AgroListCard(
            tint: widget.tint?.call(it),
            leading: AgroIconTile(icon: widget.icon),
            title: Text(widget.title(it), style: const TextStyle(fontWeight: FontWeight.w800, color: AgroColors.textDark)),
            subtitle: sub.isEmpty
                ? null
                : Text(sub, style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600, height: 1.35)),
            badges: widget.badge?.call(it),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (tt != null)
                Text(tt, style: const TextStyle(fontWeight: FontWeight.w900, color: AgroColors.primary)),
              if (widget.canEdit)
                PopupMenuButton<int>(
                  onSelected: (v) {
                    if (v == 0) _edit(it);
                    if (v == 1) _delete(it);
                    if (v >= 10) extras[v - 10].fn(c, it, reload);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 0, child: Text('Editar')),
                    const PopupMenuItem(value: 1, child: Text('Eliminar')),
                    for (var i = 0; i < extras.length; i++) PopupMenuItem(value: 10 + i, child: Text(extras[i].label)),
                  ],
                ),
            ]),
          );
        },
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Nuevo'))
          : null,
    );
  }
}

/// Pestañas superiores (TabBar + TabBarView).
class TabsPage extends StatelessWidget {
  final Map<String, Widget> tabs;
  const TabsPage({super.key, required this.tabs});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(
            color: AgroColors.surfaceGreen,
            border: Border(bottom: BorderSide(color: Color(0xFFC2D8C7))),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AgroColors.forest,
              unselectedLabelColor: AgroColors.textMuted,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              indicatorColor: AgroColors.forest,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              tabs: [for (final t in tabs.keys) Tab(text: t)],
            ),
          ),
        ),
        Expanded(child: TabBarView(children: tabs.values.toList())),
      ]),
    );
  }
}

/// Tarjeta clave/valor para mostrar mapas de datos sin conocer su forma exacta.
class KvCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  const KvCard({super.key, required this.title, required this.data});
  @override
  Widget build(BuildContext context) {
    final rows = data.entries.where((e) => e.value is! Map && e.value is! List && e.value != null).toList();
    return AgroCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
        const SizedBox(height: 10),
        for (final e in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 130, child: Text(e.key, style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(child: Text(s(e.value), style: const TextStyle(fontWeight: FontWeight.w600, color: AgroColors.textDark))),
            ]),
          ),
      ]),
    );
  }
}
