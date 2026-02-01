//
//  MicrotoolsView.swift
//  Dockhand
//
//  In-app browser for Shipyard Microtools (bypasses CORS)
//

import SwiftUI
import WebKit

struct MicrotoolsView: View {
    @State private var selectedTool: Microtool? = nil
    
    var body: some View {
        HSplitView {
            // Sidebar with tool list
            ToolSidebar(selectedTool: $selectedTool)
                .frame(minWidth: 200, maxWidth: 280)
            
            // WebView or welcome screen
            if let tool = selectedTool {
                MicrotoolWebView(tool: tool)
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Tool Model

struct Microtool: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let url: URL
    let requiresAPI: Bool
    
    static let all: [Microtool] = [
        Microtool(
            id: "explorer",
            name: "Shipyard Explorer",
            description: "Platform dashboard with leaderboard & activity",
            icon: "chart.bar.fill",
            url: URL(string: "https://crunchybananas.github.io/shipyard-microtools/explorer")!,
            requiresAPI: true
        ),
        Microtool(
            id: "attestation-tracker",
            name: "Attestation Tracker",
            description: "Find ships needing attestations",
            icon: "checkmark.seal.fill",
            url: URL(string: "https://crunchybananas.github.io/shipyard-microtools/attestation-tracker")!,
            requiresAPI: true
        ),
        Microtool(
            id: "reputation-graph",
            name: "Reputation Graph",
            description: "D3.js attestation network visualization",
            icon: "point.3.connected.trianglepath.dotted",
            url: URL(string: "https://crunchybananas.github.io/shipyard-microtools/reputation-graph")!,
            requiresAPI: true
        ),
        Microtool(
            id: "token-lens",
            name: "Token Lens",
            description: "JWT decoder & signature verifier",
            icon: "key.fill",
            url: URL(string: "https://crunchybananas.github.io/shipyard-microtools/token-lens")!,
            requiresAPI: false
        ),
        Microtool(
            id: "gradient-generator",
            name: "Gradient Generator",
            description: "CSS gradient builder with copy-to-clipboard",
            icon: "paintpalette.fill",
            url: URL(string: "https://crunchybananas.github.io/shipyard-microtools/gradient-generator")!,
            requiresAPI: false
        ),
    ]
}

// MARK: - Sidebar

struct ToolSidebar: View {
    @Binding var selectedTool: Microtool?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Microtools")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Text("Native browser — no CORS restrictions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 12)
            
            Divider()
            
            List(selection: $selectedTool) {
                Section("API Tools") {
                    ForEach(Microtool.all.filter { $0.requiresAPI }) { tool in
                        ToolRow(tool: tool)
                            .tag(tool)
                    }
                }
                
                Section("Offline Tools") {
                    ForEach(Microtool.all.filter { !$0.requiresAPI }) { tool in
                        ToolRow(tool: tool)
                            .tag(tool)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(.ultraThinMaterial)
    }
}

struct ToolRow: View {
    let tool: Microtool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tool.icon)
                .font(.title3)
                .foregroundStyle(tool.requiresAPI ? .blue : .secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.body)
                Text(tool.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("Select a Microtool")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Choose a tool from the sidebar to view it here.\nAPI-based tools work without CORS issues.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - WebView

struct MicrotoolWebView: View {
    let tool: Microtool
    @State private var isLoading = true
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewRef: WKWebView?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Navigation buttons
                Button(action: { webViewRef?.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)
                .buttonStyle(.borderless)
                
                Button(action: { webViewRef?.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
                .buttonStyle(.borderless)
                
                Button(action: { webViewRef?.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                
                Divider()
                    .frame(height: 16)
                
                // Tool info
                Image(systemName: tool.icon)
                    .foregroundStyle(.blue)
                Text(tool.name)
                    .fontWeight(.medium)
                
                if tool.requiresAPI {
                    Text("• API")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                // Open in browser
                Button(action: {
                    NSWorkspace.shared.open(tool.url)
                }) {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .help("Open in Safari")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            
            Divider()
            
            // WebView
            WebViewRepresentable(
                url: tool.url,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                webViewRef: $webViewRef,
                injectCORSBypass: tool.requiresAPI
            )
        }
    }
}

// MARK: - WebView Representable

struct WebViewRepresentable: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webViewRef: WKWebView?
    let injectCORSBypass: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Allow JavaScript
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Inject script to bypass CORS detection
        if injectCORSBypass {
            let script = WKUserScript(
                source: corsBypassScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(script)
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Store reference
        DispatchQueue.main.async {
            webViewRef = webView
        }
        
        // Load URL
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload if URL changed
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
    
    // JavaScript to make the app think it's running locally (bypass CORS detection)
    private var corsBypassScript: String {
        """
        // Override the isGitHubPages and getApiBase functions
        // This makes the microtools use the direct API URL since native apps don't have CORS
        window.__DOCKHAND_NATIVE__ = true;
        
        // Override after DOM loads to catch late-defined functions
        document.addEventListener('DOMContentLoaded', function() {
            // Override isGitHubPages to return false
            if (typeof window.isGitHubPages === 'function') {
                window.isGitHubPages = function() { return false; };
            }
            
            // Override getApiBase to use direct API (native app has no CORS)
            if (typeof window.getApiBase === 'function') {
                window.getApiBase = function() { return 'https://shipyard.bot/api'; };
            }
        });
        
        // Also try to set before any scripts run
        Object.defineProperty(window, 'isGitHubPages', {
            value: function() { return false; },
            writable: true,
            configurable: true
        });
        
        Object.defineProperty(window, 'getApiBase', {
            value: function() { return 'https://shipyard.bot/api'; },
            writable: true,
            configurable: true
        });
        """
    }
}

#Preview {
    MicrotoolsView()
        .frame(width: 900, height: 600)
}
