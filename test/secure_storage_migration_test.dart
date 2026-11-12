import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrosmart_proto/services/secure_storage.dart';

void main() {
  test('migra datos privados y conserva las preferencias no sensibles',
      () async {
    SharedPreferences.setMockInitialValues({
      'session': '{"token":"test"}',
      'cache:user:/profile:{}': '{"nombre":"Prueba"}',
      'cola_offline': '[{"path":"/test"}]',
      'adj:user:threads': ['7', '8'],
      'api_url': 'https://api.example.test',
    });
    FlutterSecureStorage.setMockInitialValues({});

    await migrateLegacyPrivateStorage();

    final preferences = await SharedPreferences.getInstance();
    expect(await secureStorage.read(key: 'session'), '{"token":"test"}');
    expect(await secureStorage.read(key: 'cache:user:/profile:{}'),
        '{"nombre":"Prueba"}');
    expect(await secureStorage.read(key: 'cola_offline'), '[{"path":"/test"}]');
    expect(await secureStorage.read(key: 'adj:user:threads'), '["7","8"]');
    expect(preferences.containsKey('session'), isFalse);
    expect(preferences.containsKey('cache:user:/profile:{}'), isFalse);
    expect(preferences.getString('api_url'), 'https://api.example.test');
  });

  test('no reemplaza el registro seguro existente', () async {
    SharedPreferences.setMockInitialValues({'session': 'legado'});
    FlutterSecureStorage.setMockInitialValues({'session': 'actual'});

    await migrateLegacyPrivateStorage();

    final preferences = await SharedPreferences.getInstance();
    expect(await secureStorage.read(key: 'session'), 'actual');
    expect(preferences.containsKey('session'), isFalse);
  });
}
