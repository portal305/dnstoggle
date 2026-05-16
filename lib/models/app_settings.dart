class AppSettings {
  final bool autoStartOnBoot;
  final bool persistentNotification;
  final bool onboardingCompleted;

  AppSettings({
    this.autoStartOnBoot = false,
    this.persistentNotification = false,
    this.onboardingCompleted = false,
  });

  AppSettings copyWith({
    bool? autoStartOnBoot,
    bool? persistentNotification,
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      persistentNotification: persistentNotification ?? this.persistentNotification,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoStartOnBoot': autoStartOnBoot,
      'persistentNotification': persistentNotification,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
      persistentNotification: json['persistentNotification'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
    );
  }
}