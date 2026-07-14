import Foundation

public struct AssignmentResolver: Sendable {
  public init() {}

  /// Static assignments reserve their keys. Running apps are then considered
  /// from most to least recent and compete for the first letter of their
  /// display name. Dynamic assignments disappear with the process.
  public func resolve(
    staticAssignments: [StaticAssignment],
    runningApps: [RunningApp]
  ) -> [String: ResolvedAssignment] {
    var result: [String: ResolvedAssignment] = [:]

    for assignment in staticAssignments {
      let key = normalized(assignment.key)
      result[key] = ResolvedAssignment(key: key, app: assignment.app, kind: .static)
    }

    let staticallyAssignedApps = Set(staticAssignments.map(\.app.bundleIdentifier))
    for running in runningApps.sorted(by: isMoreRecent) {
      guard !staticallyAssignedApps.contains(running.app.bundleIdentifier) else { continue }
      guard let key = preferredKey(for: running.app.name), result[key] == nil else {
        continue
      }
      result[key] = ResolvedAssignment(key: key, app: running.app, kind: .dynamic)
    }

    return result
  }

  private func preferredKey(for name: String) -> String? {
    name.lowercased().first(where: \.isLetter).map(String.init)
  }

  private func normalized(_ key: String) -> String {
    String(key.lowercased().prefix(1))
  }

  private func isMoreRecent(_ lhs: RunningApp, _ rhs: RunningApp) -> Bool {
    if lhs.recency != rhs.recency { return lhs.recency > rhs.recency }
    return lhs.app.bundleIdentifier < rhs.app.bundleIdentifier
  }
}
