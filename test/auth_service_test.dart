import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product.dart';
import 'package:inventory_api_app/models/product_image.dart';
import 'package:inventory_api_app/services/auth_service.dart';
import 'package:inventory_api_app/services/api_service.dart';
import 'fakes/auth_test_backend.dart';
import 'fixtures/image_fixture.dart';

void main() {
  late AuthTestBackend backend;
  late AuthService auth;
  setUp(() {
    backend = AuthTestBackend();
    auth = AuthService(dio: backend.dio);
  });
  tearDown(() => auth.dispose());

  Future<String> login() => auth.login(
    email: ' student@example.invalid ',
    password: ' test-password ',
  );

  test(
    'Login POST memakai input dan token dipasang pada seluruh operasi produk',
    () async {
      expect(await login(), 'test-only-token');
      final request = backend.requests.single;
      expect(request.path, '/auth/login');
      expect(request.method, 'POST');
      expect(request.data, {
        'email': 'student@example.invalid',
        'password': ' test-password ',
      });
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(await auth.apiService.getProducts(), isEmpty);
      // Fake mengembalikan envelope list: operasi tetap dikirim, parsing menolaknya.
      await expectLater(
        auth.apiService.createProduct(const Product()),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        auth.apiService.updateProduct('7', const Product()),
        throwsA(isA<ApiException>()),
      );
      await auth.apiService.deleteProduct('7');
      await expectLater(
        auth.apiService.uploadProductImage(
          ProductImage.fromBytes(imageFixture(), 'test.png'),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(backend.requests.skip(1).map((r) => r.method), [
        'GET',
        'POST',
        'PATCH',
        'DELETE',
        'POST',
      ]);
      for (final request in backend.requests.skip(1)) {
        expect(request.headers['Authorization'], 'Bearer test-only-token');
      }
      auth.logout();
      expect(backend.dio.options.headers.containsKey('Authorization'), isFalse);
      await auth.apiService.getProducts();
      expect(
        backend.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  test('Respons token invalid ditolak dan token lama dibersihkan', () async {
    for (final body in [
      null,
      [],
      {},
      {'data': []},
      {'data': {}},
      {
        'data': {'access_token': ''},
      },
      {
        'data': {'access_token': '  '},
      },
      {
        'data': {'access_token': 9},
      },
    ]) {
      backend.dio.options.headers['Authorization'] = 'Bearer old-test-token';
      backend.loginBody = body;
      await expectLater(login(), throwsA(isA<AuthException>()));
      expect(backend.dio.options.headers.containsKey('Authorization'), isFalse);
    }
  });

  for (final entry in {
    400: 'Permintaan login tidak valid.',
    401: 'Email atau password salah.',
    403: 'Akses ditolak.',
    404: 'Layanan login tidak ditemukan.',
    500: 'Terjadi kesalahan pada server.',
    503: 'Tidak dapat login. Silakan coba lagi.',
  }.entries) {
    test('Login HTTP ${entry.key}', () async {
      backend.status = entry.key;
      await expectLater(
        login(),
        throwsA(
          isA<AuthException>().having((e) => e.message, 'pesan', entry.value),
        ),
      );
      expect(backend.dio.options.headers.containsKey('Authorization'), isFalse);
    });
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('Login gagal $type', () async {
      backend.errorType = type;
      await expectLater(
        login(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'pesan',
            type == DioExceptionType.connectionError
                ? 'Tidak dapat terhubung ke server.'
                : 'Koneksi ke server timeout.',
          ),
        ),
      );
    });
  }
}
