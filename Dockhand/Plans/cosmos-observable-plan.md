# Cosmos → "The Observable"

**A 40-order-of-magnitude living universe you can rewind to the Big Bang.**

Cosmos is already an infinite deterministic universe at 6 scale levels. This plan transforms it into the most ambitious browser-based universe simulator ever built — seamless zoom from cosmic web to alien terrain, a time axis spanning 13.8 billion years, and a fully procedural soundscape.

---

## Current State (v1)
- **6 scale levels:** Universe → Cluster → Galaxy → Sector → System → Planet
- **Canvas 2D renderer** — tops out at ~800 particles per galaxy
- **Procedural generation:** SeededRandom (LCG), coordinate hashing, deterministic everything
- **Features:** Pan/zoom, bookmarks, URL deep-linking, click-to-focus, info panel
- **~1,400 lines** across 5 source files

## Target State (v2: The Observable)
- **9+ scale levels:** Cosmic Web → ... → Planet → Atmosphere → Surface → Terrain
- **WebGL renderer** — instanced rendering for 100,000+ particles, GLSL shaders for planets
- **Time dimension** — scrub bar from Big Bang (t=0) to present (t=1), stellar evolution
- **Cosmic soundscape** — procedural Web Audio synthesis tied to zoom level and location
- **Nebula particles, gravitational lensing, atmospheric scattering**
- **~5,000+ lines** estimated

---

## Build Phases

### Phase 1: WebGL Renderer Migration
**Goal:** Replace Canvas 2D with WebGL2 for galaxy/star rendering. Keep Canvas 2D as overlay for text/UI.

**Steps:**
1. Create `cosmos-engine.ts` — WebGL2 setup, shader compilation, FBO management
2. Write vertex/fragment shaders for:
   - Point sprites (stars, galaxy particles) with instanced rendering
   - Background gradient (fullscreen quad)
   - Star glow (additive blending, radial falloff)
3. Port `drawBackground()` → WebGL fullscreen quad shader
4. Port `renderGalaxies()` → instanced point sprites with per-instance color/size
5. Port `renderStars()` → instanced point sprites with glow
6. Port `renderSystem()` → keep Canvas 2D for now (planet detail needs it)
7. Port `drawStar()` / `drawPlanet()` to WebGL shaders
8. Add bloom post-processing pass (bright extraction → gaussian blur → composite)

**Commit milestone:** Galaxy view renders 100K+ particles at 60fps.

### Phase 2: Procedural Planet Surfaces ("The Landing")
**Goal:** Three new scale levels below Planet — zoom into atmosphere, land on terrain.

**Steps:**
1. Add scales to `universe-generator.ts`:
   - `ATMOSPHERE` (500K → 5M zoom) — atmospheric scattering
   - `SURFACE` (5M → 50M zoom) — continent/ocean/terrain overview
   - `TERRAIN` (50M → 500M zoom) — ground-level detail
2. Create `atmosphere-shader.glsl` — Rayleigh + Mie scattering model
   - Sky color derived from star temperature + planet atmosphere composition
   - Horizon gradient from black (space) to sky color as zoom increases
   - Sun position based on parent star's actual coordinates
3. Create `terrain-generator.ts`:
   - GPU fractal noise heightmap (4 octaves simplex)
   - Biome-appropriate coloring based on planet type:
     - Rocky: grey/brown ridges, craters
     - Earth-like: oceans, continents, forests (Voronoi), mountains
     - Desert: dunes (directional noise), canyons
     - Lava: cooled basalt, glowing lava rivers, volcanic peaks
     - Ice: glaciers, crevasses, frost patterns
     - Ocean: wave simulation, depth gradient
     - Gas giants: cloud bands, storm eyes (Great Red Spot analog)
   - Deterministic from planet seed
4. Implement smooth scale transitions — alpha crossfade between adjacent renderers
5. Click-to-land on planets from System view → smooth zoom to surface

**Commit milestone:** Seamless zoom from galaxy cluster to standing on terrain.

### Phase 3: Cosmic Soundscape
**Goal:** Procedural Web Audio synthesis that shifts continuously with zoom and location.

**Steps:**
1. Create `cosmic-soundscape.ts` service:
   - Lazy AudioContext init on first user interaction
   - Master gain + compressor output chain
   - Layer system: up to 4 concurrent audio layers, crossfaded by zoom
2. Define sound layers per scale:

   | Scale | Sound | Synthesis |
   |-------|-------|-----------|
   | Cosmic Web / Universe | Sub-bass hum | Brown noise → 20-40Hz bandpass |
   | Cluster | Harmonic resonance | 2 detuned sines, freq = hash(camera) |
   | Galaxy | Stellar wind | Pink noise + sweeping bandpass |
   | Sector | Interstellar medium | Filtered noise + subtle reverb |
   | System | Solar harmonics | Sawtooth at star temp frequency, LFO tremolo |
   | Planet orbit | Orbital music | Planet periods → pentatonic intervals |
   | Atmosphere | Wind crescendo | Noise burst, rising highpass cutoff |
   | Surface | Biome ambience | Type-specific (ocean surf, wind, volcanic rumble) |
   | Terrain | Detail sounds | Subtle variations of biome layer |

3. Crossfade logic: each layer has a gain envelope driven by zoom position within its scale range
4. Location-based frequency shifting: camera position hashes to slight pitch/filter variations
5. Master volume control + mute toggle in UI

**Commit milestone:** Continuous audio journey from deep space hum to planetary wind.

### Phase 4: The Time Dimension
**Goal:** A scrub bar from t=0 (Big Bang) to t=1 (present, 13.8 Byr). Everything becomes f(x, y, seed, t).

**Steps:**
1. Add `cosmicTime` parameter (0→1) to generator functions
2. Stellar evolution model:
   - Lifespan by spectral class: O=10Myr, B=100Myr, A=1Gyr, F=3Gyr, G=10Gyr, K=20Gyr, M=100Gyr+
   - At t < star_birth_time: star doesn't exist
   - At star_birth < t < star_death: main sequence (current rendering)
   - At t approaching star_death: red giant expansion (increased radius, shifted color to red)
   - At t > star_death: remnant (white dwarf for < 8 solar mass, neutron star/black hole for massive)
3. Galaxy formation:
   - t < 0.01: No galaxies, just density fluctuations (noise field)
   - t ≈ 0.01-0.05: Protogalaxies coalescing (scattered, dim)
   - t ≈ 0.05-0.3: Galaxy formation era (spirals developing arms)
   - t > 0.3: Mature galaxies (current rendering)
4. Planet formation:
   - Only possible after heavy elements exist (t > 0.3 for rocky, t > 0.1 for gas)
   - Early planets: molten surfaces regardless of type
5. Time scrub UI:
   - Horizontal bar at top, logarithmic scale
   - Labels: "Big Bang", "First Stars", "Galaxy Formation", "Solar System Era", "Present"
   - Play/pause button for auto-advance
   - Current epoch displayed in info panel
6. CMB (Cosmic Microwave Background) renderer for t ≈ 0:
   - Noise-based temperature fluctuation map
   - Characteristic orange/blue/white colormap

**Commit milestone:** Rewind to Big Bang, watch stars ignite and die.

### Phase 5: Polish & Cosmic Effects
**Goal:** Visual spectacle — nebulae, lensing, particles, smooth transitions, all the eye candy.

**Steps:**
1. **Nebulae:** Procedural volumetric noise rendered as semi-transparent colored clouds between Cluster and Galaxy scales. Seeded by position. Emission nebulae (hot pink/cyan near young stars), reflection nebulae (blue), dark nebulae (obscuring background).
2. **Gravitational lensing:** Near massive galaxies and black holes (post-stellar remnants), apply a distortion shader that bends the UV coordinates of surrounding stars/background.
3. **Particle systems:** 
   - Solar wind streaming from stars
   - Comet tails along hyperbolic orbits
   - Meteor showers on planet surfaces
   - Auroras at planet poles (for planets with magnetospheres)
4. **Scale transition polish:**
   - Smooth alpha crossfade between renderers (not hard zoom threshold switching)
   - Parallax effect between foreground/background layers
   - Motion blur on fast camera movement
5. **Planet rings:** Full Roche-limit particle simulation (replace current arc stroke)
6. **Moon orbits:** Render moons orbiting planets (currently generated but undrawn)
7. **Binary star systems:** Some seeds produce binary pairs
8. **Performance:** LOD system — reduce particle count for off-screen/distant objects

**Commit milestone:** Visually stunning at every scale level.

---

## Architecture Notes

### File Structure (target)
```
app/cosmos/
  cosmos-engine.ts        — WebGL2 renderer (new)
  shaders/
    star.vert             — Instanced star vertex shader
    star.frag             — Star fragment with glow
    galaxy.vert           — Galaxy particle vertex
    galaxy.frag           — Galaxy particle fragment
    atmosphere.frag       — Rayleigh/Mie scattering
    terrain.frag          — Fractal noise terrain
    bloom.frag            — Bloom post-process
    background.frag       — Background gradient
    planet.frag           — Planet sphere rendering
    nebula.frag           — Volumetric nebula
    lensing.frag          — Gravitational distortion
  terrain-generator.ts    — CPU-side terrain data (new)
  cosmic-soundscape.ts    — Web Audio synthesis (new)
  stellar-evolution.ts    — Time-dependent star lifecycle (new)
app/services/
  universe-generator.ts   — Extended with time parameter
  bookmark-manager.ts     — Add time to bookmarks
app/components/cosmos/
  app.gts                 — Main component (WebGL integration)
  info-panel.gts          — Extended with epoch info
  bookmarks-modal.gts     — Minor updates
  time-controls.gts       — New: time scrub bar component
  sound-controls.gts      — New: audio controls component
```

### Key Patterns
- **Engine/wrapper** from Aether: `CosmosEngine` class owns WebGL context, public API via setters, Ember component owns tracked state and UI
- **Web Audio** from Synth Studio: `CosmicSoundscape` class with lazy AudioContext, gain nodes, crossfade logic
- **Shaders as string constants** (like Aether): GLSL embedded in TS files for co-location
- **Determinism preserved:** All new generators take `(x, y, seed, t)` — same inputs always produce same outputs

---

## Implementation Order
Each phase is independently shippable and demo-worthy. Commits at every completion milestone.

**Estimated total:** ~4,000 new lines of code across ~15 files.
**Timeline:** 5 build sessions.

---

*"The moment a user seamlessly zooms from an entire galaxy cluster down to standing on a hillside watching an alien sunset — with zero loading screens, all from one seed — is the moment this becomes the most impressive browser demo on the internet."*
