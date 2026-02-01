# Dockhand

Dockhand is a macOS SwiftUI app for Shipyard. It includes an in-app microtools browser, Shipyard feed, ships, attestations, and wallet views.

## Requirements
- macOS 26+
- Xcode 17+
- Swift 6

## Build & Run
1. Open Dockhand.xcodeproj in Xcode.
2. Select the Dockhand scheme.
3. Build and run (⌘R).

## Auth
The Shipyard API key is stored securely in macOS Keychain.

## Microtools
Microtools are hosted on GitHub Pages and loaded inside a WebView. API-based tools use a native fetch bridge to bypass CORS.

Local-only tools require a CORS proxy:

- Start proxy: npx local-cors-proxy --proxyUrl https://shipyard.bot --port 8010
- Serve docs: npx serve docs
- Open: http://localhost:3000/<tool>

## Repo Layout
- Dockhand/: App source
- Dockhand/Views/: SwiftUI views
- Dockhand/Services/: App services (Keychain, app state)
- Dockhand/ShipyardKit/: API models and client
- shipyard-microtools/: Git submodule with web tools
- Dockhand/Plans/: Roadmap and ideas

## License
MIT. See LICENSE.
