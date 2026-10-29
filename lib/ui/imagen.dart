import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _evidenciaPickerPendiente = 'evidencia_picker_pendiente';
const _limiteEvidencia = 10 * 1024 * 1024;

class ImagenElegida {
  final Uint8List bytes;
  final String nombre;
  final String mime;
  const ImagenElegida(this.bytes, this.nombre, this.mime);

  String get dataUrl => 'data:$mime;base64,${base64Encode(bytes)}';
}

/// Fotos elegidas para completar tareas, aún no enviadas (en memoria, por sesión).
class EvidenciaPendiente {
  static final Map<int, ImagenElegida> _fotos = {};
  static ImagenElegida? de(int idtarea) => _fotos[idtarea];
  static void poner(int idtarea, ImagenElegida img) => _fotos[idtarea] = img;
  static void quitar(int idtarea) => _fotos.remove(idtarea);
}

String _mime(String nombre) {
  final n = nombre.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}

class EvidenciaPerdida {
  final int idtarea;
  final String scope;
  final ImagenElegida? imagen;
  final String? error;

  const EvidenciaPerdida({
    required this.idtarea,
    required this.scope,
    this.imagen,
    this.error,
  });
}

Future<EvidenciaPerdida?> recuperarEvidenciaPerdida() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_evidenciaPickerPendiente);
  if (raw == null) return null;

  final Map<String, dynamic> intent;
  try {
    intent = (jsonDecode(raw) as Map).cast<String, dynamic>();
  } catch (error) {
    debugPrint(
        'No se pudo leer la solicitud de recuperación de imagen: $error');
    await prefs.remove(_evidenciaPickerPendiente);
    return null;
  }
  final idtarea = (intent['idtarea'] as num?)?.toInt();
  final scope = intent['scope'] as String?;
  if (idtarea == null || scope == null) {
    await prefs.remove(_evidenciaPickerPendiente);
    return null;
  }
  try {
    final response = await ImagePicker().retrieveLostData();
    if (response.exception != null) {
      return EvidenciaPerdida(
        idtarea: idtarea,
        scope: scope,
        error:
            'No se pudo recuperar la foto seleccionada. Intenta tomarla de nuevo.',
      );
    }
    final file = response.file ??
        (response.files == null || response.files!.isEmpty
            ? null
            : response.files!.last);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > _limiteEvidencia) {
      return EvidenciaPerdida(
        idtarea: idtarea,
        scope: scope,
        error:
            'La foto recuperada supera el límite de 10 MB. Tómala de nuevo con menor resolución.',
      );
    }
    final nombre = file.name.isEmpty ? 'foto.jpg' : file.name;
    return EvidenciaPerdida(
      idtarea: idtarea,
      scope: scope,
      imagen: ImagenElegida(bytes, nombre, file.mimeType ?? _mime(nombre)),
    );
  } catch (error) {
    return EvidenciaPerdida(
      idtarea: idtarea,
      scope: scope,
      error:
          'No se pudo recuperar la foto seleccionada. Intenta tomarla de nuevo.',
    );
  } finally {
    await prefs.remove(_evidenciaPickerPendiente);
  }
}

/// Pide una imagen: en el celular deja elegir cámara o galería; en web abre el selector de archivos.
Future<ImagenElegida?> elegirImagen(
  BuildContext c, {
  double maxWidth = 1600,
  bool allowWebCamera = false,
  int? evidenciaTarea,
  String? scope,
  int? maxBytes,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(c);
  SharedPreferences? prefs;
  try {
    ImageSource? fuente = ImageSource.gallery;
    if (!kIsWeb || allowWebCamera) {
      fuente = await showModalBottomSheet<ImageSource>(
        context: c,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        ),
      );
      if (fuente == null) return null;
    }
    if (evidenciaTarea != null) {
      prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _evidenciaPickerPendiente,
        jsonEncode({'idtarea': evidenciaTarea, 'scope': scope ?? ''}),
      );
    }
    final x = await ImagePicker().pickImage(
      source: fuente,
      maxWidth: maxWidth,
      maxHeight: maxWidth,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (maxBytes != null && bytes.lengthInBytes > maxBytes) {
      _avisar(messenger,
          'La imagen supera el tamaño máximo de ${maxBytes ~/ (1024 * 1024)} MB. Elige otra foto.');
      return null;
    }
    final nombre = x.name.isEmpty ? 'foto.jpg' : x.name;
    return ImagenElegida(bytes, nombre, x.mimeType ?? _mime(nombre));
  } on PlatformException catch (error) {
    debugPrint('No se pudo abrir la cámara o galería: $error');
    _avisar(messenger,
        'No se pudo abrir la cámara o galería. Revisa los permisos e intenta de nuevo.');
    return null;
  } catch (error) {
    debugPrint('No se pudo cargar la imagen seleccionada: $error');
    _avisar(messenger, 'No se pudo cargar la imagen. Intenta elegir otra.');
    return null;
  } finally {
    if (prefs != null) await prefs.remove(_evidenciaPickerPendiente);
  }
}

void _avisar(ScaffoldMessengerState? messenger, String mensaje) {
  if (messenger?.mounted ?? false) {
    messenger!.showSnackBar(SnackBar(content: Text(mensaje)));
  }
}
