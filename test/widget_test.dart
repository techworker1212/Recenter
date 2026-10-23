import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:re_think/models/app_rule.dart';
import 'package:re_think/models/app_settings.dart';

void main() {
  test('empty notification copy uses the shared fallback', () {
    const rule = AppRule(
      id: '1',
      platformAppId: 'com.google.android.youtube',
      displayLabel: 'YouTube',
      limitMinutes: 10,
      notificationTitle: '',
      notificationBody: '  ',
    );
    expect(rule.resolvedTitle, AppRule.fallbackTitle);
    expect(rule.resolvedBody, AppRule.fallbackBody);
  });

  test('unlock minutes round-trip, and older saved rules default to 2', () {
    const rule = AppRule(
      id: '3',
      platformAppId: 'x',
      displayLabel: 'YouTube',
      limitMinutes: 30,
      unlockMinutes: 5,
      notificationTitle: '',
      notificationBody: '',
    );
    expect(AppRule.fromJson(rule.toJson()).unlockMinutes, 5);

    final legacy = rule.toJson()..remove('unlockMinutes');
    expect(AppRule.fromJson(legacy).unlockMinutes, AppRule.defaultUnlockMinutes);
  });

  test('custom copy is used when present', () {
    const rule = AppRule(
      id: '2',
      platformAppId: 'com.instagram.android',
      displayLabel: 'Instagram',
      limitMinutes: 8,
      notificationTitle: 'That’s enough TikTok',
      notificationBody: 'Unlock only if you still need it.',
    );
    expect(rule.resolvedTitle, 'That’s enough TikTok');
    expect(rule.resolvedBody, 'Unlock only if you still need it.');
  });

  test('theme choice is saved, and older settings follow the phone', () {
    const dark = AppSettings(themeMode: ThemeMode.dark);
    expect(AppSettings.fromJson(dark.toJson()).themeMode, ThemeMode.dark);
    expect(AppSettings.fromJson({'defaultLimitMinutes': 10}).themeMode, ThemeMode.system);
  });
}
