class AppRule {
  static const fallbackTitle = 'Time to recenter.';
  static const fallbackBody = "You've reached the limit you set for this app.";
  static const titleMax = 50;
  static const bodyMax = 120;
  static const defaultLimitMinutes = 10;
  static const defaultUnlockMinutes = 2;

  const AppRule({
    required this.id,
    required this.platformAppId,
    required this.displayLabel,
    required this.limitMinutes,
    this.unlockMinutes = defaultUnlockMinutes,
    required this.notificationTitle,
    required this.notificationBody,
    this.enabled = true,
  });

  final String id;
  final String platformAppId;
  final String displayLabel;
  final int limitMinutes;

  /// How long "Unlock" on the pause screen lets this app be used before the next reminder.
  final int unlockMinutes;
  final String notificationTitle;
  final String notificationBody;
  final bool enabled;

  String get resolvedTitle {
    final title = notificationTitle.trim();
    if (title.isEmpty) {
      return fallbackTitle;
    }
    return title;
  }

  String get resolvedBody {
    final body = notificationBody.trim();
    if (body.isEmpty) {
      return fallbackBody;
    }
    return body;
  }

  AppRule copyWith({
    String? id,
    String? platformAppId,
    String? displayLabel,
    int? limitMinutes,
    int? unlockMinutes,
    String? notificationTitle,
    String? notificationBody,
    bool? enabled,
  }) {
    return AppRule(
      id: id ?? this.id,
      platformAppId: platformAppId ?? this.platformAppId,
      displayLabel: displayLabel ?? this.displayLabel,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      unlockMinutes: unlockMinutes ?? this.unlockMinutes,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'platformAppId': platformAppId,
    'displayLabel': displayLabel,
    'limitMinutes': limitMinutes,
    'unlockMinutes': unlockMinutes,
    'notificationTitle': notificationTitle,
    'notificationBody': notificationBody,
    'enabled': enabled,
  };

  factory AppRule.fromJson(Map<String, Object?> json) {
    return AppRule(
      id: json['id'] as String,
      platformAppId: json['platformAppId'] as String? ?? '',
      displayLabel: json['displayLabel'] as String? ?? 'App',
      limitMinutes: json['limitMinutes'] as int? ?? 10,
      unlockMinutes: json['unlockMinutes'] as int? ?? defaultUnlockMinutes,
      notificationTitle: json['notificationTitle'] as String? ?? '',
      notificationBody: json['notificationBody'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
