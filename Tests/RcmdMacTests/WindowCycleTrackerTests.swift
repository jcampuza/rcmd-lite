import Testing

@testable import RcmdMac

@Test func cycleSessionIgnoresLiveMostRecentWindowReordering() {
  var tracker = WindowCycleTracker<String>()

  #expect(
    tracker.nextWindow(appID: "zed", windows: ["A", "B", "C"], focusedWindow: "A", now: 0)
      == "B")
  #expect(
    tracker.nextWindow(appID: "zed", windows: ["B", "A", "C"], focusedWindow: "B", now: 0.2)
      == "C")
  #expect(
    tracker.nextWindow(appID: "zed", windows: ["C", "B", "A"], focusedWindow: "C", now: 0.4)
      == "A")
}

@Test func cycleSessionResetsAfterExternalFocusChange() {
  var tracker = WindowCycleTracker<String>()

  #expect(
    tracker.nextWindow(appID: "chrome", windows: ["A", "B", "C"], focusedWindow: "A", now: 0)
      == "B")
  #expect(
    tracker.nextWindow(appID: "chrome", windows: ["C", "A", "B"], focusedWindow: "C", now: 0.2)
      == "A")
}

@Test func cycleSessionReconcilesWindowSetChanges() {
  var tracker = WindowCycleTracker<String>()

  #expect(
    tracker.nextWindow(appID: "zed", windows: ["A", "B", "C"], focusedWindow: "A", now: 0)
      == "B")
  #expect(
    tracker.nextWindow(appID: "zed", windows: ["B", "C", "D"], focusedWindow: "B", now: 0.2)
      == "C")
}

@Test func cycleSessionExpiresAfterPause() {
  var tracker = WindowCycleTracker<String>()

  #expect(
    tracker.nextWindow(appID: "chrome", windows: ["A", "B", "C"], focusedWindow: "A", now: 0)
      == "B")
  #expect(
    tracker.nextWindow(appID: "chrome", windows: ["B", "A", "C"], focusedWindow: "B", now: 3)
      == "A")
}
