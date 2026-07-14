# Repository Guidelines

## Project Structure

RcmdLite is a macOS-only Swift Package Manager project with no third-party
dependencies. `Sources/RcmdCore` contains platform-independent models,
assignment resolution, and command dispatch. `Sources/RcmdMac` owns AppKit,
Accessibility, workspace observation, keyboard events, persistence, and window
cycling. `Sources/RcmdApp` contains the SwiftUI menu-bar application and preview
overlay. `Sources/RcmdDevTool` provides the JSON Lines simulation CLI.

Tests mirror these boundaries under `Tests/RcmdCoreTests` and
`Tests/RcmdMacTests`. Application metadata and icons live in `Resources`, build
and signing automation in `scripts`, screenshots and design notes in `docs`.

## Development Commands

- `swift test`: build all targets and run the complete test suite.
- `swift build`: compile an unoptimized command-line development build.
- `swift run rcmd-devtool snapshot`: inspect running apps without changing
  focus.
- `./scripts/build-debug.sh`: install a packaged debug app at
  `~/Applications/RcmdLite Debug.app`.
- `./scripts/build-release.sh`: create the optimized packaged release app.

Run `swift test` after changes. Use the packaged debug build when testing
Accessibility, Input Monitoring, keyboard interception, or window focus; a
plain `swift run` does not have the same stable application identity.

## Architecture Guidelines

Keep macOS APIs out of `RcmdCore`. Put workspace, Accessibility, and AppKit
behavior in `RcmdMac`, and keep SwiftUI views focused on presentation. Route
launch, activation, and window-cycling decisions through `CommandDispatcher`
so keyboard input and development tooling exercise the same behavior.

## Testing Guidelines

Tests use Swift Testing (`import Testing`, `@Test`, and `#expect`). Give tests
behavior-oriented names such as `cycleSessionExpiresAfterPause`. Add regression
tests for assignment collisions, launch/focus dispatch, Accessibility window
ordering, and persistence changes.
