import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'package:agrosmart_proto/services/api_client.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'package:agrosmart_proto/views/plan/plan_view.dart';

/// Asistente IA (Premium): consultas agrícolas. La conversación no se guarda.
class AsistentePage extends StatefulWidget {
  const AsistentePage({super.key});
  @override
  State<AsistentePage> createState() => _AsistentePageState();
}

class _AsistentePageState extends State<AsistentePage> {
  final _msgs = <Map<String, String>>[];
  final _in = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _premium = false;
  String? _error;

  static const _sugerencias = [
    '¿Cada cuánto debo fertilizar la palma?',
    '¿Cómo controlo la broca del café?',
    'Ideas para reducir costos de insumos',
  ];

  @override
  void dispose() {
    _in.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? texto]) async {
    final t = (texto ?? _in.text).trim();
    if (t.isEmpty || _busy) return;
    setState(() {
      _msgs.add({'role': 'user', 'content': t});
      _in.clear();
      _busy = true;
      _error = null;
    });
    _bajar();
    try {
      final txt = await chatService.enviar(_msgs);
      if (!mounted) return;
      setState(() => _msgs.add({'role': 'assistant', 'content': txt.isEmpty ? 'No obtuve respuesta, intenta de nuevo.' : txt}));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeLast();
        _in.text = t;
        if (Api.esPremiumRequerido(e)) {
          _premium = true;
        } else {
          _error = Api.errorMsg(e);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _bajar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_premium) {
      return PremiumNotice(
        message: 'El asistente IA responde dudas sobre cultivos, plagas, riego y costos de tu finca.',
        onVerPlanes: esAdmin ? () => pushPage(context, 'Plan y suscripción', const PlanPage()) : null,
      );
    }
    return Column(children: [
      Expanded(
        child: _msgs.isEmpty
            ? ListView(padding: const EdgeInsets.all(20), children: [
                const SizedBox(height: 20),
                const Center(child: AgroIconTile(icon: Icons.smart_toy, size: 64)),
                const SizedBox(height: 14),
                const Text('¿En qué te ayudo hoy?',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
                const SizedBox(height: 6),
                const Text('Pregúntame sobre cultivos, plagas, riego o costos.', textAlign: TextAlign.center, style: AgroText.muted),
                const SizedBox(height: 18),
                for (final q in _sugerencias)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AgroColors.slateBorder), backgroundColor: Colors.white),
                      onPressed: () => _send(q),
                      child: Text(q, textAlign: TextAlign.center),
                    ),
                  ),
              ])
            : ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
                for (final m in _msgs) _burbuja(m['role'] == 'user', m['content']!),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ]),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AgroAlert(icon: Icons.error_outline, message: _error!, action: 'Reintentar', onAction: () => _send()),
        ),
      SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _in,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Escribe tu pregunta…'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(tooltip: 'Enviar', onPressed: _busy ? null : () => _send(), icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }

  Widget _burbuja(bool user, String texto) => Align(
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
          decoration: BoxDecoration(
            color: user ? AgroColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: user ? null : Border.all(color: AgroColors.slateBorder),
          ),
          child: SelectableText(texto, style: TextStyle(color: user ? Colors.white : AgroColors.textDark, height: 1.4)),
        ),
      );
}
