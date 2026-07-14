import AppKit
import RcmdCore
import SwiftUI

/// A snapshot of the apps displayed while the trigger modifier is held.
struct PreviewOverlaySnapshot: Equatable {
  var staticAssignments: [ResolvedAssignment]
  var dynamicAssignments: [ResolvedAssignment]
  var unassignedApps: [AppIdentity]

  static let empty = PreviewOverlaySnapshot(
    staticAssignments: [], dynamicAssignments: [], unassignedApps: [])
}

/// Owns a delayed, non-activating app-switcher preview.
///
/// Integration from `AppModel` is intentionally small:
/// - call `update(snapshot:)` whenever assignments/running apps change
/// - call `triggerChanged(isHeld:)` from `KeyboardEventSource.triggerHandler`
@MainActor
final class PreviewOverlayController {
  var presentationDelay: Duration = .milliseconds(550)
  var showsUnassignedApps = true

  private let model = PreviewOverlayModel()
  private var panel: PreviewPanel?
  private var presentationTask: Task<Void, Never>?

  func update(snapshot: PreviewOverlaySnapshot) {
    model.snapshot = snapshot
    if panel?.isVisible == true {
      positionPanel()
    }
  }

  func triggerChanged(isHeld: Bool) {
    presentationTask?.cancel()
    presentationTask = nil

    guard isHeld else {
      hide()
      return
    }

    let delay = presentationDelay
    presentationTask = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else { return }
      self?.show()
    }
  }

  func hide() {
    presentationTask?.cancel()
    presentationTask = nil
    panel?.orderOut(nil)
  }

  private func show() {
    guard
      !model.snapshot.staticAssignments.isEmpty
        || !model.snapshot.dynamicAssignments.isEmpty
        || (showsUnassignedApps && !model.snapshot.unassignedApps.isEmpty)
    else { return }

    let panel = panel ?? makePanel()
    self.panel = panel
    model.showsUnassignedApps = showsUnassignedApps
    positionPanel()
    panel.orderFrontRegardless()
  }

  private func makePanel() -> PreviewPanel {
    let panel = PreviewPanel(
      contentRect: NSRect(x: 0, y: 0, width: 330, height: 420),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.contentView = NSHostingView(rootView: PreviewOverlayView(model: model))
    return panel
  }

  private func positionPanel() {
    guard let panel else { return }
    panel.contentView?.layoutSubtreeIfNeeded()
    let fittingSize = panel.contentView?.fittingSize ?? NSSize(width: 330, height: 420)
    let size = NSSize(
      width: max(300, min(fittingSize.width, 380)),
      height: max(120, min(fittingSize.height, 620))
    )
    panel.setContentSize(size)

    let screen =
      NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
      ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else { return }
    panel.setFrameOrigin(
      NSPoint(
        x: visibleFrame.maxX - size.width - 20,
        y: visibleFrame.minY + 20
      ))
  }
}

@MainActor
private final class PreviewOverlayModel: ObservableObject {
  @Published var snapshot = PreviewOverlaySnapshot.empty
  @Published var showsUnassignedApps = true
}

private final class PreviewPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private struct PreviewOverlayView: View {
  @ObservedObject var model: PreviewOverlayModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !model.snapshot.staticAssignments.isEmpty {
        section("Assigned", assignments: model.snapshot.staticAssignments, primary: true)
      }
      if !model.snapshot.dynamicAssignments.isEmpty {
        section("Temporary", assignments: model.snapshot.dynamicAssignments, primary: false)
      }
      if model.showsUnassignedApps, !model.snapshot.unassignedApps.isEmpty {
        Divider()
        Text("Running")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        ForEach(model.snapshot.unassignedApps, id: \.bundleIdentifier) { app in
          appRow(app: app, key: nil, primary: false)
        }
      }
    }
    .padding(16)
    .frame(width: 330, alignment: .leading)
    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(.white.opacity(0.12))
    }
  }

  private func section(
    _ title: String,
    assignments: [ResolvedAssignment],
    primary: Bool
  ) -> some View {
    Group {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(primary ? .primary : .secondary)
      ForEach(assignments, id: \.app.bundleIdentifier) { assignment in
        appRow(app: assignment.app, key: assignment.key, primary: primary)
      }
    }
  }

  private func appRow(app: AppIdentity, key: String?, primary: Bool) -> some View {
    HStack(spacing: 10) {
      appIcon(for: app)
      Text(app.name)
        .font(primary ? .body.weight(.semibold) : .body)
        .lineLimit(1)
      Spacer(minLength: 8)
      if let key {
        Text(key.uppercased())
          .font(.system(.body, design: .rounded, weight: .bold))
          .frame(width: 30, height: 30)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  @ViewBuilder
  private func appIcon(for app: AppIdentity) -> some View {
    if let url = app.bundleURL {
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable()
        .frame(width: 28, height: 28)
    } else {
      Image(systemName: "app")
        .frame(width: 28, height: 28)
    }
  }
}
