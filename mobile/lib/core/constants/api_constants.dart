import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Dynamically switch the URL based on the platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000'; // Chrome/Edge Web
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // Android Emulator
    }
    return 'http://127.0.0.1:8000'; // iOS Simulator / Desktop
  }

  static const String apiVersion = '/api/v1';

  // Auth endpoints
  static const String register = '$apiVersion/auth/register';
  static const String login = '$apiVersion/auth/login';
  static const String logout = '$apiVersion/auth/logout';
  static const String refresh = '$apiVersion/auth/refresh';
  static const String me = '$apiVersion/auth/me';

  // Token storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
}