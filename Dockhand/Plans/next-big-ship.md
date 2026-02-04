# Next Big Project - Brainstorm

**Goal:** Build something that makes people say "WOW, an AI made this?"

---

## Option 1: 🏝️ The Island (Myst-style Adventure)

**Concept:** A first-person puzzle adventure with hand-crafted SVG scenes. You wake up on a mysterious island and must solve interconnected puzzles to escape.

**Why it's achievable:**
- SVG scenes are just XML I can write directly
- State management in JS is straightforward  
- No real-time physics or complex rendering
- Puzzles are logic, which I'm good at

**Features:**
- 12-15 interconnected locations (SVG scenes with parallax layers)
- Atmospheric ambient sounds (Web Audio API)
- Inventory system with item combinations
- 4-5 multi-step puzzles that unlock each other
- Cryptic journal entries that hint at the story
- Smooth transitions between scenes (CSS/JS)
- Save/load game state (localStorage)

**Puzzles ideas:**
- Lighthouse lens alignment (rotate mirrors to direct light)
- Music box sequence (play notes in correct order from clues)
- Ancient mechanism with gears (drag to position)
- Star chart navigation (connect constellations)
- Final door with symbols from all previous puzzles

**Estimated scope:** 3-4 hours of focused building

**WOW factor:** 8/10 - Immersive, atmospheric, tells a story

---

## Option 2: 🎹 Synth Studio (Music Creation Tool)

**Concept:** A browser-based synthesizer with visual feedback, sequencer, and drum machine. Make actual music.

**Why it's achievable:**
- Web Audio API is well-documented
- Oscillators, filters, effects are built-in
- Canvas for waveform visualization
- Grid-based sequencer is just a 2D array

**Features:**
- Polyphonic synthesizer with keyboard input
- ADSR envelope controls
- Multiple waveforms (sine, square, saw, triangle)
- Filter with cutoff/resonance
- Delay and reverb effects
- 16-step sequencer with multiple tracks
- Drum machine with samples
- Real-time waveform/frequency visualization
- Export to WAV
- Preset sounds (bass, lead, pad, etc.)

**Estimated scope:** 2-3 hours

**WOW factor:** 9/10 - Sensory impact, people can actually make music

---

## Option 3: 🔗 FlowForge (Visual Programming Editor)

**Concept:** A node-based visual programming tool. Connect nodes to build data transformations, automations, or game logic - then execute it.

**Why it's achievable:**
- DOM-based nodes with absolute positioning
- SVG for connection lines (bezier curves)
- Execution is just traversing a graph
- Could target: JSON transformation, math, or simple game AI

**Features:**
- Drag-and-drop node palette
- Multiple node types (input, transform, output, logic)
- Bezier curve connections with automatic routing
- Real-time execution preview
- Zoom and pan canvas
- Save/load flows as JSON
- Built-in example flows
- Dark mode IDE aesthetic

**Use cases:**
- Data transformation (JSON in → transformed JSON out)
- Math/calculator flows
- Simple chatbot logic
- Game AI decision trees

**Estimated scope:** 3-4 hours

**WOW factor:** 8/10 - Technical flex, practical utility

---

## Option 4: 📖 Chronicle (Interactive Fiction Engine)

**Concept:** Both a playable story AND an editor to create your own. Like Twine but prettier and all in one tool.

**Why it's achievable:**
- Text-based, no graphics to generate
- Markdown parsing is simple
- State machine for story flow
- The authoring tool is forms + preview

**Features:**
- Play mode with beautiful typography
- Rich text with inline choices
- Variables and conditions (if player has key...)
- Inventory and stats
- Built-in demo story (30+ passages)
- Visual story map editor
- Export/import stories as JSON
- Typewriter text effect
- Ambient background music per scene
- Character portraits

**Estimated scope:** 2-3 hours

**WOW factor:** 7/10 - Creative tool, but less visual impact

---

## Option 5: 🌌 Cosmos (Procedural Universe)

**Concept:** An infinite procedural universe to explore. Zoom from galaxy clusters down to individual planets. No game mechanics, just exploration and wonder.

**Why it's achievable:**
- Procedural generation from seeds (deterministic)
- Canvas rendering at different scales
- No persistence needed (regenerate from seed)
- Math-heavy but no complex game logic

**Features:**
- Infinite zoom from universe → galaxy → star system → planet → surface
- Procedurally generated:
  - Galaxy shapes and colors
  - Star types (red dwarf, blue giant, etc.)
  - Planet types (gas giant, rocky, ice, etc.)
  - Terrain and atmosphere colors
  - Moon systems
- Naming algorithm for everything
- Bookmark locations
- Screenshot/share feature
- Ambient space music

**Estimated scope:** 3-4 hours

**WOW factor:** 9/10 - Infinite content, visually stunning

---

## My Recommendation

**For pure WOW: Synth Studio or Cosmos**
- Immediate sensory impact
- People can share what they create/discover
- Replay value

**For depth/story: The Island**
- More personal, memorable experience  
- Showcases puzzle design and narrative
- People will want to finish it

**For practical value: FlowForge**
- Actually useful tool
- Technical showcase
- Could integrate with agent workflows

---

## Decision Needed

Pick one (or suggest a mashup!) and I'll build it next session.

Which speaks to you?
