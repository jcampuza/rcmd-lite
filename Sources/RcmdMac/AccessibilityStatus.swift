import AppKit
import ApplicationServices
import Foundation

private enum PrivacySettingsPane {
  static let accessibility = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  )!
  static let inputMonitoring = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
  )!

  @discardableResult
  static func open(_ url: URL) -> Bool {
    NSWorkspace.shared.open(url)
  }
}

public enum AccessibilityStatus {
  public static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  public static func requestAccess() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  @discardableResult
  public static func openSystemSettings() -> Bool {
    PrivacySettingsPane.open(PrivacySettingsPane.accessibility)
  }
}

public enum InputMonitoringStatus {
  public static var isTrusted: Bool {
    CGPreflightListenEventAccess()
  }

  @discardableResult
  public static func requestAccess() -> Bool {
    CGRequestListenEventAccess()
  }

  /// `CGRequestListenEventAccess` only presents a prompt the first time macOS sees
  /// an app. After a denial (and on some macOS releases), it returns `false`
  /// without navigating anywhere, so callers need an explicit Settings route.
  @discardableResult
  public static func openSystemSettings() -> Bool {
    PrivacySettingsPane.open(PrivacySettingsPane.inputMonitoring)
  }
}
