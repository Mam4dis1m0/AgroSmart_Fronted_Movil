import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/providers/app_providers.dart';
import 'package:agrosmart_proto/services/contadores.dart';
import 'package:agrosmart_proto/services/socket_service.dart';
import 'package:agrosmart_proto/theme.dart';
import 'package:agrosmart_proto/ui/design.dart';
import 'package:agrosmart_proto/ui/widgets.dart';
import 'hilo_view.dart';

Future<void> abrirBandeja(BuildContext c) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => const BandejaPage()));

/// Abre (o crea) la conversación con el vendedor de una oferta.
Future<void> chatearConVendedor(BuildContext c, int idlistado, {int? idorden}) async {
  final hilo = await cargar(c, () => mensajeriaService.abrirHilo(idlistado, idorden: idorden));
  if (hilo == null || !c.mounted) return;
  await Navigator.of(c).push(MaterialPageRoute(builder: (_) => HiloPage(hilo: hilo)));
}

/// Bandeja de conversaciones del Marketplace.
class BandejaPage extends StatefulWidget {
  const BandejaPage({super.key});
  @override
  State<BandejaPage> createState() => _BandejaPageState();
}

class _BandejaPageState extends State<BandejaPage> {
  final _k = GlobalKey<AsyncListState>();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = socketService.nuevos.listen((_) => _k.currentState?.reload());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: AsyncList(
        key: _k,
        loader: mensajeriaService.hilos,
        empty: 'Aún no tienes conversaciones.\nAbre una oferta del catálogo y toca «Chatear con el vendedor».',
        emptyIcon: Icons.chat_bubble_outline,
        itemBuilder: (c, h, reload) {
          final noLeidos = n(h['noLeidos']).round();
          final foto = s(h['foto']);
          final yoEscribi = h['ultimoRemitente'] != null && h['ultimoRemitente'] != h['otroId'];
          return AgroListCard(
            tint: noLeidos > 0 ? AgroColors.warningSoft : null,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 48,
                height: 48,
                child: foto.isEmpty
                    ? const AgroIconTile(icon: Icons.storefront)
                    : Image.network(foto, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const AgroIconTile(icon: Icons.storefront)),
              ),
            ),
            title: Text(s(h['otroNombre']).isEmpty ? 'Usuario' : s(h['otroNombre']),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AgroText.title),
            subtitle: Text(
              '${s(h['titulo'])}\n${yoEscribi ? 'Tú: ' : ''}${s(h['ultimoContenido'])}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: noLeidos > 0 ? AgroColors.textDark : AgroColors.textMuted,
                fontWeight: noLeidos > 0 ? FontWeight.w700 : FontWeight.w600,
                height: 1.35,
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fecha(h['ultimoMensajeAt']), style: const TextStyle(fontSize: 12, color: AgroColors.textMuted)),
                const SizedBox(height: 6),
                if (noLeidos > 0) Badge(label: Text('$noLeidos'), backgroundColor: AgroColors.primary),
              ]),
            ),
            onTap: () async {
              await Navigator.of(c).push(MaterialPageRoute(builder: (_) => HiloPage(hilo: h)));
              reload();
              contadores.refrescar();
            },
          );
        },
      ),
    );
  }
}
