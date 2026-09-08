import '../../../../../core/error/failure.dart';
import '../../domain/entity/app_session_entity.dart';

enum SplashStatus { initial, loading, ready, failure }

class SplashState {
  const SplashState({
    this.status = SplashStatus.initial,
    this.session,
    this.nextRoute,
    this.failure,
  });

  final SplashStatus status;
  final AppSessionEntity? session;

  /// Where the view should navigate once [status] is `ready`.
  final String? nextRoute;
  final Failure? failure;

  bool get isReady => status == SplashStatus.ready && nextRoute != null;

  SplashState copyWith({
    SplashStatus? status,
    AppSessionEntity? session,
    String? nextRoute,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return SplashState(
      status: status ?? this.status,
      session: session ?? this.session,
      nextRoute: nextRoute ?? this.nextRoute,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
