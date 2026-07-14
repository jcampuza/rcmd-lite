import AppKit
import SwiftUI

@main
struct RcmdLiteApp: App {
  @StateObject private var model = AppModel()

  init() {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  var body: some Scene {
    WindowGroup("RcmdLite") {
      ContentView(model: model)
    }
    .defaultSize(width: 560, height: 360)

    MenuBarExtra("RcmdLite", systemImage: "command.square") {
      ContentView(model: model)
    }
    .menuBarExtraStyle(.window)
  }
}
