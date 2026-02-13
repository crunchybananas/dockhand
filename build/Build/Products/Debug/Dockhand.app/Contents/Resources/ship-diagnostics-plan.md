# Ship Diagnostics Studio - Local-First Log Explorer

## Overview
A local-first diagnostics studio for parsing and exploring log files. Users can upload JSON or JSONL logs, filter by level/service, search messages, and inspect details. No remote dependencies required for the demo.

---

## Goals
- Parse JSON arrays or JSONL logs locally.
- Provide fast filtering (level, service) and full-text search.
- Show a timeline-like list with rich detail pane.
- Export filtered logs as JSON.
- Ship with bundled sample fixtures for demo.

## Non-Goals (MVP)
- Live tailing via WebSocket.
- External integrations (Sentry, Datadog, etc.).
- Complex visualization (sparklines, charts).

---

## MVP Features
1. **Local Input**
   - File upload (JSON or JSONL).
   - Built-in sample datasets (2–3).

2. **Filtering**
   - Level filter: all/info/warn/error.
   - Service filter (auto-generated).
   - Search box (message + tags).

3. **Inspection**
   - List view with timestamp, level, service, and message.
   - Detail pane with full payload.

4. **Export**
   - Download filtered logs as JSON.

---

## UI Layout (MVP)
```
┌──────────────────────────────────────────────────────────────┐
│ ← All Tools   Ship Diagnostics Studio                         │
├──────────────────────────────────────────────────────────────┤
│ Filters                          │ Log Stream                │
│ • Dataset (Sample A/B/File)      │  • 12:01:03 ERROR auth ... │
│ • Level                          │  • 12:01:05 WARN  api  ... │
│ • Service                         │  • 12:01:08 INFO  ui   ... │
│ • Search                           │                             │
│ • Export                           │                             │
├──────────────────────────────────────────────────────────────┤
│ Detail                                                     │
│ • Timestamp / Level / Service                                │
│ • Message                                                    │
│ • Context JSON                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## Data Fixtures
- **Dockhand Boot**: startup sequence, config load, auth handshake.
- **API Incident**: rate limit spikes, retry storm, recovery.

---

## File Structure (Ember app)
```
apps/ship-diagnostics/
  app/
    components/ship-diagnostics/app.gts
    ship-diagnostics/init.ts
    ship-diagnostics/data/sample-logs.ts
    templates/index.gts
    styles/app.css
  config/
  index.html
  vite.config.mjs
```

---

## Build Order
1. App shell + static layout
2. Sample dataset rendering
3. Filters + search
4. Detail pane selection
5. File upload parsing
6. Export JSON
7. Style polish

---

## Demo Mode Defaults
- Preload “Dockhand Boot” dataset
- Auto-select first log entry
- Keep all logic local/offline
