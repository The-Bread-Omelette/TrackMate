import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/dashboard_placeholder_page.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String splash = '/';

  static GoRouter create(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: _BlocListenable(authBloc),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isAuthRoute =
            state.matchedLocation == login || state.matchedLocation == register;

        if (authState is AuthAuthenticatedState) {
          return isAuthRoute ? dashboard : null;
        }
        if (authState is AuthUnauthenticatedState || authState is AuthErrorState) {
          return isAuthRoute ? null : login;
        }
        return null;
      },
      routes: [
        GoRoute(path: splash, builder: (_, __) => const _SplashPage()),
        GoRoute(
          path: login,
          builder: (context, _) => LoginPage(
            onNavigateToRegister: () => context.go(register),
          ),
        ),
        GoRoute(
          path: register,
          builder: (context, _) => RegisterPage(
            onNavigateToLogin: () => context.go(login),
          ),
        ),
        GoRoute(
          path: dashboard,
          builder: (_, __) => const DashboardPlaceholderPage(),
        ),
      ],
    );
  }
}

class _BlocListenable extends ChangeNotifier {
  _BlocListenable(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2563EB),
      body: Center(
        child: Icon(Icons.track_changes_rounded, color: Colors.white, size: 56),
      ),
    );
  }
}
