import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    return "https://trackmate-tgmy.onrender.com";
  }

  static const String apiVersion = '/api/v1';

  // Auth
  static const String register = '$apiVersion/auth/register';
  static const String login = '$apiVersion/auth/login';
  static const String logout = '$apiVersion/auth/logout';
  static const String refresh = '$apiVersion/auth/refresh';
  static const String me = '$apiVersion/auth/me';
  static const String verifyEmail = '$apiVersion/auth/verify-email';
  static const String resendVerification = '$apiVersion/auth/resend-verification';

  // Profile
  static const String profile = '$apiVersion/profile/me';
  static const String biometrics = '$apiVersion/profile/me/biometrics';
  static const String userSearch = '$apiVersion/profile/users/search';

  // Trainer
  static const String trainerApply = '$apiVersion/trainer/apply';
  static const String trainerAvailable = '$apiVersion/trainer/available';
  static const String trainerRequest = '$apiVersion/trainer/request';
  static const String myTrainer = '$apiVersion/trainer/my-trainer';
  static const String mySessions = '$apiVersion/trainer/my-sessions';
  static const String trainerStudents = '$apiVersion/trainer/students';
  static const String trainerStats = '$apiVersion/trainer/stats';
  static const String trainerRequests = '$apiVersion/trainer/requests';
  static const String trainerCalendar = '$apiVersion/trainer/calendar';
  static const String trainerCalendarSessions = '$apiVersion/trainer/calendar/sessions';

  // Admin
  static const String adminStats = '$apiVersion/admin/stats';
  static const String adminUsers = '$apiVersion/admin/users';
  static const String adminTrainerApplications = '$apiVersion/admin/trainer-applications';
  static const String adminReports = '$apiVersion/admin/reports';
  static const String adminFlaggedMessages = '$apiVersion/admin/reports/flagged-messages';

  // Messaging
  static const String conversations = '$apiVersion/messaging/conversations';
  static const String wsTicket = '$apiVersion/messaging/ws-ticket';
  static const String presence = '$apiVersion/messaging/users';

  // Social
  static const String friends = '$apiVersion/social/friends';
  static const String friendRequests = '$apiVersion/social/friends/requests';
  static const String feed = '$apiVersion/social/feed';
  static const String posts = '$apiVersion/social/posts';
  static const String leaderboard = '$apiVersion/social/leaderboard';
  static const String reportMessage = '$apiVersion/social/report/message';

  // Notifications
  static const String notifications = '$apiVersion/notifications';

  // Fitness
  static const String exercises = '$apiVersion/fitness/exercises';
  static const String workoutSessions = '$apiVersion/fitness/workouts/sessions';
  static const String workoutSets = '$apiVersion/fitness/workouts/sets';
  static const String foodSearch = '$apiVersion/fitness/foods/search';
  static const String meals = '$apiVersion/fitness/nutrition/meals';
  static const String nutritionSummary = '$apiVersion/fitness/nutrition/summary';
  static const String steps = '$apiVersion/fitness/steps';
  static const String stepsSummary = '$apiVersion/fitness/steps/summary';
  static const String stepsHistory = '$apiVersion/fitness/steps/history';
  static const String stepsStreak = '$apiVersion/fitness/steps/streak';
  static const String hydration = '$apiVersion/fitness/hydration';
  static const String hydrationSummary = '$apiVersion/fitness/hydration/summary';
  static const String weight = '$apiVersion/fitness/weight';
  static const String weightTrend = '$apiVersion/fitness/weight/trend';
  static const String weeklyStats = '$apiVersion/fitness/stats/weekly';
  static const String clearData = '$apiVersion/fitness/data/clear';
}