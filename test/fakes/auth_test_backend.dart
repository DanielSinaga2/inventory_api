import 'dart:async';
import 'package:dio/dio.dart';

class AuthTestBackend {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  final requests = <RequestOptions>[];
  Object? loginBody = {
    'data': {'access_token': 'test-only-token'},
  };
  int status = 200;
  DioExceptionType? errorType;
  Completer<void>? pending;

  AuthTestBackend() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          if (options.path == '/auth/login') {
            if (pending != null) await pending!.future;
            if (errorType != null || status >= 400) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: errorType ?? DioExceptionType.badResponse,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: status,
                  ),
                ),
              );
              return;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: status,
                data: loginBody,
              ),
            );
          } else {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {'data': []},
              ),
            );
          }
        },
      ),
    );
  }
}
