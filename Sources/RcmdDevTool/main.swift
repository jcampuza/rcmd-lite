import Foundation
import RcmdCore
import RcmdMac

private struct Request: Codable {
  let assignment: ResolvedAssignment
  let running: Bool
  let frontmost: Bool
}

private actor RecordingController: AppControlling {
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

@main
private enum DevTool {
  static func main() async throws {
    if CommandLine.arguments.dropFirst().first == "snapshot" {
      let apps = WorkspaceSnapshot().runningApps()
      let assignments = AssignmentResolver().resolve(staticAssignments: [], runningApps: apps)
      let response = SnapshotResponse(runningApps: apps, dynamicAssignments: assignments)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      print(String(decoding: try encoder.encode(response), as: UTF8.self))
      return
    }

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    while let line = readLine() {
      do {
        let request = try decoder.decode(Request.self, from: Data(line.utf8))
        let controller = RecordingController(
          running: request.running,
          frontmost: request.frontmost
        )
        let result = try await CommandDispatcher(controller: controller)
          .trigger(request.assignment)
        print(String(decoding: try encoder.encode(result), as: UTF8.self))
      } catch {
        let message = ["error": String(describing: error)]
        print(String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self))
      }
    }
  }
}

private struct SnapshotResponse: Codable {
  let runningApps: [RunningApp]
  let dynamicAssignments: [String: ResolvedAssignment]
}
