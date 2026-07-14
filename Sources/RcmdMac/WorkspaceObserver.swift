@preconcurrency import AppKit
import Combine
import RcmdCore

@MainActor
public final class WorkspaceObserver: ObservableObject {
  @Published public private(set) var runningApps: [RunningApp] = []

  private var recencyByBundleID: [String: Int] = [:]
  private var recencyCounter = 0
  private var lastFrontmostBundleID: String?
  private var observers: [NSObjectProtocol] = []

  public init(center: NotificationCenter = NSWorkspace.shared.notificationCenter) {
    let names: [Notification.Name] = [
      NSWorkspace.didLaunchApplicationNotification,
      NSWorkspace.didTerminateApplicationNotification,
      NSWorkspace.didActivateApplicationNotification,
    ]
    observers = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.refresh()
        }
      }
    }
    refresh()
  }

  public func refresh() {
    let snapshot = WorkspaceSnapshot().runningApps()
    let frontmostBundleID = snapshot.first(where: { $0.recency == Int.max })?.app.bundleIdentifier
    if let frontmostBundleID, frontmostBundleID != lastFrontmostBundleID {
      recencyCounter += 1
      recencyByBundleID[frontmostBundleID] = recencyCounter
      lastFrontmostBundleID = frontmostBundleID
    }

    let runningBundleIDs = Set(snapshot.map(\.app.bundleIdentifier))
    recencyByBundleID = recencyByBundleID.filter { runningBundleIDs.contains($0.key) }
    runningApps = snapshot.map { running in
      RunningApp(
        app: running.app,
        processIdentifier: running.processIdentifier,
        recency: recencyByBundleID[running.app.bundleIdentifier] ?? 0
      )
    }
  }
}
