import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../network/dio_client.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/dashboard/data/dashboard_remote_datasource.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/nutrition/data/nutrition_remote_datasource.dart';
import '../../features/analytics/data/analytics_remote_datasource.dart';
import '../../features/workout/data/workout_remote_datasource.dart';
import '../../features/admin/data/admin_remote_datasource.dart';
import '../../features/trainer/data/trainer_remote_datasource.dart';
import '../../features/social/data/social_remote_datasource.dart';
import '../../features/notifications/data/notifications_remote_datasource.dart';
import '../../features/messaging/data/messaging_remote_datasource.dart';
import '../../features/notifications/presentation/bloc/notification_badge_cubit.dart';
final sl = GetIt.instance;

Future<void> setupDependencies() async {
  sl.registerSingletonAsync<Dio>(() async {
    return await DioClient.create();
  });
  await sl.isReady<Dio>();

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(repository: sl<AuthRepository>()),
  );

  sl.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSource(sl<Dio>()),
  );
  sl.registerFactory<DashboardBloc>(
    () => DashboardBloc(
      dataSource: sl<DashboardRemoteDataSource>(),
      dio: sl<Dio>(),
    ),
  );
  sl.registerLazySingleton<NutritionRemoteDataSource>(
    () => NutritionRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<AnalyticsRemoteDataSource>(
    () => AnalyticsRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<WorkoutRemoteDataSource>(
    () => WorkoutRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<AdminRemoteDataSource>(
    () => AdminRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<TrainerRemoteDataSource>(
    () => TrainerRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<SocialRemoteDataSource>(
    () => SocialRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSource(sl<Dio>()),
  );

  sl.registerLazySingleton<MessagingRemoteDataSource>(
    () => MessagingRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<NotificationBadgeCubit>(
    () => NotificationBadgeCubit(sl<NotificationsRemoteDataSource>()),
  );
}