import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final result = await remoteDataSource.register(
        email: email,
        password: password,
        fullName: fullName,
        role: roleToString(role),
      );
      return Right(_mapUser(result.user));
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final result = await remoteDataSource.login(
        email: email,
        password: password,
        role: roleToString(role),
      );
      return Right(_mapUser(result.user));
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
    } catch (_) {
      // Best-effort: ignore failures when logging out.
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      return Right(_mapUser(user));
    } on Failure catch (f) {
      return Left(f);
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<bool> hasStoredSession() async {
    // Cookie-based auth relies on cookies being present in the HTTP client.
    // The safest way to determine if the user is logged in is to attempt to load their session.
    try {
      await remoteDataSource.getCurrentUser();
      return true;
    } catch (_) {
      return false;
    }
  }

  UserEntity _mapUser(UserModel model) => UserEntity(
        id: model.id,
        email: model.email,
        fullName: model.fullName,
        role: roleFromString(model.role),
        isActive: model.isActive,
        isVerified: model.isVerified,
      );
}
