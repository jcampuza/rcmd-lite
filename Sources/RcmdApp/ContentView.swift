import AppKit
import RcmdCore
import RcmdMac
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel
  @State private var editingBundleID: String?
  @State private var editedKey = ""
  @FocusState private var keyEditorFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header

      Label("Hold Right Option (⌥), then press an assigned letter", systemImage: "keyboard")
        .font(.callout)
        .foregroundStyle(.secondary)

      List {
        Section {
          if model.staticAssignments.isEmpty {
            Label(
              "No pinned apps — pin one below to keep its shortcut after it quits.",
              systemImage: "pin"
            )
            .foregroundStyle(.secondary)
          } else {
            ForEach(model.staticAssignments, id: \.app.bundleIdentifier) { assignment in
              appRow(
                app: assignment.app,
                key: assignment.key,
                keyKind: .static,
                isRunning: model.runningApps.contains {
                  $0.app.bundleIdentifier == assignment.app.bundleIdentifier
                }
              )
            }
          }
        } header: {
          Label("Pinned", systemImage: "pin.fill")
        }

        Section {
          if model.dynamicAssignments.isEmpty && model.unassignedRunningApps.isEmpty {
            Text("No other applications are running")
              .foregroundStyle(.secondary)
          } else {
            ForEach(model.dynamicAssignments, id: \.app.bundleIdentifier) { dynamic in
              appRow(
                app: dynamic.app,
                key: dynamic.key,
                keyKind: .dynamic,
                isRunning: true
              )
            }
            ForEach(model.unassignedRunningApps, id: \.app.bundleIdentifier) { running in
              appRow(
                app: running.app,
                key: nil,
                keyKind: nil,
                isRunning: true
              )
            }
          }
        } header: {
          HStack {
            Label("Running Apps", systemImage: "circle.fill")
            Spacer()
            Text("Temporary shortcuts")
              .fontWeight(.regular)
              .textCase(nil)
              .foregroundStyle(.tertiary)
          }
        }
      }
      .listStyle(.inset)
      .frame(minHeight: 290)

      footer
    }
    .padding(18)
    .frame(width: 620, height: 520)
    .onAppear { model.refreshPermissions() }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 3) {
        Text("RcmdLite")
          .font(.title2.bold())
        Text("App shortcuts")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        permissionLabel("Accessibility", granted: model.accessibilityTrusted)
        permissionLabel("Input Monitoring", granted: model.inputMonitoringTrusted)
      }
    }
  }

  @ViewBuilder
  private func appRow(
    app: AppIdentity,
    key: String?,
    keyKind: AssignmentKind?,
    isRunning: Bool
  ) -> some View {
    HStack(spacing: 11) {
      appIcon(for: app)

      VStack(alignment: .leading, spacing: 2) {
        Text(app.name)
          .lineLimit(1)
        HStack(spacing: 5) {
          Circle()
            .fill(isRunning ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 6, height: 6)
          Text(isRunning ? "Running" : "Not running")
          if keyKind == .dynamic {
            Text("• Temporary")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Spacer()

      if editingBundleID == app.bundleIdentifier {
        TextField("Key", text: $editedKey)
          .textFieldStyle(.roundedBorder)
          .multilineTextAlignment(.center)
          .font(.system(.body, design: .monospaced).bold())
          .frame(width: 46)
          .focused($keyEditorFocused)
          .onSubmit { commitEdit(for: app) }
          .onChange(of: editedKey) { newValue in
            let normalized = String(newValue.lowercased().filter(\.isLetter).prefix(1))
            if editedKey != normalized { editedKey = normalized }
          }
        Button("Save") { commitEdit(for: app) }
          .buttonStyle(.borderless)
          .disabled(editedKey.isEmpty)
        Button("Cancel") { cancelEdit() }
          .buttonStyle(.borderless)
      } else {
        Button {
          beginEdit(app: app, suggestedKey: key)
        } label: {
          Text(key?.uppercased() ?? "—")
            .font(.system(.body, design: .monospaced).bold())
            .foregroundStyle(key == nil ? .secondary : .primary)
            .frame(minWidth: 22)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(key == nil ? "Assign a key" : "Change shortcut key")

        if keyKind == .static {
          Button {
            model.unpin(app: app)
          } label: {
            Image(systemName: "pin.slash")
          }
          .buttonStyle(.borderless)
          .help("Unpin \(app.name)")
          .accessibilityLabel("Unpin \(app.name)")
        } else {
          Button {
            model.pin(app: app)
          } label: {
            Image(systemName: "plus.circle.fill")
          }
          .buttonStyle(.borderless)
          .help(key.map { "Pin \(app.name) to \($0.uppercased())" } ?? "Pin \(app.name)")
          .accessibilityLabel("Pin \(app.name)")
        }
      }
    }
    .padding(.vertical, 3)
    .contextMenu {
      if let key {
        Button("Test \(key.uppercased())") { model.trigger(key: key) }
      }
    }
  }

  private var footer: some View {
    HStack {
      Text(model.lastMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
      Spacer()
      Button("Preview") { model.previewAssignments() }
      if !model.accessibilityTrusted {
        Button("Grant Accessibility") { model.requestAccessibility() }
      }
      if !model.inputMonitoringTrusted {
        Button("Grant Input Monitoring") { model.requestInputMonitoring() }
      }
      Button("Quit") { NSApplication.shared.terminate(nil) }
    }
  }

  private func beginEdit(app: AppIdentity, suggestedKey: String?) {
    editingBundleID = app.bundleIdentifier
    editedKey = suggestedKey ?? ""
    keyEditorFocused = true
  }

  private func commitEdit(for app: AppIdentity) {
    guard !editedKey.isEmpty else { return }
    model.assign(key: editedKey, app: app)
    cancelEdit()
  }

  private func cancelEdit() {
    editingBundleID = nil
    editedKey = ""
    keyEditorFocused = false
  }

  @ViewBuilder
  private func appIcon(for app: AppIdentity) -> some View {
    if let bundleURL = app.bundleURL {
      Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
        .resizable()
        .scaledToFit()
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    } else {
      Image(systemName: "app.fill")
        .font(.title2)
        .foregroundStyle(.secondary)
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
  }

  private func permissionLabel(_ name: String, granted: Bool) -> some View {
    Label(
      "\(name): \(granted ? "Enabled" : "Required")",
      systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    )
    .font(.caption)
    .foregroundStyle(granted ? .green : .orange)
  }
}
