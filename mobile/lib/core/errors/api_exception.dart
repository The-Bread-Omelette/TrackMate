import 'package:dio/dio.dart';
import 'failures.dart';

Failure mapDioError(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return const NetworkFailure();
  }

  final statusCode = e.response?.statusCode;
  final detail = e.response?.data?['detail'] ?? '';

  switch (statusCode) {
    case 401:
      return AuthFailure(detail.toString().isNotEmpty ? detail.toString() : 'Invalid credentials');
    case 403:
      return ForbiddenFailure(detail.toString().isNotEmpty ? detail.toString() : 'Access denied');
    case 409:
      return ConflictFailure(detail.toString().isNotEmpty ? detail.toString() : 'Account already exists');
    case 422:
      // Extract first validation error message
      final errors = e.response?.data?['detail'];
      if (errors is List && errors.isNotEmpty) {
        final msg = errors[0]['msg'] ?? 'Validation error';
        return AuthFailure(msg.toString());
      }
      return const AuthFailure('Validation error');
    default:
      return const ServerFailure();
  }
}
