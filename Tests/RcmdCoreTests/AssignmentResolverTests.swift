import Foundation
import Testing

@testable import RcmdCore

private let chrome = AppIdentity(bundleIdentifier: "com.google.Chrome", name: "Chrome")
private let cursor = AppIdentity(bundleIdentifier: "com.cursor.Cursor", name: "Cursor")
private let calendar = AppIdentity(bundleIdentifier: "com.apple.iCal", name: "Calendar")

@Test func staticAssignmentWinsItsKey() {
  let assignments = AssignmentResolver().resolve(
    staticAssignments: [StaticAssignment(key: "c", app: cursor)],
    runningApps: [RunningApp(app: chrome, processIdentifier: 1, recency: 10)]
  )

  #expect(assignments["c"]?.app == cursor)
  #expect(assignments["c"]?.kind == .static)
  #expect(!assignments.values.contains(where: { $0.app == chrome }))
}

@Test func mostRecentRunningAppWinsDynamicCollision() {
  let assignments = AssignmentResolver().resolve(
    staticAssignments: [],
    runningApps: [
      RunningApp(app: calendar, processIdentifier: 1, recency: 1),
      RunningApp(app: chrome, processIdentifier: 2, recency: 2),
    ]
  )

  #expect(assignments["c"]?.app == chrome)
  #expect(!assignments.values.contains(where: { $0.app == calendar }))
}

@Test func closedUnassignedAppHasNoDynamicAssignment() {
  let assignments = AssignmentResolver().resolve(
    staticAssignments: [],
    runningApps: []
  )

  #expect(assignments["c"] == nil)
}
