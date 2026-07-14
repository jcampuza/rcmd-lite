import AppKit
import ApplicationServices
import Foundation
import RcmdCore

public enum MacAppControllerError: Error, LocalizedError {
  case applicationNotFound(String)
  case applicationHasNoWindows(String)
  case accessibilityFailure(AXError)

  public var errorDescription: String? {
    switch self {
    case .applicationNotFound(let name): "Could not find \(name)."
    case .applicationHasNoWindows(let name): "\(name) has no accessible windows."
    case .accessibilityFailure(let error): "Accessibility operation failed (\(error.rawValue))."
    }
  }
}

public final class MacAppController: AppControlling, @unchecked Sendable {
  private struct WindowReference: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowReference, rhs: WindowReference) -> Bool {
      CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(CFHash(element))
    }
  }

  private let cycleLock = NSLock()
  private var cycleTracker = WindowCycleTracker<WindowReference>()

  public init() {}

  public func isRunning(_ app: AppIdentity) async throws -> Bool {
    runningApplication(for: app) != nil
  }

  public func isFrontmost(_ app: AppIdentity) async throws -> Bool {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier == app.bundleIdentifier
  }

  public func launch(_ app: AppIdentity) async throws {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true

    if let bundleURL = app.bundleURL {
      _ = try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
      return
    }
    guard
      let bundleURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: app.bundleIdentifier)
    else {
      throw MacAppControllerError.applicationNotFound(app.name)
    }
    _ = try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
  }

  public func activate(_ app: AppIdentity) async throws {
    guard let application = runningApplication(for: app) else {
      throw MacAppControllerError.applicationNotFound(app.name)
    }
    application.activate(options: [.activateAllWindows])
  }

  public func cycleWindow(_ app: AppIdentity) async throws {
    try cycleLock.withLock {
      try cycleWindowSynchronously(app)
    }
  }

  private func cycleWindowSynchronously(_ app: AppIdentity) throws {
    guard let application = runningApplication(for: app) else {
      throw MacAppControllerError.applicationNotFound(app.name)
    }

    let element = AXUIElementCreateApplication(application.processIdentifier)
    var value: CFTypeRef?
    let copyError = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
    guard copyError == .success else { throw MacAppControllerError.accessibilityFailure(copyError) }
    guard let windows = value as? [AXUIElement], !windows.isEmpty else {
      cycleTracker.reset(appID: app.bundleIdentifier)
      throw MacAppControllerError.applicationHasNoWindows(app.name)
    }

    var focusedValue: CFTypeRef?
    _ = AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focusedValue)
    let focused = focusedValue as! AXUIElement?
    let windowReferences = windows.map(WindowReference.init)
    let focusedReference = focused.map(WindowReference.init)
    guard
      let target = cycleTracker.nextWindow(
        appID: app.bundleIdentifier,
        windows: windowReferences,
        focusedWindow: focusedReference,
        now: ProcessInfo.processInfo.systemUptime
      )
    else {
      throw MacAppControllerError.applicationHasNoWindows(app.name)
    }

    let raiseError = AXUIElementPerformAction(target.element, kAXRaiseAction as CFString)
    guard raiseError == .success else {
      cycleTracker.reset(appID: app.bundleIdentifier)
      throw MacAppControllerError.accessibilityFailure(raiseError)
    }
    _ = AXUIElementSetAttributeValue(
      element,
      kAXFocusedWindowAttribute as CFString,
      target.element
    )
    application.activate()
  }

  private func runningApplication(for app: AppIdentity) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first
  }
}
