import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart'; // <-- ADD THIS IMPORT
import '../constants/api_constants.dart';

class DioClient {
  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Browsers handle cookies automatically. 
    // We only need the CookieJar for Android/iOS/Desktop.
    if (!kIsWeb) {
      final cookieJar = CookieJar();
      dio.interceptors.add(CookieManager(cookieJar));
    }

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print(obj),
    ));

    dio.interceptors.add(_RefreshInterceptor(dio));

    return dio;
  }
}

class _RefreshInterceptor extends Interceptor {
  final Dio dio;

  _RefreshInterceptor(this.dio);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only refresh if this was an authenticated failure and it's not already a refresh attempt
    if (err.response?.statusCode == 401 && err.requestOptions.path != ApiConstants.refresh) {
      try {
        await dio.post(ApiConstants.refresh);
        // Retry original request after refreshing
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        // Fall through to original error
      }
    }
    handler.next(err);
  }
}