import 'package:dio/dio.dart';

import 'api_service.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({Dio? dio}) : _dio = dio ?? createApiDio() {
    apiService = ApiService(dio: _dio);
  }

  final Dio _dio;
  late final ApiService apiService;

  Future<String> login({
    required String email,
    required String password,
  }) async {
    logout();
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final token = data is Map<String, dynamic> ? data['access_token'] : null;
      if (token is! String ||
          token.trim().isEmpty ||
          RegExp(r'\s').hasMatch(token)) {
        throw const AuthException(
          'Respons login tidak valid: access token tidak tersedia.',
        );
      }
      // Satu-satunya penyimpanan token adalah header Dio dalam memory.
      _dio.options.headers['Authorization'] = 'Bearer $token';
      return token;
    } on DioException catch (e) {
      throw AuthException(_loginErrorMessage(e));
    }
  }

  void logout() => _dio.options.headers.remove('Authorization');

  void dispose() {
    logout();
    _dio.close(force: true);
  }
}

String _loginErrorMessage(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Koneksi ke server timeout.';
    case DioExceptionType.connectionError:
      return 'Tidak dapat terhubung ke server.';
    case DioExceptionType.badResponse:
      return switch (error.response?.statusCode) {
        400 => 'Permintaan login tidak valid.',
        401 => 'Email atau password salah.',
        403 => 'Akses ditolak.',
        404 => 'Layanan login tidak ditemukan.',
        500 => 'Terjadi kesalahan pada server.',
        _ => 'Tidak dapat login. Silakan coba lagi.',
      };
    default:
      return 'Tidak dapat login. Silakan coba lagi.';
  }
}
