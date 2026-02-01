//
//  AttestationQueueView.swift
//  Dockhand
//
//  Attestation Copilot - streamlined workflow for reviewers
//

import SwiftUI
import WebKit

struct AttestationQueueView: View {
    @Environment(AppState.self) private var appState
    
    @State private var pendingShips: [Ship] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading: Bool = true
    @State private var showChecklist: Bool = true
    @State private var checklistState: ChecklistState = ChecklistState()
    @State private var isAttesting: Bool = false
    @State private var showProofPreview: Bool = true
    
    struct ChecklistState {
        var proofLoads: Bool? = nil
        var isClaimedProject: Bool? = nil
        var actuallyWorks: Bool? = nil
        
        var isComplete: Bool {
            proofLoads != nil && isClaimedProject != nil && actuallyWorks != nil
        }
        
        var suggestedVerdict: String {
            guard isComplete else { return "valid" }
            if proofLoads == false { return "invalid" }
            if isClaimedProject == false { return "invalid" }
            if actuallyWorks == false { return "unsure" }
            return "valid"
        }
        
        mutating func reset() {
            proofLoads = nil
            isClaimedProject = nil
            actuallyWorks = nil
        }
    }
    
    private var currentShip: Ship? {
        guard currentIndex >= 0 && currentIndex < pendingShips.count else { return nil }
        return pendingShips[currentIndex]
    }
    
    private var filteredPendingShips: [Ship] {
        pendingShips.filter { ship in
            !appState.hasAttested(ship.id) && !appState.isOwnShip(ship)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            headerBar
            
            Divider()
            
            if isLoading {
                ProgressView("Loading attestation queue...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPendingShips.isEmpty {
                emptyState
            } else {
                HSplitView {
                    // Left: Ship queue list
                    queueList
                        .frame(minWidth: 280, maxWidth: 320)
                    
                    // Right: Current ship detail + proof preview
                    if let ship = currentShip {
                        shipReviewPanel(ship: ship)
                    } else {
                        Text("Select a ship to review")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .task {
            await loadPendingShips()
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Attestation Queue")
                    .font(.headline)
                Text("\(filteredPendingShips.count) ships need review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Stats
                statBadge(icon: "clock", value: "\(shipsOldestFirst.count)", label: "Waiting")
                statBadge(icon: "checkmark.seal", value: "\(shipsAlmostThere.count)", label: "Almost There")
                
                Divider()
                    .frame(height: 24)
                
                Button {
                    Task { await loadPendingShips() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding()
    }
    
    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Queue List
    
    private var queueList: some View {
        List(selection: Binding(
            get: { currentShip?.id },
            set: { newId in
                if let id = newId, let idx = filteredPendingShips.firstIndex(where: { $0.id == id }) {
                    currentIndex = idx
                    checklistState.reset()
                }
            }
        )) {
            Section("Almost There (2/3 attests)") {
                ForEach(shipsAlmostThere) { ship in
                    queueRow(ship: ship)
                        .tag(ship.id)
                }
            }
            
            Section("Needs Review (oldest first)") {
                ForEach(shipsOldestFirst) { ship in
                    queueRow(ship: ship)
                        .tag(ship.id)
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private func queueRow(ship: Ship) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ship.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            HStack {
                Text(ship.agentName ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Attestation dots
                HStack(spacing: 2) {
                    let count = ship.attestations ?? 0
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < count ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                
                if let createdAt = ship.createdAt {
                    Text(createdAt, format: .relative(presentation: .numeric))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Ship Review Panel
    
    private func shipReviewPanel(ship: Ship) -> some View {
        VSplitView {
            // Top: Ship info + checklist
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Ship header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(ship.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            attestationProgress(ship: ship)
                        }
                        
                        HStack {
                            Text("by \(ship.agentName ?? "Unknown")")
                                .foregroundStyle(.secondary)
                            
                            if let createdAt = ship.createdAt {
                                Text("• \(createdAt, format: .relative(presentation: .numeric))")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .font(.caption)
                    }
                    
                    if let description = ship.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                    }
                    
                    Divider()
                    
                    // Verification checklist
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Verification Checklist", systemImage: "checklist")
                                .font(.headline)
                            
                            checklistItem(
                                question: "Does the proof URL load?",
                                binding: $checklistState.proofLoads,
                                shortcut: "1"
                            )
                            
                            checklistItem(
                                question: "Is this the claimed project?",
                                binding: $checklistState.isClaimedProject,
                                shortcut: "2"
                            )
                            
                            checklistItem(
                                question: "Does it actually work?",
                                binding: $checklistState.actuallyWorks,
                                shortcut: "3"
                            )
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Verdict buttons
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Submit Verdict", systemImage: "checkmark.seal")
                                .font(.headline)
                            
                            if checklistState.isComplete {
                                Text("Suggested: \(checklistState.suggestedVerdict.capitalized)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 12) {
                                Button {
                                    submitVerdict("valid")
                                } label: {
                                    Label("Valid", systemImage: "checkmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .keyboardShortcut("v", modifiers: .command)
                                .disabled(isAttesting)
                                
                                Button {
                                    submitVerdict("invalid")
                                } label: {
                                    Label("Invalid", systemImage: "xmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .keyboardShortcut("x", modifiers: .command)
                                .disabled(isAttesting)
                                
                                Button {
                                    submitVerdict("unsure")
                                } label: {
                                    Label("Unsure", systemImage: "questionmark.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .keyboardShortcut("u", modifiers: .command)
                                .disabled(isAttesting)
                            }
                            
                            HStack {
                                Button {
                                    skipToNext()
                                } label: {
                                    Label("Skip", systemImage: "forward.fill")
                                }
                                .keyboardShortcut(.rightArrow, modifiers: .command)
                                
                                Spacer()
                                
                                Text("⌘V valid • ⌘X invalid • ⌘U unsure • ⌘→ skip")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
            .frame(minHeight: 300)
            
            // Bottom: Proof preview
            if showProofPreview, let proofUrl = ship.proofUrl {
                VStack(spacing: 0) {
                    HStack {
                        Label("Proof Preview", systemImage: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button {
                            if let url = resolvedProofURL(from: proofUrl) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Open in Browser", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    if let url = resolvedProofURL(from: proofUrl) {
                        WebPreview(url: url)
                    } else {
                        Text("Invalid proof URL")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minHeight: 250)
            }
        }
    }
    
    private func checklistItem(question: String, binding: Binding<Bool?>, shortcut: String) -> some View {
        HStack {
            Text(question)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    binding.wrappedValue = true
                } label: {
                    Image(systemName: binding.wrappedValue == true ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(binding.wrappedValue == true ? .green : .secondary)
                }
                .buttonStyle(.plain)
                
                Button {
                    binding.wrappedValue = false
                } label: {
                    Image(systemName: binding.wrappedValue == false ? "xmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(binding.wrappedValue == false ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func attestationProgress(ship: Ship) -> some View {
        HStack(spacing: 6) {
            let count = ship.attestations ?? 0
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < count ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
            Text("\(count)/3")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Ships to Review", systemImage: "checkmark.seal")
        } description: {
            Text("All pending ships have been reviewed or are your own.")
        } actions: {
            Button("Refresh") {
                Task { await loadPendingShips() }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var shipsAlmostThere: [Ship] {
        filteredPendingShips.filter { ($0.attestations ?? 0) == 2 }
    }
    
    private var shipsOldestFirst: [Ship] {
        filteredPendingShips
            .filter { ($0.attestations ?? 0) < 2 }
            .sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
    }
    
    // MARK: - Actions
    
    private func loadPendingShips() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load ships with pending status
        await appState.loadShips(status: .pending, refresh: true)
        pendingShips = appState.ships.filter { $0.status == .pending }
        
        // Select first ship if available
        if !filteredPendingShips.isEmpty && currentIndex >= filteredPendingShips.count {
            currentIndex = 0
        }
        checklistState.reset()
    }
    
    private func submitVerdict(_ verdict: String) {
        guard let ship = currentShip else { return }
        
        isAttesting = true
        Task {
            let success = await appState.attestShip(ship.id, verdict: verdict)
            isAttesting = false
            
            if success {
                // Move to next ship
                skipToNext()
            }
        }
    }
    
    private func skipToNext() {
        checklistState.reset()
        
        // Remove current ship from pending and move to next
        if let current = currentShip {
            pendingShips.removeAll { $0.id == current.id }
        }
        
        if currentIndex >= filteredPendingShips.count {
            currentIndex = max(0, filteredPendingShips.count - 1)
        }
    }
    
    private func setupKeyboardShortcuts() {
        // Keyboard shortcuts are handled via .keyboardShortcut modifiers
    }
    
    private func resolvedProofURL(from proofUrl: String) -> URL? {
        let trimmed = proofUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://" + trimmed)
    }
}

// MARK: - WebKit Preview

struct WebPreview: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    AttestationQueueView()
        .environment(AppState())
}
