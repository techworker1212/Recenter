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
    UNUserNotificationCenter.current().setNotificationCategories([
      // The warning. Its expanded view (GoalsNotification extension) is the goal checklist,
      // so it needs no action buttons.
      UNNotificationCategory(
        identifier: GoalStore.notificationCategory, actions: [], intentIdentifiers: [],
        options: []),
      MorningReminder.category,
    ])
    // Keeps the daily reminder scheduled (on at 6:00 AM unless the user changed it).
    MorningReminder.reschedule()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let category = response.notification.request.content.categoryIdentifier
    guard category == MorningReminder.categoryId else {
      super.userNotificationCenter(
        center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    if response.actionIdentifier == MorningReminder.addGoalAction,
      let reply = response as? UNTextInputNotificationResponse
    {
      // Typed straight into the notification: add it without opening the app.
      GoalStore.shared.add(reply.userText)
    } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      // Tapped: open on Today's goals, ready to type.
      PendingAction.set(PendingAction.openGoals)
    }
    completionHandler()
  }

  /// Show Recenter's notifications even while the app is open.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RecenterHostApi") {
      RecenterHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: hostApi)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RecenterAppLabel") {
      registrar.register(AppLabelViewFactory(), withId: AppLabelViewFactory.viewType)
    }
  }
}
