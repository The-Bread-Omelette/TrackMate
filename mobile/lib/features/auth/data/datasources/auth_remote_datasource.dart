import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/failures.dart';
import '../models/auth_models.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
  });

  Future<AuthResponseModel> login({
    required String email,
    required String password,
    required String role,
  });

  Future<void> logout();

  Future<UserModel> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl(this.dio);

  @override
  Future<AuthResponseModel> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      final response = await dio.post(ApiConstants.register, data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      });
      return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
        'role': role,
      });
      return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dio.post(ApiConstants.logout);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await dio.get(ApiConstants.me);
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
