import Foundation

public enum SwitchAction: String, Codable, Sendable {
  case launch
  case activate
  case cycleWindow
}

public struct SwitchResult: Codable, Equatable, Sendable {
  public let action: SwitchAction
  public let app: AppIdentity

  public init(action: SwitchAction, app: AppIdentity) {
    self.action = action
    self.app = app
  }
}

public protocol AppControlling: Sendable {
  func isRunning(_ app: AppIdentity) async throws -> Bool
  func isFrontmost(_ app: AppIdentity) async throws -> Bool
  func launch(_ app: AppIdentity) async throws
  func activate(_ app: AppIdentity) async throws
  func cycleWindow(_ app: AppIdentity) async throws
}

public struct CommandDispatcher: Sendable {
  private let controller: any AppControlling

  public init(controller: any AppControlling) {
    self.controller = controller
  }

  /// Both the physical event tap and the development JSON transport call here.
  public func trigger(_ assignment: ResolvedAssignment) async throws -> SwitchResult {
    if try await !controller.isRunning(assignment.app) {
      try await controller.launch(assignment.app)
      return SwitchResult(action: .launch, app: assignment.app)
    }
    if try await controller.isFrontmost(assignment.app) {
      try await controller.cycleWindow(assignment.app)
      return SwitchResult(action: .cycleWindow, app: assignment.app)
    }
    try await controller.activate(assignment.app)
    return SwitchResult(action: .activate, app: assignment.app)
  }
}
