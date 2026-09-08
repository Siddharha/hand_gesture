import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../data/di/splash_di.dart';
import '../../domain/usecase/load_app_session_usecase.dart';
import 'splash_state.dart';

/// Decides where the app starts. The view only reads `nextRoute` and navigates.
class SplashViewModel extends Notifier<SplashState> {
  /// Keeps the splash on screen long enough not to flash on fast start-ups.
  static const _minimumDisplay = Duration(milliseconds: 600);

  late final LoadAppSessionUseCase _loadSession = ref.read(loadAppSessionUseCaseProvider);

  @override
  SplashState build() => const SplashState();

  Future<void> bootstrap() async {
    if (state.status == SplashStatus.loading) return;
    state = state.copyWith(status: SplashStatus.loading, clearFailure: true);

    final elapsed = Stopwatch()..start();
    final result = await _loadSession(const NoParams());

    final remaining = _minimumDisplay - elapsed.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    state = result.fold(
      onSuccess: (session) => state.copyWith(
        status: SplashStatus.ready,
        session: session,
        nextRoute: AppRoutes.home,
        clearFailure: true,
      ),
      onError: (failure) => state.copyWith(
        status: SplashStatus.failure,
        failure: failure,
      ),
    );
  }
}

final splashViewModelProvider = NotifierProvider<SplashViewModel, SplashState>(
  SplashViewModel.new,
);
