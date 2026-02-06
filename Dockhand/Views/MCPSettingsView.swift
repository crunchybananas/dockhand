//
//  MCPSettingsView.swift
//  Dockhand
//
//  Created by Cory Loken on 2/5/26.
//
//  Settings pane for the MCP server – port, LAN mode, status,
//  IDE integration, and tool listing.
//

import SwiftUI
import UniformTypeIdentifiers

struct MCPSettingsView: View {
  @Environment(MCPService.self) private var mcpService

  @State private var portText: String = "8766"
  @State private var showCopiedToast: Bool = false

  // IDE Integration
  @State private var vscodeServerName = "Dockhand"
  @State private var vscodeServerURL = "http://127.0.0.1:8766/rpc"
  @State private var vscodeWriteToWorkspace = false
  @State private var vscodeWorkspacePath = ""
  @State private var isWritingVSCodeConfig = false
  @State private var vscodeConfigStatus: String?
  @State private var vscodeConfigError: String?
  @State private var isWorkspacePickerPresented = false

  var body: some View {
    @Bindable var mcp = mcpService

    Form {
      // MARK: - Server Status

      Section {
        HStack {
          Circle()
            .fill(mcpService.isRunning ? .green : .secondary)
            .frame(width: 10, height: 10)
          Text(mcpService.isRunning ? "Running on port \(mcpService.port)" : "Stopped")
            .foregroundStyle(mcpService.isRunning ? .primary : .secondary)

          Spacer()

          Button(mcpService.isRunning ? "Stop" : "Start") {
            if mcpService.isRunning {
              mcpService.stop()
            } else {
              mcpService.start()
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(mcpService.isRunning ? .red : .green)
        }

        if let error = mcpService.lastError {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .font(.caption)
        }
      } header: {
        Text("Server Status")
      }

      // MARK: - Configuration

      Section {
        LabeledContent("Port") {
          TextField("Port", text: $portText)
            .frame(width: 80)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
              if let newPort = Int(portText), (1024...65535).contains(newPort) {
                mcpService.setPort(newPort)
                vscodeServerURL = "http://127.0.0.1:\(newPort)/rpc"
              } else {
                portText = String(mcpService.port)
              }
            }
        }

        Toggle("Allow LAN connections", isOn: $mcp.lanModeEnabled)
          .onChange(of: mcpService.lanModeEnabled) { _, newValue in
            mcpService.setLanMode(newValue)
          }
      } header: {
        Text("Configuration")
      }

      // MARK: - IDE Integration

      Section {
        VStack(alignment: .leading, spacing: 12) {
          Text("Install Dockhand as an MCP server in VS Code.")
            .font(.caption)
            .foregroundStyle(.secondary)

          HStack(spacing: 12) {
            TextField("Server Name", text: $vscodeServerName)
              .textFieldStyle(.roundedBorder)
            TextField("Server URL", text: $vscodeServerURL)
              .textFieldStyle(.roundedBorder)
          }

          Toggle("Write to workspace settings", isOn: $vscodeWriteToWorkspace)
            .font(.caption)

          if vscodeWriteToWorkspace {
            HStack(spacing: 12) {
              TextField("Workspace folder", text: $vscodeWorkspacePath)
                .textFieldStyle(.roundedBorder)
              Button("Choose…") {
                isWorkspacePickerPresented = true
              }
            }
          }

          HStack {
            Button(isWritingVSCodeConfig ? "Installing…" : "Install VS Code Config") {
              Task { await installVSCodeMCPConfig() }
            }
            .disabled(isWritingVSCodeConfig)

            if let status = vscodeConfigStatus {
              Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let error = vscodeConfigError {
              Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            }
          }
        }
      } header: {
        Text("IDE Integration")
      }

      // MARK: - Manual Config

      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("Or add this to your MCP client config manually:")
            .font(.caption)
            .foregroundStyle(.secondary)

          let configSnippet = """
            {
              "servers": {
                "dockhand": {
                  "type": "http",
                  "url": "http://127.0.0.1:\(mcpService.port)/rpc"
                }
              }
            }
            """

          Text(configSnippet)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(configSnippet, forType: .string)
            showCopiedToast = true
            Task {
              try? await Task.sleep(for: .seconds(2))
              showCopiedToast = false
            }
          } label: {
            Label(showCopiedToast ? "Copied!" : "Copy Config", systemImage: showCopiedToast ? "checkmark" : "doc.on.doc")
          }
          .buttonStyle(.bordered)
        }
      } header: {
        Text("Manual Config")
      }

      // MARK: - Available Tools

      Section {
        VStack(alignment: .leading, spacing: 4) {
          toolRow("dockhand.release_ship", description: "Create a new ship")
          toolRow("dockhand.list_ships", description: "List ships (with filters)")
          toolRow("dockhand.get_ship", description: "Get ship details by ID")
          toolRow("dockhand.attest_ship", description: "Attest another agent's ship")
          toolRow("dockhand.list_posts", description: "Browse the feed")
          toolRow("dockhand.create_post", description: "Create a new post")
          toolRow("dockhand.get_profile", description: "Get agent profile")
          toolRow("dockhand.get_balance", description: "Get $SHIPYARD balance")
          toolRow("dockhand.generate_ship", description: "Auto-generate a microtool")
        }
      } header: {
        Text("Available Tools")
      }
    }
    .formStyle(.grouped)
    .padding()
    .onAppear {
      portText = String(mcpService.port)
      vscodeServerURL = "http://127.0.0.1:\(mcpService.port)/rpc"
    }
    .fileImporter(
      isPresented: $isWorkspacePickerPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      if case .success(let urls) = result, let url = urls.first {
        vscodeWorkspacePath = url.path
      }
    }
  }

  // MARK: - VS Code Config

  private func installVSCodeMCPConfig() async {
    vscodeConfigError = nil
    vscodeConfigStatus = nil
    isWritingVSCodeConfig = true
    defer { isWritingVSCodeConfig = false }

    let scope: VSCodeService.ConfigTarget
    if vscodeWriteToWorkspace {
      let trimmedPath = vscodeWorkspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedPath.isEmpty else {
        vscodeConfigError = "Choose a workspace folder first."
        return
      }
      scope = .workspace(path: trimmedPath)
    } else {
      scope = .user
    }

    do {
      let cleanName = vscodeServerName.trimmingCharacters(in: .whitespacesAndNewlines)
      let name = cleanName.isEmpty ? "Dockhand" : cleanName
      let url = vscodeServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
      let path = try await VSCodeService.shared.installMCPConfig(
        serverName: name,
        serverURL: url,
        scope: scope
      )
      vscodeConfigStatus = "Updated: \(path)"
    } catch {
      vscodeConfigError = error.localizedDescription
    }
  }

  // MARK: - Helpers

  @ViewBuilder
  private func toolRow(_ name: String, description: String) -> some View {
    HStack {
      Text(name)
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.primary)
      Spacer()
      Text(description)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 2)
  }
}
