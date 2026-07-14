import AppKit
import Combine
import RcmdCore
import RcmdMac

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var resolved: [String: ResolvedAssignment] = [:]
  @Published var lastMessage = "Ready"
  @Published private(set) var accessibilityTrusted = AccessibilityStatus.isTrusted
  @Published private(set) var inputMonitoringTrusted = InputMonitoringStatus.isTrusted

  let workspace = WorkspaceObserver()
  let store = AssignmentStore()

  private let resolver = AssignmentResolver()
  private let dispatcher = CommandDispatcher(controller: MacAppController())
  private let previewOverlay = PreviewOverlayController()
  private var cancellables = Set<AnyCancellable>()
  private var keyboard: KeyboardEventSource?

  init() {
    workspace.$runningApps
      .combineLatest(store.$assignments)
      .sink { [weak self] runningApps, assignments in
        guard let self else { return }
        let nextResolved = resolver.resolve(
          staticAssignments: assignments,
          runningApps: runningApps
        )
        resolved = nextResolved

        let assignedBundleIDs = Set(nextResolved.values.map(\.app.bundleIdentifier))
        previewOverlay.update(
          snapshot: PreviewOverlaySnapshot(
            staticAssignments: nextResolved.values
              .filter { $0.kind == .static }
              .sorted { $0.key < $1.key },
            dynamicAssignments: nextResolved.values
              .filter { $0.kind == .dynamic }
              .sorted { $0.key < $1.key },
            unassignedApps:
              runningApps
              .map(\.app)
              .filter { !assignedBundleIDs.contains($0.bundleIdentifier) }
              .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
              }
          )
        )
      }
      .store(in: &cancellables)

    keyboard = KeyboardEventSource(
      handler: { [weak self] key in
        Task { @MainActor in
          self?.trigger(key: key)
        }
      },
      triggerHandler: { [weak self] isHeld in
        Task { @MainActor in
          self?.previewOverlay.triggerChanged(isHeld: isHeld)
        }
      }
    )

    NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      .sink { [weak self] _ in
        self?.refreshPermissions()
      }
      .store(in: &cancellables)
    startKeyboardIfAuthorized()
  }

  var runningApps: [RunningApp] {
    workspace.runningApps.sorted {
      $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
    }
  }

  var staticAssignments: [StaticAssignment] {
    store.assignments.sorted {
      $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
    }
  }

  var dynamicAssignments: [ResolvedAssignment] {
    resolved.values
      .filter { $0.kind == .dynamic }
      .sorted { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }
  }

  var unassignedRunningApps: [RunningApp] {
    let assignedBundleIDs = Set(resolved.values.map(\.app.bundleIdentifier))
    return runningApps.filter { !assignedBundleIDs.contains($0.app.bundleIdentifier) }
  }

  func assign(key: String, app: AppIdentity) {
    store.assign(key: key, app: app)
  }

  func pin(app: AppIdentity) {
    if let temporary = dynamicAssignments.first(where: {
      $0.app.bundleIdentifier == app.bundleIdentifier
    }) {
      assign(key: temporary.key, app: app)
      return
    }

    let reserved = Set(store.assignments.map { $0.key.lowercased() })
    guard
      let key = app.name.lowercased().first(where: {
        $0.isLetter && !reserved.contains(String($0))
      })
    else {
      lastMessage = "No available letter for \(app.name)"
      return
    }
    assign(key: String(key), app: app)
  }

  func unpin(app: AppIdentity) {
    store.remove(app: app)
  }

  func trigger(key: String) {
    guard let assignment = resolved[key.lowercased()] else {
      lastMessage = "No assignment for \(key.uppercased())"
      return
    }
    Task {
      do {
        let result = try await dispatcher.trigger(assignment)
        lastMessage = "\(result.action.rawValue.capitalized): \(result.app.name)"
      } catch {
        lastMessage = error.localizedDescription
      }
    }
  }

  func previewAssignments() {
    previewOverlay.triggerChanged(isHeld: true)
    Task {
      try? await Task.sleep(for: .seconds(3))
      previewOverlay.triggerChanged(isHeld: false)
    }
  }

  func requestAccessibility() {
    AccessibilityStatus.requestAccess()
    refreshPermissions()
  }

  func requestInputMonitoring() {
    InputMonitoringStatus.requestAccess()
    if !InputMonitoringStatus.isTrusted {
      InputMonitoringStatus.openSystemSettings()
      lastMessage = "Enable RcmdLite in Input Monitoring, then relaunch"
    }
    refreshPermissions()
  }

  func refreshPermissions() {
    accessibilityTrusted = AccessibilityStatus.isTrusted
    inputMonitoringTrusted = InputMonitoringStatus.isTrusted
    startKeyboardIfAuthorized()
  }

  private func startKeyboardIfAuthorized() {
    guard inputMonitoringTrusted else {
      lastMessage = "Grant Input Monitoring, then relaunch RcmdLite"
      return
    }
    if keyboard?.start() == true {
      lastMessage = "Listening for Right Option + letter"
    } else {
      lastMessage = "Keyboard event tap failed; relaunch after granting permissions"
    }
  }
}
