import Foundation

struct WindowCycleTracker<WindowID: Hashable> {
  struct State {
    var orderedWindows: [WindowID]
    var nextIndex: Int
    var expectedFocusedWindow: WindowID
    var lastCycleTime: TimeInterval
  }

  var continuationInterval: TimeInterval = 2
  private var states: [String: State] = [:]

  mutating func nextWindow(
    appID: String,
    windows: [WindowID],
    focusedWindow: WindowID?,
    now: TimeInterval
  ) -> WindowID? {
    guard !windows.isEmpty else {
      states[appID] = nil
      return nil
    }

    let liveSet = Set(windows)
    if var state = states[appID],
      now - state.lastCycleTime <= continuationInterval,
      Set(state.orderedWindows) == liveSet,
      focusedWindow == state.expectedFocusedWindow
    {
      let target = state.orderedWindows[state.nextIndex]
      state.nextIndex = (state.nextIndex + 1) % state.orderedWindows.count
      state.expectedFocusedWindow = target
      state.lastCycleTime = now
      states[appID] = state
      return target
    }

    let currentIndex = focusedWindow.flatMap { windows.firstIndex(of: $0) }
    let targetIndex = currentIndex.map { ($0 + 1) % windows.count } ?? 0
    let target = windows[targetIndex]
    states[appID] = State(
      orderedWindows: windows,
      nextIndex: (targetIndex + 1) % windows.count,
      expectedFocusedWindow: target,
      lastCycleTime: now
    )
    return target
  }

  mutating func reset(appID: String) {
    states[appID] = nil
  }
}
