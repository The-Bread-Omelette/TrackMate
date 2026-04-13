import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'shared/theme/app_theme.dart';
import 'features/fitness/services/pedometer_service.dart';

final globalPedometer = PedometerService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const TrackMateApp());
}

class TrackMateApp extends StatefulWidget {
  const TrackMateApp({super.key});

  @override
  State<TrackMateApp> createState() => _TrackMateAppState();
}

class _TrackMateAppState extends State<TrackMateApp> {
  late final AuthBloc _authBloc;
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>();
    router = AppRouter.create(_authBloc);
    _authBloc.add(const AuthCheckSessionEvent());

    globalPedometer.start();
  }

  @override
  void dispose() {
    _authBloc.close();
    globalPedometer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'TrackMate',
        theme: AppTheme.light,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}