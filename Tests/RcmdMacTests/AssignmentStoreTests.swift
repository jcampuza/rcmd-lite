import Foundation
import RcmdCore
import Testing

@testable import RcmdMac

@MainActor
@Test func assignmentStorePersistsAndReplacesReservedKeys() {
  let suiteName = "RcmdMacTests.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defer { defaults.removePersistentDomain(forName: suiteName) }

  let chrome = AppIdentity(bundleIdentifier: "com.google.Chrome", name: "Chrome")
  let cursor = AppIdentity(bundleIdentifier: "com.cursor.Cursor", name: "Cursor")
  let store = AssignmentStore(defaults: defaults)
  store.assign(key: "C", app: chrome)
  store.assign(key: "c", app: cursor)

  #expect(store.assignments == [StaticAssignment(key: "c", app: cursor)])
  #expect(AssignmentStore(defaults: defaults).assignments == store.assignments)

  store.remove(app: cursor)
  #expect(store.assignments.isEmpty)
}
