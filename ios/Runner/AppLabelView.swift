import FamilyControls
import Flutter
import SwiftUI
import UIKit

/// Shows the real icon and name of the app (or category or website) a rule watches.
/// Apple never tells Recenter what was picked, but its `Label(token)` view can draw it, so
/// Flutter embeds this view wherever a rule's app appears.
///
/// Creation params:
/// - `selection`: the rule's platformAppId (base64 FamilyActivitySelection JSON)
/// - `fallback`: text to show if the selection can't be read (demo data, old rules)
/// - `style`: "titleAndIcon" (default) or "iconOnly"
/// - `fontSize`, `color` (ARGB int): to match the Flutter text around it
final class AppLabelViewFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "recenter/app-label"

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    AppLabelPlatformView(frame: frame, params: args as? [String: Any] ?? [:])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class AppLabelPlatformView: NSObject, FlutterPlatformView {
  private let host: UIHostingController<AppLabelContent>

  init(frame: CGRect, params: [String: Any]) {
    let selection = (params["selection"] as? String).flatMap(ActivitySelectionCoding.decode)
    let argb = (params["color"] as? NSNumber)?.uint32Value ?? 0xFF00_0000
    let content = AppLabelContent(
      selection: selection,
      fallback: params["fallback"] as? String ?? "",
      iconOnly: params["style"] as? String == "iconOnly",
      fontSize: CGFloat((params["fontSize"] as? NSNumber)?.doubleValue ?? 16),
      color: Color(
        .sRGB,
        red: Double((argb >> 16) & 0xFF) / 255,
        green: Double((argb >> 8) & 0xFF) / 255,
        blue: Double(argb & 0xFF) / 255,
        opacity: Double((argb >> 24) & 0xFF) / 255
      )
    )
    host = UIHostingController(rootView: content)
    host.view.frame = frame
    host.view.backgroundColor = .clear
    // Taps belong to the Flutter row around it (e.g. "open this rule").
    host.view.isUserInteractionEnabled = false
    super.init()
  }

  func view() -> UIView { host.view }
}

private struct AppLabelContent: View {
  let selection: FamilyActivitySelection?
  let fallback: String
  let iconOnly: Bool
  let fontSize: CGFloat
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      label
        .labelStyle(StyleChoice(iconOnly: iconOnly))
        .lineLimit(1)
      if !iconOnly, extraCount > 0 {
        Text("+\(extraCount)").foregroundStyle(color.opacity(0.7))
      }
      Spacer(minLength: 0)
    }
    .font(.system(size: fontSize))
    .foregroundStyle(color)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  /// The first app, category or website in the selection, drawn by iOS.
  @ViewBuilder private var label: some View {
    if let token = selection?.applicationTokens.first {
      Label(token)
    } else if let token = selection?.categoryTokens.first {
      Label(token)
    } else if let token = selection?.webDomainTokens.first {
      Label(token)
    } else {
      Text(fallback)
    }
  }

  /// Anything else in the same rule, shown as "+N".
  private var extraCount: Int {
    guard let selection else { return 0 }
    let total = selection.applicationTokens.count + selection.categoryTokens.count
      + selection.webDomainTokens.count
    return max(0, total - 1)
  }
}

private struct StyleChoice: LabelStyle {
  let iconOnly: Bool

  func makeBody(configuration: Configuration) -> some View {
    if iconOnly {
      configuration.icon
    } else {
      HStack(spacing: 10) {
        configuration.icon
        configuration.title
      }
    }
  }
}
