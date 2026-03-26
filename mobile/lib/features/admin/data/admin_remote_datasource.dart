import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/api_exception.dart';

class AdminRemoteDataSource {
  final Dio dio;
  AdminRemoteDataSource(this.dio);

  Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await dio.get(ApiConstants.adminStats);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

Future<Map<String, dynamic>> getTrainerApplications({String? status}) async {
    try {
      final res = await dio.get(ApiConstants.adminTrainerApplications,
          queryParameters: status != null ? {'status': status} : null);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

 Future<void> approveTrainer(String userId, bool approve) async {
    try {
      await dio.post(
          '${ApiConstants.adminTrainerApplications}/$userId/approve',
          // 🔥 FIX: Added 'user_id' back into the JSON payload so Pydantic stops crashing
          data: {'user_id': userId, 'approve': approve}); 
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> getReports({String? status}) async {
    try {
      final res = await dio.get(ApiConstants.adminReports,
          queryParameters: status != null ? {'status': status} : null);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> resolveReport(String reportId, {bool dismiss = false}) async {
    try {
      await dio.put('${ApiConstants.adminReports}/$reportId/resolve',
          data: {'dismiss': dismiss});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<dynamic>> getUsers({String? role, int page = 1}) async {
    try {
      final res = await dio.get(ApiConstants.adminUsers, queryParameters: {
        if (role != null) 'role': role,
        'page': page,
      });
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> toggleUserStatus(String userId, bool activate) async {
    try {
      final endpoint = activate ? 'activate' : 'deactivate';
      await dio.put('${ApiConstants.adminUsers}/$userId/$endpoint');
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}