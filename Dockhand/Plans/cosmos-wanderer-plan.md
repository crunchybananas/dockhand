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
2. Solo discoveries (IndexedDB persistence)
3. Metal planet prototype (single sphere in MTKView)
4. Firebase discovery sync
5. Metal terrain with water
6. Live explorer presence
7. Full Metal scene port
