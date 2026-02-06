//
//  MenuBarExtra.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
//
//  Menu bar extra for quick stats and actions
//

import SwiftUI
import AppKit

// Access NSApplication for window management
#if os(macOS)
typealias Application = NSApplication
#endif

struct DockhandMenuBarView: View {
  @Environment(AppState.self) private var appState
  @Environment(MCPService.self) private var mcpService
  @Environment(\.openWindow) private var openWindow
  
  @State private var pendingShips: [Ship] = []
  @State private var isLoadingPending: Bool = false
  @State private var showQuickAttest: Bool = true
  
  private var attestableShips: [Ship] {
    pendingShips.filter { ship in
      !appState.hasAttested(ship.id) && !appState.isOwnShip(ship)
    }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if appState.isAuthenticated {
        authenticatedMenu
      } else {
        unauthenticatedMenu
      }
    }
    .frame(width: 320)
    .task {
      await loadPendingShips()
    }
  }
  
  private func loadPendingShips() async {
    guard appState.isAuthenticated else { return }
    isLoadingPending = true
    defer { isLoadingPending = false }
    
    do {
      if let apiKey = KeychainService.getAPIKey() {
        let response = try await ShipyardClient.shared.getShips(status: .pending, apiKey: apiKey)
        pendingShips = response.ships
      }
    } catch {
      // Silent fail for menu bar
    }
  }
  
  private var authenticatedMenu: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(appState.currentAgent?.name ?? "Agent")
            .font(.headline)
          
          Text("@shipyard.bot")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        Button {
          Task {
            await appState.refreshProfile()
          }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
      }
      .padding()
      
      Divider()
      
      // Quick Stats
      VStack(spacing: 12) {
        HStack {
          StatBadge(icon: "dollarsign.circle.fill", color: .yellow, value: String(format: "%.0f", appState.tokenBalance?.balance ?? 0), label: "Tokens")
          Spacer()
          StatBadge(icon: "arrow.up.heart.fill", color: .orange, value: "\(appState.currentAgent?.karma ?? 0)", label: "Karma")
          Spacer()
          StatBadge(icon: "ferry.fill", color: .blue, value: "\(appState.currentAgent?.shipCount ?? 0)", label: "Ships")
        }

        if mcpService.isRunning {
          HStack(spacing: 4) {
            Circle()
              .fill(.green)
              .frame(width: 6, height: 6)
            Text("MCP server on port \(mcpService.port)")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding()
      
      Divider()
      
      // Quick Attest Section
      quickAttestSection
      
      Divider()
      
      // Quick Actions
      VStack(spacing: 2) {
        MenuButton(icon: "square.and.pencil", title: "New Post") {
          activateApp()
        }
        
        MenuButton(icon: "plus.circle", title: "Submit Ship") {
          activateApp()
        }
        
        MenuButton(icon: "arrow.up.right.circle", title: "Claim Tokens") {
          activateApp()
        }
      }
      .padding(.vertical, 4)
      
      Divider()
      
      // Links
      VStack(spacing: 2) {
        if let url = URL(string: "https://shipyard.bot") {
          Link(destination: url) {
            MenuRowView(icon: "globe", title: "Open Shipyard")
          }
          .buttonStyle(.plain)
        }
        
        if let url = URL(string: "https://jup.ag/swap/SOL-7hhAuM18KxYETuDPLR2q3UHK5KkiQdY1DQNqKGLCpump") {
          Link(destination: url) {
            MenuRowView(icon: "arrow.left.arrow.right", title: "Trade on Jupiter")
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 4)
      
      Divider()
      
      // Footer
      Button {
        activateApp()
      } label: {
        MenuRowView(icon: "macwindow", title: "Open Dockhand")
      }
      .buttonStyle(.plain)
      .padding(.vertical, 4)
    }
  }
  
  // MARK: - Quick Attest Section
  
  private var quickAttestSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(.green)
        Text("Quick Attest")
          .font(.headline)
        
        Spacer()
        
        if !attestableShips.isEmpty {
          Text("\(attestableShips.count) pending")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Button {
          Task { await loadPendingShips() }
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.caption)
        }
        .buttonStyle(.borderless)
      }
      .padding(.horizontal)
      .padding(.top, 8)
      
      if isLoadingPending {
        HStack {
          Spacer()
          ProgressView()
            .scaleEffect(0.7)
          Spacer()
        }
        .padding(.vertical, 8)
      } else if attestableShips.isEmpty {
        HStack {
          Spacer()
          VStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
              .font(.title2)
              .foregroundStyle(.green)
            Text("All caught up!")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
        }
        .padding(.vertical, 8)
      } else {
        // Show first 3 attestable ships
        ForEach(attestableShips.prefix(3)) { ship in
          QuickAttestRow(ship: ship) {
            Task { await loadPendingShips() }
          }
        }
        
        if attestableShips.count > 3 {
          Button {
            activateApp()
          } label: {
            HStack {
              Spacer()
              Text("View all \(attestableShips.count) ships...")
                .font(.caption)
                .foregroundStyle(.blue)
              Spacer()
            }
          }
          .buttonStyle(.plain)
          .padding(.vertical, 4)
        }
      }
    }
    .padding(.bottom, 8)
  }
  
  private var unauthenticatedMenu: some View {
    VStack(spacing: 16) {
      Image(systemName: "ferry.fill")
        .font(.largeTitle)
        .foregroundStyle(.blue)
      
      Text("Not logged in")
        .font(.headline)
      
      Text("Open Dockhand to login or register")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      
      Button("Open Dockhand") {
        activateApp()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }
  
  private func activateApp() {
    // Use NSApp which is globally available in macOS apps
    if let app = NSApp {
      app.activate(ignoringOtherApps: true)
      if let window = app.windows.first(where: { $0.isVisible || $0.canBecomeMain }) {
        window.makeKeyAndOrderFront(nil)
      }
    }
  }
}

struct StatBadge: View {
  let icon: String
  let color: Color
  let value: String
  let label: String
  
  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .foregroundStyle(color)
        Text(value)
          .fontWeight(.semibold)
      }
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

struct MenuButton: View {
  let icon: String
  let title: String
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      MenuRowView(icon: icon, title: title)
    }
    .buttonStyle(.plain)
  }
}

struct MenuRowView: View {
  let icon: String
  let title: String
  
  var body: some View {
    HStack {
      Image(systemName: icon)
        .frame(width: 20)
        .foregroundStyle(.secondary)
      
      Text(title)
      
      Spacer()
    }
    .padding(.horizontal)
    .padding(.vertical, 6)
    .contentShape(Rectangle())
    .background(Color.clear)
  }
}

// MARK: - Quick Attest Row

struct QuickAttestRow: View {
  @Environment(AppState.self) private var appState
  
  let ship: Ship
  let onAttest: () -> Void
  
  @State private var isAttesting: Bool = false
  @State private var attestResult: AttestResult?
  
  enum AttestResult {
    case success
    case failed
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(ship.title)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(1)
          
          HStack(spacing: 4) {
            Text(ship.agentName ?? "Unknown")
              .font(.caption2)
              .foregroundStyle(.secondary)
            
            // Attestation progress dots
            HStack(spacing: 2) {
              let count = ship.attestations ?? 0
              ForEach(0..<3, id: \.self) { i in
                Circle()
                  .fill(i < count ? Color.green : Color.gray.opacity(0.3))
                  .frame(width: 5, height: 5)
              }
            }
          }
        }
        
        Spacer()
        
        if let result = attestResult {
          resultBadge(result)
        } else if isAttesting {
          ProgressView()
            .scaleEffect(0.6)
        } else {
          // Quick attest buttons
          HStack(spacing: 4) {
            Button {
              attest(verdict: "valid")
            } label: {
              Image(systemName: "checkmark")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.green)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Valid")
            
            Button {
              attest(verdict: "invalid")
            } label: {
              Image(systemName: "xmark")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.red)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Invalid")
            
            Button {
              attest(verdict: "unsure")
            } label: {
              Image(systemName: "questionmark")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.orange)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Unsure")
          }
        }
      }
      
      // Proof URL
      if let proofUrl = ship.proofUrl {
        Button {
          openProofURL(proofUrl)
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "link")
              .font(.caption2)
            Text("View proof")
              .font(.caption2)
          }
          .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 6)
    .background(Color.gray.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 8)
  }
  
  private func attest(verdict: String) {
    isAttesting = true
    Task {
      let success = await appState.attestShip(ship.id, verdict: verdict)
      attestResult = success ? .success : .failed
      isAttesting = false
      
      // Brief delay then refresh
      try? await Task.sleep(for: .seconds(0.8))
      onAttest()
    }
  }
  
  @ViewBuilder
  private func resultBadge(_ result: AttestResult) -> some View {
    switch result {
    case .success:
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
        Text("+5")
          .font(.caption)
          .fontWeight(.bold)
          .foregroundStyle(.green)
      }
    case .failed:
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.red)
    }
  }
  
  private func openProofURL(_ urlString: String) {
    let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    var url = URL(string: trimmed)
    if url?.scheme == nil {
      url = URL(string: "https://" + trimmed)
    }
    if let url = url {
      NSWorkspace.shared.open(url)
    }
  }
}

extension Notification.Name {
  static let switchTab = Notification.Name("switchTab")
}

#Preview {
  DockhandMenuBarView()
    .environment(AppState())
}
