import Testing

@testable import RcmdCore

private actor FakeController: AppControlling {
  let running: Bool
  let frontmost: Bool

  init(running: Bool, frontmost: Bool) {
    self.running = running
    self.frontmost = frontmost
  }

  func isRunning(_ app: AppIdentity) -> Bool { running }
  func isFrontmost(_ app: AppIdentity) -> Bool { frontmost }
  func launch(_ app: AppIdentity) {}
  func activate(_ app: AppIdentity) {}
  func cycleWindow(_ app: AppIdentity) {}
}

private let assignment = ResolvedAssignment(
  key: "c",
  app: AppIdentity(bundleIdentifier: "com.google.Chrome", name: "Chrome"),
  kind: .dynamic
)

@Test(arguments: [
  (false, false, SwitchAction.launch),
  (true, false, SwitchAction.activate),
  (true, true, SwitchAction.cycleWindow),
])
func dispatchesExpectedAction(running: Bool, frontmost: Bool, action: SwitchAction) async throws {
  let controller = FakeController(running: running, frontmost: frontmost)
  let result = try await CommandDispatcher(controller: controller).trigger(assignment)
  #expect(result.action == action)
}
