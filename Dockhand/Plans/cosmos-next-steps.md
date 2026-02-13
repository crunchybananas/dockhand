# Cosmos — Next Steps

> Captured Feb 13, 2026 after Phase 5 + architecture refactor session.

---

## Known Issues

### 1. Galaxy "Box" Artifact
**Problem:** Galaxies render inside a visible rectangular boundary — you can see sharp edges where particles cut off.
**Root cause:** Each galaxy generates a fixed `starCount` of particles spread over a bounded area. The particle cloud doesn't feather at the edges, creating hard cut-offs. Also the instanced particle quad renders with abrupt alpha at the glow boundary.
**Fix:** Add a radial fade-out to particle alpha based on distance from galaxy center. Increase the outer particle spread slightly and reduce alpha near the edge of the distribution. Consider adding a soft-disc underlay glow behind each galaxy.

### 2. Galaxy Resolution — Low Star Density
**Problem:** Galaxies look sparse / low-res when viewed up close. Individual particles are visible as dots rather than a dense luminous structure.
**Root cause:** `starCount` per galaxy is modest (~100–300 particles). At close zoom, you see each one as an isolated point. The bloom helps but can't fill the gaps.
**Fix:**
- Scale `starCount` by zoom level — add more particles as you zoom into a galaxy.
- Add a procedural luminosity texture (fullscreen shader pass) under the particle layer for the galaxy's diffuse glow / dust lanes.
- Consider a dedicated galaxy shader that renders a proper spiral/elliptical with fbm noise, replacing the pure-particle approach at close zoom.

### 3. Planet Selection UX
**Problem:** Clicking planets works but is undiscoverable. If you zoom past system view without clicking, you get a random planet based on position hash.
**Fix:** Add a planet picker overlay when approaching system-to-surface boundary — a small ring menu or sidebar listing the system's planets with type icons, letting you choose before descent.

### 4. Surface Exit — No Way Back
**Problem:** Once on a surface at zoom ≥ 5M, scroll changes speed. The only way out is Alt+scroll, which is undiscoverable.
**Fix:** Add a visible "Return to Orbit" button in the surface HUD. Also consider Escape key as a quick-zoom-out. Show "Alt+Scroll to zoom out" hint in the controls bar.

---

## Visual Quality

### 5. Galaxy Shader Pass
Replace the particle-only galaxy rendering with a hybrid approach:
- **Background layer:** A fullscreen shader that draws a procedural spiral/elliptical structure with fbm noise, dust lanes, and color gradients. Driven by galaxy seed, type, arm count, rotation.
- **Foreground layer:** Bright star particles on top for sparkle.
- This keeps galaxies looking dense and beautiful at any zoom level.

### 6. Nebula Improvements
- More variety in nebula colors and shapes.
- Nebulae should feel like distinct objects (pillars, clouds, rings) not just tinted fog.
- Consider raymarched volumetric nebula pass for nearby nebulae at star scale.

### 7. Star Variety
- Different star types should look visually distinct beyond color (size, corona, flares).
- Binary/multiple star systems.
- Pulsars, white dwarfs, red giants with visual differences.

### 8. Planet Sphere Improvements
- The planet sphere shader could show terrain features (continents, ice caps) from orbit.
- Cloud layer overlay.
- Ring rendering improvements (translucent, shadowed).

---

## UX & Controls

### 9. Controls Reference Overlay
- Press `?` or `H` to toggle a translucent controls reference card.
- Shows all keybindings per mode (space vs surface).
- Currently controls are only mentioned in tiny bottom text.

### 10. Smooth Zoom-to-Surface Transition
- The jump from system view (orbiting planets) to surface (first-person terrain) is abrupt.
- Add an atmospheric entry animation: camera descends toward the planet sphere, atmosphere thickens, transitions to terrain view.
- Tie into the existing atmosphere shader more smoothly.

### 11. Minimap
- Small inset showing your position in the parent scale (galaxy position when viewing stars, system position when on a planet).

### 12. Object Info Panel Expansion
- Clicking a galaxy/star/planet should show richer details (mass, composition, habitability score, etc.).
- Expand the existing info panel with tabs or expandable sections.

---

## Architecture

### 13. Shader Module Extraction
`cosmos-engine.ts` is 1700+ lines with 11 GLSL shaders inlined as template strings.
- Extract each shader to its own `.glsl` file (or `.ts` containing the source string).
- Create a `shaders/` directory: `background.frag.ts`, `particle.vert.ts`, `terrain.frag.ts`, etc.
- Engine imports and compiles them.

### 14. Renderer Decomposition
`app.gts` at ~1150 lines handles input, camera, rendering dispatch, and HUD.
- Extract `renderGalaxiesWebGL()` + `addGalaxyParticles()` → `galaxy-renderer.ts`
- Extract `renderStarsWebGL()` → `star-renderer.ts`
- Extract `renderSystemWebGL()` → `system-renderer.ts`
- Extract `renderSurfaceWebGL()` → `surface-renderer.ts`
- Each renderer gets the engine, particles, overlay context, and camera as dependencies.
- `app.gts` becomes a thin coordinator.

### 15. Scale State Machine
Replace the zoom-threshold if/else chain with a proper state machine:
- States: `cosmic`, `galaxy`, `sector`, `system`, `atmosphere`, `surface`
- Transitions have entry/exit hooks (e.g., "entering surface → reset camera controller")
- Each state owns its renderer, input mode, and HUD configuration.

---

## Performance

### 16. LOD (Level of Detail) for Particles
- At wide zoom, use fewer but larger particles per galaxy.
- At close zoom, add more particles.
- Frustum culling — skip off-screen galaxies/stars entirely.

### 17. Spatial Index
- Replace the grid-iteration approach with a quadtree or spatial hash.
- Dramatically reduces the number of objects checked per frame at high zoom.

### 18. Terrain Shader Optimization
- The raymarcher runs 200 steps per pixel. At 4K resolution that's ~16M march steps per frame.
- Consider adaptive step count based on distance, early termination, and half-res rendering with upscale.

---

## Stretch Goals

### 19. Multiplayer Presence
- See other explorers as dots on the map (via simple WebSocket).
- Share location in real-time.

### 20. Procedural Audio per Planet
- Different ambient soundscapes per biome (wind on desert, waves on ocean, volcanic rumbles on lava).
- Currently the soundscape only varies by zoom level, not by planet type.

### 21. Screenshot / Journal
- Capture the current view as an image.
- Save to a journal with notes and coordinates.
- Share as a Shipyard post.

### 22. Deep Space Objects
- Black holes with gravitational lensing shader.
- Quasars, magnetars, neutron stars.
- Asteroid belts between planets.

---

## Priority Order for Next Session

1. **Galaxy box fix** (#1) — most visible visual bug
2. **Galaxy shader pass** (#5) — makes galaxies look spectacular
3. **Controls overlay** (#9) — UX is undiscoverable
4. **Surface exit button** (#4) — users get stuck
5. **Planet picker** (#3) — better planet variety access
6. **Shader extraction** (#13) — engine.ts is becoming unwieldy
7. **Renderer decomposition** (#14) — app.gts is too large
