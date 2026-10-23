import 'package:flutter/material.dart';

class AppSettings {
  static const warningSeconds = 5;

  const AppSettings({
    this.onboardingComplete = false,
    this.monitoringEnabled = false,
    this.themeMode = ThemeMode.system,
  });

  final bool onboardingComplete;
  final bool monitoringEnabled;

  /// Follows the phone until the user picks light or dark with the toggle.
  final ThemeMode themeMode;

  AppSettings copyWith({
    bool? onboardingComplete,
    bool? monitoringEnabled,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, Object?> toJson() => {
    'onboardingComplete': onboardingComplete,
    'monitoringEnabled': monitoringEnabled,
    'themeMode': themeMode.name,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      monitoringEnabled: json['monitoringEnabled'] as bool? ?? false,
      themeMode: ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.system,
    );
  }
}
