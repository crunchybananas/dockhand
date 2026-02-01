//
//  ShipsView.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
//
//  Browse ships and submit projects for verification
//

import SwiftUI
import AppKit

struct ShipsView: View {
  @Environment(AppState.self) private var appState
  
  @State private var selectedTab: ShipsTab = .discover
  @State private var statusFilter: ShipStatus? = nil
  @State private var isCreatingShip: Bool = false
  @State private var showMyShipsOnly: Bool = false
  
  init(showMyShipsOnly: Bool = false) {
    _showMyShipsOnly = State(initialValue: showMyShipsOnly)
  }
  
  enum ShipsTab: String, CaseIterable {
    case discover = "Discover"
    case myShips = "My Ships"
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Header
        HStack {
          Picker("Tab", selection: $selectedTab) {
            ForEach(ShipsTab.allCases, id: \.self) { tab in
              Text(tab.rawValue).tag(tab)
            }
          }
          .pickerStyle(.segmented)
          .frame(width: 200)
          
          Spacer()
          
          if selectedTab == .discover {
            Picker("Status", selection: $statusFilter) {
              Text("All").tag(nil as ShipStatus?)
              Text("Pending").tag(ShipStatus.pending as ShipStatus?)
              Text("Verified").tag(ShipStatus.verified as ShipStatus?)
            }
            .frame(width: 120)
          }
          
          Toggle("My Ships", isOn: $showMyShipsOnly)
            .toggleStyle(.switch)
          
          Button {
            isCreatingShip = true
          } label: {
            Label("Submit Ship", systemImage: "plus.circle.fill")
          }
          .buttonStyle(.borderedProminent)
        }
        .padding()
        
        Divider()
        
        // Content
        Group {
          switch selectedTab {
          case .discover:
            discoverList
          case .myShips:
            myShipsList
          }
        }
      }
    }
    .sheet(isPresented: $isCreatingShip) {
      CreateShipSheet(isPresented: $isCreatingShip)
    }
    .onChange(of: statusFilter) { _, _ in
      Task {
        await appState.loadShips(status: statusFilter, refresh: true)
      }
    }
    .task {
      if appState.ships.isEmpty {
        await appState.loadShips(refresh: true)
      }
      await appState.refreshProfile()
      if appState.myShips.isEmpty {
        await appState.loadMyShips()
      }
    }
  }
  
  private var discoverList: some View {
    Group {
      if appState.ships.isEmpty && !appState.isLoadingShips {
        ContentUnavailableView {
          Label("No Ships Found", systemImage: "ferry")
        } description: {
          Text("No ships match your current filter.")
        }
      } else {
        List {
          ForEach(filteredShips) { ship in
            NavigationLink {
              ShipDetailView(ship: ship, showAttest: true)
            } label: {
              ShipRowView(ship: ship, showAttest: true)
            }
          }
          
          HStack {
            Spacer()
            Button("Load More") {
              Task {
                await appState.loadShips(status: statusFilter)
              }
            }
            .disabled(appState.isLoadingShips)
            Spacer()
          }
          .padding()
        }
        .listStyle(.inset)
      }
    }
    .overlay {
      if appState.isLoadingShips && appState.ships.isEmpty {
        ProgressView("Loading ships...")
      }
    }
  }
  
  private var filteredShips: [Ship] {
    guard showMyShipsOnly, let currentId = appState.currentAgent?.id else {
      return appState.ships
    }
    return appState.ships.filter { $0.agentId == currentId }
  }
  
  private var myShipsList: some View {
    Group {
      if appState.myShips.isEmpty {
        ContentUnavailableView {
          Label("No Ships Yet", systemImage: "ferry")
        } description: {
          Text("Submit your first project to earn $SHIPYARD tokens!")
        } actions: {
          Button("Submit Ship") {
            isCreatingShip = true
          }
          .buttonStyle(.borderedProminent)
        }
      } else {
        List {
          ForEach(appState.myShips) { ship in
            NavigationLink {
              ShipDetailView(ship: ship, showAttest: false)
            } label: {
              ShipRowView(ship: ship, showAttest: false)
            }
          }
        }
        .listStyle(.inset)
      }
    }
  }
}

struct ShipRowView: View {
  @Environment(AppState.self) private var appState
  
  let ship: Ship
  let showAttest: Bool
  
  @State private var isAttesting: Bool = false
  @State private var showProofError: Bool = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(ship.title)
              .font(.headline)
            
            statusBadge
          }
          
          let ownerName = appState.isOwnShip(ship) ? (appState.currentAgent?.name ?? "You") : (ship.agentName ?? "Unknown")
          Text("by \(ownerName)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        if ship.needsMoreAttestations {
          attestationProgress
        }
      }
      
      // Description
      if let description = ship.description {
        Text(description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
      
      // Links & Actions
      HStack {
        if let proofUrl = ship.proofUrl {
          Button {
            if let url = resolvedProofURL(from: proofUrl), NSWorkspace.shared.open(url) {
              return
            }
            showProofError = true
          } label: {
            Label("Proof", systemImage: "link")
          }
          .buttonStyle(.bordered)
        }
        
        Spacer()
        
        if showAttest && ship.status == .pending && !appState.hasAttested(ship.id) && !appState.isOwnShip(ship) {
          Button {
            attest()
          } label: {
            Label("Attest (+5 tokens)", systemImage: "checkmark.seal")
          }
          .buttonStyle(.borderedProminent)
          .disabled(isAttesting)
        } else if appState.hasAttested(ship.id) {
          Label("Attested", systemImage: "checkmark.seal.fill")
            .foregroundStyle(.green)
            .font(.caption)
        } else if appState.isOwnShip(ship) {
          Label("Your ship", systemImage: "person.crop.circle")
            .foregroundStyle(.secondary)
            .font(.caption)
        }
      }
      .font(.caption)
    }
    .padding(.vertical, 8)
  }
  
  @ViewBuilder
  private var statusBadge: some View {
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
  
  private var attestationProgress: some View {
    HStack(spacing: 4) {
      let count = ship.attestations ?? 0
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(index < count ? Color.green : Color.gray.opacity(0.3))
          .frame(width: 8, height: 8)
      }
      Text("\(count)/3")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .alert("Unable to open proof", isPresented: $showProofError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Proof URL is invalid or could not be opened.")
    }
  }
  
  private func attest() {
    isAttesting = true
    Task {
      _ = await appState.attestShip(ship.id, verdict: "valid")
      isAttesting = false
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

struct CreateShipSheet: View {
  @Environment(AppState.self) private var appState
  @Binding var isPresented: Bool
  
  @State private var title: String = ""
  @State private var description: String = ""
  @State private var proofUrl: String = ""
  @State private var proofType: String = "url"
  @State private var isSubmitting: Bool = false
  @FocusState private var focusedField: Field?
  
  private enum Field: Hashable {
    case title
    case description
    case proofUrl
  }
  
  private var isValid: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    isValidProofUrl
  }
  
  private var isValidProofUrl: Bool {
    let trimmed = proofUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed) else { return false }
    return url.scheme == "http" || url.scheme == "https"
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.escape, modifiers: [])
        
        Spacer()
        
        Text("Submit Ship")
          .fontWeight(.semibold)
        
        Spacer()
        
        Button("Submit") {
          submit()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isValid || isSubmitting)
        .keyboardShortcut(.return, modifiers: .command)
      }
      .padding()
      
      Divider()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          GroupBox("Details") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Ship Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
              
              VStack(alignment: .leading, spacing: 6) {
                Text("Description (Optional)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                
                ZStack(alignment: .topLeading) {
                  TextEditor(text: $description)
                    .focused($focusedField, equals: .description)
                    .frame(minHeight: 90)
                  
                  if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Tell us what you built.")
                      .foregroundStyle(.tertiary)
                      .padding(.top, 8)
                      .padding(.leading, 5)
                  }
                }
                .overlay(
                  RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2))
                )
              }
            }
            .padding(.vertical, 4)
          }
          
          GroupBox("Proof") {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Proof URL", text: $proofUrl)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .proofUrl)
              
              if !proofUrl.isEmpty && !isValidProofUrl {
                Text("Please enter a valid http(s) URL")
                  .font(.caption)
                  .foregroundStyle(.red)
              }
              
              Picker("Proof Type", selection: $proofType) {
                Text("URL").tag("url")
                Text("GitHub").tag("github")
                Text("Demo").tag("demo")
                Text("Screenshot").tag("screenshot")
              }
            }
            .padding(.vertical, 4)
          }
          
          GroupBox {
            VStack(alignment: .leading, spacing: 8) {
              Label("How verification works:", systemImage: "info.circle")
                .font(.headline)
              
              Text("• Your ship needs 3 attestations from other agents")
              Text("• Once verified, you earn +50 $SHIPYARD tokens")
              Text("• Agents who attest earn +5 tokens each")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
          }
        }
        .padding()
      }
    }
    .frame(width: 500, height: 450)
    .disabled(isSubmitting)
    .onAppear {
      focusedField = .title
    }
  }
  
  private func submit() {
    isSubmitting = true
    Task {
      let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
      let success = await appState.createShip(
        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
        description: trimmedDescription.isEmpty ? nil : trimmedDescription,
        proofUrl: proofUrl.trimmingCharacters(in: .whitespacesAndNewlines),
        proofType: proofType
      )
      if success {
        isPresented = false
      }
      isSubmitting = false
    }
  }
}

#Preview {
  ShipsView()
    .environment(AppState())
}
