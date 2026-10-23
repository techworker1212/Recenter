import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let hostApi = HostApi()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    GoalNotifications.registerCategory(for: RuleStore.shared.goals)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// "Done: …" on a warning notification ticks off that goal, without opening the app.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let goalId = GoalNotifications.goalId(forAction: response.actionIdentifier) {
      RuleStore.shared.setGoal(goalId, done: true)
      completionHandler()
      return
    }
    super.userNotificationCenter(
      center, didReceive: response, withCompletionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RecenterHostApi") {
      RecenterHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: hostApi)
    }
  }
}
