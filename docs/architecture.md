# Architecture

## Product scope

- Static key-to-app assignments persist even when the app is closed.
- Static assignments reserve their letters and always win.
- Running, non-static apps receive dynamic assignments for unreserved letters.
- Dynamic assignments disappear when the corresponding process terminates.
- Triggering launches a closed static app, activates a background app, or
  cycles windows when the app is already frontmost.

The initial collision policy is deterministic and easy to test: consider apps
in most-recently-used order, then let each app compete for the first letter in
its display name. A static assignment reserves that letter completely; a losing
dynamic candidate gets no fallback key. We can change this policy without
touching keyboard or window-management code.

## Runtime boundaries

1. `WorkspaceObserver` converts `NSWorkspace` launch, terminate, activate, and
   rename notifications into a running-app snapshot with recency values.
2. `AssignmentResolver` is a pure Swift value that combines static settings
   with that snapshot.
3. `KeyboardEventSource` recognizes the physical Right Option key and letters,
   consumes matched keystrokes, and re-enables its event tap after a timeout.
4. `CommandDispatcher` contains the only launch/activate/cycle decision tree.
5. `MacAppController` implements that decision tree with `NSWorkspace`,
   `NSRunningApplication`, and `AXUIElement`. A short-lived stable window cycle
   preserves the original window order because some applications reorder their
   Accessibility window list after every focus change.
6. The SwiftUI menu/settings UI only edits settings and renders snapshots.

The keyboard source and test transport both submit the same typed command. A
test endpoint must never duplicate application-switching logic.

## Agent-friendly test control

The checked-in `rcmd-devtool` is the first layer: JSON Lines over stdin with a
fake controller. It makes resolver and dispatcher scenarios reproducible in CI
without Accessibility permission or synthesized keyboard events.

For packaged end-to-end tests, add a development-only loopback HTTP server:

- Bind only to `127.0.0.1` on an ephemeral port.
- Enable it only with `RCMD_ENABLE_TEST_API=1` or a debug build flag.
- Write its selected port and random per-launch bearer token to a file under
  the app's temporary directory.
- Accept semantic events such as `triggerKey`, `refreshApps`, and `snapshot`.
- Route `triggerKey` through `CommandDispatcher`, exactly like the event tap.
- Never ship or enable the listener in release builds.

The server should support two controller modes:

- `recording`: deterministic tests with no external side effects.
- `live`: exercises actual `NSWorkspace` and Accessibility behavior against
  fixture applications created specifically for tests.

A tiny fixture app can expose three named windows and a JSON state file. That
lets an agent verify activation and window cycling without relying on Chrome,
Zed, or any other user's current session.

## Dependencies

No third-party package is required for the first release. SwiftUI, AppKit,
ApplicationServices, ServiceManagement, Foundation, and Network all ship with
macOS. Avoiding dependencies keeps the command-line build and signing surface
small.

If a router becomes worthwhile for the debug-only server, prefer a tiny
`Network.framework` handler over adding a production dependency solely for
tests.

## SwiftPM application packaging

SwiftPM can compile and test all modules without opening Xcode. A release script
will assemble the executable, `Info.plist`, resources, and icon into a standard
`.app` directory before code signing. Xcode may remain installed as the SDK and
signing-tool provider, but no `.xcodeproj` is required.

## Current targets

- `RcmdCore`: models, resolver, dispatcher, protocols.
- `RcmdMac`: live Workspace discovery, persisted settings, app control,
  Accessibility window cycling, and the Right Option event tap.
- `RcmdApp`: SwiftUI/AppKit menu-bar and settings-window executable.
- `PreviewOverlayController`: delayed, non-activating bottom-right assignment
  preview driven by trigger press/release events.
- `RcmdDevTool`: JSON Lines simulation harness.

## Remaining implementation

- Add the authenticated debug-only loopback server and fixture app.
- Improve Accessibility window filtering for sheets, minimized windows, and
  utility panels.
- Add launch-at-login support and permission deep links.
- Add settings for preview delay, preview visibility, and trigger selection.
- `RcmdFixtureApp`: development-only multi-window test application.
