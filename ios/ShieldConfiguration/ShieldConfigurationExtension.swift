import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The iOS "pause screen": the shield shows the matching rule's own title and body.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
  private let store = RuleStore.shared

  override func configuration(shielding application: Application) -> ShieldConfiguration {
    make(store.rule(application: application.token))
  }

  override func configuration(
    shielding application: Application,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    make(store.rule(application: application.token) ?? store.rule(category: category.token))
  }

  override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
    make(store.rule(webDomain: webDomain.token))
  }

  override func configuration(
    shielding webDomain: WebDomain,
    in category: ActivityCategory
  ) -> ShieldConfiguration {
    make(store.rule(webDomain: webDomain.token) ?? store.rule(category: category.token))
  }

  /// The user's message, plus today's unfinished goals.
  private func subtitle(_ message: String) -> String {
    guard let goals = GoalStore.shared.summary else { return message }
    return "\(message)\n\n\(goals)"
  }

  private func make(_ rule: StoredRule?) -> ShieldConfiguration {
    // Mirrors AppRule.fallbackTitle / fallbackBody in Dart.
    let fallbackTitle = "Time to recenter."
    let fallbackBody = "You've reached the limit you set for this app."
    let teal = UIColor(red: 15 / 255, green: 118 / 255, blue: 110 / 255, alpha: 1)
    let label = rule?.label ?? "app"
    return ShieldConfiguration(
      backgroundBlurStyle: .systemUltraThinMaterialDark,
      backgroundColor: UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 0.9),
      // SF Symbols render black unless tinted, which disappears on the dark shield.
      icon: UIImage(systemName: "hourglass.bottomhalf.filled")?
        .withTintColor(.white, renderingMode: .alwaysOriginal),
      title: ShieldConfiguration.Label(text: rule?.title ?? fallbackTitle, color: .white),
      subtitle: ShieldConfiguration.Label(
        text: subtitle(rule?.body ?? fallbackBody),
        color: UIColor.white.withAlphaComponent(0.7)
      ),
      primaryButtonLabel: ShieldConfiguration.Label(text: "Close \(label)", color: .white),
      primaryButtonBackgroundColor: teal,
      secondaryButtonLabel: ShieldConfiguration.Label(
        text: "Unlock for \(rule?.unlockMinutes ?? StoredRule.defaultUnlockMinutes) min",
        color: UIColor.white.withAlphaComponent(0.8)
      )
    )
  }
}
