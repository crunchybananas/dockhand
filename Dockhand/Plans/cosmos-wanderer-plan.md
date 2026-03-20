# Cosmos: Galactic Wanderer & Native Graphics Plan

## 1. Galactic Wanderer — Persistent Multiplayer Exploration

### Core Concept
As explorers browse the universe, their **discoveries become permanent**. Each named star system, catalogued planet, or planted flag persists in a shared Firebase universe. Multiple explorers see each other's discoveries, creating a living galaxy map.

### Discovery Model
| Action | What gets stored | Visible to others |
|---|---|---|
| Visit a star system | Timestamp, explorer name | "Discovered by X" label |
| Name a planet | Custom name override | Shows custom name to all |
| Plant a flag on surface | GPS coords, message | Flag marker on surface |
| Chart a route | Waypoint list | Shared route overlay |
| Catalog a biome | Screenshot + metadata | Gallery entry |

### Firebase Architecture
```
cosmos-universe/
  discoveries/
    {regionHash}/
      {discoveryId}: {
        type: "star" | "planet" | "flag" | "route",
        explorerUid: string,
        explorerName: string,
        worldX: number,
        worldY: number,
        zoom: number,
        seed: number,
        customName?: string,
        message?: string,
        timestamp: Timestamp,
      }
  explorers/
    {uid}: {
      name: string,
      avatar: string,
      totalDiscoveries: number,
      firstSeen: Timestamp,
      lastPosition: { x, y, zoom },
    }
  live-positions/        # Realtime presence
    {uid}: { x, y, zoom, timestamp }
```

### Key Design Decisions
- **Region hashing**: Shard discoveries by spatial region (grid cell hash) so we only query nearby data
- **Seeded universe is canonical**: The procedural generation is deterministic — Firebase stores *annotations* on top, not the universe itself
- **Conflict resolution**: First discoverer wins for naming; flags can stack
- **Offline-first**: Cache discoveries in IndexedDB, sync when online
- **Rate limiting**: Firebase security rules limit writes per user per minute

### Implementation Phases
1. **Phase 1 — Solo discoveries**: Store your own discoveries locally (IndexedDB), display them on return visits
2. **Phase 2 — Firebase sync**: Connect to Firestore, upload/download discoveries for your region
3. **Phase 3 — Live presence**: Show other explorers' cursors on the galaxy map via Realtime Database
4. **Phase 4 — Social**: Discovery feed, leaderboard, shared routes, screenshots

### Integration Points in Dockhand
- Cosmos is a microtool hosted on GitHub Pages — Firebase JS SDK works directly
- Auth via Firebase Anonymous (upgrade to GitHub OAuth for persistent identity)
- The SwiftUI app could show a discovery feed via `ShipyardClient` if we add a `/discoveries` API

---

## 2. WebGL → Metal Translation

### What Translates Directly
| WebGL2 Concept | Metal Equivalent | Effort |
|---|---|---|
| Vertex/Fragment shaders (GLSL ES 3.0) | Metal Shading Language (MSL) | Medium — syntax differs but concepts map 1:1 |
| Instanced rendering | `drawIndexedPrimitives(instanceCount:)` | Direct |
| Framebuffer objects (FBO) | `MTLRenderPassDescriptor` with texture attachments | Direct |
| Bloom post-processing | Metal compute or fragment passes | Direct |
| Uniform buffers | `MTLBuffer` with `setVertexBuffer` | Direct |
| `texImage2D` / sampler | `MTLTexture` + `MTLSamplerState` | Direct |

### What Gets Better with Metal
- **Compute shaders**: Particle simulation, terrain generation, wave physics on GPU
- **Tile-based deferred rendering**: Perfect for bloom, atmosphere, fog passes
- **Mesh shaders / object shaders** (Apple GPU family 7+): Generate geometry on-GPU
- **MetalFX upscaling**: Render at lower res, AI-upscale to Retina
- **Raytracing**: Hardware-accelerated RT for reflections, shadows, ambient occlusion
- **Argument buffers**: Bindless resources for massive scene data
- **HDR / EDR**: Native P3 wide color + EDR for sun/star bloom exceeding 1.0

### Shader Translation Strategy
Our GLSL shaders are already well-structured in `shaders/`:
```
fullscreen.vert.ts  →  fullscreen.metal
background.frag.ts  →  background.metal
particle.vert.ts    →  particle.metal (combined vert+frag)
planet.frag.ts      →  planet.metal
terrain.frag.ts     →  terrain.metal
atmosphere.frag.ts  →  atmosphere.metal
galaxy-disc.frag.ts →  galaxy_disc.metal
nebula.frag.ts      →  nebula.metal
bloom-*.frag.ts     →  bloom.metal (compute pipeline)
```

### Recommended Architecture for Native
```
Dockhand/
  CosmosNative/
    Renderer/
      CosmosMetalRenderer.swift     // MTKViewDelegate
      ShaderTypes.h                 // Shared C struct definitions
      Shaders/
        terrain.metal
        planet.metal
        atmosphere.metal
        ...
    Engine/
      UniverseGenerator.swift       // Port from TS (seeded random, etc.)
      ParticleSystem.swift          // GPU-driven particle buffers
      CameraController.swift        // Shared with existing
    Views/
      CosmosMetalView.swift         // SwiftUI MTKView wrapper
```

### Incremental Approach
1. **Start with planet sphere** in Metal — port `planet.frag` to MSL, render a single planet with the new water shader in a `MTKView`
2. **Add terrain raymarching** — port `terrain.frag` with the Gerstner water
3. **Particle system** — instanced star/galaxy rendering
4. **Full scene** — bloom pipeline, atmosphere, nebula

### Key Advantage
Metal gives us **compute shaders** which WebGL2 lacks. This means:
- Wave simulation as a GPU compute pass (proper FFT ocean)
- Terrain heightmap pre-computation on GPU
- Particle physics (gravitational attraction, trail persistence)
- Real-time ambient occlusion via screen-space techniques

---

## 3. Water Effects Implemented (This Session)

### Planet Shader (Orbit View)
**Ocean planet type** — completely rewritten with:
- Multi-layer depth coloring (abyss → deep → mid → shallow → shoal)
- Animated Gerstner-style wave normals (4 wave trains)
- Subsurface scattering (light through wave crests near terminator)
- Schlick Fresnel reflection with sky color
- Multi-octave specular (sharp glint + soft path + wide sheen)
- Sun path glitter (sparkling micro-reflections)
- Foam/whitecaps on shallow wave peaks
- Polar ice caps with noisy edge breakup

**Earth-like planet** — upgraded oceans with:
- Depth-varying ocean color
- Fresnel sky reflection on water areas
- Specular highlights on ocean (land areas unaffected)

### Terrain Shader (Surface View)
**Water surface** — upgraded from basic noise waves to:
- 4-direction Gerstner wave trains (swell, cross-swell, wind chop, ripples)
- Beer's Law light absorption (red absorbed first, blue deepest)
- Visible seabed in shallow water
- Subsurface scattering with seabed bounce
- Schlick Fresnel with proper IOR (1.33)
- Triple-octave specular (512-exp glint, 48-exp path, 8-exp sheen)
- Micro-glitter sparkles along sun reflection path
- Shore foam with dual-frequency patterns
- Open-water whitecaps on wave crests
- Voronoi-like caustic patterns on shallow seabed

---

## Priority Order

1. ✅ Water effects (planet + terrain shaders)
2. **CosmosNative Xcode project** — see setup below
3. Metal planet renderer (single sphere with water shader)
4. Solo discoveries (IndexedDB persistence in web version)
5. Metal terrain with water + camera controller
6. Firebase discovery sync
7. Full Metal scene port

---

## 4. CosmosNative — Xcode Project Setup

### Project Template
Use **macOS → App** (SwiftUI lifecycle) — same template as Dockhand.
- **Product Name:** CosmosWanderer
- **Team:** (your team)
- **Organization Identifier:** bot.shipyard
- **Interface:** SwiftUI
- **Language:** Swift
- **Storage:** None
- **Testing:** Include Tests
- **Location:** `/Users/cloken/code/CosmosNative`

Then add Metal support manually (no Game template needed — it brings baggage we don't want).

### Why Not the Game Template
The Xcode Game template creates a `GameViewController` with UIKit/AppKit patterns that fight SwiftUI. We want SwiftUI as the app shell (matching Dockhand's architecture) with an `MTKView` embedded via `NSViewRepresentable`. This gives us native macOS chrome (toolbar, sidebar, panels) wrapping the Metal viewport.

### Project Structure (Matching Dockhand Patterns)
```
CosmosNative/
  CosmosNativeApp.swift          // @main, WindowGroup, .environment()
  ContentView.swift               // Root view — Metal viewport + overlays
  Assets.xcassets/
  CosmosNative.entitlements

  Engine/
    CosmosRenderer.swift           // MTKViewDelegate — render loop
    ShaderTypes.h                  // Shared C structs (uniforms, vertex data)
    Shaders/
      Common.metal                 // Noise functions, shared utilities
      Planet.metal                 // Port of planet.frag (sphere + water)
      Terrain.metal                // Port of terrain.frag (raymarching)
      Atmosphere.metal             // Port of atmosphere.frag
      Background.metal             // Starfield background
      Bloom.metal                  // Compute-based bloom pipeline
      Water.metal                  // Dedicated water compute (FFT ocean later)

  Services/
    AppState.swift                 // @Observable central state (like Dockhand)
    UniverseGenerator.swift        // Port of universe-generator.ts
    CameraController.swift         // Port of camera-controller.ts
    InputManager.swift             // Keyboard/mouse/trackpad handling

  Views/
    MetalView.swift                // NSViewRepresentable wrapping MTKView
    HUDOverlay.swift               // SwiftUI overlay (compass, altitude, etc.)
    ControlsOverlay.swift          // Keybinding help card

CosmosNativeTests/
  CosmosNativeTests.swift
```

### Key Patterns from Dockhand to Follow
- `@Observable` + `@MainActor` for state (not ObservableObject)
- `@Environment` injection from App → Views
- `@State` for view-local state
- 2-space indentation, K&R braces
- Entitlements: `app-sandbox`, `network.client` (for Firebase later)

### Phase 1 — Metal Planet (First Session Target)
1. Create the Xcode project
2. `ShaderTypes.h` — define `PlanetUniforms` struct (color, lightDir, planetType, seed, time, resolution)
3. `Planet.metal` — translate `planet.frag.ts` GLSL → MSL (the enhanced water shader)
4. `Common.metal` — noise functions (hash31, noise3, fbm)
5. `CosmosRenderer.swift` — MTKViewDelegate with render pipeline for fullscreen quad
6. `MetalView.swift` — NSViewRepresentable hosting MTKView
7. `ContentView.swift` — MetalView filling the window
8. Result: spinning ocean planet with animated water, Fresnel, specular, foam

### GLSL → MSL Quick Reference
| GLSL ES 3.0 | Metal Shading Language |
|---|---|
| `in vec2 vUV` | `float2 vUV [[stage_in]]` via struct |
| `out vec4 fragColor` | `return float4(...)` (or `[[color(0)]]`) |
| `uniform float uTime` | `constant Uniforms& u [[buffer(0)]]` |
| `vec2/vec3/vec4` | `float2/float3/float4` |
| `mat2/mat3/mat4` | `float2x2/float3x3/float4x4` |
| `mix(a, b, t)` | `mix(a, b, t)` (same!) |
| `smoothstep` | `smoothstep` (same!) |
| `fract` | `fract` (same!) |
| `texture(sampler, uv)` | `tex.sample(samp, uv)` |
| `discard` | `discard_fragment()` |
| `gl_FragCoord` | `float4 pos [[position]]` in stage_in |
