import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/api_exception.dart';

class MessagingRemoteDataSource {
  final Dio dio;
  MessagingRemoteDataSource(this.dio);

  // Fetches the inbox list
  Future<List<dynamic>> getConversations() async {
    try {
      final res = await dio.get(ApiConstants.conversations);
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  // Starts a new chat or fetches an existing one with a specific user
  Future<Map<String, dynamic>> startConversation(String otherUserId) async {
    try {
      final res = await dio.post(
        ApiConstants.conversations,
        data: {'other_user_id': otherUserId},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<dynamic>> getMessages(String conversationId,
      {String? before}) async {
    try {
      final res = await dio.get(
          '${ApiConstants.conversations}/$conversationId/messages',
          queryParameters: before != null ? {'before': before} : null);
      return res.data as List<dynamic>;
    } on DioException catch (e) { throw mapDioError(e); }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await dio.put(
          '${ApiConstants.conversations}/$conversationId/read');
    } on DioException catch (e) { throw mapDioError(e); }
  }

  Future<String> getWsTicket() async {
    try {
      final res = await dio.post(ApiConstants.wsTicket);
      return (res.data as Map<String, dynamic>)['ticket'] as String;
    } on DioException catch (e) { throw mapDioError(e); }
  }

  Future<Map<String, dynamic>> getPresence(String userId) async {
    try {
      final res = await dio.get('${ApiConstants.presence}/$userId/presence');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) { throw mapDioError(e); }
  }
}