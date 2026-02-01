//
//  MicrotoolsView.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
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
    
    // Keep minimal logging for proxy failures only
    
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
        print("[ShipyardProxy] Error: \(error.localizedDescription) for \(realURL)")
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
  
  private static func safeURL(_ string: String) -> URL {
    URL(string: string) ?? URL(fileURLWithPath: "/")
  }
  
  static let all: [Microtool] = [
    Microtool(
      id: "explorer",
      name: "Shipyard Explorer",
      description: "Platform dashboard with leaderboard & activity",
      icon: "chart.bar.fill",
      url: safeURL("https://crunchybananas.github.io/shipyard-microtools/explorer"),
      requiresAPI: true
    ),
    Microtool(
      id: "attestation-tracker",
      name: "Attestation Tracker",
      description: "Find ships needing attestations",
      icon: "checkmark.seal.fill",
      url: safeURL("https://crunchybananas.github.io/shipyard-microtools/attestation-tracker"),
      requiresAPI: true
    ),
    Microtool(
      id: "reputation-graph",
      name: "Reputation Graph",
      description: "D3.js attestation network visualization",
      icon: "point.3.connected.trianglepath.dotted",
      url: safeURL("https://crunchybananas.github.io/shipyard-microtools/reputation-graph"),
      requiresAPI: true
    ),
    Microtool(
      id: "token-lens",
      name: "Token Lens",
      description: "JWT decoder & signature verifier",
      icon: "key.fill",
      url: safeURL("https://crunchybananas.github.io/shipyard-microtools/token-lens"),
      requiresAPI: false
    ),
    Microtool(
      id: "gradient-generator",
      name: "Gradient Generator",
      description: "CSS gradient builder with copy-to-clipboard",
      icon: "paintpalette.fill",
      url: safeURL("https://crunchybananas.github.io/shipyard-microtools/gradient-generator"),
      requiresAPI: false
    ),
    Microtool(
      id: "url-health",
      name: "URL Health Checker",
      description: "Batch validate proof URLs",
      icon: "stethoscope",
      url: safeURL("https://crunchybananas.github.io/shipyard-microtools/url-health"),
      requiresAPI: false
    ),
    Microtool(
      id: "ship-embed",
      name: "Ship Embed Generator",
      description: "Embeddable badges for README & portfolio",
      icon: "tag.fill",
      url: safeURL("https://crunchybananas.github.io/shipyard-microtools/ship-embed"),
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
      
      Text("Choose a tool from the sidebar to view it here.\nAPI-based tools load in-app via native networking.")
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
  @State private var errorMessage: String?
  
  private func hardReload() {
    guard let baseURL = webViewRef?.url ?? tool.url as URL? else { return }
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    var queryItems = components?.queryItems ?? []
    queryItems.removeAll { $0.name == "t" }
    queryItems.append(URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970))))
    components?.queryItems = queryItems
    if let url = components?.url {
      webViewRef?.load(URLRequest(url: url))
    } else {
      webViewRef?.reload()
    }
  }
  
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
        .help("Reload")
        
        Button(action: { hardReload() }) {
          Image(systemName: "arrow.clockwise.circle")
        }
        .buttonStyle(.borderless)
        .help("Hard reload")
        
        Divider()
          .frame(height: 16)
        
        // Tool info
        Image(systemName: tool.icon)
          .foregroundStyle(.blue)
        Text(tool.name)
          .fontWeight(.medium)
        
        if tool.requiresAPI {
          Text("API")
            .font(.caption)
            .foregroundStyle(.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15))
            .clipShape(Capsule())
            .help("Uses Shipyard API")
        } else {
          Text("Offline")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
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
      
      ZStack {
        // WebView
        WebViewRepresentable(
          url: tool.url,
          toolId: tool.id,
          isLoading: $isLoading,
          canGoBack: $canGoBack,
          canGoForward: $canGoForward,
          errorMessage: $errorMessage,
          webViewRef: $webViewRef,
          injectCORSBypass: tool.requiresAPI
        )
        
        if let errorMessage = errorMessage {
          VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 32))
              .foregroundStyle(.yellow)
            Text("Couldn’t load \(tool.name)")
              .font(.headline)
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .frame(maxWidth: 360)
            HStack(spacing: 12) {
              Button("Reload") {
                webViewRef?.reload()
              }
              Button("Hard reload") {
                hardReload()
              }
              Button("Open in Safari") {
                NSWorkspace.shared.open(tool.url)
              }
            }
          }
          .padding(24)
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .shadow(radius: 10)
        }
      }
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
  @Binding var errorMessage: String?
  @Binding var webViewRef: WKWebView?
  let injectCORSBypass: Bool
  
  // Shared scheme handler (must persist for lifetime of webview)
  private static let schemeHandler = ShipyardAPISchemeHandler()
  
  func makeNSView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    
    // Allow JavaScript
    config.defaultWebpagePreferences.allowsContentJavaScript = true
    config.preferences.javaScriptCanOpenWindowsAutomatically = true
    
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
    
    config.userContentController.add(context.coordinator, name: "dockhandFetch")
    
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator
    webView.allowsBackForwardNavigationGestures = true
    context.coordinator.webView = webView
    
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
  
  class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    var parent: WebViewRepresentable
    var currentToolId: String = ""
    weak var webView: WKWebView?
    
    init(_ parent: WebViewRepresentable) {
      self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      DispatchQueue.main.async {
        self.parent.isLoading = true
        self.parent.errorMessage = nil
      }
    }
    
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      DispatchQueue.main.async {
        self.parent.isLoading = false
        self.parent.canGoBack = webView.canGoBack
        self.parent.canGoForward = webView.canGoForward
        self.parent.errorMessage = nil
      }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      if message.name == "dockhandFetch" {
        handleDockhandFetch(message)
      }
    }
    
    private func handleDockhandFetch(_ message: WKScriptMessage) {
      guard let payload = message.body as? [String: Any],
            let id = payload["id"] as? String,
            let urlString = payload["url"] as? String,
            let url = URL(string: urlString) else {
        return
      }
      
      let method = (payload["method"] as? String) ?? "GET"
      let headers = (payload["headers"] as? [String: String]) ?? [:]
      let body = payload["body"] as? String
      
      
      var request = URLRequest(url: url)
      request.httpMethod = method
      request.allHTTPHeaderFields = headers
      if let body = body {
        request.httpBody = Data(body.utf8)
      }
      
      URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
        guard let self = self else { return }
        if let error = error {
          print("[Dockhand NativeFetch] Error: \(error.localizedDescription) for \(urlString)")
          self.sendFetchReject(id: id, error: error)
          return
        }
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let headerFields = (response as? HTTPURLResponse)?.allHeaderFields ?? [:]
        var headers: [String: String] = [:]
        for (key, value) in headerFields {
          if let key = key as? String {
            headers[key] = "\(value)"
          }
        }
        
        let bodyBase64 = data?.base64EncodedString() ?? ""
        self.sendFetchResolve(id: id, status: statusCode, headers: headers, bodyBase64: bodyBase64)
      }.resume()
    }
    
    private func sendFetchResolve(id: String, status: Int, headers: [String: String], bodyBase64: String) {
      guard let webView = webView,
            let headersData = try? JSONSerialization.data(withJSONObject: headers, options: []),
            let headersJSON = String(data: headersData, encoding: .utf8) else { return }
      
      let js = "window.__dockhandFetchResolve(\"\(id)\", \(status), \(headersJSON), \"\(bodyBase64)\");"
      DispatchQueue.main.async {
        webView.evaluateJavaScript(js, completionHandler: nil)
      }
    }
    
    private func sendFetchReject(id: String, error: Error) {
      guard let webView = webView else { return }
      let message = error.localizedDescription.replacingOccurrences(of: "\"", with: "\\\"")
      let js = "window.__dockhandFetchReject(\"\(id)\", \"\(message)\");"
      DispatchQueue.main.async {
        webView.evaluateJavaScript(js, completionHandler: nil)
      }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      DispatchQueue.main.async {
        self.parent.isLoading = false
        self.parent.errorMessage = error.localizedDescription
      }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      DispatchQueue.main.async {
        self.parent.isLoading = false
        self.parent.errorMessage = error.localizedDescription
      }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
      decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
      decisionHandler(.allow)
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
            const pendingFetches = new Map();
            let fetchCounter = 0;
        
            function sendNativeFetch(payload) {
                return new Promise((resolve, reject) => {
                    const id = `dockhand_${Date.now()}_${fetchCounter++}`;
                    pendingFetches.set(id, { resolve, reject });
                    try {
                        if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.dockhandFetch) {
                            throw new Error('dockhandFetch handler not available');
                        }
                        window.webkit.messageHandlers.dockhandFetch.postMessage({ id, ...payload });
                    } catch (e) {
                        pendingFetches.delete(id);
                        reject(e);
                    }
                });
            }
        
            window.__dockhandFetchResolve = function(id, status, headers, bodyBase64) {
                const pending = pendingFetches.get(id);
                if (!pending) return;
                pendingFetches.delete(id);
                try {
                    const binary = atob(bodyBase64 || '');
                    const bytes = new Uint8Array(binary.length);
                    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
                    const response = new Response(bytes, { status, headers });
                    pending.resolve(response);
                } catch (e) {
                    pending.reject(e);
                }
            };
        
            window.__dockhandFetchReject = function(id, message) {
                const pending = pendingFetches.get(id);
                if (!pending) return;
                pendingFetches.delete(id);
                pending.reject(new Error(message || 'Native fetch failed'));
            };
        
            window.fetch = async function(input, init) {
                let url = input;
                if (input instanceof Request) {
                    url = input.url;
                }
                // Check if this is a Shipyard API call
                if (typeof url === 'string' && url.startsWith(SHIPYARD_ORIGIN)) {
                    let method = 'GET';
                    let headers = {};
                    let body = undefined;
        
                    if (input instanceof Request) {
                        method = input.method || 'GET';
                        input.headers.forEach((value, key) => { headers[key] = value; });
                        if (method !== 'GET' && method !== 'HEAD') {
                            body = await input.clone().text();
                        }
                    } else if (init) {
                        method = init.method || 'GET';
                        if (init.headers) {
                            if (init.headers instanceof Headers) {
                                init.headers.forEach((value, key) => { headers[key] = value; });
                            } else {
                                headers = init.headers;
                            }
                        }
                        if (init.body && method !== 'GET' && method !== 'HEAD') {
                            body = init.body;
                        }
                    }
        
                    return sendNativeFetch({
                        url,
                        method,
                        headers,
                        body
                    });
                }
                
                return originalFetch.call(this, input, init);
            };
        
            // Ensure global aliases point to our wrapper
            try { globalThis.fetch = window.fetch; } catch (e) {}
            try { self.fetch = window.fetch; } catch (e) {}
            
            // Also override XMLHttpRequest for completeness
            const originalXHROpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url, ...rest) {
                if (typeof url === 'string') {
                    const proxyUrl = rewriteShipyardUrl(url);
                    if (proxyUrl !== url) {
                        return originalXHROpen.call(this, method, proxyUrl, ...rest);
                    }
                }
                return originalXHROpen.call(this, method, url, ...rest);
            };
        })();
        """
  }
}

#Preview {
  MicrotoolsView()
    .frame(width: 900, height: 600)
}
