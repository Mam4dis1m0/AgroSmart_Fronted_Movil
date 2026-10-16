import 'api_client.dart';

/// Operaciones de cuenta y sesión de usuario (registro, recuperación, perfil).
class AuthService {
  /// POST /usuarios/register
  Future<void> registrar(Map<String, dynamic> data) async {
    await Api.i.dio.post('/usuarios/register', data: data);
  }

  /// POST /usuarios/forgot-password
  Future<void> olvideContrasena(String email) async {
    await Api.i.dio.post('/usuarios/forgot-password', data: {'email': email});
  }

  /// POST /usuarios/reset-password
  Future<void> resetContrasena(Map<String, dynamic> data) async {
    await Api.i.dio.post('/usuarios/reset-password', data: data);
  }

  /// GET /usuarios/me -> mapa del usuario
  Future<Map<String, dynamic>> me() async {
    final r = await Api.i.dio.get('/usuarios/me');
    final d = (r.data as Map).cast<String, dynamic>();
    return (d['usuario'] as Map?)?.cast<String, dynamic>() ?? d;
  }

  /// GET /usuarios/{id} -> datos completos (primer/segundo nombre, cédula, teléfono…)
  Future<Map<String, dynamic>> usuario(int id) async {
    final r = await Api.i.dio.get('/usuarios/$id');
    return (r.data as Map).cast<String, dynamic>();
  }

  /// PUT /usuarios/{id}
  Future<void> actualizarUsuario(int id, Map<String, dynamic> data) async {
    await Api.i.dio.put('/usuarios/$id', data: data);
  }

  /// PUT /usuarios/{id}/password
  Future<void> cambiarContrasena(int id, Map<String, dynamic> data) async {
    await Api.i.dio.put('/usuarios/$id/password', data: data);
  }

  /// PUT /usuarios/{id}/foto-perfil  (imagen como data URL base64) -> url
  Future<String?> subirFotoPerfil(int id, String dataUrl) async {
    final r = await Api.i.dio.put('/usuarios/$id/foto-perfil', data: {'imagen': dataUrl});
    return r.data is Map ? r.data['fotoperfil']?.toString() : null;
  }

  /// GET /usuarios/comprador/perfil
  Future<Map<String, dynamic>> perfilComprador() async {
    final r = await Api.i.dio.get('/usuarios/comprador/perfil');
    return (r.data as Map).cast<String, dynamic>();
  }

  /// PUT /usuarios/comprador/ubicacion
  Future<void> actualizarUbicacionComprador(Map<String, dynamic> data) async {
    await Api.i.dio.put('/usuarios/comprador/ubicacion', data: data);
  }
}
