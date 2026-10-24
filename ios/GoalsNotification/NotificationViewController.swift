import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// The warning notification's expanded view (press and hold it): the user's message plus
/// today's goals as a checklist they can tick off without opening Recenter.
class NotificationViewController: UIViewController, UNNotificationContentExtension {
  private let model = GoalsModel()
  private lazy var host = UIHostingController(rootView: GoalsNotificationView(model: model))

  override func viewDidLoad() {
    super.viewDidLoad()
    addChild(host)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    host.view.backgroundColor = .clear
    view.addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    host.didMove(toParent: self)
    model.onChange = { [weak self] in self?.resize() }
  }

  func didReceive(_ notification: UNNotification) {
    let content = notification.request.content
    model.title = content.title
    // The plain message, without the goals line the banner adds for the collapsed view.
    model.message = content.userInfo["message"] as? String ?? content.body
    model.reload()
  }

  private func resize() {
    let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
    let size = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    preferredContentSize = CGSize(width: width, height: size.height)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    resize()
  }
}

final class GoalsModel: ObservableObject {
  @Published var title = ""
  @Published var message = ""
  @Published var goals: [Goal] = []
  var onChange: (() -> Void)?

  func reload() {
    goals = GoalStore.shared.goals
    onChange?()
  }

  func toggle(_ goal: Goal) {
    goals = GoalStore.shared.set(goal.id, done: !goal.done)
    onChange?()
  }
}

struct GoalsNotificationView: View {
  @ObservedObject var model: GoalsModel

  private let teal = Color(red: 15 / 255, green: 118 / 255, blue: 110 / 255)

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(model.title).font(.headline)
        Text(model.message).font(.subheadline).foregroundStyle(.secondary)
      }

      if !model.goals.isEmpty {
        Divider()
        HStack {
          Text("Today's goals").font(.subheadline.weight(.semibold))
          Spacer()
          Text("\(model.goals.filter(\.done).count) of \(model.goals.count) done")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        ForEach(model.goals) { goal in
          Button {
            model.toggle(goal)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: goal.done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(goal.done ? teal : .secondary)
              Text(goal.text)
                .strikethrough(goal.done)
                .foregroundStyle(goal.done ? .secondary : .primary)
                .multilineTextAlignment(.leading)
              Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(goal.text)
          .accessibilityValue(goal.done ? "Done" : "Not done")
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
