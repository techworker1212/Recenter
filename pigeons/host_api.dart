import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/rethink/app/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.rethink.app'),
    swiftOut: 'ios/Runner/Messages.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
class NativeAppRule {
  NativeAppRule({
    required this.id,
    required this.platformAppId,
    required this.displayLabel,
    required this.limitMinutes,
    required this.unlockMinutes,
    required this.notificationTitle,
    required this.notificationBody,
    required this.enabled,
  });

  String id;
  String platformAppId;
  String displayLabel;
  int limitMinutes;
  int unlockMinutes;
  String notificationTitle;
  String notificationBody;
  bool enabled;
}

class PermissionSnapshot {
  PermissionSnapshot({
    required this.familyControls,
    required this.notifications,
    required this.usageAccess,
    required this.overlay,
    required this.batteryExemption,
  });

  bool familyControls;
  bool notifications;
  bool usageAccess;
  bool overlay;
  bool batteryExemption;
}

class InstalledApp {
  InstalledApp({required this.packageId, required this.label});

  String packageId;
  String label;
}

class MonitoringStatus {
  MonitoringStatus({
    required this.running,
    required this.interruptionsToday,
    required this.interruptionsByRule,
  });

  bool running;
  int interruptionsToday;

  /// Today's interruptions keyed by rule id.
  Map<String, int> interruptionsByRule;
}

/// A goal for today. Goals live natively so notification actions can tick them off
/// while Flutter isn't running.
class NativeGoal {
  NativeGoal({required this.id, required this.text, required this.done});

  String id;
  String text;
  bool done;
}

@HostApi()
abstract class RecenterHostApi {
  PermissionSnapshot getPermissionStatus();

  @async
  PermissionSnapshot requestPermission(String kind);

  void upsertAppRule(NativeAppRule rule);

  void deleteAppRule(String id);

  void startMonitoring();

  void stopMonitoring();

  MonitoringStatus getMonitoringStatus();

  List<InstalledApp> listInstalledApps();

  @async
  String pickIosActivity();

  void unlockApp(String ruleId);

  /// Today's goals. A new day starts with an empty list.
  List<NativeGoal> getGoals();

  List<NativeGoal> addGoal(String text);

  List<NativeGoal> setGoalDone(String id, bool done);

  List<NativeGoal> deleteGoal(String id);
}
