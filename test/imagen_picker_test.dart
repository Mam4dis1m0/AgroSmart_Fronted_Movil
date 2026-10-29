import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    as picker;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agrosmart_proto/ui/imagen.dart';

class _PickerFake extends picker.ImagePickerPlatform {
  picker.ImageSource? source;
  PlatformException? failure;
  picker.LostDataResponse lostData = picker.LostDataResponse.empty();
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  @override
  Future<picker.XFile?> getImageFromSource({
    required picker.ImageSource source,
    picker.ImagePickerOptions options = const picker.ImagePickerOptions(),
  }) async {
    this.source = source;
    if (failure != null) throw failure!;
    return picker.XFile.fromData(
      bytes,
      path: 'test${Platform.pathSeparator}evidencia.png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<picker.LostDataResponse> getLostData() async => lostData;
}

class _PickerHarness extends StatefulWidget {
  const _PickerHarness();

  @override
  State<_PickerHarness> createState() => _PickerHarnessState();
}

class _PickerHarnessState extends State<_PickerHarness> {
  String _resultado = 'Sin imagen';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Text(_resultado),
            FilledButton(
              onPressed: () async {
                final image = await elegirImagen(context);
                if (mounted && image != null) {
                  setState(() => _resultado =
                      '${image.nombre}:${image.bytes.length}:${image.mime}');
                }
              },
              child: const Text('Seleccionar'),
            ),
          ],
        ),
      );
}

void main() {
  late picker.ImagePickerPlatform original;
  late _PickerFake fake;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    fake = _PickerFake();
    original = picker.ImagePickerPlatform.instance;
    picker.ImagePickerPlatform.instance = fake;
  });

  tearDown(() {
    picker.ImagePickerPlatform.instance = original;
  });

  for (final (label, source) in [
    ('Tomar foto', picker.ImageSource.camera),
    ('Elegir de la galería', picker.ImageSource.gallery),
  ]) {
    testWidgets('$label devuelve la imagen sin errores', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _PickerHarness()));
      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fake.source, source);
      expect(find.text('evidencia.png:4:image/png'), findsOneWidget);
    });
  }

  testWidgets('un error de permisos se informa y no derriba la pantalla',
      (tester) async {
    fake.failure = PlatformException(code: 'camera_access_denied');
    await tester.pumpWidget(const MaterialApp(home: _PickerHarness()));
    await tester.tap(find.text('Seleccionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sin imagen'), findsOneWidget);
    expect(
      find.text(
          'No se pudo abrir la cámara o galería. Revisa los permisos e intenta de nuevo.'),
      findsOneWidget,
    );
  });

  test('recupera una foto si Android destruye la actividad del selector',
      () async {
    SharedPreferences.setMockInitialValues({
      'evidencia_picker_pendiente': '{"idtarea":7,"scope":"u1f1"}',
    });
    fake.lostData = picker.LostDataResponse(
      file: picker.XFile.fromData(
        fake.bytes,
        path: 'test${Platform.pathSeparator}recuperada.png',
        mimeType: 'image/png',
      ),
    );

    final result = await recuperarEvidenciaPerdida();

    expect(result?.idtarea, 7);
    expect(result?.scope, 'u1f1');
    expect(result?.imagen?.nombre, 'recuperada.png');
    expect(result?.imagen?.bytes, fake.bytes);
    expect(
      (await SharedPreferences.getInstance())
          .getString('evidencia_picker_pendiente'),
      isNull,
    );
  });
}
