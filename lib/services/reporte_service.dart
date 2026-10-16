import 'package:dio/dio.dart';
import 'api_client.dart';

/// Resultado de una exportación: bytes del CSV + nombre de archivo sugerido.
class ReporteArchivo {
  final List<int> bytes;
  final String nombre;
  const ReporteArchivo(this.bytes, this.nombre);
}

/// Reportes (Premium): costos por cultivo y exportación a CSV.
class ReporteService {
  Future<List<Map<String, dynamic>>> costos({String? desde, String? hasta}) async {
    final r = await Api.i.dio.get('/api/v1/reportes/costos', queryParameters: {
      if (desde != null) 'desde': desde,
      if (hasta != null) 'hasta': hasta,
    });
    return [if (r.data is List) for (final e in r.data as List) (e as Map).cast<String, dynamic>()];
  }

  /// Descarga el CSV (el backend responde con attachment) y su nombre.
  Future<ReporteArchivo> exportar(String tipo, {String? desde, String? hasta}) async {
    final r = await Api.i.dio.get<List<int>>(
      '/api/v1/reportes/exportar',
      queryParameters: {'tipo': tipo, if (desde != null) 'desde': desde, if (hasta != null) 'hasta': hasta},
      options: Options(responseType: ResponseType.bytes),
    );
    final cd = r.headers.value('content-disposition') ?? '';
    final name = RegExp(r'filename="([^"]+)"').firstMatch(cd)?.group(1) ?? 'reporte_$tipo.csv';
    return ReporteArchivo(r.data ?? <int>[], name);
  }
}
