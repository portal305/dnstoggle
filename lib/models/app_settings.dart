class AppSettings {
  final bool autoStartOnBoot;
  final bool persistentNotification;
  final bool onboardingCompleted;
  final bool excludedAppsMonitor;
  final bool useVpnMode;
  final String customDohUrl;
  final String corporateDnsIp;
  final List<String> splitTunnelDomains;

  AppSettings({
    this.autoStartOnBoot = false,
    this.persistentNotification = false,
    this.onboardingCompleted = false,
    this.excludedAppsMonitor = true,
    this.useVpnMode = false,
    this.customDohUrl = '',
    this.corporateDnsIp = '',
    this.splitTunnelDomains = const [],
  });

  AppSettings copyWith({
    bool? autoStartOnBoot,
    bool? persistentNotification,
    bool? onboardingCompleted,
    bool? excludedAppsMonitor,
    bool? useVpnMode,
    String? customDohUrl,
    String? corporateDnsIp,
    List<String>? splitTunnelDomains,
  }) {
    return AppSettings(
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      persistentNotification: persistentNotification ?? this.persistentNotification,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      excludedAppsMonitor: excludedAppsMonitor ?? this.excludedAppsMonitor,
      useVpnMode: useVpnMode ?? this.useVpnMode,
      customDohUrl: customDohUrl ?? this.customDohUrl,
      corporateDnsIp: corporateDnsIp ?? this.corporateDnsIp,
      splitTunnelDomains: splitTunnelDomains ?? this.splitTunnelDomains,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoStartOnBoot': autoStartOnBoot,
      'persistentNotification': persistentNotification,
      'onboardingCompleted': onboardingCompleted,
      'excludedAppsMonitor': excludedAppsMonitor,
      'useVpnMode': useVpnMode,
      'customDohUrl': customDohUrl,
      'corporateDnsIp': corporateDnsIp,
      'splitTunnelDomains': splitTunnelDomains,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
      persistentNotification: json['persistentNotification'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      excludedAppsMonitor: json['excludedAppsMonitor'] as bool? ?? true,
      useVpnMode: json['useVpnMode'] as bool? ?? false,
      customDohUrl: json['customDohUrl'] as String? ?? '',
      corporateDnsIp: json['corporateDnsIp'] as String? ?? '',
      splitTunnelDomains: (json['splitTunnelDomains'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}