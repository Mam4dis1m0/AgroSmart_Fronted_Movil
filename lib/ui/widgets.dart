import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/imagen.dart';
import 'design.dart';

// ── Helpers de formato ──────────────────────────────────────────────────────
String s(dynamic v) => v == null ? '' : v.toString();

double n(dynamic v) => v is num ? v.toDouble() : double.tryParse(s(v)) ?? 0;

/// Fecha en formato de API (yyyy-mm-dd), para formularios.
String d10(dynamic v) {
  final x = s(v);
  return x.length >= 10 ? x.substring(0, 10) : x;
}

String ymd(DateTime p) =>
    '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';

/// Fecha legible en español: "15 oct 2026". Vacío si no hay fecha.
String fecha(dynamic v, {bool hora = false}) {
  final t = DateTime.tryParse(s(v));
  if (t == null) return d10(v);
  final l = t.toLocal();
  return DateFormat(hora ? 'd MMM y · h:mm a' : 'd MMM y', 'es').format(l);
}

/// Número sin ".0" sobrante y con coma decimal: 12 · 12,5 · 1.250
String cant(dynamic v) {
  final x = n(v);
  return NumberFormat(x == x.roundToDouble() ? '#,##0' : '#,##0.##', 'es')
      .format(x);
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

/// Une partes no vacías con " · ".
String juntar(Iterable<String> partes) =>
    partes.where((p) => p.trim().isNotEmpty).join(' · ');

void snack(BuildContext c, String m) {
  if (c.mounted)
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

Future<bool> confirmar(
  BuildContext c,
  String msg, {
  String titulo = '¿Estás seguro?',
  String ok = 'Aceptar',
  bool destructivo = false,
}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: destructivo
              ? FilledButton.styleFrom(backgroundColor: AgroColors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// Ejecuta una llamada a la API mostrando el error o un mensaje de éxito.
Future<bool> run(BuildContext c, Future<dynamic> Function() f,
    {String? ok}) async {
  final m = ScaffoldMessenger.maybeOf(c);
  void show(String t) => m?.showSnackBar(SnackBar(content: Text(t)));
  try {
    await f();
    if (ok != null) show(ok);
    return true;
  } catch (e) {
    show(Api.errorMsg(e));
    return false;
  }
}

/// Carga algo (p. ej. las opciones de un formulario); si falla muestra el error y devuelve null.
Future<T?> cargar<T>(BuildContext c, Future<T> Function() f) async {
  final m = ScaffoldMessenger.maybeOf(c);
  try {
    return await f();
  } catch (e) {
    m?.showSnackBar(SnackBar(content: Text(Api.errorMsg(e))));
    return null;
  }
}

Future<T?> pushPage<T>(BuildContext c, String title, Widget body,
    {List<Widget>? actions}) {
  return Navigator.of(c).push<T>(MaterialPageRoute(
    builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions), body: body),
  ));
}

// ── Formularios genéricos ───────────────────────────────────────────────────
enum FT {
  text,
  multiline,
  number,
  date,
  password,
  email,
  select,
  selectOther,
  phone,
  image
}

const _otherSelectValue = '__agro_otro__';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class FieldDef {
  final String key;
  final String label;
  final FT type;
  final bool required;
  final bool onlyCreate;
  final bool onlyEdit;
  final List<MapEntry<dynamic, String>> options;
  final int? minLength;
  final String? helper;

  /// Para contraseñas: clave del campo que este debe repetir (no se envía al backend).
  final String? matches;

  /// Para fechas: clave de otra fecha que esta no puede preceder.
  final String? after;

  /// Para números: valor mínimo permitido.
  final num? min;

  const FieldDef(
    this.key,
    this.label, {
    this.type = FT.text,
    this.required = false,
    this.onlyCreate = false,
    this.onlyEdit = false,
    this.options = const [],
    this.minLength,
    this.helper,
    this.matches,
    this.after,
    this.min,
  });
}

Future<Map<String, dynamic>?> showForm(
  BuildContext c,
  String title,
  List<FieldDef> fields, {
  Map<String, dynamic>? initial,
  String okLabel = 'Guardar',
  bool? edit,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: c,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FormSheet(
      title: title,
      fields: fields,
      initial: initial ?? const {},
      okLabel: okLabel,
      edit: edit ?? (initial != null && initial.isNotEmpty),
    ),
  );
}

class _FormSheet extends StatefulWidget {
  final String title;
  final String okLabel;
  final List<FieldDef> fields;
  final Map<String, dynamic> initial;
  final bool edit;
  const _FormSheet(
      {required this.title,
      required this.fields,
      required this.initial,
      required this.okLabel,
      required this.edit});
  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _ctrl = <String, TextEditingController>{};
  final _sel = <String, dynamic>{};
  final _hide = <String, bool>{};
  final _imageBytes = <String, Uint8List>{};
  final _key = GlobalKey<FormState>();
  late final List<FieldDef> _fields;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _fields = widget.fields
        .where((f) => !(f.onlyCreate && edit) && !(f.onlyEdit && !edit))
        .toList();
    for (final f in _fields) {
      final v = widget.initial[f.key];
      if (f.type == FT.select || f.type == FT.selectOther) {
        final matchesOption = f.options.any((o) => o.key == v);
        _sel[f.key] = matchesOption
            ? v
            : (f.type == FT.selectOther && s(v).isNotEmpty
                ? _otherSelectValue
                : null);
        if (f.type == FT.selectOther) {
          _ctrl[f.key] = TextEditingController(text: matchesOption ? '' : s(v));
        }
      } else {
        _ctrl[f.key] = TextEditingController(
          text: f.type == FT.date
              ? d10(v)
              : (f.type == FT.number && v != null ? _numTxt(v) : s(v)),
        );
        if (f.type == FT.password) _hide[f.key] = true;
      }
    }
  }

  static String _numTxt(dynamic v) {
    final x = n(v);
    return x == x.roundToDouble() ? x.round().toString() : x.toString();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validar(FieldDef f, String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return f.required ? 'Requerido' : null;
    if (f.minLength != null && v.length < f.minLength!)
      return 'Mínimo ${f.minLength} caracteres';
    switch (f.type) {
      case FT.email:
        if (!_emailRe.hasMatch(v)) return 'Correo inválido';
      case FT.number:
        final x = num.tryParse(v.replaceAll(',', '.'));
        if (x == null) return 'Ingresa un número válido';
        if (f.min != null && x < f.min!)
          return 'Debe ser mayor o igual a ${f.min}';
      case FT.phone:
        if (!RegExp(r'^[0-9+\s-]{7,15}$').hasMatch(v))
          return 'Teléfono inválido';
      case FT.date:
        if (f.after != null) {
          final otra = DateTime.tryParse(_ctrl[f.after]?.text ?? '');
          final esta = DateTime.tryParse(v);
          if (otra != null && esta != null && esta.isBefore(otra))
            return 'No puede ser anterior a la fecha inicial';
        }
      default:
        break;
    }
    if (f.matches != null && v != _ctrl[f.matches]?.text.trim())
      return 'Las contraseñas no coinciden';
    return null;
  }

  Widget _field(FieldDef f, bool last) {
    final action = last ? TextInputAction.done : TextInputAction.next;
    if (f.type == FT.image) {
      final value = _ctrl[f.key]!.text;
      final bytes = _imageBytes[f.key];
      final preview = bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : value.startsWith('http')
              ? Image.network(
                  value,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: AgroColors.navInactive,
                    size: 40,
                  ),
                )
              : value.startsWith('data:image/')
                  ? Image.memory(
                      base64Decode(value.substring(value.indexOf(',') + 1)),
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.landscape_outlined,
                      color: AgroColors.navInactive,
                      size: 40,
                    );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(f.label, style: Theme.of(context).textTheme.labelLarge),
          if (f.helper != null) ...[
            const SizedBox(height: 4),
            Text(f.helper!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Container(
            height: 150,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AgroColors.surfaceGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: preview,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final image = await elegirImagen(context, allowWebCamera: true);
                if (image == null || !mounted) return;
                if (image.bytes.lengthInBytes > 5 * 1024 * 1024) {
                  snack(context, 'La imagen supera el tamaño máximo de 5 MB');
                  return;
                }
                setState(() {
                  _ctrl[f.key]!.text = image.dataUrl;
                  _imageBytes[f.key] = image.bytes;
                });
              } catch (e) {
                if (mounted) snack(context, Api.errorMsg(e));
              }
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(value.isEmpty ? 'Tomar o elegir foto' : 'Cambiar foto'),
          ),
        ],
      );
    }
    if (f.type == FT.select || f.type == FT.selectOther) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<dynamic>(
          initialValue: _sel[f.key],
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label, helperText: f.helper),
          items: [
            for (final o in f.options)
              DropdownMenuItem<dynamic>(
                  value: o.key,
                  child: Text(o.value, overflow: TextOverflow.ellipsis)),
            if (f.type == FT.selectOther)
              const DropdownMenuItem<dynamic>(
                  value: _otherSelectValue, child: Text('Otro (escribir)')),
          ],
          onChanged: (v) => setState(() => _sel[f.key] = v),
          validator: (v) => f.required && v == null ? 'Requerido' : null,
        ),
        if (f.type == FT.selectOther && _sel[f.key] == _otherSelectValue) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _ctrl[f.key],
            textInputAction: last ? TextInputAction.done : TextInputAction.next,
            decoration: InputDecoration(
                labelText: 'Escribe ${f.label.toLowerCase()}'),
            validator: (value) {
              final name = (value ?? '').trim();
              if (f.required && name.isEmpty) return 'Requerido';
              if (f.minLength != null &&
                  name.isNotEmpty &&
                  name.length < f.minLength!) {
                return 'Mínimo ${f.minLength} caracteres';
              }
              return null;
            },
            onFieldSubmitted: last ? (_) => _submit() : null,
          ),
        ],
      ]);
    }
    switch (f.type) {
      case FT.date:
        final ctrl = _ctrl[f.key]!;
        return TextFormField(
          controller: ctrl,
          readOnly: true,
          decoration: InputDecoration(
            labelText: f.label,
            helperText: f.helper,
            suffixIcon: ctrl.text.isEmpty || f.required
                ? const Icon(Icons.calendar_today)
                : IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(ctrl.clear),
                  ),
          ),
          validator: (v) => _validar(f, v),
          onTap: () async {
            final init = DateTime.tryParse(ctrl.text) ?? DateTime.now();
            final p = await showDatePicker(
              context: context,
              initialDate: init,
              firstDate: DateTime(1990),
              lastDate: DateTime(2100),
            );
            if (p != null && mounted) setState(() => ctrl.text = ymd(p));
          },
        );
      default:
        final pass = f.type == FT.password;
        return TextFormField(
          controller: _ctrl[f.key],
          obscureText: pass && (_hide[f.key] ?? true),
          maxLines: f.type == FT.multiline ? 3 : 1,
          textInputAction:
              f.type == FT.multiline ? TextInputAction.newline : action,
          onFieldSubmitted: last ? (_) => _submit() : null,
          keyboardType: switch (f.type) {
            FT.number => const TextInputType.numberWithOptions(decimal: true),
            FT.email => TextInputType.emailAddress,
            FT.phone => TextInputType.phone,
            FT.multiline => TextInputType.multiline,
            _ => null,
          },
          autofillHints: switch (f.type) {
            FT.email => const [AutofillHints.email],
            FT.phone => const [AutofillHints.telephoneNumber],
            _ => null,
          },
          decoration: InputDecoration(
            labelText: f.label,
            helperText: f.helper,
            suffixIcon: pass
                ? IconButton(
                    tooltip: (_hide[f.key] ?? true) ? 'Mostrar' : 'Ocultar',
                    icon: Icon((_hide[f.key] ?? true)
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _hide[f.key] = !(_hide[f.key] ?? true)),
                  )
                : null,
          ),
          validator: (v) => _validar(f, v),
        );
    }
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    final out = <String, dynamic>{};
    for (final f in _fields) {
      if (f.matches != null) continue;
      if (f.type == FT.select || f.type == FT.selectOther) {
        final selected = _sel[f.key];
        if (f.type == FT.selectOther && selected == _otherSelectValue) {
          final value = _ctrl[f.key]!.text.trim();
          if (value.isNotEmpty) out[f.key] = value;
        } else if (selected != null) {
          out[f.key] = selected;
        }
        continue;
      }
      final t = _ctrl[f.key]!.text.trim();
      if (t.isEmpty) {
        // En edición, una fecha borrada se envía como null para limpiarla.
        if (widget.edit &&
            f.type == FT.date &&
            s(widget.initial[f.key]).isNotEmpty) out[f.key] = null;
        continue;
      }
      out[f.key] = f.type == FT.number ? num.parse(t.replaceAll(',', '.')) : t;
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                    color: AgroColors.handle,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(children: [
                Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AgroColors.textDark))),
                IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Form(
                  key: _key,
                  child: AutofillGroup(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _fields.length; i++)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _field(
                                    _fields[i], i == _fields.length - 1)),
                        ]),
                  ),
                ),
              ),
            ),
            // El botón queda fijo abajo aunque el formulario sea largo.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: FilledButton(
                    onPressed: _submit, child: Text(widget.okLabel)),
              ),
            ),
          ]),
    );
  }
}

// ── Listas ──────────────────────────────────────────────────────────────────
typedef ItemBuilder = Widget Function(
    BuildContext, Map<String, dynamic>, VoidCallback reload);

class AsyncList extends StatefulWidget {
  final Future<List<dynamic>> Function() loader;
  final ItemBuilder itemBuilder;
  final String empty;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final Widget? header;

  /// Filtro local opcional (p. ej. chips de estado) aplicado sobre lo cargado.
  final bool Function(Map<String, dynamic>)? filter;
  const AsyncList({
    super.key,
    required this.loader,
    required this.itemBuilder,
    this.empty = 'Sin registros',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.header,
    this.filter,
  });
  @override
  State<AsyncList> createState() => AsyncListState();
}

class AsyncListState extends State<AsyncList>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>>? _data;
  Object? _error;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Recarga conservando la lista actual en pantalla mientras llega la nueva.
  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final rows = await widget.loader();
      if (!mounted) return;
      setState(() {
        _data = [for (final r in rows) (r as Map).cast<String, dynamic>()];
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_data == null) {
      if (_error != null)
        return AgroError(message: Api.errorMsg(_error!), onRetry: reload);
      return const Center(child: CircularProgressIndicator());
    }
    final items =
        widget.filter == null ? _data! : _data!.where(widget.filter!).toList();
    return Stack(children: [
      RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: 12)
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AgroAlert(
                    message: Api.errorMsg(_error!),
                    action: 'Reintentar',
                    onAction: reload),
              ),
            if (items.isEmpty)
              AgroEmpty(
                  icon: widget.emptyIcon,
                  message: widget.empty,
                  action: widget.emptyAction),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: widget.itemBuilder(context, it, reload),
              ),
          ],
        ),
      ),
      if (_loading)
        const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2)),
    ]);
  }
}

/// Lista + botón "+" opcional.
class ListPage extends StatefulWidget {
  final Future<List<dynamic>> Function() loader;
  final ItemBuilder itemBuilder;
  final String empty;
  final IconData emptyIcon;
  final Future<void> Function(VoidCallback reload)? onAdd;
  final String addLabel;
  final Widget? header;
  final bool Function(Map<String, dynamic>)? filter;
  const ListPage({
    super.key,
    required this.loader,
    required this.itemBuilder,
    this.empty = 'Sin registros',
    this.emptyIcon = Icons.inbox_outlined,
    this.onAdd,
    this.addLabel = 'Nuevo',
    this.header,
    this.filter,
  });
  @override
  State<ListPage> createState() => ListPageState();
}

class ListPageState extends State<ListPage> {
  final _k = GlobalKey<AsyncListState>();
  void reload() => _k.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncList(
        key: _k,
        loader: widget.loader,
        itemBuilder: widget.itemBuilder,
        empty: widget.empty,
        emptyIcon: widget.emptyIcon,
        header: widget.header,
        filter: widget.filter,
      ),
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => widget.onAdd!(reload),
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
    );
  }
}

class RowAction {
  final String label;
  final IconData? icon;
  final bool destructive;
  final Future<void> Function(
      BuildContext ctx, Map<String, dynamic> item, VoidCallback reload) fn;
  const RowAction(this.label, this.fn, {this.icon, this.destructive = false});
}

PopupMenuItem<int> _menuItem(int value, String label,
    {IconData? icon, bool destructive = false}) {
  final color = destructive ? AgroColors.danger : AgroColors.textDark;
  return PopupMenuItem(
    value: value,
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon,
            size: 20,
            color: destructive ? AgroColors.danger : AgroColors.primary),
        const SizedBox(width: 12)
      ],
      Flexible(
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600))),
    ]),
  );
}

/// CRUD genérico sobre un recurso REST del backend.
class CrudList extends StatefulWidget {
  final String path;
  final String? listPath;
  final String idKey;
  final String singular;
  final String? addLabel;

  /// Género gramatical para los mensajes ("Nuevo lote" / "Nueva cosecha").
  final bool femenino;
  final Future<List<FieldDef>> Function() fields;
  final String Function(Map<String, dynamic>) title;
  final String Function(Map<String, dynamic>) subtitle;
  final IconData icon;
  final bool canEdit;
  final Gradient? Function(Map<String, dynamic>)? gradientBuilder;
  final Map<String, dynamic> Function(Map<String, dynamic>)? normalize;
  final Color? Function(Map<String, dynamic>)? tint;
  final String Function(Map<String, dynamic>)? trailingText;
  final Widget? Function(Map<String, dynamic>)? badge;
  final List<RowAction> Function(Map<String, dynamic>)? extra;
  final void Function(BuildContext, Map<String, dynamic>, VoidCallback reload)?
      onTap;
  final String? empty;
  final Widget? header;
  final Widget Function(Map<String, dynamic>)? leadingBuilder;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      prepareData;
  final Map<String, dynamic> createDefaults;
  const CrudList({
    super.key,
    required this.path,
    this.listPath,
    required this.idKey,
    required this.singular,
    this.addLabel,
    this.femenino = false,
    required this.fields,
    required this.title,
    required this.subtitle,
    this.icon = Icons.circle,
    this.canEdit = false,
    this.gradientBuilder,
    this.normalize,
    this.tint,
    this.trailingText,
    this.badge,
    this.extra,
    this.onTap,
    this.empty,
    this.header,
    this.leadingBuilder,
    this.prepareData,
    this.createDefaults = const {},
  });
  @override
  State<CrudList> createState() => _CrudListState();
}

class _CrudListState extends State<CrudList> {
  final _k = GlobalKey<AsyncListState>();
  void _reload() => _k.currentState?.reload();

  String get _nuevo => widget.femenino ? 'Nueva' : 'Nuevo';
  String get _este => widget.femenino ? 'esta' : 'este';

  Future<void> _create() async {
    final f = await cargar(context, widget.fields);
    if (f == null || !mounted) return;
    final data = await showForm(
      context,
      '$_nuevo ${widget.singular}',
      f,
      initial: widget.createDefaults,
      edit: false,
    );
    if (data == null || !mounted) return;
    final ok = await run(context, () async {
      final payload =
          widget.prepareData == null ? data : await widget.prepareData!(data);
      return Api.i.dio.post(widget.path, data: payload);
    }, ok: widget.femenino ? 'Creada' : 'Creado');
    if (ok) _reload();
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final f = await cargar(context, widget.fields);
    if (f == null || !mounted) return;
    final init = widget.normalize?.call(item) ?? item;
    final data = await showForm(context, 'Editar ${widget.singular}', f,
        initial: init, edit: true);
    if (data == null || !mounted) return;
    if (await run(context, () async {
      final payload =
          widget.prepareData == null ? data : await widget.prepareData!(data);
      return Api.i.dio
          .put('${widget.path}/${item[widget.idKey]}', data: payload);
    }, ok: 'Cambios guardados')) {
      _reload();
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final t = widget.title(item);
    if (!await confirmar(context, '«$t» se eliminará de forma permanente.',
        titulo: '¿Eliminar $_este ${widget.singular}?',
        ok: 'Eliminar',
        destructivo: true)) {
      return;
    }
    if (!mounted) return;
    if (await run(
        context, () => Api.i.dio.delete('${widget.path}/${item[widget.idKey]}'),
        ok: widget.femenino ? 'Eliminada' : 'Eliminado')) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncList(
        key: _k,
        loader: () => Api.i.getList(widget.listPath ?? widget.path),
        empty: widget.empty ?? 'Aún no hay registros',
        emptyIcon: widget.icon,
        header: widget.header,
        itemBuilder: (c, it, reload) {
          final extras = widget.extra?.call(it) ?? const <RowAction>[];
          final tt = widget.trailingText?.call(it);
          final sub = widget.subtitle(it);
          final menu = widget.canEdit || extras.isNotEmpty;
          return AgroListCard(
            tint: widget.tint?.call(it),
            gradient: widget.gradientBuilder?.call(it),
            onTap: widget.onTap == null
                ? null
                : () => widget.onTap!(c, it, reload),
            leading: widget.leadingBuilder?.call(it) ??
                AgroIconTile(icon: widget.icon),
            title: Text(widget.title(it), style: AgroText.title),
            subtitle: sub.isEmpty ? null : Text(sub, style: AgroText.muted),
            badges: widget.badge?.call(it),
            trailing: tt == null && !menu
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (tt != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(tt,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AgroText.amount),
                      ),
                    if (menu)
                      PopupMenuButton<int>(
                        tooltip: 'Opciones',
                        onSelected: (v) {
                          if (v == 0) _edit(it);
                          if (v == 1) _delete(it);
                          if (v >= 10) extras[v - 10].fn(c, it, reload);
                        },
                        itemBuilder: (_) => [
                          for (var i = 0; i < extras.length; i++)
                            _menuItem(10 + i, extras[i].label,
                                icon: extras[i].icon,
                                destructive: extras[i].destructive),
                          if (widget.canEdit) ...[
                            _menuItem(0, 'Editar', icon: Icons.edit_outlined),
                            _menuItem(1, 'Eliminar',
                                icon: Icons.delete_outline, destructive: true),
                          ],
                        ],
                      ),
                  ]),
          );
        },
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel ?? '$_nuevo ${widget.singular}'),
            )
          : null,
    );
  }
}

/// Menú "⋮" de una fila con acciones arbitrarias.
class RowMenu extends StatelessWidget {
  final List<RowAction> actions;
  final Map<String, dynamic> item;
  final VoidCallback reload;
  const RowMenu(
      {super.key,
      required this.actions,
      required this.item,
      required this.reload});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      tooltip: 'Opciones',
      onSelected: (v) => actions[v].fn(context, item, reload),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++)
          _menuItem(i, actions[i].label,
              icon: actions[i].icon, destructive: actions[i].destructive),
      ],
    );
  }
}

/// Pestañas superiores (TabBar + TabBarView).
class TabsPage extends StatelessWidget {
  final Map<String, Widget> tabs;
  final int initialIndex;
  final Map<String, IconData> tabIcons;
  const TabsPage({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.tabIcons = const {},
  });
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex.clamp(0, tabs.length - 1),
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AgroColors.surfaceLime, AgroColors.page],
            ),
            border: Border(bottom: BorderSide(color: AgroColors.mintBorder)),
          ),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding:
                const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AgroColors.primaryLight, AgroColors.brightGreen],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AgroColors.textMuted,
            dividerColor: Colors.transparent,
            tabs: [
              for (final t in tabs.keys)
                Tab(
                  height: 44,
                  icon:
                      tabIcons[t] == null ? null : Icon(tabIcons[t], size: 18),
                  text: t,
                )
            ],
          ),
        ),
        Expanded(child: TabBarView(children: tabs.values.toList())),
      ]),
    );
  }
}

/// Fila etiqueta / valor para tarjetas de detalle.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const InfoRow(this.label, this.value, {super.key, this.strong = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    color: AgroColors.textMuted, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: AgroColors.textDark)),
        ),
      ]),
    );
  }
}

/// Chips de filtro horizontales (p. ej. estados de tarea).
class FilterChips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String allLabel;
  const FilterChips(
      {super.key,
      required this.options,
      required this.selected,
      required this.onSelected,
      this.allLabel = 'Todas'});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
              label: Text(allLabel),
              selected: selected == null,
              onSelected: (_) => onSelected(null)),
        ),
        for (final o in options)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
                label: Text(o),
                selected: selected == o,
                onSelected: (_) => onSelected(selected == o ? null : o)),
          ),
      ]),
    );
  }
}
