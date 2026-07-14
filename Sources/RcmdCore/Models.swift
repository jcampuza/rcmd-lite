import Foundation

public struct AppIdentity: Codable, Hashable, Sendable {
  public let bundleIdentifier: String
  public let name: String
  public let bundleURL: URL?

  public init(bundleIdentifier: String, name: String, bundleURL: URL? = nil) {
    self.bundleIdentifier = bundleIdentifier
    self.name = name
    self.bundleURL = bundleURL
  }
}

public struct RunningApp: Codable, Equatable, Sendable {
  public let app: AppIdentity
  public let processIdentifier: Int32
  public let recency: Int

  public init(app: AppIdentity, processIdentifier: Int32, recency: Int) {
    self.app = app
    self.processIdentifier = processIdentifier
    self.recency = recency
  }
}

public struct StaticAssignment: Codable, Equatable, Sendable {
  public let key: String
  public let app: AppIdentity

  public init(key: String, app: AppIdentity) {
    self.key = key
    self.app = app
  }
}

public enum AssignmentKind: String, Codable, Sendable {
  case `static`
  case dynamic
}

public struct ResolvedAssignment: Codable, Equatable, Sendable {
  public let key: String
  public let app: AppIdentity
  public let kind: AssignmentKind

  public init(key: String, app: AppIdentity, kind: AssignmentKind) {
    self.key = key
    self.app = app
    self.kind = kind
  }
}
