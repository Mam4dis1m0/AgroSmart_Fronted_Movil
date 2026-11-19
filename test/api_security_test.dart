import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrosmart_proto/services/api_client.dart';

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('envía el JWT como token Bearer', () async {
    final dio = Api.i.dio;
    final originalAdapter = dio.httpClientAdapter;
    final originalBaseUrl = dio.options.baseUrl;
    final adapter = _CaptureAdapter();
    Api.i.token = 'fake-test-token';
    dio.options.baseUrl = 'https://api.example.test';
    dio.httpClientAdapter = adapter;

    try {
      await dio.get('/protected');
      expect(
          adapter.request?.headers['Authorization'], 'Bearer fake-test-token');
    } finally {
      Api.i.token = null;
      dio.options.baseUrl = originalBaseUrl;
      dio.httpClientAdapter = originalAdapter;
    }
  });
}
