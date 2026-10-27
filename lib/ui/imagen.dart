import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagenElegida {
  final Uint8List bytes;
  final String nombre;
  final String mime;
  const ImagenElegida(this.bytes, this.nombre, this.mime);

  String get dataUrl => 'data:$mime;base64,${base64Encode(bytes)}';
}

String _mime(String nombre) {
  final n = nombre.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Pide una imagen: en el celular deja elegir cámara o galería; en web abre el selector de archivos.
Future<ImagenElegida?> elegirImagen(
  BuildContext c, {
  double maxWidth = 1600,
  bool allowWebCamera = false,
}) async {
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
  final x = await ImagePicker().pickImage(source: fuente, maxWidth: maxWidth, imageQuality: 80);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final nombre = x.name.isEmpty ? 'foto.jpg' : x.name;
  return ImagenElegida(bytes, nombre, x.mimeType ?? _mime(nombre));
}
