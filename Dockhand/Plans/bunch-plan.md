# Bunch — Native macOS Knowledge Base

## Overview
A local-first, native macOS Markdown knowledge base with bidirectional links and graph visualization. Think Obsidian, but built from scratch in SwiftUI — fast, private, and deeply integrated with macOS. Your ideas, connected.

**Company:** Crunchy Bananas
**Tagline:** *"Your ideas, connected."*
**Target:** macOS 26+, iOS 26+
**Swift:** 6.0
**License:** Proprietary (clean-room implementation, no OSS forks)

---

## Why Native?
| Problem with Electron apps | Bunch's answer |
|---|---|
| 200MB+ RAM for a text editor | ~30MB baseline, SwiftUI views are lightweight |
| No system integration | Spotlight, Quick Note, Shortcuts, Widgets, Share Extensions |
| Sluggish with large vaults | SwiftData + GRDB for indexed queries across 100k+ notes |
| No offline-first sync | iCloud CloudKit with CRDT merge |
| Generic UI | Native macOS chrome — sidebar, inspector, toolbar, vibrancy |

---

## Technical Stack
- **SwiftUI** — All UI, NavigationSplitView, custom TextEditor
- **SwiftData** — Note metadata, links, tags, graph relationships
- **Swift Markdown** (apple/swift-markdown) — Parsing & rendering
- **TextKit 2** — Custom Markdown editor with syntax highlighting
- **Swift Charts** — Graph statistics and analytics
- **SpriteKit** or **Metal** — Graph visualization (force-directed layout)
- **CloudKit** — iCloud sync (private database)
- **Combine / AsyncSequence** — File system watching, reactive updates
- **FSEvents** — Watch vault folder for external changes
- **Uniform Type Identifiers** — `.md` file handling, drag & drop

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   BunchApp                       │
│              (App entry point)                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌───────────┐  ┌──────────┐  ┌──────────────┐  │
│  │ Sidebar   │  │ Editor   │  │  Inspector   │  │
│  │ • Files   │  │ • Write  │  │  • Backlinks │  │
│  │ • Search  │  │ • Preview│  │  • Tags      │  │
│  │ • Tags    │  │ • Split  │  │  • TOC       │  │
│  │ • Graph   │  │          │  │  • Graph     │  │
│  └─────┬─────┘  └────┬─────┘  └──────┬───────┘  │
│        │             │               │           │
│  ┌─────┴─────────────┴───────────────┴─────────┐ │
│  │              VaultService                    │ │
│  │  • File I/O, FSEvents watcher               │ │
│  │  • Markdown parsing (swift-markdown)        │ │
│  │  • Link extraction & resolution             │ │
│  └──────────────────┬──────────────────────────┘ │
│                     │                            │
│  ┌──────────────────┴──────────────────────────┐ │
│  │              DataStore                       │ │
│  │  • SwiftData (metadata, links, tags)        │ │
│  │  • Full-text search index                   │ │
│  │  • Graph relationship queries               │ │
│  └──────────────────┬──────────────────────────┘ │
│                     │                            │
│  ┌──────────────────┴──────────────────────────┐ │
│  │              SyncEngine                      │ │
│  │  • iCloud CloudKit (metadata)               │ │
│  │  • iCloud Drive (raw .md files)             │ │
│  │  • Conflict resolution (timestamp + CRDT)   │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

---

## Data Model (SwiftData)

```swift
// MARK: - Core Models

@Model
final class Note {
  @Attribute(.unique) var id: UUID
  var title: String
  var filePath: String          // Relative to vault root
  var content: String           // Raw Markdown (cached, source of truth is .md file)
  var createdAt: Date
  var modifiedAt: Date
  var wordCount: Int
  var characterCount: Int

  // Relationships
  var tags: [Tag]
  @Relationship(inverse: \NoteLink.source) var outgoingLinks: [NoteLink]
  @Relationship(inverse: \NoteLink.target) var incomingLinks: [NoteLink]
  var vault: Vault?

  // Computed
  var backlinks: [NoteLink] { incomingLinks }
  var fileName: String { URL(fileURLWithPath: filePath).lastPathComponent }
  var stem: String { URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent }
}

@Model
final class NoteLink {
  @Attribute(.unique) var id: UUID
  var source: Note?             // The note containing the link
  var target: Note?             // The note being linked to
  var targetSlug: String        // Raw [[link text]] for unresolved links
  var context: String           // Surrounding text for backlink preview
  var lineNumber: Int           // Line in source where link appears
  var createdAt: Date
}

@Model
final class Tag {
  @Attribute(.unique) var name: String
  var notes: [Note]
  var color: String?            // Optional user-assigned color

  var count: Int { notes.count }
}

@Model
final class Vault {
  @Attribute(.unique) var id: UUID
  var name: String
  var rootPath: String          // Absolute path to vault folder
  var createdAt: Date
  var notes: [Note]

  // Settings
  var defaultNewNoteFolder: String?
  var attachmentFolder: String?
  var dailyNoteFormat: String   // e.g. "yyyy-MM-dd"
}

@Model
final class Bookmark {
  @Attribute(.unique) var id: UUID
  var note: Note?
  var label: String?
  var sortOrder: Int
  var createdAt: Date
}
```

---

## File Format & Storage

### Vault Structure
```
~/Documents/Bunch/My Vault/
├── .bunch/                     # Hidden config folder
│   ├── config.json             # Vault settings
│   ├── appearance.json         # Theme, font, layout prefs
│   └── plugins/                # Plugin configs
├── Daily Notes/
│   ├── 2026-02-05.md
│   └── 2026-02-04.md
├── Projects/
│   ├── Bunch App.md
│   └── Dockhand.md
├── Ideas/
│   └── Knowledge Graph Ideas.md
├── Templates/
│   └── Daily Note.md
└── Attachments/
    ├── screenshot-2026-02-05.png
    └── diagram.pdf
```

### Markdown Extensions
Standard Markdown plus:
```markdown
# Note Title

Regular paragraph with a [[Bidirectional Link]] to another note.
Also supports [[Note Title|custom display text]] aliases.

Tags work inline: #project #idea #swift

Block references: ![[Another Note#Section Heading]]

Embeds: ![[diagram.pdf]]

---
bunch-id: 550e8400-e29b-41d4-a716-446655440000
tags: [project, swift, knowledge]
created: 2026-02-05T10:30:00Z
---
```

### YAML Frontmatter
Optional but supported. Bunch reads/writes frontmatter for:
- Custom metadata fields
- Tag declarations
- Aliases (alternative names for linking)
- `cssclass` for custom styling

---

## Core Features

### Phase 1 — Foundation (MVP)
The absolute minimum to be useful as a daily driver.

#### 1.1 Vault Management
- Open folder as vault (any folder of `.md` files)
- Create new vault from scratch
- Switch between multiple vaults
- Recent vaults in File menu

#### 1.2 File Tree Sidebar
- Hierarchical file/folder browser
- Create, rename, delete, move notes and folders
- Drag and drop reordering
- File icons by type (note, image, PDF, etc.)
- Folder collapse/expand state persisted
- Sort: name, modified, created

#### 1.3 Markdown Editor (TextKit 2)
- Custom `NSTextContentStorage` + `NSTextLayoutManager`
- Live syntax highlighting (headings, bold, italic, code, links)
- `[[wiki-link]]` detection with autocomplete popup
- `#tag` detection and highlighting
- Inline image preview (toggle)
- Code block syntax highlighting (TreeSitter or basic regex)
- Vim-like keyboard shortcuts (optional)
- Typewriter scrolling mode
- Focus mode (dim non-active paragraphs)

#### 1.4 Bidirectional Links
- `[[Note Title]]` creates a link to another note
- `[[Note Title|Display Text]]` for aliases
- Autocomplete dropdown as you type `[[`
  - Fuzzy search across all note titles
  - Shows folder path for disambiguation
  - Create new note inline if no match
- Backlinks panel in inspector
  - Shows all notes linking TO this note
  - Includes surrounding context (±2 lines)
- Unresolved links highlighted differently (create on click)

#### 1.5 Search
- Full-text search across all notes (indexed)
- Search-as-you-type with ranked results
- Search within current note (⌘F)
- Highlight matches in results with context
- Filter by: tag, folder, date range, has-links

#### 1.6 Tags
- Inline `#tag` parsed from content
- Tag browser in sidebar (with note counts)
- Click tag to filter/search
- Multi-tag filtering (AND/OR)
- Tag autocomplete as you type `#`
- Nested tags: `#project/bunch` hierarchy

---

### Phase 2 — Power Features

#### 2.1 Graph View
- Force-directed graph of all notes and their links
- Nodes = notes, edges = links
- Node size by link count (more connected = larger)
- Color by folder, tag, or age
- Click node to open note
- Hover to preview
- Zoom, pan, drag nodes
- Filter graph by tag, folder, or depth
- Local graph: show only neighbors of current note
- Implementation: SpriteKit scene with SKShapeNode + SKPhysicsBody
  - Or Metal compute shader for 10k+ nodes

#### 2.2 Daily Notes
- Auto-create today's note on demand (⌘D)
- Configurable template
- Date-based file naming (customizable format)
- Calendar picker in sidebar
- Navigate previous/next day
- "On this day" — what you wrote a year ago

#### 2.3 Templates
- Template folder with `.md` templates
- Variables: `{{date}}`, `{{title}}`, `{{time}}`, `{{vault}}`
- Apply template when creating new note
- Template picker modal

#### 2.4 Split Editor
- Horizontal and vertical splits
- Edit two notes side by side
- Link from one, see backlinks update in other
- Tabs within each split (like Xcode)
- Tab groups

#### 2.5 Command Palette
- ⌘⇧P to open (like VS Code / Obsidian)
- Fuzzy search all commands
- Recent commands
- Custom keybinding support
- Quick note switcher (⌘O)

#### 2.6 Block References & Embeds
- `![[Note Title]]` — Embed full note content
- `![[Note Title#Heading]]` — Embed specific section
- `![[image.png]]` — Inline image
- Block IDs: `^block-id` at end of paragraph
- Reference blocks: `![[Note#^block-id]]`

---

### Phase 3 — Platform Integration

#### 3.1 Spotlight Integration
- Index all note titles and content via `CSSearchableIndex`
- Search notes from macOS Spotlight
- Open directly into Bunch from Spotlight result

#### 3.2 Shortcuts & Automation
- App Intents for Shortcuts:
  - Create note (title, content, folder, tags)
  - Search notes (query → results)
  - Get daily note
  - Append to note
  - Get backlinks for note
- URL scheme: `bunch://open?vault=MyVault&note=Note%20Title`

#### 3.3 Quick Note Integration
- Share Extension for Safari, other apps
- "Save to Bunch" from share sheet
- Clip web content as Markdown
- Quick capture window (global hotkey)
  - Floating window, always accessible
  - Type and save to inbox folder
  - Auto-link detection

#### 3.4 Widgets
- Recent notes widget (small, medium)
- Daily note widget (medium, large)
- Random note / "resurface" widget
- Graph stats widget (note count, link count)

#### 3.5 Menu Bar Quick Capture
- Menu bar icon for instant capture
- Type → Enter → saved to vault inbox
- Recent notes list
- Quick search

---

### Phase 4 — Advanced

#### 4.1 Canvas / Whiteboard
- Infinite canvas with note cards
- Drag notes onto canvas
- Draw connections between cards
- Freeform text, shapes, colors
- Group cards into clusters
- Export canvas as image

#### 4.2 Version History
- Git-based version history (optional, if vault is a git repo)
- Or built-in snapshot system (periodic .bunch/snapshots/)
- Diff view between versions
- Restore previous version

#### 4.3 Publish
- Export note/folder as static site
- Built-in themes (wiki, blog, docs)
- Publish to GitHub Pages with one click
- Custom domain support

#### 4.4 Plugin System (Stretch)
- Swift-based plugin API
- Plugins can:
  - Add sidebar panels
  - Register commands
  - Transform Markdown (custom syntax)
  - Add export formats
- Plugin manifest (JSON + Swift package)
- Plugin marketplace (future)

#### 4.5 AI Features (Stretch)
- Local LLM integration (MLX on Apple Silicon)
- Summarize note
- Suggest links ("This note might connect to...")
- Auto-tag based on content
- Semantic search (embeddings-based)
- Chat with your vault

---

## UI Layout

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ◉ ◉ ◉   Bunch — My Vault                          🔍  ⚙️  ├─│─┤  ⤢   │
├──────────┬───────────────────────────────────────────┬───────────────────┤
│ SIDEBAR  │ EDITOR                                    │ INSPECTOR         │
│          │                                           │                   │
│ 📋 Notes │ Daily Notes / 2026-02-05.md        [⌄][×] │ BACKLINKS (3)     │
│ 🔍 Search│                                           │                   │
│ 🏷️ Tags  │ # February 5, 2026                        │ ┌───────────────┐ │
│ 🕸️ Graph │                                           │ │ Bunch App.md  │ │
│ 📅 Daily │ ## Morning                                │ │ "...working on │ │
│ ⭐ Starred│                                           │ │  [[2026-02-05]]│ │
│          │ Started working on the [[Graph View]]     │ │  today..."     │ │
│ ▾ Notes  │ for [[Bunch App]]. Need to figure out     │ └───────────────┘ │
│   ▾ Proj │ force-directed layout performance.        │ ┌───────────────┐ │
│     Bunch│                                           │ │ Graph View.md │ │
│     Dock │ Ideas from #research:                     │ │ "implemented   │ │
│   ▾ Daily│ - SpriteKit physics bodies                │ │  in [[2026-02- │ │
│     02-05│ - Metal compute shaders                   │ │  05]] session" │ │
│     02-04│ - Barnes-Hut approximation                │ └───────────────┘ │
│   ▾ Ideas│                                           │                   │
│     Graph│ ![[architecture-sketch.png]]              │ TAGS              │
│          │                                           │ #research #swift  │
│ ─────────│ ## Afternoon                              │ #bunch            │
│ 🏷️ TAGS  │                                           │                   │
│  swift (8)│ Connected the [[Link Parser]] to the     │ TABLE OF CONTENTS │
│  idea (5)│ indexing pipeline. Performance looks       │ • Morning         │
│  bunch(3)│ good — 10k notes indexed in 0.3s.        │ • Afternoon       │
│          │                                           │ • Links           │
│          │ ## Links                                  │                   │
│          │ - [[Graph View]]                          │ STATS             │
│          │ - [[Link Parser]]                         │ Words: 142        │
│          │ - [[Bunch App]]                           │ Links: 4          │
│          │                                           │ Backlinks: 3      │
│          │                                           │ Created: 10:30am  │
│          │                                           │ Modified: 2:15pm  │
└──────────┴───────────────────────────────────────────┴───────────────────┘
```

---

## Key Services

### VaultService
```swift
@Observable
@MainActor
final class VaultService {
  var currentVault: Vault?
  var notes: [Note] = []
  var isIndexing = false

  // File operations
  func openVault(at url: URL) async throws
  func createNote(title: String, in folder: String?, template: Template?) async throws -> Note
  func saveNote(_ note: Note) async throws
  func deleteNote(_ note: Note) async throws
  func moveNote(_ note: Note, to folder: String) async throws
  func renameNote(_ note: Note, to newTitle: String) async throws

  // Indexing
  func reindexVault() async throws     // Full reindex
  func indexNote(_ note: Note) async    // Single note (on save)

  // File watching
  func startWatching() async            // FSEvents stream
  func stopWatching()
}
```

### LinkService
```swift
@Observable
@MainActor
final class LinkService {
  // Parsing
  func extractLinks(from content: String) -> [ParsedLink]
  func extractTags(from content: String) -> [String]

  // Resolution
  func resolveLink(_ slug: String, in vault: Vault) -> Note?
  func unresolvedLinks(in vault: Vault) -> [String]

  // Backlinks
  func backlinks(for note: Note) -> [NoteLink]

  // Graph
  func buildGraph(for vault: Vault) -> NoteGraph
  func localGraph(for note: Note, depth: Int) -> NoteGraph
}
```

### SearchService
```swift
@Observable
@MainActor
final class SearchService {
  func search(query: String, in vault: Vault) async -> [SearchResult]
  func searchByTag(_ tag: String, in vault: Vault) -> [Note]
  func searchByDateRange(_ range: ClosedRange<Date>, in vault: Vault) -> [Note]
  func rebuildSearchIndex(for vault: Vault) async

  // Quick switcher
  func fuzzyMatch(query: String, candidates: [Note]) -> [Note]
}
```

### SyncService
```swift
@Observable
@MainActor
final class SyncService {
  var syncStatus: SyncStatus = .idle

  func enableSync(for vault: Vault) async throws
  func sync() async throws
  func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) async throws
}

enum SyncStatus {
  case idle, syncing(progress: Double), error(Error), upToDate
}
```

---

## Editor Architecture (TextKit 2)

The editor is the heart of Bunch. We use TextKit 2 for full control.

```
NSTextView (AppKit, wrapped in NSViewRepresentable)
    │
    ├── NSTextContentStorage
    │     └── Backing store: String (raw Markdown)
    │
    ├── NSTextLayoutManager
    │     └── Custom NSTextLayoutFragment for:
    │           • Heading sizes (H1-H6)
    │           • Code blocks (monospace + background)
    │           • Block quotes (left border + indent)
    │           • Horizontal rules
    │
    ├── Syntax Highlighting (NSTextContentManager delegate)
    │     └── Regex-based attribute application:
    │           • **bold** → NSFont.bold
    │           • *italic* → NSFont.italic
    │           • `code` → monospace + background
    │           • [[links]] → blue + underline + clickable
    │           • #tags → teal + clickable
    │           • [urls](http://...) → blue + underline
    │
    └── Autocomplete Controller
          ├── [[ trigger → Note title fuzzy search popup
          ├── # trigger → Tag autocomplete popup
          └── / trigger → Slash commands (future)
```

---

## Graph Visualization (SpriteKit)

```swift
struct NoteGraph {
  var nodes: [GraphNode]
  var edges: [GraphEdge]
}

struct GraphNode: Identifiable {
  let id: UUID
  let noteID: UUID
  let title: String
  let linkCount: Int
  var position: CGPoint
  var velocity: CGPoint = .zero
}

struct GraphEdge: Identifiable {
  let id: UUID
  let sourceID: UUID
  let targetID: UUID
}

// Force-directed layout using SpriteKit physics
class GraphScene: SKScene {
  // Each node = SKShapeNode with SKPhysicsBody
  // Each edge = SKShapeNode line (updated each frame)
  // Forces:
  //   - Repulsion between all nodes (charge)
  //   - Attraction along edges (spring)
  //   - Center gravity (prevents drift)
  //   - Damping (stabilization)

  func layoutGraph(_ graph: NoteGraph) { ... }
  func handleNodeTap(_ node: GraphNode) { ... }    // Open note
  func handleNodeHover(_ node: GraphNode) { ... }  // Preview
}
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New note |
| ⌘⇧N | New note in current folder |
| ⌘O | Quick note switcher |
| ⌘⇧P | Command palette |
| ⌘D | Open/create daily note |
| ⌘F | Search in note |
| ⌘⇧F | Search in vault |
| ⌘[ | Navigate back |
| ⌘] | Navigate forward |
| ⌘\ | Toggle sidebar |
| ⌘⇧\ | Toggle inspector |
| ⌘⇧G | Toggle graph view |
| ⌘⇧E | Toggle editor/preview |
| ⌘K | Insert link |
| ⌘⇧L | Toggle checkbox |
| ⌥⌘←/→ | Previous/next daily note |

---

## Implementation Phases & Timeline

### Phase 1 — MVP (Weeks 1–6)
**Goal:** Usable daily driver for personal notes.

- **Week 1–2:** Project setup, data model, VaultService (open folder, read .md files, FSEvents watcher)
- **Week 2–3:** TextKit 2 Markdown editor (syntax highlighting, basic editing)
- **Week 3–4:** `[[wiki-link]]` parsing, autocomplete, link resolution, backlinks panel
- **Week 4–5:** File tree sidebar, search (full-text), tag parsing
- **Week 5–6:** Inspector panel (backlinks, tags, TOC), keyboard shortcuts, polish

**Deliverable:** App that can open a folder of Markdown files, edit them with syntax highlighting, create/follow `[[links]]`, see backlinks, search, and browse tags.

### Phase 2 — Power Features (Weeks 7–12)
- **Week 7–8:** Graph view (SpriteKit force-directed layout)
- **Week 8–9:** Daily notes, templates, command palette
- **Week 9–10:** Split editor, tabs, tab groups
- **Week 10–11:** Block references, embeds, inline image preview
- **Week 11–12:** Settings UI, themes (light/dark/custom), font options, polish

### Phase 3 — Platform (Weeks 13–16)
- **Week 13:** Spotlight indexing, App Intents / Shortcuts
- **Week 14:** Share Extension, Quick Capture window
- **Week 15:** Widgets, Menu Bar quick capture
- **Week 16:** iCloud sync (CloudKit + iCloud Drive)

### Phase 4 — Advanced (Weeks 17+)
- Canvas / whiteboard view
- Version history (git integration)
- Publish to static site
- Plugin system (Swift-based)
- AI features (MLX local LLM)

---

## Dependencies (Swift Packages)

```swift
// Package.swift dependencies
dependencies: [
  // Markdown parsing
  .package(url: "https://github.com/apple/swift-markdown.git", from: "0.4.0"),

  // Collections utilities
  .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),

  // Syntax highlighting for code blocks
  .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.53.0"),

  // YAML frontmatter parsing
  .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),

  // Fuzzy string matching (for quick switcher)
  .package(url: "https://github.com/khoi/fuzzy-swift.git", from: "0.1.0"),
]
```

---

## Competitive Advantages over Obsidian

1. **Performance** — Native binary, ~30MB RAM vs 200MB+ Electron
2. **Battery** — No Chromium runtime burning cycles
3. **System integration** — Spotlight, Shortcuts, Widgets, Share Extensions, Quick Note
4. **Typography** — TextKit 2 renders text beautifully, native font rendering
5. **Privacy** — Local-first, no account required, iCloud sync (Apple handles encryption)
6. **File access** — No Electron sandboxing quirks, proper macOS file integration
7. **Instant launch** — Sub-second cold start vs multi-second Electron boot

---

## Open Questions
- [ ] iOS/iPadOS companion app? (Phase 5, share SwiftData model + iCloud sync)
- [ ] Pricing model? (Free core + paid sync/publish, or one-time purchase?)
- [ ] Should we support Obsidian vault format 1:1 for migration?
- [ ] Community plugins in Swift vs scripting language (Lua? JS via JavaScriptCore?)
- [ ] Collaboration features? (SharedWithYou framework, real-time CRDT editing?)
