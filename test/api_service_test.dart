import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product.dart';
import 'package:inventory_api_app/services/api_service.dart';

import 'fixtures/product_fixture.dart';

void main() {
  late Dio dio;
  late ApiService service;
  late List<RequestOptions> requests;
  dynamic responseBody;
  late int status;
  DioExceptionType? errorType;

  setUp(() {
    requests = [];
    responseBody = null;
    status = 200;
    errorType = null;
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final response = Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: responseBody,
          );
          if (errorType != null) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: errorType!,
              ),
            );
          } else {
            handler.resolve(response);
          }
        },
      ),
    );
    service = ApiService(dio: dio);
  });

  tearDown(() => dio.close(force: true));

  test('GET mengirim search, offset, limit, dan urutan stabil', () async {
    responseBody = {'data': []};
    await service.getProducts(limit: 11, offset: 10, search: '  Buku  ');
    expect(requests.single.queryParameters, {
      'limit': 11,
      'offset': 10,
      'sort': 'id',
      'search': 'Buku',
    });
  });

  test('Pagination invalid ditolak sebelum request', () async {
    await expectLater(
      service.getProducts(limit: 0),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      service.getProducts(offset: -1),
      throwsA(isA<ApiException>()),
    );
    expect(requests, isEmpty);
  });

  test('GET mem-parsing data dan menerima list kosong', () async {
    responseBody = {
      'data': [productFixture, nullableProductFixture],
    };
    final products = await service.getProducts();
    expect(products, hasLength(2));
    expect(products.first.price, 7500000.0);
    expect(products.first.quantity, 5);
    expect(products.first.imageUrl, 'asset-id');
    expect(products.last.price, isNull);
    expect(products.last.quantity, isNull);
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/items/products');
    responseBody = {'data': []};
    expect(await service.getProducts(), isEmpty);
  });

  test('GET menolak envelope dan item yang salah', () async {
    for (final body in [
      null,
      [],
      {},
      {'data': {}},
      {
        'data': [42],
      },
    ]) {
      responseBody = body;
      await expectLater(service.getProducts(), throwsA(isA<ApiException>()));
    }
  });

  test(
    'POST, PATCH, DELETE memakai endpoint dan payload yang sesuai',
    () async {
      const product = Product(id: '7', name: 'Buku', price: 2500);
      responseBody = {
        'data': {'id': 7, 'name': 'Buku', 'price': 2500},
      };
      expect((await service.createProduct(product))?.id, '7');
      expect((await service.updateProduct('7', product))?.name, 'Buku');
      status = 204;
      responseBody = null;
      await service.deleteProduct('7');
      expect(requests.map((r) => r.method), ['POST', 'PATCH', 'DELETE']);
      expect(requests.map((r) => r.path), [
        '/items/products',
        '/items/products/7',
        '/items/products/7',
      ]);
      expect(requests.first.data, {'name': 'Buku', 'price': '2500'});
      expect(requests[1].data, requests.first.data);
    },
  );

  test('Respons single item salah ditolak; 204 menghasilkan null', () async {
    for (final body in [
      {},
      {'data': []},
      {'data': null},
    ]) {
      responseBody = body;
      await expectLater(
        service.createProduct(const Product()),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.updateProduct('7', const Product()),
        throwsA(isA<ApiException>()),
      );
    }
    status = 204;
    responseBody = null;
    expect(await service.createProduct(const Product()), isNull);
    expect(await service.updateProduct('7', const Product()), isNull);
  });

  test('Setiap operasi meneruskan pesan error HTTP untuk UI', () async {
    errorType = DioExceptionType.badResponse;
    const messages = {
      400: '400: Data tidak valid',
      401: '401: Sesi tidak valid atau Anda belum login.',
      403: '403: Tidak memiliki izin',
      404: '404: Data tidak ditemukan',
      500: '500: Server bermasalah',
      503: 'Permintaan gagal (HTTP 503).',
    };
    for (final entry in messages.entries) {
      status = entry.key;
      final error = isA<ApiException>().having(
        (e) => e.message,
        'status HTTP',
        entry.value,
      );
      await expectLater(service.getProducts(), throwsA(error));
      await expectLater(service.createProduct(const Product()), throwsA(error));
      await expectLater(
        service.updateProduct('7', const Product()),
        throwsA(error),
      );
      await expectLater(service.deleteProduct('7'), throwsA(error));
    }
  });

  test('Timeout dan koneksi gagal memiliki pesan berbeda', () async {
    final messages = <String>{};
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      errorType = type;
      await expectLater(
        service.getProducts(),
        throwsA(
          isA<ApiException>().having(
            (e) {
              messages.add(e.message);
              return e.message;
            },
            'pesan',
            isNotEmpty,
          ),
        ),
      );
    }
    expect(messages, hasLength(4));
  });

  test('POST/PATCH menerima HTTP sukses dengan body kosong', () async {
    for (final code in [200, 201, 204]) {
      status = code;
      for (final body in [null, '', '  ']) {
        responseBody = body;
        expect(await service.createProduct(const Product()), isNull);
        expect(await service.updateProduct('uuid', const Product()), isNull);
      }
    }
  });

  test('ID kosong ditolak sebelum PATCH atau DELETE', () async {
    for (final id in ['', '   ']) {
      await expectLater(
        service.updateProduct(id, const Product()),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.deleteProduct(id),
        throwsA(isA<ApiException>()),
      );
    }
    expect(requests, isEmpty);
  });
}
