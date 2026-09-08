import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/datasource/splash_local_datasource.dart';
import '../../domain/repository/splash_repository.dart';
import '../../domain/usecase/load_app_session_usecase.dart';
import '../datasource/splash_local_datasource_impl.dart';
import '../repository/splash_repository_impl.dart';

/// Wiring for the splash module.

final splashLocalDataSourceProvider = Provider<SplashLocalDataSource>(
  (ref) => SplashLocalDataSourceImpl(),
);

final splashRepositoryProvider = Provider<SplashRepository>(
  (ref) => SplashRepositoryImpl(
    localDataSource: ref.watch(splashLocalDataSourceProvider),
  ),
);

final loadAppSessionUseCaseProvider = Provider<LoadAppSessionUseCase>(
  (ref) => LoadAppSessionUseCase(ref.watch(splashRepositoryProvider)),
);
