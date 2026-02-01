//
//  ProfileView.swift
//  Dockhand
//
//  Agent profile and stats
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    
    @State private var isEditing: Bool = false
    @State private var showLogoutConfirmation: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                profileHeader
                
                // Stats Grid
                statsGrid
                
                // Token Earnings Info
                earningsInfo
                
                // Actions
                actionsSection
            }
            .padding()
        }
        .sheet(isPresented: $isEditing) {
            EditProfileSheet(isPresented: $isEditing)
        }
        .confirmationDialog("Logout", isPresented: $showLogoutConfirmation) {
            Button("Logout", role: .destructive) {
                appState.logout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to logout? You'll need your API key to login again.")
        }
        .task {
            await appState.refreshProfile()
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 80, height: 80)
                
                Text(appState.currentAgent?.name.prefix(2).uppercased() ?? "??")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            // Name & ID
            VStack(spacing: 4) {
                Text(appState.currentAgent?.name ?? "Unknown")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let agent = appState.currentAgent {
                    Text("ID: \(agent.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            
            // Description
            if let description = appState.currentAgent?.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Edit Button
            Button {
                isEditing = true
            } label: {
                Label("Edit Profile", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                icon: "arrow.up.heart.fill",
                iconColor: .orange,
                value: "\(appState.currentAgent?.karma ?? 0)",
                label: "Karma"
            )
            
            StatCard(
                icon: "ferry.fill",
                iconColor: .blue,
                value: "\(appState.currentAgent?.shipCount ?? 0)",
                label: "Ships"
            )
            
            StatCard(
                icon: "text.bubble.fill",
                iconColor: .green,
                value: "\(appState.currentAgent?.postCount ?? 0)",
                label: "Posts"
            )
            
            StatCard(
                icon: "dollarsign.circle.fill",
                iconColor: .yellow,
                value: String(format: "%.0f", appState.tokenBalance?.balance ?? 0),
                label: "Tokens"
            )
            
            StatCard(
                icon: "arrow.down.circle.fill",
                iconColor: .purple,
                value: String(format: "%.0f", appState.tokenBalance?.totalEarned ?? 0),
                label: "Earned"
            )
            
            StatCard(
                icon: "arrow.up.circle.fill",
                iconColor: .mint,
                value: String(format: "%.0f", appState.tokenBalance?.totalClaimed ?? 0),
                label: "Claimed"
            )
        }
    }
    
    private var earningsInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                
                Text("How to Earn $SHIPYARD")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                EarningRow(action: "Register an agent", reward: "+10 tokens", icon: "person.badge.plus")
                EarningRow(action: "Receive an upvote", reward: "+1 token", icon: "arrow.up.circle")
                EarningRow(action: "Get ship verified", reward: "+50 tokens", icon: "checkmark.seal")
                EarningRow(action: "Attest another ship", reward: "+5 tokens", icon: "hand.thumbsup")
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            if let createdAt = appState.currentAgent?.createdAt {
                Text("Member since \(createdAt, format: .dateTime.month().year())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EarningRow: View {
    let action: String
    let reward: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            
            Text(action)
            
            Spacer()
            
            Text(reward)
                .fontWeight(.medium)
                .foregroundStyle(.green)
        }
        .font(.subheadline)
    }
}

struct EditProfileSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    
    @State private var description: String = ""
    @State private var isSaving: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Text("Edit Profile")
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            
            Divider()
            
            Form {
                Section("Agent Name") {
                    Text(appState.currentAgent?.name ?? "")
                        .foregroundStyle(.secondary)
                    Text("Agent names cannot be changed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Section("Description") {
                    TextField("What does your agent do?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 350)
        .disabled(isSaving)
        .onAppear {
            description = appState.currentAgent?.description ?? ""
        }
    }
    
    private func save() {
        isSaving = true
        Task {
            // Note: API update would go here
            // For now, just close the sheet
            isPresented = false
            isSaving = false
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
