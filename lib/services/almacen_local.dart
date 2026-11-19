import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento local con Hive para trabajar sin internet.
///
///  - [cache]: copia de cada lectura (GET) por usuario+finca. Clave: `scope:path:query`, valor: JSON en texto.
///  - [cola]: cambios hechos sin red, pendientes de enviar. Clave: id, valor: JSON en texto.
///
/// Hive escribe en disco por partes (SharedPreferences reescribe todo un XML en cada cambio),
/// por eso aguanta muchos más datos guardados sin volver lenta la app.
class AlmacenLocal {
  AlmacenLocal._();

  static late final Box<String> cache;
  static late final Box<String> cola;
  static bool _listo = false;

  static Future<void> init() async {
    if (_listo) return;
    await Hive.initFlutter('agrosmart');
    cache = await Hive.openBox<String>('cache');
    cola = await Hive.openBox<String>('cola_offline');
    _listo = true;
    await _migrarDesdePrefs();
  }

  /// Pasa a Hive lo que versiones anteriores guardaban en SharedPreferences (una sola vez).
  static Future<void> _migrarDesdePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('hive_migrado') == true) return;
    for (final k in p.getKeys().where((k) => k.startsWith('cache:')).toList()) {
      final v = p.getString(k);
      if (v != null) await cache.put(k.substring('cache:'.length), v);
      await p.remove(k);
    }
    final rawCola = p.getString('cola_offline');
    if (rawCola != null) {
      try {
        for (final it in (jsonDecode(rawCola) as List).cast<Map>()) {
          await cola.put(it['id'].toString(), jsonEncode(it));
        }
      } catch (_) {}
      await p.remove('cola_offline');
    }
    await p.setBool('hive_migrado', true);
  }
}
