import AppKit
import Foundation
import RcmdCore

public struct WorkspaceSnapshot: Sendable {
  public init() {}

  public func runningApps() -> [RunningApp] {
    let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

    return NSWorkspace.shared.runningApplications
      .filter { application in
        guard application.bundleIdentifier != nil, application.localizedName != nil else {
          return false
        }
        return application.activationPolicy == .regular
      }
      .enumerated()
      .map { offset, application in
        RunningApp(
          app: AppIdentity(
            bundleIdentifier: application.bundleIdentifier!,
            name: CanonicalAppName.resolve(application.localizedName!),
            bundleURL: application.bundleURL
          ),
          processIdentifier: application.processIdentifier,
          recency: application.processIdentifier == frontmostPID ? Int.max : -offset
        )
      }
  }
}
