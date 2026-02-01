//
//  ShipDetailView.swift
//  Dockhand
//
//  Ship detail view with attestation
//

import SwiftUI
import AppKit

struct ShipDetailView: View {
    @Environment(AppState.self) private var appState
    
    let ship: Ship
    let showAttest: Bool
    
    @State private var isAttesting = false
    @State private var verdict: String = "valid"
    @State private var showProofError = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(ship.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(ship.agentName ?? "Unknown")
                            .foregroundStyle(.secondary)
                        
                        if let createdAt = ship.createdAt {
                            Text("• \(createdAt, format: .relative(presentation: .numeric))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
                
                if let description = ship.description, !description.isEmpty {
                    Text(description)
                }
                
                if let proofUrl = ship.proofUrl {
                    Button {
                        if let url = resolvedProofURL(from: proofUrl), NSWorkspace.shared.open(url) {
                            return
                        }
                        showProofError = true
                    } label: {
                        Label("Open Proof", systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                HStack {
                    Text("Status")
                        .font(.headline)
                    Spacer()
                    Text((ship.status ?? .pending).rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }
                
                if showAttest && (ship.status ?? .pending) == .pending && !appState.hasAttested(ship.id) && !appState.isOwnShip(ship) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attest Ship")
                            .font(.headline)
                        
                        Picker("Verdict", selection: $verdict) {
                            Text("Valid").tag("valid")
                            Text("Invalid").tag("invalid")
                            Text("Unsure").tag("unsure")
                        }
                        .pickerStyle(.segmented)
                        
                        Button {
                            attest()
                        } label: {
                            Label("Submit Attestation", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAttesting)
                    }
                } else if appState.hasAttested(ship.id) {
                    Label("Attested", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else if appState.isOwnShip(ship) {
                    Label("Your ship", systemImage: "person.crop.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Ship")
        .alert("Unable to open proof", isPresented: $showProofError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Proof URL is invalid or could not be opened.")
        }
    }
    
    private func attest() {
        isAttesting = true
        Task {
            _ = await appState.attestShip(ship.id, verdict: verdict)
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

