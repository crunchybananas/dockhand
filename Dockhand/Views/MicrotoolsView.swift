//
//  MicrotoolsView.swift
//  Dockhand
//
//  In-app browser for Shipyard Microtools (bypasses CORS via native proxy)
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

// MARK: - Native API Proxy (bypasses CORS at network level)

/// Intercepts requests to shipyard-proxy:// and makes them via native URLSession
final class ShipyardAPISchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let queue = DispatchQueue(label: "com.dockhand.schemehandler")
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme == "shipyard-proxy" else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        
        // Convert shipyard-proxy://api/ships → https://shipyard.bot/api/ships
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        components?.host = "shipyard.bot"
        
        guard let realURL = components?.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        
        print("[ShipyardProxy] \(urlSchemeTask.request.httpMethod ?? "GET") \(realURL)")
        
        var request = URLRequest(url: realURL)
        request.httpMethod = urlSchemeTask.request.httpMethod
        request.allHTTPHeaderFields = urlSchemeTask.request.allHTTPHeaderFields
        request.httpBody = urlSchemeTask.request.httpBody
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            self.queue.async {
                // Check if task was cancelled
                guard self.activeTasks[ObjectIdentifier(urlSchemeTask)] != nil else { return }
                self.activeTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))
            }
            
            if let error = error {
                print("[ShipyardProxy] Error: \(error.localizedDescription)")
                urlSchemeTask.didFailWithError(error)
                return
            }
            
            if let response = response as? HTTPURLResponse {
                // Create response with CORS headers so WebKit accepts it
                var headers = response.allHeaderFields as? [String: String] ?? [:]
                headers["Access-Control-Allow-Origin"] = "*"
                headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
                headers["Access-Control-Allow-Headers"] = "*"
                
                if let modifiedResponse = HTTPURLResponse(
                    url: url, // Use original URL so WebKit is happy
                    statusCode: response.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                ) {
                    urlSchemeTask.didReceive(modifiedResponse)
                }
            }
            
            if let data = data {
                urlSchemeTask.didReceive(data)
            }
            
            urlSchemeTask.didFinish()
        }
        
        queue.async {
            self.activeTasks[ObjectIdentifier(urlSchemeTask)] = task
        }
        
        task.resume()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        queue.async {
            if let task = self.activeTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask)) {
                task.cancel()
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
                toolId: tool.id,
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
    let toolId: String  // Use this to track which tool we're showing
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webViewRef: WKWebView?
    let injectCORSBypass: Bool
    
    // Shared scheme handler (must persist for lifetime of webview)
    private static let schemeHandler = ShipyardAPISchemeHandler()
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Allow JavaScript
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // Enable JavaScript console logging in Xcode
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Register custom scheme handler for API proxy
        if injectCORSBypass {
            config.setURLSchemeHandler(Self.schemeHandler, forURLScheme: "shipyard-proxy")
            
            // Inject script that redirects API calls to our proxy scheme
            let script = WKUserScript(
                source: proxyInjectionScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(script)
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Store reference and current tool ID
        context.coordinator.currentToolId = toolId
        DispatchQueue.main.async {
            webViewRef = webView
        }
        
        // Load URL
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload if we switched to a different tool
        if context.coordinator.currentToolId != toolId {
            context.coordinator.currentToolId = toolId
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewRepresentable
        var currentToolId: String = ""
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("[MicrotoolsWebView] Started loading: \(webView.url?.absoluteString ?? "unknown")")
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[MicrotoolsWebView] Finished loading: \(webView.url?.absoluteString ?? "unknown")")
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
            
            // Debug: Check if our flag was set
            webView.evaluateJavaScript("window.__DOCKHAND_NATIVE__") { result, error in
                print("[MicrotoolsWebView] __DOCKHAND_NATIVE__ = \(String(describing: result))")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[MicrotoolsWebView] Navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("[MicrotoolsWebView] Provisional navigation failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        // Capture JavaScript console.log messages
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("[MicrotoolsWebView JS Alert] \(message)")
            completionHandler()
        }
    }
    
    // JavaScript that intercepts fetch() and redirects API calls through our native proxy
    private var proxyInjectionScript: String {
        """
        (function() {
            console.log('[Dockhand] Installing native API proxy...');
            
            // Mark as running in native app
            window.__DOCKHAND_NATIVE__ = true;
            
            const SHIPYARD_ORIGIN = 'https://shipyard.bot';
            const PROXY_ORIGIN = 'shipyard-proxy://shipyard.bot';

            function rewriteShipyardUrl(rawUrl) {
                try {
                    const resolved = new URL(rawUrl, window.location.href);
                    if (resolved.origin !== SHIPYARD_ORIGIN) return rawUrl;
                    resolved.protocol = 'shipyard-proxy:';
                    return resolved.toString();
                } catch (e) {
                    return rawUrl;
                }
            }
            
            // Override fetch to intercept Shipyard API calls
            const originalFetch = window.fetch;
            window.fetch = function(input, init) {
                let url = input;
                if (input instanceof Request) {
                    url = input.url;
                }
                
                // Check if this is a Shipyard API call
                if (typeof url === 'string') {
                    const proxyUrl = rewriteShipyardUrl(url);
                    if (proxyUrl !== url) {
                        console.log('[Dockhand Proxy] ' + url + ' → ' + proxyUrl);
                    
                        if (input instanceof Request) {
                            // Clone the request with new URL
                            return originalFetch.call(this, proxyUrl, {
                                method: input.method,
                                headers: input.headers,
                                body: input.body,
                                mode: 'cors',
                                credentials: input.credentials
                            });
                        }
                        return originalFetch.call(this, proxyUrl, init);
                    }
                }
                
                return originalFetch.call(this, input, init);
            };
            
            // Also override XMLHttpRequest for completeness
            const originalXHROpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url, ...rest) {
                if (typeof url === 'string') {
                    const proxyUrl = rewriteShipyardUrl(url);
                    if (proxyUrl !== url) {
                        console.log('[Dockhand XHR Proxy] ' + url + ' → ' + proxyUrl);
                        return originalXHROpen.call(this, method, proxyUrl, ...rest);
                    }
                }
                return originalXHROpen.call(this, method, url, ...rest);
            };
            
            console.log('[Dockhand] Native API proxy installed');
        })();
        """
    }
}

#Preview {
    MicrotoolsView()
        .frame(width: 900, height: 600)
}
