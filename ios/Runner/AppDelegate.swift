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
    // The warning's category. Its expanded view (GoalsNotification extension) is the goal
    // checklist, so it needs no action buttons.
    UNUserNotificationCenter.current().setNotificationCategories([
      UNNotificationCategory(
        identifier: GoalStore.notificationCategory, actions: [], intentIdentifiers: [],
        options: [])
    ])
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RecenterHostApi") {
      RecenterHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: hostApi)
    }
  }
}
