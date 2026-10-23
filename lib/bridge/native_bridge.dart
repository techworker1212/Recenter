import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/app_rule.dart';
import '../models/goal.dart';
import 'messages.g.dart';

class ListedApp {
  const ListedApp({required this.packageId, required this.label});

  final String packageId;
  final String label;
}

class NativeBridge {
  NativeBridge({RecenterHostApi? api}) : _api = api ?? RecenterHostApi();

  final RecenterHostApi _api;

  bool get isIos => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<PermissionSnapshot> status() => _api.getPermissionStatus();

  Future<PermissionSnapshot> request(String kind) =>
      _api.requestPermission(kind);

  Future<void> upsert(AppRule rule) {
    return _api.upsertAppRule(
      NativeAppRule(
        id: rule.id,
        platformAppId: rule.platformAppId,
        displayLabel: rule.displayLabel,
        limitMinutes: rule.limitMinutes,
        unlockMinutes: rule.unlockMinutes,
        notificationTitle: rule.resolvedTitle,
        notificationBody: rule.resolvedBody,
        enabled: rule.enabled,
      ),
    );
  }

  Future<void> delete(String id) => _api.deleteAppRule(id);

  Future<void> start() => _api.startMonitoring();

  Future<void> stop() => _api.stopMonitoring();

  Future<MonitoringStatus> monitoring() => _api.getMonitoringStatus();

  Future<List<ListedApp>> installedApps() async {
    final apps = await _api.listInstalledApps();
    return apps
        .map((app) => ListedApp(packageId: app.packageId, label: app.label))
        .toList();
  }

  Future<String> pickIosActivity() => _api.pickIosActivity();

  Future<void> unlock(String ruleId) => _api.unlockApp(ruleId);

  Future<List<Goal>> goals() async => _goals(await _api.getGoals());

  Future<List<Goal>> addGoal(String text) async => _goals(await _api.addGoal(text));

  Future<List<Goal>> setGoalDone(String id, bool done) async =>
      _goals(await _api.setGoalDone(id, done));

  Future<List<Goal>> deleteGoal(String id) async =>
      _goals(await _api.deleteGoal(id));

  static List<Goal> _goals(List<NativeGoal> goals) => goals
      .map((goal) => Goal(id: goal.id, text: goal.text, done: goal.done))
      .toList();
}
