import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product_image.dart';
import 'package:inventory_api_app/services/api_service.dart';
import 'fixtures/image_fixture.dart';

void main() {
  test('File kosong, non-gambar, dan ukuran berlebih ditolak', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      Uint8List(ProductImage.maxBytes + 1),
    ]) {
      expect(
        () => ProductImage.fromBytes(bytes, 'foto.png'),
        throwsFormatException,
      );
    }
    expect(
      ProductImage.fromBytes(imageFixture(), 'foto.png').mimeType,
      'image/png',
    );
  });

  test('Upload memakai multipart file dan mengambil ID server', () async {
    final dio = Dio();
    addTearDown(() => dio.close());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'POST');
          expect(options.path, '/files');
          final file = (options.data as FormData).files.single;
          expect(file.key, 'file');
          expect(file.value.filename, 'foto.png');
          expect(file.value.contentType.toString(), 'image/png');
          expect(file.value.length, imageFixture().length);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {'id': 'new-image-uuid'},
              },
            ),
          );
        },
      ),
    );
    expect(
      await ApiService(
        dio: dio,
      ).uploadProductImage(ProductImage.fromBytes(imageFixture(), 'foto.png')),
      'new-image-uuid',
    );
  });

  test('Respons upload tanpa ID ditolak', () async {
    final dio = Dio();
    addTearDown(() => dio.close());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': {}},
            ),
          );
        },
      ),
    );
    await expectLater(
      ApiService(
        dio: dio,
      ).uploadProductImage(ProductImage.fromBytes(imageFixture(), 'foto.png')),
      throwsA(isA<ApiException>()),
    );
  });

  test('Akses upload ditolak memiliki pesan jelas', () async {
    final dio = Dio();
    addTearDown(() => dio.close());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: options, statusCode: 403),
            ),
          );
        },
      ),
    );
    await expectLater(
      ApiService(
        dio: dio,
      ).uploadProductImage(ProductImage.fromBytes(imageFixture(), 'foto.png')),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'pesan',
          contains('403: Tidak memiliki izin'),
        ),
      ),
    );
  });
}
