//
//  ShipHealthMonitorView.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
//
//  Ship Health Monitor - dashboard for tracking your ships' status
//

import SwiftUI

struct ShipHealthMonitorView: View {
  @Environment(AppState.self) private var appState
  
  @State private var isLoading: Bool = true
  @State private var healthChecks: [String: ProofHealthStatus] = [:]
  @State private var isCheckingHealth: Bool = false
  
  enum ProofHealthStatus {
    case checking
    case healthy
    case unhealthy
    case unknown
    
    var icon: String {
      switch self {
      case .checking: return "arrow.triangle.2.circlepath"
      case .healthy: return "checkmark.circle.fill"
      case .unhealthy: return "exclamationmark.triangle.fill"
      case .unknown: return "questionmark.circle"
      }
    }
    
    var color: Color {
      switch self {
      case .checking: return .secondary
      case .healthy: return .green
      case .unhealthy: return .red
      case .unknown: return .orange
      }
    }
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Stats header
      statsHeader
      
      Divider()
      
      if isLoading && appState.myShips.isEmpty {
        ProgressView("Loading your ships...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if appState.myShips.isEmpty {
        emptyState
      } else {
        shipsList
      }
    }
    .task {
      isLoading = true
      await appState.loadMyShips()
      isLoading = false
    }
  }
  
  // MARK: - Stats Header
  
  private var statsHeader: some View {
    HStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Ship Health Monitor")
          .font(.headline)
        Text("Track your ships' verification progress")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      // Quick stats
      HStack(spacing: 20) {
        statCard(
          value: "\(appState.myShips.count)",
          label: "Total Ships",
          icon: "ferry",
          color: .blue
        )
        
        statCard(
          value: "\(verifiedCount)",
          label: "Verified",
          icon: "checkmark.seal.fill",
          color: .green
        )
        
        statCard(
          value: "\(pendingCount)",
          label: "Pending",
          icon: "clock.fill",
          color: .orange
        )
        
        statCard(
          value: "\(tokensEarned)",
          label: "Tokens Earned",
          icon: "dollarsign.circle.fill",
          color: .yellow
        )
      }
      
      Divider()
        .frame(height: 40)
      
      Button {
        Task { await checkAllProofHealth() }
      } label: {
        Label("Check Health", systemImage: "stethoscope")
      }
      .disabled(isCheckingHealth)
      
      Button {
        Task {
          isLoading = true
          await appState.loadMyShips()
          isLoading = false
        }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
      }
    }
    .padding()
  }
  
  private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
    VStack(spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .foregroundStyle(color)
        Text(value)
          .font(.title2)
          .fontWeight(.bold)
      }
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
  
  // MARK: - Ships List
  
  private var shipsList: some View {
    List {
      // Pending ships first (need attention)
      if !pendingShips.isEmpty {
        Section {
          ForEach(pendingShips) { ship in
            shipHealthRow(ship: ship)
          }
        } header: {
          Label("Pending Verification", systemImage: "clock")
        }
      }
      
      // Verified ships
      if !verifiedShips.isEmpty {
        Section {
          ForEach(verifiedShips) { ship in
            shipHealthRow(ship: ship)
          }
        } header: {
          Label("Verified", systemImage: "checkmark.seal.fill")
        }
      }
      
      // Rejected ships
      if !rejectedShips.isEmpty {
        Section {
          ForEach(rejectedShips) { ship in
            shipHealthRow(ship: ship)
          }
        } header: {
          Label("Rejected", systemImage: "xmark.seal.fill")
        }
      }
    }
    .listStyle(.inset)
  }
  
  private func shipHealthRow(ship: Ship) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header row
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(ship.title)
              .font(.headline)
            
            statusBadge(for: ship)
          }
          
          if let createdAt = ship.createdAt {
            HStack(spacing: 8) {
              Text(createdAt, format: .relative(presentation: .numeric))
              
              Text("•")
              
              Text(timeSinceSubmission(createdAt))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }
        
        Spacer()
        
        // Proof health indicator
        proofHealthIndicator(for: ship)
      }
      
      // Description
      if let description = ship.description, !description.isEmpty {
        Text(description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      
      // Progress section (for pending ships)
      if ship.status == .pending {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Attestation Progress")
              .font(.caption)
              .fontWeight(.medium)
            
            Spacer()
            
            Text("\(ship.attestations ?? 0) of 3")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          
          attestationProgressBar(ship: ship)
          
          // Estimated time
          if let estimate = estimatedTimeToVerification(ship: ship) {
            Text(estimate)
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.top, 4)
      }
      
      // Proof URL
      if let proofUrl = ship.proofUrl {
        HStack {
          Button {
            if let url = resolvedProofURL(from: proofUrl) {
              NSWorkspace.shared.open(url)
            }
          } label: {
            Label("View Proof", systemImage: "link")
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          
          Text(proofUrl)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
    }
    .padding(.vertical, 8)
  }
  
  @ViewBuilder
  private func statusBadge(for ship: Ship) -> some View {
    let (text, color): (String, Color) = switch ship.status ?? .pending {
    case .pending: ("Pending", .orange)
    case .verified: ("Verified", .green)
    case .rejected: ("Rejected", .red)
    }
    
    Text(text)
      .font(.caption2)
      .fontWeight(.medium)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.2))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }
  
  private func proofHealthIndicator(for ship: Ship) -> some View {
    let status = healthChecks[ship.id] ?? .unknown
    
    return HStack(spacing: 4) {
      Image(systemName: status.icon)
        .foregroundStyle(status.color)
      
      Text(healthLabel(for: status))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(status.color.opacity(0.1))
    .clipShape(Capsule())
  }
  
  private func healthLabel(for status: ProofHealthStatus) -> String {
    switch status {
    case .checking: return "Checking..."
    case .healthy: return "Proof Live"
    case .unhealthy: return "Proof Down"
    case .unknown: return "Not Checked"
    }
  }
  
  private func attestationProgressBar(ship: Ship) -> some View {
    GeometryReader { geometry in
      let count = ship.attestations ?? 0
      let progress = CGFloat(count) / 3.0
      
      ZStack(alignment: .leading) {
        // Background
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.gray.opacity(0.2))
        
        // Progress
        RoundedRectangle(cornerRadius: 4)
          .fill(progressColor(for: count))
          .frame(width: geometry.size.width * progress)
        
        // Dots
        HStack(spacing: 0) {
          ForEach(0..<3, id: \.self) { i in
            Circle()
              .fill(i < count ? Color.white : Color.clear)
              .frame(width: 6, height: 6)
              .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal, 4)
      }
    }
    .frame(height: 12)
  }
  
  private func progressColor(for count: Int) -> Color {
    switch count {
    case 0: return .gray
    case 1: return .orange
    case 2: return .yellow
    default: return .green
    }
  }
  
  // MARK: - Empty State
  
  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Ships Yet", systemImage: "ferry")
    } description: {
      Text("Submit your first ship to start earning $SHIPYARD tokens!")
    }
  }
  
  // MARK: - Computed Properties
  
  private var pendingShips: [Ship] {
    appState.myShips
      .filter { $0.status == .pending }
      .sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
  }
  
  private var verifiedShips: [Ship] {
    appState.myShips.filter { $0.status == .verified }
  }
  
  private var rejectedShips: [Ship] {
    appState.myShips.filter { $0.status == .rejected }
  }
  
  private var verifiedCount: Int {
    verifiedShips.count
  }
  
  private var pendingCount: Int {
    pendingShips.count
  }
  
  private var tokensEarned: String {
    let count = verifiedCount * 50 // 50 tokens per verified ship
    return "\(count)"
  }
  
  // MARK: - Helper Functions
  
  private func timeSinceSubmission(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    let hours = Int(interval / 3600)
    let days = hours / 24
    
    if days > 0 {
      return "\(days)d \(hours % 24)h waiting"
    } else {
      return "\(hours)h waiting"
    }
  }
  
  private func estimatedTimeToVerification(ship: Ship) -> String? {
    let count = ship.attestations ?? 0
    let remaining = 3 - count
    
    if remaining <= 0 { return nil }
    
    // Rough estimate: ~12h per attestation on average
    let hoursEstimate = remaining * 12
    
    if hoursEstimate >= 24 {
      return "~\(hoursEstimate / 24) days to verification"
    } else {
      return "~\(hoursEstimate) hours to verification"
    }
  }
  
  private func checkAllProofHealth() async {
    isCheckingHealth = true
    defer { isCheckingHealth = false }
    
    for ship in appState.myShips {
      guard let proofUrl = ship.proofUrl,
            let url = resolvedProofURL(from: proofUrl) else {
        healthChecks[ship.id] = .unknown
        continue
      }
      
      healthChecks[ship.id] = .checking
      
      do {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           (200...299).contains(httpResponse.statusCode) {
          healthChecks[ship.id] = .healthy
        } else {
          healthChecks[ship.id] = .unhealthy
        }
      } catch {
        healthChecks[ship.id] = .unhealthy
      }
    }
  }
  
  private func resolvedProofURL(from proofUrl: String) -> URL? {
    let trimmed = proofUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url = URL(string: trimmed), url.scheme != nil {
      return url
    }
    return URL(string: "https://" + trimmed)
  }
}

#Preview {
  ShipHealthMonitorView()
    .environment(AppState())
}
