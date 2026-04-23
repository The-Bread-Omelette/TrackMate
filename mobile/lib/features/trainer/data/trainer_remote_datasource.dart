import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/api_exception.dart';

class TrainerRemoteDataSource {
  final Dio dio;
  TrainerRemoteDataSource(this.dio);

  Future<Map<String, dynamic>?> getMyTrainer() async {
    try {
      // 🔥 FIX: Using ApiConstants.myTrainer so it hits /api/v1/trainer/my-trainer
      final res = await dio.get(ApiConstants.myTrainer);
      return res.data['trainer'] as Map<String, dynamic>?;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<dynamic>> getStudents() async {
    try {
      final res = await dio.get(ApiConstants.trainerStudents);
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentDetail(String id) async {
    try {
      final res = await dio.get('${ApiConstants.trainerStudents}/$id');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<dynamic>> getStudentWorkouts(String id) async {
    try {
      final res = await dio.get('${ApiConstants.trainerStudents}/$id/workouts');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentNutrition(String id) async {
    try {
      final res = await dio.get('${ApiConstants.trainerStudents}/$id/nutrition');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentStats(String id) async {
    try {
      final res = await dio.get('${ApiConstants.trainerStudents}/$id/stats');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> addNote(String traineeId, String content) async {
    try {
      await dio.post('${ApiConstants.trainerStudents}/$traineeId/notes',
          data: {'content': content});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await dio.get(ApiConstants.trainerStats);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<dynamic>> getRequests() async {
    try {
      final res = await dio.get(ApiConstants.trainerRequests);
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> respondToRequest(String requestId, bool accept) async {
    try {
      await dio.put('${ApiConstants.trainerRequests}/$requestId',
          data: {'accept': accept});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<dynamic>> getCalendar() async {
    try {
      final res = await dio.get(ApiConstants.trainerCalendar);
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  // For Trainer to book a session
  Future<void> scheduleSession(
    String studentId,
    DateTime scheduledAt,
    int duration,
    String rawNotes, {
    String? location,
    String? meetingLink,
    String? type,
  }) async {
    try {
      // 🔥 FRONTEND TRICK: Pack the extra data into the notes string so the backend doesn't reject it
      final combinedNotes = '[Type:${type ?? "online"}] [Link:${meetingLink ?? ""}] [Loc:${location ?? ""}]\n$rawNotes';

      await dio.post(
        '/api/v1/trainer/calendar/sessions',
        data: {
          'trainee_id': studentId,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'duration_minutes': duration,
          'notes': combinedNotes, // Send the packed string instead of separate fields
        },
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
// 🔥 REQUIRED FOR THE EDIT BUTTON TO WORK
  Future<void> updateSession(String sessionId, Map<String, dynamic> updates) async {
    try {
      await dio.patch('/api/v1/trainer/calendar/sessions/$sessionId', data: updates);
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
  Future<List<dynamic>> getAvailableTrainers() async {
    try {
      final res = await dio.get(ApiConstants.trainerAvailable);
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> sendTrainerRequest(String trainerId, String goal) async {
    try {
      await dio.post(ApiConstants.trainerRequest,
          data: {'trainer_id': trainerId, 'goal': goal});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  // For Trainee to get their notes
  Future<List<dynamic>> getMyNotes() async {
    try {
      final res = await dio.get('${ApiConstants.apiVersion}/trainer/my-notes');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}