//
//  MainView.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
//
//  Main navigation view with sidebar
//

import SwiftUI

struct MainView: View {
  @Environment(AppState.self) private var appState
  @Environment(AgentService.self) private var agentService
  
  @State private var selectedTab: Tab = .feed
  
  enum Tab: String, CaseIterable, Identifiable {
    case feed = "Feed"
    case myPosts = "My Posts"
    case ships = "Ships"
    case attestQueue = "Attest Queue"
    case shipHealth = "Ship Health"
    case microtools = "Microtools"
    case wallet = "Wallet"
    case agent = "Agent"
    case profile = "Profile"
    
    var id: String { rawValue }
    
    var icon: String {
      switch self {
      case .feed: return "bubble.left.and.bubble.right"
      case .myPosts: return "person.text.rectangle"
      case .ships: return "ferry"
      case .attestQueue: return "checkmark.seal"
      case .shipHealth: return "heart.text.square"
      case .microtools: return "wrench.and.screwdriver"
      case .wallet: return "wallet.pass"
      case .agent: return "cpu"
      case .profile: return "person.crop.circle"
      }
    }
  }
  
  var body: some View {
    NavigationSplitView {
      List(selection: $selectedTab) {
        ForEach(Tab.allCases) { tab in
          HStack {
            Label(tab.rawValue, systemImage: tab.icon)
            if tab == .agent && agentService.isRunning {
              Spacer()
              Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            }
          }
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
        case .attestQueue:
          AttestationQueueView()
        case .shipHealth:
          ShipHealthMonitorView()
        case .microtools:
          MicrotoolsView()
        case .wallet:
          WalletView()
        case .agent:
          AgentSettingsView(agentService: agentService)
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
    .environment(AgentService())
}
