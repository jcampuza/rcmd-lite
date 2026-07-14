import Foundation
import RcmdCore

@MainActor
public final class AssignmentStore: ObservableObject {
  @Published public private(set) var assignments: [StaticAssignment]

  private let defaults: UserDefaults
  private let storageKey = "staticAssignments"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: storageKey),
      let decoded = try? JSONDecoder().decode([StaticAssignment].self, from: data)
    {
      assignments = decoded
    } else {
      assignments = []
    }
  }

  public func assign(key: String, app: AppIdentity) {
    let normalized = String(key.lowercased().prefix(1))
    guard normalized.count == 1, normalized.first?.isLetter == true else { return }
    assignments.removeAll {
      $0.key.lowercased() == normalized || $0.app.bundleIdentifier == app.bundleIdentifier
    }
    assignments.append(StaticAssignment(key: normalized, app: app))
    assignments.sort { $0.key < $1.key }
    persist()
  }

  public func remove(key: String) {
    assignments.removeAll { $0.key.lowercased() == key.lowercased() }
    persist()
  }

  public func remove(app: AppIdentity) {
    assignments.removeAll { $0.app.bundleIdentifier == app.bundleIdentifier }
    persist()
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(assignments) else { return }
    defaults.set(data, forKey: storageKey)
  }
}
