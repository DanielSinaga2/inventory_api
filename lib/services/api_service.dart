import 'package:dio/dio.dart';

import '../models/product.dart';
import '../models/product_image.dart';

Dio createApiDio() => Dio(
  BaseOptions(
    baseUrl: 'https://pos.cicd.web.id',
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ),
);

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  // AuthService memasok Dio yang sama untuk seluruh operasi produk.
  ApiService({Dio? dio}) : _dio = dio ?? createApiDio();

  final Dio _dio;
  static const _productsPath = '/items/products';

  Future<String> uploadProductImage(
    ProductImage image, {
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/files',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            image.bytes,
            filename: image.filename,
            contentType: DioMediaType.parse(image.mimeType),
          ),
        }),
        onSendProgress: onSendProgress,
      );
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final id = data is Map<String, dynamic> ? data['id'] : null;
      if (id is! String || id.trim().isEmpty) {
        throw const ApiException(
          'Upload selesai tetapi ID gambar tidak tersedia.',
        );
      }
      return id;
    } on DioException catch (e) {
      throw ApiException('Gagal mengunggah gambar. ${getErrorMessage(e)}');
    }
  }

  Future<List<Product>> getProducts({
    int? limit,
    int offset = 0,
    String search = '',
  }) async {
    if ((limit != null && limit < 1) || offset < 0) {
      throw const ApiException('Parameter halaman produk tidak valid.');
    }
    try {
      final response = await _dio.get<dynamic>(
        _productsPath,
        queryParameters: {
          'limit': ?limit,
          if (offset > 0) 'offset': offset,
          'sort': 'id',
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );
      final body = response.data;
      if (body is! Map<String, dynamic> || body['data'] is! List) {
        throw const ApiException(
          'Format response produk tidak valid: diharapkan objek dengan data berupa list.',
        );
      }

      final items = body['data'] as List;
      return items.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const ApiException(
            'Format response produk tidak valid: setiap item harus berupa objek JSON.',
          );
        }
        return Product.fromJson(item);
      }).toList();
    } on DioException catch (e) {
      throw ApiException(getErrorMessage(e));
    }
  }

  Future<Product?> createProduct(Product product) async {
    try {
      final response = await _dio.post<dynamic>(
        _productsPath,
        data: product.toJson(),
      );
      return _parseProductResponse(response);
    } on DioException catch (e) {
      throw ApiException(getErrorMessage(e));
    }
  }

  Future<Product?> updateProduct(String id, Product product) async {
    _validateId(id);
    try {
      final response = await _dio.patch<dynamic>(
        '$_productsPath/${Uri.encodeComponent(id)}',
        data: product.toJson(),
      );
      return _parseProductResponse(response);
    } on DioException catch (e) {
      throw ApiException(getErrorMessage(e));
    }
  }

  Future<void> deleteProduct(String id) async {
    _validateId(id);
    try {
      await _dio.delete<dynamic>('$_productsPath/${Uri.encodeComponent(id)}');
    } on DioException catch (e) {
      throw ApiException(getErrorMessage(e));
    }
  }

  void _validateId(String id) {
    if (id.trim().isEmpty) {
      throw const ApiException(
        'ID produk tidak tersedia. Muat ulang daftar produk.',
      );
    }
  }

  Product? _parseProductResponse(Response<dynamic> response) {
    final body = response.data;
    // Respons sukses tanpa body tetap sukses; UI mengambil data lewat GET ulang.
    if (response.statusCode == 204 ||
        body == null ||
        (body is String && body.trim().isEmpty)) {
      return null;
    }
    if (body is! Map<String, dynamic> ||
        body['data'] is! Map<String, dynamic>) {
      throw const ApiException(
        'Format response produk tidak valid: diharapkan objek dengan data berupa objek produk.',
      );
    }
    return Product.fromJson(body['data'] as Map<String, dynamic>);
  }
}

String getErrorMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      return 'Waktu koneksi habis. Silakan coba lagi.';
    case DioExceptionType.sendTimeout:
      return 'Waktu pengiriman data habis. Silakan coba lagi.';
    case DioExceptionType.receiveTimeout:
      return 'Waktu menunggu response habis. Silakan coba lagi.';
    case DioExceptionType.connectionError:
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      switch (status) {
        case 400:
          return '400: Data tidak valid';
        case 401:
          return '401: Sesi tidak valid atau Anda belum login.';
        case 403:
          return '403: Tidak memiliki izin';
        case 404:
          return '404: Data tidak ditemukan';
        case 500:
          return '500: Server bermasalah';
        default:
          return 'Permintaan gagal (HTTP ${status ?? 'tidak diketahui'}).';
      }
    case DioExceptionType.cancel:
      return 'Permintaan dibatalkan.';
    case DioExceptionType.badCertificate:
      return 'Sertifikat keamanan server tidak valid.';
    default:
      return 'Terjadi kesalahan saat memproses permintaan.';
  }
}
