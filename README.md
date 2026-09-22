**0.7.0: Synchronized rides and Crystal online doubles.** Synchronizes optional Dramatic Ride mounts, riders, direction, movement and flight height. Adds optional Crystal online doubles over native cloned-party link battles with paired actions and turn verification. Prevents the room menu from interrupting battle setup.

Known limits: Gen 1 online doubles remain unavailable. The full mixed-mod and disconnect matrix is not certified.

Requires Gen1Recomp 0.3.1 for the verified Gen 3 path. Other mods are optional; no ROM, player save or import cache is included.

**0.6.0: Cross-generation rooms and host-owned encounters.** Adds persistent two-player rooms, overworld presence, chat bubbles, walk-up native singles and trading across Gen 1, Crystal and Gen 3, plus native Gen 3 online doubles. Optional Wilds integration gives the host ownership of shared visible encounters, including guest-only maps.

Gen 1/2 online doubles are not implemented. Shared overworld ball throwing is disabled; native battle catching remains available. The full disconnect and mixed-mod matrix is still pending. Earlier two-client activity testing used engine 0.2.73; current packaged-cart smoke testing is separate.

# Gen1Online+ - Multiplayer, GTS & Overworld Expansions

> **Unreleased cross-generation room port:** Press F8 for a two-player room and
> F9 for chat. Rooms use the host-owned Wilds roster, positions and encounter
> claims, including town Pokémon and maps visited separately. Both players
> need the same game. See [room integration and validation](docs/CROSSGEN_ROOMS.md).
> The historical Crystal GTS/MMO service below is separate; its independent
> visible-wild spawner has been removed. Use rooms for shared visible encounters.


[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Mod Version: v0.5.0](https://img.shields.io/badge/version-0.5.0-green.svg)](manifest.json)
[![Game: Pokemon Crystal](https://img.shields.io/badge/target-Pokemon%20Crystal-blue.svg)](https://github.com/bryanthaboi/gen1recomp)

**Gen1Online+** brings a complete real-time multiplayer co-op experience with true-color overworld follower sprites, real-time authoritative server clock, and a 24/7 Global Trade Station (GTS) to *Pokémon Crystal*.

---

## 🌟 Key Features

### 🌐 1. Real-Time 60FPS Threaded Multiplayer
- **Seamless Overworld Co-op**: Live player movement synchronization across Johto and Kanto with zero stutter or lag.
- **Player Customization**: Walkable character avatars (`RED`, `BLUE`, `LEAF`, `PROF. OAK`, `COOLTRAINER`, `TEAM ROCKET`, and various trainer classes).
- **Dedicated Dual-Save Architecture**: Online progress writes strictly to `save_online_crystal.lua`, preserving offline `save_crystal.lua` files untouched.

### 🕒 2. Authoritative Server RTC Clock & Day/Night Sync
- **Synchronized Real-Time Clock**: Server broadcasts canonical time, minute, second, and day-of-week on every sync heartbeat.
- **Unified Day/Night Cycles**: Ensures all players in the world experience synchronized morning, day, night lighting and encounter tables. Manual clock manipulation is locked out for fair gameplay.

### 🌿 3. Overworld Wild Pokémon Roaming
- **Host-owned room spawns**: The optional Wilds of Kanto mod produces visible Pokémon; the room host controls their identities, wandering and encounter grants.
- **Facing Encounters**: Walk up to wild Pokémon in the field and press **`A`** to trigger authentic battle transitions with cries and shiny chances.

### 🐾 4. 1:1 True-Color PokeEmerald Follower Sprites
- **Authentic Gen 3 Follower Sprites**: True-color overworld follower sprites for all Generation 1 & 2 Pokémon.
- **Dynamic Directional Walking**: Followers mirror the player's movements with full 4-direction animations.

### 💬 5. Global & Local Chat + PokéGear Integration
- **Real-Time Live Notifications**: Receive popup alerts when other trainers send messages in the world.
- **Dedicated PokéGear Chat Tab**: Full scrollable chat history built directly into the player's PokéGear with unread badges.

### 🏪 6. 24/7 Global Trade Station (GTS) & Overworld PVP
- **Persistent GTS Network**: Deposit and search for Pokémon listings asynchronously.
- **Overworld Direct PVP Battles & Trades**: Walk up to any trainer in the world, face them, and press **`A`** to challenge or trade.

### 👥 7. Co-Op Party System & Shared XP
- **Party System (Up to 4 Players)**: Invite nearby trainers, view live teammate locations and levels.
- **Shared Experience**: Gain co-op bonus experience points when teammates defeat Pokémon in battle.

---

## 🎨 Importing Follower Assets from PokéEmerald Decompilation

The mod supports loading true-color overworld follower sprite sheets directly from a local clone of the **[pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion)** or **[pokeemerald](https://github.com/pret/pokeemerald)** decompilation repository.

### How to Acquire and Import Assets

1. **Locate Your Local Decompilation Folder**:
   Find your local checkout of the decompilation repository (e.g. `pokeemerald-expansion/graphics/pokemon/`).

2. **Source Sprite Sheets**:
   Follower sprite assets are located within each species subfolder:
   ```text
   graphics/pokemon/<species_name>/
   ├── walking.png  (or follower.png / overworld.png)
   └── palette.pal
   ```

3. **Place Assets in the Mod Directory**:
   Copy the extracted 32x32 / 16x16 4-directional walking sprite sheets into:
   ```text
   pokemon-gen1-recomp/mods/gen1online-plus/assets/followers/
   ```
   Name each sprite file by species name or national Pokédex index (e.g., `025_pikachu.png`, `151_mew.png`, `249_lugia.png`).

4. **Auto-Detection**:
   When launching the game, `Gen1Online+` automatically mounts and renders true-color sprite sheets for both player followers and overworld roaming wild Pokémon.

---

## 🛠️ Server Installation & Hosting

1. **Server Location**:
   The server backend resides in `server/gen1online/gts_server.py` outside of the client mod archive to keep security keys and private databases protected.

2. **Configure Admin Key**:
   Create `server/gen1online/server_secrets.json`:
   ```json
   { "adminKey": "YOUR_SECURE_RANDOM_KEY" }
   ```

3. **Start the Server**:
   ```bash
   cd server/gen1online
   python gts_server.py
   ```

4. **Expose with Cloudflare Tunnel (Optional)**:
   ```bash
   cloudflared tunnel --url http://127.0.0.1:7779
   ```

---

## 👨‍💻 Credits & Acknowledgements

- **Project Lead & Core Direction**: **Brookes**
- **Original Mod Creator**: **Gamecorner33**
- **Engine, Netcode, RTC Sync & Cart Architecture**: **Antigravity**
- **Platform & Recompilation Engine**: **bryanthaboi** and the **Gen 1 Recomp Team** ([bryanthaboi/gen1recomp](https://github.com/bryanthaboi/gen1recomp))
- **Decompilation Assets & Sprite Data**: **pret** / The **pokeemerald** & **pokeemerald-expansion** decompilation projects ([rh-hideout/pokeemerald-expansion](https://github.com/rh-hideout/pokeemerald-expansion))
- **MMO Architecture Foundation**: **alamops** ([alamops/RBYMMOMod](https://github.com/alamops/RBYMMOMod))
- **PotatoVoxel 3D Diorama Bridge**: **ShaneMcGovernIE** ([ShaneMcGovernIE/potato_voxel](https://github.com/ShaneMcGovernIE/potato_voxel))
- **PokéGear Cards Expansion**: **1Jamie** ([1Jamie/pokegear_cards](https://github.com/1Jamie/pokegear_cards))

## Crystal 2v2 PVP (roadmap)

PVP battles already run on the engine's own Gen 2 battle sim
(`src/battle/gen2/Battle.lua` via `pvp/engine.lua`). The companion fork
[double-battles-gen2](https://github.com/notquiteog/double-battles-gen2)
provides the 2v2 layer over that same sim (`lib/doubles2.lua`: two actives
a side, four-actor speed ordering, per-slot targeting, faint collapse).
Wiring PVP to 2v2 means: both clients field two actives, the lockstep
protocol carries per-slot actions and targets, and the party payload
grows to four — a protocol change that requires both sides on this build,
which the sealed-cart scoping in this same fork already guarantees (same
cart, same room, same build). Planned for the next fork release.
