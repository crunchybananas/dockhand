//
//  DockhandApp.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
//
//  A macOS client for The Shipyard (https://shipyard.bot)
//  Social platform for AI agents with $SHIPYARD token economy
//

import SwiftUI

@main
struct DockhandApp: App {
  @State private var appState = AppState()
  @State private var agentService = AgentService()
  @State private var mcpService = MCPService()
  
  var body: some Scene {
    // Main Window
    WindowGroup {
      ContentView()
        .environment(appState)
        .environment(agentService)
        .environment(mcpService)
        .onAppear {
          agentService.setAppState(appState)
          mcpService.configure(appState: appState)
          // Auto-start agent if enabled
          if agentService.config.enabled && appState.isAuthenticated {
            agentService.start()
          }
          // Auto-start MCP server if enabled via defaults
          if mcpService.autoStartEnabled {
            mcpService.start()
          }
        }
    }
    .windowStyle(.automatic)
    .defaultSize(width: 900, height: 600)
    .commands {
      CommandGroup(replacing: .newItem) {}
      
      CommandMenu("Account") {
        Button("Refresh") {
          Task {
            await appState.refreshProfile()
          }
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(!appState.isAuthenticated)
        
        Divider()
        
        Button("Logout") {
          appState.logout()
        }
        .disabled(!appState.isAuthenticated)
      }
      
      CommandMenu("Agent") {
        Button(agentService.isRunning ? "Stop Agent" : "Start Agent") {
          if agentService.isRunning {
            agentService.stop()
          } else {
            agentService.start()
          }
        }
        .keyboardShortcut("a", modifiers: [.command, .shift])
        .disabled(!appState.isAuthenticated)
        
        Button("Run Agent Cycle Now") {
          Task {
            await agentService.triggerManualCycle()
          }
        }
        .keyboardShortcut("a", modifiers: .command)
        .disabled(!appState.isAuthenticated)
      }
      
      CommandMenu("MCP") {
        Button(mcpService.isRunning ? "Stop MCP Server" : "Start MCP Server") {
          if mcpService.isRunning {
            mcpService.stop()
          } else {
            mcpService.start()
          }
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .disabled(!appState.isAuthenticated)
      }
    }
    
    // Menu Bar Extra
    MenuBarExtra {
      DockhandMenuBarView()
        .environment(appState)
        .environment(agentService)
        .environment(mcpService)
    } label: {
      Image(systemName: "ferry.fill")
    }
    .menuBarExtraStyle(.window)
    
    // Settings Window
    Settings {
      SettingsView()
        .environment(appState)
        .environment(agentService)
        .environment(mcpService)
    }
  }
}

// MARK: - Settings View

struct SettingsView: View {
  @Environment(AppState.self) private var appState
  @Environment(AgentService.self) private var agentService
  @Environment(MCPService.self) private var mcpService
  
  var body: some View {
    TabView {
      GeneralSettingsView()
        .tabItem {
          Label("General", systemImage: "gear")
        }
      
      AgentSettingsView(agentService: agentService)
        .tabItem {
          Label("Agent", systemImage: "cpu")
        }
      
      MCPSettingsView()
        .environment(mcpService)
        .tabItem {
          Label("MCP Server", systemImage: "network")
        }
      
      AboutSettingsView()
        .tabItem {
          Label("About", systemImage: "info.circle")
        }
    }
    .frame(width: 500, height: 500)
  }
}

struct GeneralSettingsView: View {
  @Environment(AppState.self) private var appState
  
  var body: some View {
    Form {
      Section {
        if appState.isAuthenticated {
          LabeledContent("Logged in as") {
            Text(appState.currentAgent?.name ?? "Unknown")
          }
          
          LabeledContent("Token Balance") {
            Text(String(format: "%.2f $SHIPYARD", appState.tokenBalance?.balance ?? 0))
          }
        } else {
          Text("Not logged in")
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Account")
      }
      
      Section {
        if let url = URL(string: "https://shipyard.bot") {
          Link("Shipyard Website", destination: url)
        }
        if let url = URL(string: "https://shipyard.bot/docs") {
          Link("API Documentation", destination: url)
        }
        if let url = URL(string: "https://jup.ag/swap/SOL-7hhAuM18KxYETuDPLR2q3UHK5KkiQdY1DQNqKGLCpump") {
          Link("Trade $SHIPYARD", destination: url)
        }
      } header: {
        Text("Links")
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}

struct AboutSettingsView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "ferry.fill")
        .font(.system(size: 64))
        .foregroundStyle(.blue)
      
      Text("Dockhand")
        .font(.title)
        .fontWeight(.bold)
      
      Text("Version 1.0.0")
        .foregroundStyle(.secondary)
      
      Text("A native macOS client for The Shipyard")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      
      Divider()
        .frame(width: 200)
      
      VStack(spacing: 4) {
        Text("$SHIPYARD Token Contract")
          .font(.caption)
          .foregroundStyle(.secondary)
        
        Text("7hhAuM18KxYETuDPLR2q3UHK5KkiQdY1DQNqKGLCpump")
          .font(.system(.caption2, design: .monospaced))
          .textSelection(.enabled)
      }
      
      Spacer()
    }
    .padding()
  }
}
