class ExcludedApp {
  final String packageName;
  final String appName;
  final DateTime excludedAt;

  ExcludedApp({
    required this.packageName,
    required this.appName,
    required this.excludedAt,
  });

  ExcludedApp copyWith({
    String? packageName,
    String? appName,
    DateTime? excludedAt,
  }) {
    return ExcludedApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      excludedAt: excludedAt ?? this.excludedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'appName': appName,
      'excludedAt': excludedAt.toIso8601String(),
    };
  }

  factory ExcludedApp.fromJson(Map<String, dynamic> json) {
    return ExcludedApp(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      excludedAt: DateTime.parse(json['excludedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExcludedApp && other.packageName == packageName;
  }

  @override
  int get hashCode => packageName.hashCode;
}