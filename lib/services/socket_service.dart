import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:agrosmart_proto/providers/session_provider.dart';
import 'api_client.dart';
import 'contadores.dart';
import 'demo/demo_data.dart';

/// Conexión Socket.IO al namespace /mercado: el backend solo EMPUJA eventos
/// (mensaje nuevo / leído); enviar y leer siempre van por REST.
class SocketService {
  io.Socket? _socket;
  String? _token;

  final _nuevos = StreamController<Map<String, dynamic>>.broadcast();
  final _leidos = StreamController<Map<String, dynamic>>.broadcast();

  /// `{ idhilo, mensaje: { idmensaje, idremitente, mio, contenido, createdAt, leidoAt } }`
  Stream<Map<String, dynamic>> get nuevos => _nuevos.stream;

  /// `{ idhilo, hasta, por }`: el otro leyó hasta ese idmensaje.
  Stream<Map<String, dynamic>> get leidos => _leidos.stream;

  final ValueNotifier<bool> conectado = ValueNotifier(false);

  bool get _habilitado =>
      !kDemoMode && session.logged && (session.esComprador || (esAdmin && session.idfinca != null));

  /// Se llama en cada cambio de sesión: conecta, reconecta con el token nuevo o desconecta.
  void sync() {
    final t = Api.i.token;
    if (!_habilitado || t == null) return _cerrar();
    if (t == _token && _socket != null) return;
    _cerrar();
    _token = t;
    final s = io.io(
      '${Api.i.baseUrl}/mercado',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': t})
          .disableAutoConnect()
          .enableReconnection()
          .enableForceNew()
          .build(),
    );
    s.onConnect((_) => conectado.value = true);
    s.onDisconnect((_) => conectado.value = false);
    s.on('mensaje:nuevo', (d) {
      if (d is! Map) return;
      final m = d.cast<String, dynamic>();
      _nuevos.add(m);
      final msg = m['mensaje'];
      if (msg is Map && msg['mio'] != true) contadores.mensajes.value++;
    });
    s.on('mensaje:leido', (d) {
      if (d is Map) _leidos.add(d.cast<String, dynamic>());
    });
    s.on('error:auth', (_) => _cerrar());
    s.connect();
    _socket = s;
  }

  void _cerrar() {
    _socket?.dispose();
    _socket = null;
    _token = null;
    conectado.value = false;
  }
}

final socketService = SocketService();
