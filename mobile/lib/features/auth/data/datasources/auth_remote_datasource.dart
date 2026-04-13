import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/errors/failures.dart';
import '../models/auth_models.dart';

abstract class AuthRemoteDataSource {
  Future<void> register({
    required String email,
    required String password,
  required String fullName,
    required bool applyAsTrainer,
  });

  Future<UserModel> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<UserModel> getCurrentUser();  // ADD THIS

  Future<UserModel> verifyEmail({required String email, required String otp});

  Future<void> resendVerification({required String email});
  Future<void> forgotPassword(String email);
  
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl(this.dio);


  @override
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required bool applyAsTrainer,
  }) async {
    try {
      await dio.post(ApiConstants.register, data: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'apply_as_trainer': applyAsTrainer,
      });
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
    Future<UserModel> login({
      required String email,
      required String password
    }) async {
      try {
        final response = await dio.post(ApiConstants.login, data: {
          'email': email,
          'password': password
        });
        return UserModel.fromJson(response.data as Map<String, dynamic>);
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

  
  @override
  Future<void> resendVerification({required String email}) async {
    try {
      await dio.post(ApiConstants.resendVerification, data: {'email': email});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
    Future<UserModel> verifyEmail({
      required String email,
      required String otp,
    }) async {
      try {
        final response = await dio.post(ApiConstants.verifyEmail, data: {
          'email': email,
          'otp': otp,
        });

        return UserModel.fromJson(response.data as Map<String, dynamic>);
      } on DioException catch (e) {
        throw mapDioError(e);
      }
    }
  @override
  Future<void> forgotPassword(String email) async {
    try {
      await dio.post('/api/v1/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await dio.post('/api/v1/auth/reset-password', data: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
