import 'api_client.dart';
import '../models/produccion.dart';

/// Producción: lotes, cultivos, cosechas, palmas, producción de palma e insumos.
class ProduccionService {
  Future<List<Map<String, dynamic>>> _list(String path) async {
    final rows = await Api.i.getList(path);
    return [for (final r in rows) (r as Map).cast<String, dynamic>()];
  }

  Future<List<Lote>> lotes() async =>
      [for (final m in await _list('/lotes')) Lote.fromJson(m)];
  Future<List<Cultivo>> cultivos() async =>
      [for (final m in await _list('/cultivos')) Cultivo.fromJson(m)];
  Future<List<Cosecha>> cosechas() async =>
      [for (final m in await _list('/api/v1/cosechas')) Cosecha.fromJson(m)];
  Future<List<Palma>> palmas() async =>
      [for (final m in await _list('/palmas')) Palma.fromJson(m)];
  Future<List<ProduccionPalma>> produccionPalma() async =>
      [for (final m in await _list('/produccion-palma')) ProduccionPalma.fromJson(m)];
  Future<List<Insumo>> insumos() async =>
      [for (final m in await _list('/api/v1/insumos')) Insumo.fromJson(m)];
  Future<List<Insumo>> insumosStockBajo() async =>
      [for (final m in await _list('/api/v1/insumos/stock-bajo')) Insumo.fromJson(m)];

  /// Opciones {valor, etiqueta} para los selects de lote.
  Future<List<MapEntry<dynamic, String>>> lotesOpc() async =>
      [for (final l in await _list('/lotes')) MapEntry(l['idlote'], '${l['nombre'] ?? ''}'.isEmpty ? 'Lote #${l['idlote']}' : '${l['nombre']}')];

  /// Opciones {valor, etiqueta} para los selects de palma.
  Future<List<MapEntry<dynamic, String>>> palmasOpc() async =>
      [for (final p in await _list('/palmas')) MapEntry(p['idpalma'], '${p['codigo'] ?? ''}'.isEmpty ? 'Palma #${p['idpalma']}' : '${p['codigo']}')];

  /// Opciones {valor, etiqueta} para los selects de cultivo.
  Future<List<MapEntry<dynamic, String>>> cultivosOpc() async =>
      [for (final c in await _list('/cultivos')) MapEntry(c['idcultivo'], '${c['tipo'] ?? ''}'.isEmpty ? 'Cultivo #${c['idcultivo']}' : '${c['tipo']}')];
}
