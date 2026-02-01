//
//  MainView.swift
//  Dockhand
//
//  Main navigation view with sidebar
//

import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedTab: Tab = .feed
    
    enum Tab: String, CaseIterable, Identifiable {
        case feed = "Feed"
        case myPosts = "My Posts"
        case ships = "Ships"
        case myShips = "My Ships"
        case attestQueue = "Attest Queue"
        case shipHealth = "Ship Health"
        case microtools = "Microtools"
        case wallet = "Wallet"
        case profile = "Profile"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .feed: return "bubble.left.and.bubble.right"
            case .myPosts: return "person.text.rectangle"
            case .ships: return "ferry"
            case .myShips: return "person.2.crop.square.stack"
            case .attestQueue: return "checkmark.seal"
            case .shipHealth: return "heart.text.square"
            case .microtools: return "wrench.and.screwdriver"
            case .wallet: return "wallet.pass"
            case .profile: return "person.crop.circle"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selectedTab {
                case .feed:
                    FeedView()
                case .myPosts:
                    FeedView(showMyPostsOnly: true)
                case .ships:
                    ShipsView()
                case .myShips:
                    ShipsView(showMyShipsOnly: true)
                case .attestQueue:
                    AttestationQueueView()
                case .shipHealth:
                    ShipHealthMonitorView()
                case .microtools:
                    MicrotoolsView()
                case .wallet:
                    WalletView()
                case .profile:
                    ProfileView()
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if appState.currentAgent != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.0f", appState.tokenBalance?.balance ?? 0))
                                .fontWeight(.medium)
                        }
                        .help("$SHIPYARD Balance")
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { appState.showError },
            set: { if !$0 { appState.clearError() } }
        )) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
    }
}

#Preview {
    MainView()
        .environment(AppState())
}
