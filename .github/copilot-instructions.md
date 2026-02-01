# GitHub Copilot Instructions for Dockhand

## Project Context
Dockhand is a macOS SwiftUI app for Shipyard with an in-app microtools browser, feed, ships, attestations, and wallet views.

**Targets:** macOS 26
**Swift Version:** 6.0
**Status:** Active development

---

## Preferred Languages & Tech
1. **Swift** — Primary for app code, services, and features
2. **Shell (bash/zsh)** — Build/run scripts and automation

---

## Formatting & Style
- **Indentation:** 2 spaces (no tabs)
- **Line Length:** ~120 characters
- **Braces:** K&R style
- **Keep edits minimal** and follow existing style

---

## Repo Navigation
| Looking for... | Location |
|---|---|
| App entry point | Dockhand/DockhandApp.swift |
| Main UI layout | Dockhand/ContentView.swift |
| Views | Dockhand/Views/ |
| Services | Dockhand/Services/ |
| Shipyard API models/client | Dockhand/ShipyardKit/ |
| Microtools submodule | shipyard-microtools/ |
| Plans | Dockhand/Plans/ |

---

## Security & Storage
- Store API keys in Keychain only.
- Never log tokens or secrets.

---

## SwiftUI & Concurrency
- Prefer async/await.
- Use @MainActor for UI updates.
- Avoid DispatchQueue.main unless required.

---

## Microtools Notes
- Microtools are hosted on GitHub Pages.
- API-based tools rely on a native fetch bridge in the app.
- Local-only tools require a local CORS proxy.

---

## Build & Test
- Build with Xcode (⌘R) or `xcodebuild -scheme Dockhand -destination 'platform=macOS' build`.
- Do not launch the app from terminal.

---

**Last Updated:** February 1, 2026
