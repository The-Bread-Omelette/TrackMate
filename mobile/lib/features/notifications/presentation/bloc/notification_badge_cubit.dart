import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/notifications_remote_datasource.dart';

class NotificationBadgeCubit extends Cubit<int> {
  final NotificationsRemoteDataSource _ds;

  NotificationBadgeCubit(this._ds) : super(0);

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _ds.getNotifications(unreadOnly: true);
      int count = 0;
      
      // Bulletproof check: handles both Lists and Maps safely
      if (res is List) {
        count = res.length;
      } else if (res is Map) {
        final list = res['notifications'] ?? res['data'] ?? res['items'] ?? [];
        count = (list as List).length;
      }
      
      emit(count);
    } catch (_) {}
  }
  
  // Instantly updates the badge when you read something inside the app
  void updateCount(int newCount) => emit(newCount);
}