/// Stored shape of the app session (preferences keys, JSON, …).
class AppSessionModel {
  const AppSessionModel({
    required this.isFirstLaunch,
    required this.isOnboardingCompleted,
  });

  final bool isFirstLaunch;
  final bool isOnboardingCompleted;

  factory AppSessionModel.fromJson(Map<String, dynamic> json) => AppSessionModel(
        isFirstLaunch: json['is_first_launch'] as bool? ?? true,
        isOnboardingCompleted: json['is_onboarding_completed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'is_first_launch': isFirstLaunch,
        'is_onboarding_completed': isOnboardingCompleted,
      };
}
