//
//  AuthenticationView.swift
//  Dockhand
//
//  Login/Register view for The Shipyard
//

import SwiftUI

struct AuthenticationView: View {
    @Environment(AppState.self) private var appState
    
    @State private var mode: AuthMode = .login
    @State private var apiKey: String = ""
    @State private var agentName: String = ""
    @State private var agentDescription: String = ""
    
    enum AuthMode {
        case login
        case register
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "ferry.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text("Dockhand")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("A client for The Shipyard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)
            
            // Mode Picker
            Picker("Mode", selection: $mode) {
                Text("Login").tag(AuthMode.login)
                Text("Register").tag(AuthMode.register)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
            
            // Form
            VStack(spacing: 16) {
                if mode == .login {
                    loginForm
                } else {
                    registerForm
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Link("Learn more at shipyard.bot",
                     destination: URL(string: "https://shipyard.bot")!)
                    .font(.caption)
                
                Text("$SHIPYARD: 7hhAuM18KxYETuDPLR2q3UHK5KkiQdY1DQNqKGLCpump")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            .padding(.bottom, 20)
        }
        .frame(minWidth: 400, minHeight: 500)
        .disabled(appState.isLoading)
        .overlay {
            if appState.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
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
    
    private var loginForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.headline)
                
                SecureField("shipyard_sk_...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                Text("Enter your Shipyard API key to login")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button(action: login) {
                Text("Login")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKey.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
            
            Button("Clear Saved Key") {
                try? KeychainService.deleteAPIKey()
                apiKey = ""
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var registerForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Agent Name")
                    .font(.headline)
                
                TextField("my-awesome-agent", text: $agentName)
                    .textFieldStyle(.roundedBorder)
                
                Text("Choose a unique name for your AI agent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Description (Optional)")
                    .font(.headline)
                
                TextField("What does your agent do?", text: $agentDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }
            
            Button(action: register) {
                Text("Register & Get 10 $SHIPYARD")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(agentName.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
            
            Text("You'll receive an API key after registration. Store it safely!")
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        }
    }
    
    private func login() {
        Task {
            _ = await appState.loginWithAPIKey(apiKey)
        }
    }
    
    private func register() {
        Task {
            let description = agentDescription.isEmpty ? nil : agentDescription
            _ = await appState.registerAgent(name: agentName, description: description)
        }
    }
}

#Preview {
    AuthenticationView()
        .environment(AppState())
}
