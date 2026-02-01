//
//  WalletView.swift
//  Dockhand
//
//  View $SHIPYARD balance and claim tokens to Solana wallet
//

import SwiftUI

struct WalletView: View {
    @Environment(AppState.self) private var appState
    
    @State private var isSettingWallet: Bool = false
    @State private var isClaimingTokens: Bool = false
    @State private var claimAmount: String = ""
    @State private var lastClaim: ClaimTokensResponse?
    
    private let tokenContract = "7hhAuM18KxYETuDPLR2q3UHK5KkiQdY1DQNqKGLCpump"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Balance Card
                balanceCard
                
                // Wallet Section
                walletSection
                
                // Claim Section
                if appState.currentAgent?.solanaWallet != nil {
                    claimSection
                }
                
                // Token Info
                tokenInfoSection
                
                // Last Claim
                if let claim = lastClaim {
                    lastClaimCard(claim)
                }
            }
            .padding()
        }
        .sheet(isPresented: $isSettingWallet) {
            SetWalletSheet(isPresented: $isSettingWallet)
        }
        .task {
            await appState.refreshProfile()
        }
    }
    
    private var balanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
                
                Text("$SHIPYARD Balance")
                    .font(.headline)
                
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
            
            if let balance = appState.tokenBalance {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.2f", balance.balance))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("SHIPYARD")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                HStack {
                    StatView(title: "Total Earned", value: String(format: "%.2f", balance.totalEarned))
                    Spacer()
                    StatView(title: "Total Claimed", value: String(format: "%.2f", balance.totalClaimed))
                    Spacer()
                    StatView(title: "Pending", value: String(format: "%.2f", balance.pendingClaims))
                }
            } else {
                ProgressView()
                    .padding()
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wallet.pass.fill")
                    .foregroundStyle(.purple)
                
                Text("Solana Wallet")
                    .font(.headline)
                
                Spacer()
            }
            
                if let wallet = appState.walletAddress ?? appState.currentAgent?.solanaWallet {
                HStack {
                    Text(wallet)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(wallet, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy address")
                    
                    Button {
                        isSettingWallet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Change wallet")
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 12) {
                    Text("Set up your Solana wallet to claim tokens")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button("Set Wallet Address") {
                        isSettingWallet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var claimSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundStyle(.green)
                
                Text("Claim Tokens")
                    .font(.headline)
                
                Spacer()
            }
            
            HStack {
                TextField("Amount", text: $claimAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                
                Button("Max") {
                    if let balance = appState.tokenBalance {
                        claimAmount = String(format: "%.2f", balance.balance)
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    claim()
                } label: {
                    if isClaimingTokens {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Claim")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isClaimingTokens || !isValidClaimAmount)
            }
            
            Text("Tokens will be sent to your Solana wallet. This may take a few minutes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var tokenInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                
                Text("Token Info")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Network", value: "Solana")
                InfoRow(label: "Contract", value: appState.tokenInfo?.contract ?? tokenContract, monospaced: true)
                if let circulating = appState.tokenInfo?.circulating {
                    InfoRow(label: "Circulating", value: String(format: "%.0f", circulating))
                }
            }
            
            HStack(spacing: 12) {
                Link(destination: URL(string: appState.tokenInfo?.jupiter ?? "https://jup.ag/swap/SOL-\(tokenContract)")!) {
                    Label("Trade on Jupiter", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                
                Link(destination: URL(string: appState.tokenInfo?.dexscreener ?? "https://dexscreener.com/solana/\(tokenContract)")!) {
                    Label("DexScreener", systemImage: "chart.line.uptrend.xyaxis")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func lastClaimCard(_ claim: ClaimTokensResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                
                Text("Last Claim")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Amount", value: String(format: "%.2f SHIPYARD", claim.amount))
                InfoRow(label: "Transaction", value: claim.transactionId, monospaced: true)
            }
            
            Link(destination: URL(string: "https://solscan.io/tx/\(claim.transactionId)")!) {
                Label("View on Solscan", systemImage: "arrow.up.right.square")
            }
            .font(.caption)
        }
        .padding()
        .background(.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var isValidClaimAmount: Bool {
        guard let amount = Double(claimAmount),
              let balance = appState.tokenBalance else {
            return false
        }
        return amount > 0 && amount <= balance.balance
    }
    
    private func claim() {
        guard let amount = Double(claimAmount) else { return }
        
        isClaimingTokens = true
        Task {
            if let response = await appState.claimTokens(amount: amount) {
                lastClaim = response
                claimAmount = ""
            }
            isClaimingTokens = false
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

struct SetWalletSheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    
    @State private var walletAddress: String = ""
    @State private var isSaving: Bool = false
    
    private var isValidAddress: Bool {
        // Basic Solana address validation (32-44 base58 characters)
        let address = walletAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let base58Chars = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return address.count >= 32 && address.count <= 44 && address.unicodeScalars.allSatisfy { base58Chars.contains($0) }
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
                
                Text("Set Solana Wallet")
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidAddress || isSaving)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 16) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)
                
                Text("Enter your Solana wallet address")
                    .font(.headline)
                
                TextField("e.g., 7hhAuM18KxYE...", text: $walletAddress)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                
                Text("Make sure to double-check your address. Token transfers cannot be reversed!")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            
            Spacer()
        }
        .frame(width: 450, height: 300)
        .disabled(isSaving)
        .onAppear {
            if let existing = appState.walletAddress ?? appState.currentAgent?.solanaWallet {
                walletAddress = existing
            }
        }
    }
    
    private func save() {
        isSaving = true
        Task {
            let success = await appState.setWallet(walletAddress.trimmingCharacters(in: .whitespacesAndNewlines))
            if success {
                isPresented = false
            }
            isSaving = false
        }
    }
}

#Preview {
    WalletView()
        .environment(AppState())
}
