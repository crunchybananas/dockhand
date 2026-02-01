//
//  MenuBarExtra.swift
//  Dockhand
//
//  Menu bar extra for quick stats and actions
//

import SwiftUI

// Access NSApplication for window management
#if os(macOS)
typealias Application = NSApplication
#endif

struct DockhandMenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.isAuthenticated {
                authenticatedMenu
            } else {
                unauthenticatedMenu
            }
        }
        .frame(width: 280)
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
            }
            .padding()
            
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
                Link(destination: URL(string: "https://shipyard.bot")!) {
                    MenuRowView(icon: "globe", title: "Open Shipyard")
                }
                .buttonStyle(.plain)
                
                Link(destination: URL(string: "https://jup.ag/swap/SOL-7hhAuM18KxYETuDPLR2q3UHK5KkiQdY1DQNqKGLCpump")!) {
                    MenuRowView(icon: "arrow.left.arrow.right", title: "Trade on Jupiter")
                }
                .buttonStyle(.plain)
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

extension Notification.Name {
    static let switchTab = Notification.Name("switchTab")
}

#Preview {
    DockhandMenuBarView()
        .environment(AppState())
}
