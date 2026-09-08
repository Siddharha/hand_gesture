/// What the splash screen needs to decide where the user goes next.
class AppSessionEntity {
  const AppSessionEntity({
    required this.isFirstLaunch,
    required this.isOnboardingCompleted,
  });

  const AppSessionEntity.initial()
      : isFirstLaunch = true,
        isOnboardingCompleted = false;

  final bool isFirstLaunch;
  final bool isOnboardingCompleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSessionEntity &&
          other.isFirstLaunch == isFirstLaunch &&
          other.isOnboardingCompleted == isOnboardingCompleted;

  @override
  int get hashCode => Object.hash(isFirstLaunch, isOnboardingCompleted);
}
