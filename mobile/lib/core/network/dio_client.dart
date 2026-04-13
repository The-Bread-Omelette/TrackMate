import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/api_constants.dart';

class DioClient {
  static Future<Dio> create() async {
    final options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      extra: {'withCredentials': true}, 
    );

    final dio = Dio(options);
    final refreshDio = Dio(options);

    if (kDebugMode) {
      final logger = LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      );
      dio.interceptors.add(logger);
      refreshDio.interceptors.add(logger);
    }

    if (!kIsWeb) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final String path = "${appDocDir.path}/.cookies/";
      
      await Directory(path).create(recursive: true);
      
      final cookieJar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage(path),
      );

      final cookieManager = CookieManager(cookieJar);
      
      dio.interceptors.add(cookieManager);
      refreshDio.interceptors.add(cookieManager);
    } else {
      debugPrint("[Dio] Web environment detected: Using native browser cookie management.");
    }

    dio.interceptors.add(_CookieRefreshInterceptor(refreshDio));

    return dio;
  }
}

class _CookieRefreshInterceptor extends QueuedInterceptor {
  final Dio _refreshDio; // Uses the separate instance
  
  _CookieRefreshInterceptor(this._refreshDio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && err.requestOptions.path != ApiConstants.refresh) {
      try {
        final refreshResponse = await _refreshDio.post(ApiConstants.refresh);

        if (refreshResponse.statusCode == 200 || refreshResponse.statusCode == 204) {
          final response = await _refreshDio.fetch(err.requestOptions);
          return handler.resolve(response);
        }
      } catch (e) {
        debugPrint("[Auth] Token refresh failed: $e");
      }
    }
    return handler.next(err);
  }
}