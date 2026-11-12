import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const secureStorage = FlutterSecureStorage();

Future<void> migrateLegacyPrivateStorage() async {
  final preferences = await SharedPreferences.getInstance();
  final keys = preferences.getKeys().where((key) {
    return key == 'session' ||
        key == 'logins_locales' ||
        key == 'cola_offline' ||
        key.startsWith('cache:') ||
        key.startsWith('adj:');
  }).toList();

  for (final key in keys) {
    final oldValue = preferences.get(key);
    if (oldValue == null) continue;

    final value = oldValue is String ? oldValue : jsonEncode(oldValue);
    final currentValue = await secureStorage.read(key: key);
    if (currentValue == null) {
      await secureStorage.write(key: key, value: value);
    }
    await preferences.remove(key);
  }
}
