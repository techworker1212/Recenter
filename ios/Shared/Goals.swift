import Foundation

/// A goal for today, stored in the App Group so the warning notification, the shield and
/// the app all see the same list.
struct Goal: Codable, Equatable, Identifiable {
  var id: String
  var text: String
  var done: Bool
}

/// Today's goals in the App Group. Self-contained (no Screen Time imports) so the
/// notification content extension can use it on its own.
final class GoalStore {
  static let shared = GoalStore()

  /// The category the warning notification uses; the content extension registers for it.
  static let notificationCategory = "recenter.warning"

  private let defaults: UserDefaults

  init(defaults: UserDefaults? = UserDefaults(suiteName: "group.com.aquibkhan.recenter")) {
    self.defaults = defaults ?? .standard
  }

  /// Today's goals. Goals from an earlier day read as an empty list.
  var goals: [Goal] {
    guard defaults.string(forKey: Keys.day) == Self.today(),
      let data = defaults.data(forKey: Keys.goals),
      let goals = try? JSONDecoder().decode([Goal].self, from: data)
    else { return [] }
    return goals
  }

  var unfinished: [Goal] {
    goals.filter { !$0.done }
  }

  @discardableResult
  func add(_ text: String) -> [Goal] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return goals }
    return save(goals + [Goal(id: UUID().uuidString, text: trimmed, done: false)])
  }

  @discardableResult
  func set(_ id: String, done: Bool) -> [Goal] {
    save(goals.map { $0.id == id ? Goal(id: $0.id, text: $0.text, done: done) : $0 })
  }

  @discardableResult
  func delete(_ id: String) -> [Goal] {
    save(goals.filter { $0.id != id })
  }

  /// Today's unfinished goals as a bulleted list, one per line, for notification and
  /// shield text.
  var summary: String? {
    let open = unfinished
    guard !open.isEmpty else { return nil }
    let label = open.count == 1 ? "Today's goal:" : "Today's goals:"
    return ([label] + open.map { "• \($0.text)" }).joined(separator: "\n")
  }

  private func save(_ goals: [Goal]) -> [Goal] {
    if let data = try? JSONEncoder().encode(goals) {
      defaults.set(data, forKey: Keys.goals)
      defaults.set(Self.today(), forKey: Keys.day)
    }
    return goals
  }

  private static func today() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  private enum Keys {
    static let goals = "goals"
    static let day = "goalsDay"
  }
}
