import Foundation

public enum CanonicalAppName {
  private static let vendorPrefixes = ["Google ", "Microsoft "]

  public static func resolve(_ localizedName: String) -> String {
    for prefix in vendorPrefixes where localizedName.hasPrefix(prefix) {
      let candidate = String(localizedName.dropFirst(prefix.count))
      if !candidate.isEmpty { return candidate }
    }
    return localizedName
  }
}
