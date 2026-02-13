# Mega Ship Plan - AI-Powered Proof Analysis Suite + WebGL Game

## Overview
Six new ships for Shipyard that leverage the unique attestation/proof system, plus a WebGL first-person shooter inspired by Marathon. Ember-first approach (Ember is the cornerstone), with vanilla ports where practical.

---

## Ship 1: Chronicle - AI Work Journal
**Category:** ⚓ Shipyard Tools  
**Concept:** Agents build narratives from attestation chains. Upload proofs, get story.

### Features
- Paste/select multiple attestations (URLs, screenshots, commits)
- Agent analyzes proof progression
- Generates "what I shipped" summaries
- Creates portfolio-ready case studies
- Identifies patterns ("You ship most on Thursdays")
- Export as markdown or share link

### Technical
- Uses proof type detection from URLs (GitHub, screenshot, demo)
- Simulated AI analysis (heuristic + prompts for LLM integration)
- Timeline visualization
- Local storage for proof collections

### UI Sections
1. **Proof Import** - Add URLs, paste screenshots, connect GitHub
2. **Timeline View** - Visual proof chain
3. **Story Generator** - AI-generated narrative
4. **Insights Panel** - Patterns and stats
5. **Export** - Markdown, JSON, shareable link

---

## Ship 2: Proof Composer - Chain Proofs into Stories
**Category:** ⚓ Shipyard Tools  
**Concept:** Visual timeline builder for crafting narratives from proofs.

### Features
- Drag-and-drop proof arrangement
- AI suggests connections between proofs
- Multiple narrative templates (case study, retro, demo script)
- Rich text annotations
- Preview and export

### UI Sections
1. **Proof Library** - All imported proofs
2. **Canvas** - Drag/arrange proofs
3. **Story Panel** - Live narrative generation
4. **Templates** - Case study, retrospective, pitch deck
5. **Export** - PDF, markdown, slideshow

---

## Ship 3: Ship Forecast - Predictive Project Health
**Category:** ⚓ Shipyard Tools  
**Concept:** Agents analyze proof velocity to predict completion.

### Features
- Track proof submission cadence
- Predict ship completion date
- Flag stalled projects (no proofs in X days)
- Compare to similar ships
- Burndown-style visualization

### UI Sections
1. **Ship Selector** - Pick active ships
2. **Velocity Chart** - Proof submission over time
3. **Prediction Panel** - "Likely ships in 2 weeks"
4. **Health Alerts** - Stalled, at-risk flags
5. **Comparison** - Similar ship benchmarks

---

## Ship 4: Challenge Arena - Community Proof Challenges
**Category:** ⚓ Shipyard Tools  
**Concept:** Weekly challenges where agents verify completion via proofs.

### Features
- Browse active challenges ("Build with WebGL", "Open source contribution")
- Submit proof for challenge
- Agent verifies proof matches criteria
- Leaderboards and streaks
- Challenge creation (for verified users)

### UI Sections
1. **Active Challenges** - Current week's challenges
2. **Submit Proof** - Upload for verification
3. **Leaderboard** - Points, streaks, badges
4. **Archive** - Past challenges
5. **Create** - Propose new challenges

---

## Ship 5: Proof Insights - Personal Analytics Dashboard
**Category:** ⚓ Shipyard Tools  
**Concept:** Deep analysis of your proof patterns.

### Features
- Work style insights (visual vs code-heavy, solo vs collaborative)
- Skill graph from attestation types
- "You've proven expertise in: React, CLI tools, Game Dev"
- Comparison to community averages
- Exportable proof portfolio

### UI Sections
1. **Overview** - Key stats at a glance
2. **Skills Graph** - Spider/radar chart
3. **Work Patterns** - Day/time heatmap
4. **Proof Types** - Breakdown by type
5. **Portfolio** - Shareable skill summary

---

## Ship 6: Orbital Strike - WebGL FPS
**Category:** 🎮 Games  
**Concept:** Marathon/Bungie-inspired corridor shooter with sci-fi aesthetic.

### Features
- First-person WebGL gameplay
- Procedural space station corridors
- Classic Bungie-style weapons (pistol, shotgun, AR)
- Enemy AI (drones, bots)
- Ammo/health pickups
- Terminal story snippets (Marathon-style lore)
- Keyboard + mouse controls

### Technical
- Three.js for WebGL rendering
- Raycasting for collision/shooting
- Procedural level generation
- Retro sci-fi aesthetic (dark corridors, glowing terminals)
- Sound effects via Web Audio API

### UI Sections
1. **Main Menu** - New game, controls, settings
2. **HUD** - Health, ammo, radar
3. **Terminal** - Story snippets when found
4. **Pause Menu** - Resume, settings, quit

---

## Implementation Strategy

### Why Ember First?
1. Component architecture maps cleanly to features
2. Services for shared state (proofs, user data)
3. Better TypeScript support with Glint
4. Testing infrastructure built-in
5. Routing for multi-view apps

### Vanilla Approach
- For simpler tools: direct port with similar structure
- For complex tools (Chronicle, Forecast): may skip vanilla
- For games: vanilla might actually be easier (less framework overhead)

### Build Order
1. **Proof Insights** - Simplest, good foundation for proof analysis
2. **Chronicle** - Builds on proof analysis
3. **Proof Composer** - Visual builder, moderate complexity
4. **Ship Forecast** - Prediction logic
5. **Challenge Arena** - Community features, more complex
6. **Orbital Strike** - Standalone WebGL game

---

## Shared Services (Ember)

```typescript
// services/proof-analyzer.ts
export default class ProofAnalyzerService extends Service {
  detectProofType(url: string): 'github' | 'screenshot' | 'demo' | 'url' | 'unknown'
  extractMetadata(url: string): ProofMetadata
  analyzeProofChain(proofs: Proof[]): ChainAnalysis
  generateNarrative(proofs: Proof[], template: string): string
}

// services/proof-store.ts  
export default class ProofStoreService extends Service {
  @tracked proofs: Proof[] = []
  addProof(url: string): void
  removeProof(id: string): void
  loadFromStorage(): void
  saveToStorage(): void
}
```

---

## File Structure

```
apps/
  chronicle/           # Ember app
  proof-composer/      # Ember app
  ship-forecast/       # Ember app
  challenge-arena/     # Ember app
  proof-insights/      # Ember app
  orbital-strike/      # Ember app (WebGL game)

docs/
  chronicle/           # Vanilla (if built)
  proof-composer/      # Vanilla (if built)
  ship-forecast/       # Vanilla (if built)
  challenge-arena/     # Vanilla (if built)
  proof-insights/      # Vanilla
  orbital-strike/      # Vanilla (likely easier for game)
  ember/
    chronicle/         # Ember build output
    proof-composer/
    ship-forecast/
    challenge-arena/
    proof-insights/
    orbital-strike/
```

---

## Nav Updates (docs/index.html)

Add to Shipyard section:
- Chronicle
- Proof Composer
- Ship Forecast
- Challenge Arena
- Proof Insights

Add to Games section:
- Orbital Strike (with WebGL badge)

---

## Estimated Effort

| Ship | Ember | Vanilla | Notes |
|------|-------|---------|-------|
| Proof Insights | 2-3 hrs | 1-2 hrs | Charts, analytics |
| Chronicle | 3-4 hrs | Skip | Complex AI narrative |
| Proof Composer | 3-4 hrs | Skip | Drag-drop canvas |
| Ship Forecast | 2-3 hrs | 1-2 hrs | Charts, predictions |
| Challenge Arena | 4-5 hrs | Skip | Community features |
| Orbital Strike | 6-8 hrs | 4-6 hrs | WebGL, Three.js |

**Total:** ~20-30 hours

---

## Let's Ship! 🚀

Starting with **Proof Insights** as the foundation, then building up.
