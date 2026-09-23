## 0.8.0 — 2026-09-22

Includes optional cross-generation riding and host-owned ground/sky encounter synchronization, chat, trading and single/double battle integration. Multiplayer move/disconnect edge cases still need wider coverage.

Numbered release of the tested 0.8.0-test.2 build. Runtime and assets are unchanged except version metadata; packaging and cart pins are refreshed. Validation from the prior exact releases remains applicable: official Gen1Recomp 0.3.1, isolated profiles, targeted native rendering/integration checks. This release does not claim complete cross-generation feature or visual parity.

## 0.8.0-test.2 — 2026-09-22

Adds optional host-owned Wild Skies populations across generations. Bird claims preserve altitude and identity, reserve a bird during its battle, and restore it after escape or failed entry. Captured/defeated birds stay consumed. Both peers negotiate support; Wild Skies remains optional.

Shared visible-spawn ball throws now resolve through the native generation adapter after host approval, consume the ball only on grant, and restore a failed catch. Preserves full unsigned 32-bit Gen 3 personality values and synchronizes optional ride size/rider visibility.

Focused protocol tests cover duplicate grants, stale snapshots, range/altitude, failed catches, escapes and disconnect restoration. This prerelease is published before native gameplay verification at the user's request. Shared skies on maps outside the host provider's supported resident/neighbor fields remain a documented limitation; exhaustive move and disconnect combinations are not certified.

## 0.8.0-test.1 — 2026-09-22

Optional Gen 1 paired-action online doubles using native party clones, handshake, turn hashes and room cleanup. Existing single/trade paths retained.

**TEST PRERELEASE — published before gameplay testing at the user’s request.** Build/compile validation only at publication. Gen 1 online doubles and the new door/healing projection require native gameplay verification; advanced move effects and disconnect combinations may need corrections. Existing stable releases remain unchanged.

## 0.7.0 — 2026-09-22

Synchronizes optional Dramatic Ride mounts, riders, direction, movement and flight height. Adds optional Crystal online doubles over native cloned-party link battles with paired actions and turn verification. Prevents the room menu from interrupting battle setup.

Known limits: Gen 1 online doubles remain unavailable. The full mixed-mod and disconnect matrix is not certified.

Requires Gen1Recomp 0.3.1 for the verified Gen 3 path. Other mods are optional; no ROM, player save or import cache is included.

## 0.6.0 — 2026-09-22

Adds persistent two-player rooms, overworld presence, chat bubbles, walk-up native singles and trading across Gen 1, Crystal and Gen 3, plus native Gen 3 online doubles. Optional Wilds integration gives the host ownership of shared visible encounters, including guest-only maps.

Known limits: Gen 1/2 online doubles are not implemented. Shared overworld ball throwing is disabled; native battle catching remains available. The full disconnect and mixed-mod matrix is still pending. Earlier two-client activity testing used engine 0.2.73; current packaged-cart smoke testing is separate.

## 0.5.5 — 2026-09-14

Correct standalone offline encounter selection for Crystal's numeric time-of-day
IDs. Morning and night now select their own slots; darkness uses night slots.
Regression coverage checks all four numeric IDs and named equivalents. The
cart still delegates its offline encounters to Wilds.

## 0.5.4 — 2026-09-14

Fix the rapidly respawning placeholder Pokémon in towns. The offline encounter
population now persists for a map visit, claimed encounters stay removed, and
unknown species/invalid levels cannot become actors. Remove eight corrupted
rare slots (including landmark aliases) from New Bark and Cherrygrove.

When Wilds provides encounters/followers, it owns the offline population and
local follower. Server encounters retain their separate connected behavior.
This avoids duplicate wild spawners and a second local follower in the cart.

Reproduced with the user's copied Linux AppImage profile and its installed
0.2.60 update: old code repeatedly creates obj_301/302 with species T/M and the
Charmander placeholder; candidate runs 900 frames without them, preserves the
ambient Sentret, and asserts one follower after receiving Cyndaquil. The QA
launcher must dispatch core.update (PlatformHooks.update); the engine's usual
script driver calls Game:update directly and misses this bug. Pure roster tests
cover malformed slots, stable identity, consumption and server validation.

## 0.5.3 — 2026-09-14

Skip Gen 1 Game Corner map-script registration on Crystal. Native Gen 2 has no
target for that registry. Online services and casino menus remain available;
this release does not port the Casino Lounge map. Native Crystal companion
loader check passes alongside the full cart set.

## [0.5.2] - 2026-09-13 - the server tells you where to connect

- tools/gts_server.py prints the addresses players type into the game's
  SERVER ADDRESS prompt at startup: the LAN address (default route first,
  every interface after), and the public address as the outside world sees
  it, with the port-forward note. The public check degrades gracefully
  with no outbound web access.

# Changelog

## [0.5.1] - 2026-09-13 - Johto Diorama fork: ask-for-server, sealed-cart scoped sync

Forked from gamecorner-033/Gen1Online v0.5.0 (tag and manifest agree at
0.5.0; this fork releases as 0.5.1). Three changes, no gameplay edits:

- **The server is always asked for.** CONNECT opens a server address prompt
  (typed, keyboard or gamepad), prefilled with the last address (mod
  storage, then gts_config.txt, then the shipped default) and nothing
  connects until it is confirmed. The chosen address normalizes, persists,
  and wins for the whole session. The old read-only "current server" box is
  now the same live editor.
- **Sync is scoped to the sealed cart.** Every request stamps the running
  cart's id plus a fingerprint of its pin list (read from the engine's own
  cart report, so any future quest mod changes the scope automatically). A
  cart-aware server shows you only players from the same sealed cart;
  peers without a hash (unpatched servers) keep the old open behaviour.
- **tools/gts_server.py** is the self-hostable backend, patched to store
  the cart scope per player, scope map visibility to same-cart peers, and
  refuse challenges across carts, plus a /server/info endpoint. MOD_VERSION
  stays 0.5.0, so the official server's version handshake still accepts
  this build.

## [0.5.0] - 2026-08-27

### Added
- Synchronized Real-Time Clock with server authority and automatic Day/Night cycle locking.
- 1:1 True-Color PokeEmerald follower sprites.
- Synchronized overworld wild Pokémon encounters with live grass roaming across Johto and Kanto.
- Rebranded to Gen1Online+.

## [0.4.0] - 2026-08-24

### Added

- **Gen1Online++ rebrand**: new mod id `gen1online-plus`, targeting
  **Pokemon Crystal only** (Gen 2 / `crystal` engine).

### Removed

- **Blackjack** and the expanded blackjack code.
- **Live Multiplayer Online Texas Hold'em** (the poker tables, screens, rules,
  and table art).

### Changed

- Version bumped to 0.4.0.0 across manifest, mod.card, README, and server.
- Online save files now use the `_crystal` suffix (`save_online_crystal.lua`).

## [0.3.6.1] - 2026-08-17

### Added

- **Custom Gen 2 PVP battle engine** (`pvp/` modules): deterministic lockstep
  battles on Gold using the native Gen 2 battle engine, with full-party
  switching, shared RNG seed, canonical turn order, and the vanilla battle UI.
  Swappable backend (`pvp.config.engine = "custom" | "native"`) for an easy
  switch back when the recomp gains native PVP.
- **Active server logout on quit** — new `logout` server action; the START-menu
  QUIT item and quit-to-title both log the player out immediately (no 30s ghost).
- **1x game-speed lock while online** — all players are forced to normal speed
  and cannot alter it while connected, so the MMO stays synced.

### Changed

- Version bumped to 0.3.6.1 across manifest, mod.card, README, and server.
- Remote-player movement over-prediction capped to one tile per packet (no more
  walking off the map before snapping back).
- PVP battle end now returns to the map (pops the battle state) instead of
  freezing on the victory/defeat screen.
- Battle-message transport is non-blocking via the async HTTP engine; the async
  queue cap raised so battle messages are never dropped.

## [0.3.5.0] - 2026-08-11

### Added

- **Gen 2 (Gold) Support.** The mod now declares `"api": 2` and
  `"games": ["gen1", "gen2"]`, enabling it to load on Gold boots via the
  Gen 2 compatibility adapter.
- Generation detection helper (`currentGeneration` / `isGen2`) for
  future generation-conditional logic.

### Changed

- Online save files on Gold now use a `_gold` suffix
  (`save_online_gold.lua`) to keep progress separate from Gen 1 saves.
- `Game.logicSpeed` override is now guarded with a nil check for Gen 2
  facade safety — the patch only installs when the method exists.

## [0.2.0] - 2026-08-07

### Added

- A 1,000,000-coin Coin Case limit across the mod's purchases, wagers, payouts,
  prize refunds, and pawn transactions.
- Compatibility for the original slot machines, including high-balance-safe
  payouts and a compact four-character credit counter up to `1.0M`.
- House-banked Texas Hold'em with real best-five-of-seven hand evaluation.
- Progressive Play wagering across all three streets: check or bet 3x/4x
  before the flop, continue with 2x after the flop, then check or bet 1x at
  the river.
- One clear starting bet, standard best-hand comparison against the house,
  and 1:1 payouts across all committed wagers.
- A dedicated blue-felt Hold'em screen with hole cards, five community cards,
  staged controls, showdown hands, and net results.
- A second dealer and interactive poker table in the casino lounge.
- A shady Pokemon pawn broker at the original Game Corner counter.
- Stat-, level-, and rarity-based appraisals paid in Game Corner coins, with
  exact Pokemon restoration for a 30% redemption premium.
- Five persistent pawn slots with an explicit first-pawned-first-sold warning
  when adding a sixth Pokemon.
- Safe party/PC redemption and protections for the final party member, full
  Coin Cases, and full Pokemon storage.
- Three generated center-lounge arcade cabinets with separate Crash, Tube
  Flyer, and Prize Case screens.
- A wager-and-cash-out Crash game with a hidden house-edged crash point,
  continuously rising multiplier, four wager sizes, and persistent records.
- A 10-coin flying game with deterministic tube physics, immediate one-coin
  payouts per passed tube, best scores, and safe Coin Case limits.
- A 500-coin case-opening reel with rarity colors, a premium Pokemon roster,
  rare items and TMs, and a roughly 0.1% Master Ball chance.
- Transactional case rewards that use party/PC delivery and refund the full
  opening price if the selected reward cannot be stored.

### Improved

- Replaced low-tier Prize Case Pokemon with starters, fossils, Dragonite,
  Mew, and a special Pikachu that arrives knowing Surf.
- Styled the Master Ball reel card as a gold-and-black jackpot and slowed the
  case reel and Crash multiplier growth for clearer decision timing.
- Refactored the runtime into per-game `games/` modules and supporting
  `other/` services, reducing `main.lua` to composition and registration.
- Rebuilt all three arcade screens around bright, machine-specific Game Boy
  palettes so the engine's black tile font remains legible in every state.
- Crash now presents all four wagers at once with a clear selection, a visual
  launch preview, and a light graph surface.
- Tube Flyer gained readable top-HUD scoring, capped pipe openings, a clearer
  bird silhouette, and a compact result ribbon that preserves the playfield.
- Prize Case gained icon-led reel cards, shorter readable reel labels, stronger
  winner markers, and compact opening/result panels without a dark backdrop.
- Expanded the lounge from 14x10 to 20x12 walk cells for two distinct games,
  more breathing room, and a central circulation aisle.
- Reduced both overworld tables from five to four tiles wide and gave each
  game its own locally generated table art.
- Added concise in-world guidance for progressive Hold'em decisions and
  standard best-hand payouts.
- Verify each wager independently, so a player with exactly one starting bet
  can check every street and still reach showdown.
- Early bets now reveal only the next street instead of skipping directly to
  showdown, and unaffordable bets never block the free Check action.
- Removed the Ultimate Hold'em Ante, Blind, bonus-paytable, and dealer-
  qualification rules that conflicted with the multi-street game.

### Fixed

- Original slot payouts now cross the old 9,999-coin boundary instead of
  silently losing the next payout coin.
- Hidden Game Corner coin pickups preserve five- and six-digit balances
  instead of clamping them back to 9,999.
- Prize Case reel positioning and winner highlighting now share the same
  configured winning-card index.

## [0.1.0] - 2026-08-06

### Added

- Playable blackjack using the existing Game Corner coin balance.
- Pixel-drawn cards, chips, casino table, action states, and round feedback.
- Expanded Red- and Blue-aware Pokemon prize catalogues.
- Persistent shiny upgrades with locally derived gold battle art.
- Rare item prizes and a one-time 9,999-coin Master Ball redemption.
- Larger 50, 250, 500, 1,000, and capacity-aware MAX coin purchases.
- Red-, Blue-, and Yellow-aware prize catalogues with starters, fossils, and
  opposite-version species.
- Safe party/PC delivery and failure handling that never charges for a prize
  the player cannot receive.

### Improved

- Removed level suffixes from Pokemon prize rows so long names no longer
  collide with their prices.
- Failed prize purchases now return to the catalogue instead of closing it.
- Replaced the borrowed octagonal dining table with a wide, green semicircular
  blackjack table, centered dealer, betting marks, chips, deck, and a fully
  interactive front edge.
- Moved the table into a dedicated Blackjack Lounge with its own double-door,
  spectators, open circulation space, and reciprocal Game Corner warps.
- Expanded the coin clerk with 50, 250, 500, 1,000, and capacity-aware MAX
  purchases at the original exchange rate.
- Card pips, court cards, silhouettes, and color rendering were rebuilt for the
  real 160x144 game pipeline.
