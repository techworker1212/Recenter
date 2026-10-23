import '../bridge/messages.g.dart';
import '../bridge/native_bridge.dart';
import '../models/app_rule.dart';
import '../models/app_settings.dart';
import '../models/goal.dart';
import '../persistence/local_store.dart';

/// Demo mode for App Store screenshots in the Simulator, where Screen Time can't be
/// authorized. Only active in builds made with `--dart-define=RECENTER_DEMO=true`.
const demoMode = bool.fromEnvironment('RECENTER_DEMO');

/// Pretends every permission is granted and monitoring is running, without touching
/// any native code.
class DemoBridge extends NativeBridge {
  DemoBridge() : super(api: RecenterHostApi());

  static final _granted = PermissionSnapshot(
    familyControls: true,
    notifications: true,
    usageAccess: true,
    overlay: true,
    batteryExemption: true,
  );

  @override
  Future<PermissionSnapshot> status() async => _granted;


  @override
  Future<PermissionSnapshot> request(String kind) async => _granted;

  @override
  Future<void> upsert(AppRule rule) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<MonitoringStatus> monitoring() async =>
      MonitoringStatus(
        running: true,
        interruptionsToday: 3,
        interruptionsByRule: {'demo_instagram': 2, 'demo_tiktok': 1},
      );

  @override
  Future<List<ListedApp>> installedApps() async => const [];

  @override
  Future<String> pickIosActivity() async => 'demo-selection';

  @override
  Future<void> unlock(String ruleId) async {}

  List<Goal> _goals = const [
    Goal(id: 'g1', text: 'Go for a 20-minute walk', done: true),
    Goal(id: 'g2', text: 'Read 20 pages', done: false),
    Goal(id: 'g3', text: 'Call Mum', done: false),
  ];

  @override
  Future<List<Goal>> goals() async => _goals;

  @override
  Future<List<Goal>> addGoal(String text) async => _goals = [
    ..._goals,
    Goal(id: 'g${_goals.length + 1}', text: text, done: false),
  ];

  @override
  Future<List<Goal>> setGoalDone(String id, bool done) async => _goals = [
    for (final goal in _goals)
      goal.id == id ? Goal(id: goal.id, text: goal.text, done: done) : goal,
  ];

  @override
  Future<List<Goal>> deleteGoal(String id) async =>
      _goals = _goals.where((goal) => goal.id != id).toList();
}

/// Keeps the sample rules in memory so demo runs never touch real saved data.
class DemoStore extends LocalStore {
  List<AppRule> _rules = const [
    AppRule(
      id: 'demo_instagram',
      platformAppId: 'demo-selection',
      displayLabel: 'Instagram',
      limitMinutes: 15,
      unlockMinutes: 5,
      notificationTitle: 'That’s enough Instagram',
      notificationBody: 'You said 15 minutes. Call Mum instead?',
    ),
    AppRule(
      id: 'demo_tiktok',
      platformAppId: 'demo-selection',
      displayLabel: 'TikTok',
      limitMinutes: 10,
      unlockMinutes: 1,
      notificationTitle: 'Put the phone down',
      notificationBody: 'Ten minutes is plenty. Your book is waiting.',
    ),
    AppRule(
      id: 'demo_youtube',
      platformAppId: 'demo-selection',
      displayLabel: 'YouTube',
      limitMinutes: 30,
      notificationTitle: 'One more video?',
      notificationBody: 'You came for one. Time to get back to your project.',
    ),
  ];
  AppSettings _settings = const AppSettings(
    onboardingComplete: true,
    monitoringEnabled: true,
  );

  @override
  Future<List<AppRule>> loadRules() async => _rules;

  @override
  Future<void> saveRules(List<AppRule> rules) async => _rules = rules;

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async => _settings = settings;
}
