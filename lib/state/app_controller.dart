import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../bridge/messages.g.dart';
import '../bridge/native_bridge.dart';
import '../models/app_rule.dart';
import '../models/app_settings.dart';
import '../models/goal.dart';
import '../persistence/local_store.dart';

class AppController extends ChangeNotifier {
  AppController({required LocalStore store, required NativeBridge bridge})
    : _store = store,
      _bridge = bridge;

  final LocalStore _store;
  final NativeBridge _bridge;

  AppSettings settings = const AppSettings();
  List<AppRule> rules = [];
  PermissionSnapshot permissions = PermissionSnapshot(
    familyControls: false,
    notifications: false,
    usageAccess: false,
    overlay: false,
    batteryExemption: false,
  );
  int interruptionsToday = 0;

  /// Today's interruptions keyed by rule id.
  Map<String, int> interruptionsByRule = const {};

  /// Today's goals, shown on the home screen and with every interruption.
  List<Goal> goals = const [];
  bool busy = false;
  String? errorMessage;

  NativeBridge get bridge => _bridge;

  AppLifecycleListener? _lifecycle;

  /// Permissions that must be on for monitoring to work on this platform.
  List<String> get missingPermissions {
    if (_bridge.isIos) {
      return [
        if (!permissions.familyControls) 'familyControls',
        if (!permissions.notifications) 'notifications',
      ];
    }
    return [
      if (!permissions.usageAccess) 'usageAccess',
      if (!permissions.notifications) 'notifications',
      if (!permissions.overlay) 'overlay',
    ];
  }

  Future<void> bootstrap() async {
    settings = await _store.loadSettings();
    rules = await _store.loadRules();
    await refreshNative();
    // Permissions are granted in system settings, so re-check whenever we come back.
    _lifecycle = AppLifecycleListener(
      onResume: () async {
        await refreshNative();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> refreshNative() async {
    try {
      permissions = await _bridge.status();
      // Goals can be ticked off from a notification while the app is closed.
      goals = await _bridge.goals();
      final status = await _bridge.monitoring();
      interruptionsToday = status.interruptionsToday;
      interruptionsByRule = status.interruptionsByRule;
      if (settings.monitoringEnabled && !status.running) {
        await _syncAllRules();
        await _bridge.start();
      }
      errorMessage = null;
    } catch (error) {
      errorMessage = _describe(error);
    }
  }

  Future<void> completeOnboarding() async {
    settings = settings.copyWith(onboardingComplete: true);
    await _store.saveSettings(settings);
    notifyListeners();
  }

  Future<void> requestPermission(String kind) async {
    busy = true;
    notifyListeners();
    try {
      permissions = await _bridge.request(kind);
      errorMessage = null;
    } catch (error) {
      errorMessage = _describe(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setMonitoring(bool enabled) async {
    try {
      if (enabled) {
        await _syncAllRules();
        await _bridge.start();
      } else {
        await _bridge.stop();
      }
      settings = settings.copyWith(monitoringEnabled: enabled);
      errorMessage = null;
    } catch (error) {
      // Keep the switch honest: monitoring is only "on" if native accepted it.
      settings = settings.copyWith(monitoringEnabled: false);
      errorMessage = _describe(error);
    }
    await _store.saveSettings(settings);
    final status = await _safeMonitoringStatus();
    if (status != null) {
      interruptionsToday = status.interruptionsToday;
      interruptionsByRule = status.interruptionsByRule;
    }
    notifyListeners();
  }

  /// Saves locally first, then hands the rule to native. Returns an error message if
  /// native rejected it (e.g. the iOS app selection could not be read).
  Future<String?> upsertRule(AppRule rule) async {
    final index = rules.indexWhere((item) => item.id == rule.id);
    if (index >= 0) {
      rules = [...rules]..[index] = rule;
    } else {
      rules = [...rules, rule];
    }
    await _store.saveRules(rules);
    String? failure;
    try {
      await _bridge.upsert(rule);
    } catch (error) {
      failure = _describe(error);
    }
    notifyListeners();
    return failure;
  }

  Future<void> setRuleEnabled(AppRule rule, bool enabled) async {
    final failure = await upsertRule(rule.copyWith(enabled: enabled));
    if (failure != null) {
      errorMessage = failure;
      notifyListeners();
    }
  }

  Future<void> deleteRule(String id) async {
    rules = rules.where((rule) => rule.id != id).toList();
    await _store.saveRules(rules);
    try {
      await _bridge.delete(id);
    } catch (error) {
      errorMessage = _describe(error);
    }
    notifyListeners();
  }

  /// The light/dark toggle. Before the first tap the app follows the phone, so the toggle
  /// flips whichever look is on screen right now.
  Future<void> toggleTheme(Brightness current) async {
    settings = settings.copyWith(
      themeMode: current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
    notifyListeners();
    await _store.saveSettings(settings);
  }

  Future<void> addGoal(String text) => _updateGoals(() => _bridge.addGoal(text));

  Future<void> setGoalDone(Goal goal, bool done) =>
      _updateGoals(() => _bridge.setGoalDone(goal.id, done));

  Future<void> deleteGoal(Goal goal) => _updateGoals(() => _bridge.deleteGoal(goal.id));

  Future<void> _updateGoals(Future<List<Goal>> Function() change) async {
    try {
      goals = await change();
      errorMessage = null;
    } catch (error) {
      errorMessage = _describe(error);
    }
    notifyListeners();
  }

  Future<void> _syncAllRules() async {
    for (final rule in rules) {
      await _bridge.upsert(rule);
    }
  }

  Future<MonitoringStatus?> _safeMonitoringStatus() async {
    try {
      return await _bridge.monitoring();
    } catch (_) {
      return null;
    }
  }

  static String _describe(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }
}
