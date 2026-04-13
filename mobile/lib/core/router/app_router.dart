import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/check_email_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../shared/pages/dashboard_page.dart';
import '../../shared/pages/settings_page.dart';
import '../../features/nutrition/presentation/pages/food_logging_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/workout/presentation/pages/exercise_page.dart';
import '../../features/trainer/presentation/pages/trainer_students_page.dart';
import '../../features/trainer/presentation/pages/trainer_requests_page.dart';
import '../../features/trainer/presentation/pages/find_trainer_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_trainers_page.dart';
import '../../features/admin/presentation/pages/admin_users_page.dart';
import '../../features/social/presentation/pages/social_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/messaging/presentation/pages/conversations_page.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/trainer/presentation/pages/coaching_hub_page.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String checkEmail = '/check-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  
  static const String dashboard = '/dashboard';
  static const String settings = '/settings';
  static const String trainerStudents = '/trainer/students';
  static const String adminDashboard = '/admin/dashboard';
  static const String food = '/food';
  static const String exercise = '/exercise';
  static const String analytics = '/analytics';
  static const String trainerRequests = '/trainer/requests';  
  static const String findTrainer = '/find-trainer';
  static const String adminTrainers = '/admin/trainers';
  static const String adminUsers = '/admin/users';
  static const String notifications = '/notifications';
  static const String social = '/social';
  static const String messages = '/messages';
  static const String calendar = '/calendar';
  static const String onboarding = '/onboarding';
  static const String trainerCalendar = '/trainer/calendar';
  static const String coachingHub = '/coaching-hub';

  static GoRouter create(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: _BlocListenable(authBloc),
      redirect: (context, state) {
        final authState = authBloc.state;
        final loc = state.matchedLocation;

        final isAuthRoute = loc == login || loc == register || loc == forgotPassword || loc == resetPassword;
        final isCheckEmailRoute = loc == checkEmail;

        if (authState is AuthLoadingState || authState is AuthInitialState) return null;
        
        if (authState is AuthUnauthenticatedState || authState is AuthErrorState) return isAuthRoute ? null : login;
        
        if (authState is AuthRegisteredState) {
          return isCheckEmailRoute ? null : '$checkEmail?email=${Uri.encodeComponent(authState.email)}';
        }
        if (authState is AuthUnverifiedState) {
          return isCheckEmailRoute ? null : '$checkEmail?email=${Uri.encodeComponent(authState.email)}';
        }
        
        if (authState is AuthPasswordResetEmailSentState) {
          return loc == resetPassword ? null : '$resetPassword?email=${Uri.encodeComponent(authState.email)}';
        }
        if (authState is AuthPasswordResetSuccessState) {
          return login;
        }
        
        if (authState is AuthOnboardingState) return loc == onboarding ? null : onboarding;

        if (authState is AuthAuthenticatedState) {
          if (isAuthRoute || isCheckEmailRoute || loc == splash || loc == onboarding) {
            return _homeForRole(authState.user.role);
          }
          return null;
        }
        
        return null;
      },
      routes: [
        GoRoute(path: splash, builder: (_, __) => const _SplashPage()),
        GoRoute(
          path: login,
          builder: (context, state) => LoginPage(
            onNavigateToRegister: () => context.go(register),
            verified: state.uri.queryParameters['verified'] == 'true',
          ),
        ),
        GoRoute(path: register, builder: (context, _) => RegisterPage(onNavigateToLogin: () => context.go(login))),
        GoRoute(
          path: checkEmail,
          builder: (context, state) => CheckEmailPage(email: state.uri.queryParameters['email'] ?? ''),
        ),
        GoRoute(
          path: onboarding,
          builder: (context, _) => OnboardingPage(
            onComplete: () => context.read<AuthBloc>().add(const AuthCompleteOnboardingEvent()),
          ),
        ),
        
        GoRoute(
          path: forgotPassword,
          builder: (context, _) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: resetPassword,
          builder: (context, state) => ResetPasswordPage(email: state.uri.queryParameters['email'] ?? ''),
        ),
        
        // Core User Routes
        GoRoute(path: dashboard, builder: (_, __) => const DashboardPage()),
        GoRoute(path: settings, builder: (_, __) => const SettingsPage()),
        GoRoute(path: food, builder: (_, __) => const FoodLoggingPage()),
        GoRoute(path: exercise, builder: (_, __) => const ExercisePage()),
        GoRoute(path: analytics, builder: (_, __) => const AnalyticsPage()),
        GoRoute(path: social, builder: (_, __) => const SocialPage()),
        GoRoute(path: notifications, builder: (_, __) => const NotificationsPage()),
        GoRoute(path: messages, builder: (_, __) => const ConversationsPage()),
        GoRoute(path: calendar, builder: (_, __) => const CalendarPage()),
        
        // Trainer Routes
        GoRoute(path: trainerStudents, builder: (_, __) => const TrainerStudentsPage()), 
        GoRoute(path: trainerRequests, builder: (_, __) => const TrainerRequestsPage()),
        GoRoute(path: trainerCalendar, builder: (_, __) => const CalendarPage()), 
        GoRoute(path: findTrainer, builder: (_, __) => const FindTrainerPage()),
        GoRoute(
            path: coachingHub,
            builder: (context, state) {
              final extraData = state.extra as Map<String, dynamic>? ?? {};
              return CoachingHubPage(trainerInfo: extraData);
            }
        ),
        // Admin Routes
        GoRoute(path: adminDashboard, builder: (_, __) => const AdminDashboardPage()),
        GoRoute(path: adminTrainers, builder: (_, __) => const AdminTrainersPage()),
        GoRoute(path: adminUsers, builder: (_, __) => const AdminUsersPage()),
      ],
    );
  }

  static String _homeForRole(UserRole role) {
    switch (role) {
      case UserRole.admin: return adminDashboard;
      case UserRole.trainer: return trainerStudents; 
      case UserRole.trainee: return dashboard;
    }
  }
}

class _BlocListenable extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  _BlocListenable(AuthBloc bloc) { _sub = bloc.stream.listen((_) => notifyListeners()); }
  @override void dispose() { _sub.cancel(); super.dispose(); }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();
  @override Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Color(0xFF2563EB), body: Center(child: Icon(Icons.track_changes_rounded, color: Colors.white, size: 56)));
  }
}