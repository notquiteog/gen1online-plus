# Release checkpoint — 2026-09-22

Prepared for publication at the user's request: Online 0.7.0, Wilds 2.3.1,
Double Battles 0.11.0, Ride 0.3.0; Johto Diorama 1.16.0, Yellow Online 1.4.0,
Voxel Red Preview 0.3.0. Battle Art runtime remains 1.22.0. This checkpoint
supersedes the unfinished-test status below, without claiming complete parity.

Current evidence on official Gen1Recomp 0.3.1 (isolated profiles):
- All three exact sealed-cart archives boot, validate cart identity and every
  pinned mod version, render their lab and return to the field. Crystal loads
  seven pins and full_body_backs=true; Yellow six; FireRed all five, including
  the new Ride port. Lab captures inspected for all three generations.
- 155 packaged Lua modules and the runtime-concatenated Ride source compile
  with LuaJIT. ZIP contents/hashes checked; no ROMs, saves or import caches.
- Native two-client FireRed Ride sync passes ground/flight, height, movement,
  dismount, local-state isolation and disconnect. Ground/flight captures inspected.
- Native Yellow and Crystal two-client ground Ride sync passes mount, movement,
  dismount and disconnect. Yellow remote mount capture inspected.
- Native Crystal online doubles pass paired choices, explicit targets, bench
  replacement, mirrored state hashes, win/loss completion, cloned-party restore
  and retained room. Native mirrored mechanics fixture and 43 unit checks pass.
  Final native run preceded the small PP/egg validation and Future Sight state
  normalization follow-ups; those have source/unit coverage, not a repeat duel.
- Native FireRed doubles and trade fixtures pass completion, party integrity
  and room/chat retention. Standalone FireRed Ride passes without companions.
- Fresh LeafGreen import into a disposable profile passes ground/flight/Surf,
  safe dismount and walkable axis-aligned follower trails.
- Crystal sprite provider passes full-body animation checks for Cyndaquil,
  Totodile, Chikorita, Raikou and Ho-Oh. Full-body battle capture inspected.

Evidence: /tmp/ports-parity-031 (doubles-release, double-core-final,
ride-net2, ride-gb2, ride-crystal2, ride-lg-verified, native-double, trade-final,
sprites-cart) and /tmp/release-ports-20260922 (archives, checksums, logs, captures).
Scripted QA .love uses the official interactive PlatformHooks.update seam and
passes the cart ID, correcting two stock driver omissions only. No production
engine patch or user profile/save changes. Live AppImage left untouched.

Remaining: Gen 1 online doubles, advanced Crystal double weather/delayed-move
combinations, broader mixed-mod/cancellation/disconnect matrix, exact GB custom
rider skin/scale parity and exhaustive scenery coverage. Crystal lab/field QA
logs a nonfatal Wilds nil-sprite fallback warning; investigate separately.
Gen 3 flight is map-local; standalone mount fallback art is nondirectional.
No new visual runtime changes this release. Gen 5 FireRed battle backs are
explicitly deferred by the user to a separate future mod. Crystal uses its
Gen 2 sprite companion, not Gen 5 art.

# Port work checkpoint — 2026-09-22 (UNRELEASED)

Sprite/cart QA passed on 2026-09-22: all seven exact published mod archives
load, sealed-cart full_body_backs=true reaches the provider, and Cyndaquil,
Totodile, Chikorita, Raikou and Ho-Oh advance animation frames through Battle
Art's public Gen2Staged.picFor integration. Native Cyndaquil/Sentret battle
capture inspected: full-body Cyndaquil is visible on stage. Evidence:
/tmp/ports-parity-031/sprites-cart.log and sprites-cart-battle.png.
Test harness detail: stock 0.3.1 scripted boot ignores the cart and bypasses
PlatformHooks.update, unlike interactive gameplay. The isolated QA .love
changes only cart boot arguments and the driver update call to the normal
PlatformHooks.update seam; no production engine/mod patches. An initial
unadjusted driver failed animation advance because it skipped that hook.
Cart manifest/index match, all seven ZIP hashes verified locally, strict
cartkit validation and packing pass. No new cart release published yet.

Current source changes remain uncommitted; published baseline below is unchanged.
Gen 3 Ride now has a native implementation in dramatic-sky-ride/lib/gen3/init.lua.
Official Gen1Recomp 0.3.1 standalone FireRed fixture passed ground movement,
free flight, native Surf, safe dismount and mounted follower suppression. Two
native FireRed clients passed remote mount, flight height, dismount, local-state
isolation and disconnect cleanup. Evidence: /tmp/ports-parity-031/ride*.log.
Only the standalone ground capture has been inspected so far; other captures
still need visual inspection. No claim of complete cross-generation Ride sync.

GB Ride read-only visual/pose exports and Online adapters are implemented but
not yet tested. Wilds Gen 3 now records the player's actual trail and hides its
follower while mounted; corner/warp cases still need verification. Optional
Crystal online-double provider and paired-turn transport are implemented but
NOT verified: the first two-client run timed out with host at intro and guest
at link-wait. Logs: /tmp/ports-parity-031/doubles-crystal-{host,guest}.log.
Gen 1 online doubles remain unimplemented. Do not publish these as complete.
Remaining work includes double mechanics/hash/refill checks, cancellation and
mixed-mod cases, standalone/LeafGreen Ride, and additional Gen 2/3 visual work.

Latest user addition: Crystal cart source re-adds animated sprites 2.1.0,
SHA256 9432787d25476ccf5ce63309efefad794ba6fae877f710013e6bf73ad2aa192f,
with full_body_backs=true in both cart.json and index-entry/meta.json. Preserve
this seventh pin when regenerating cart manifests. Cart 1.15.0 on GitHub has
not changed. Dedicated exact-release sprite/cart QA is under
/tmp/ports-parity-031/sprites-cart* and isolated profile
/home/admin/.local/share/crystal-sprites-cart-031-qa. No player saves changed.

# Release QA — 2026-09-22

Packaged ZIPs, exact SHA-256 pins and sealed carts tested in isolated
release-031-{yellow,crystal,firered}-qa profiles. Official Gen1Recomp 0.3.1
.love checksum verified. A QA-only copy changes only the scripted boot's two
cart-id arguments to honor QA_CART (stock driver boot discards --cart); no
production engine/loader/gameplay changes. FireRed reimported from the user's
local ROM into the disposable QA cache. Player profiles/saves untouched.

Three cart runs passed identity/pin/version checks, four native interiors and
field return each. Crystal/Yellow load all five mods plus Running Shoes.
FireRed bundles all five at the user's request: four load, Ride stays
wrong_generation because its Gen 3 port is unfinished. Rendered Yellow and
Crystal contact sheet and FireRed Oak lab/field captures inspected. Logs and
archives: /tmp/release-031-20260922. 368 packaged Lua files and the assembled
Ride source compile with LuaJIT; tree-art, lab, options, LeafGreen alias,
shared-world/activity and Gen 2 target-selection focused tests pass. Wilds
version, ASCII metadata, option-label and ZIP hygiene checks pass.

No claim of exhaustive visual parity or full multiplayer activity revalidation
on 0.3.1. Earlier two-client 0.2.73 evidence is retained separately. Gen 1/2
online doubles, Gen 3 Ride and the remaining disconnect/mixed-mod matrix are
still unfinished. Kanto Gear is absent; all packages exclude ROMs, player saves,
import caches and private battle artwork. Companion mods remain independent.

# Main-branch source checkpoint — 2026-09-22

User requested all pending mod/cart source committed and pushed to main. This
checkpoint includes the earlier uncommitted work below; it is not a release.
Ride Gen3, GB online doubles and the remaining integration matrix are still open.
Historical no-commit notes describe previous checkpoints. Cart manifests remain
unreleased drafts with existing published pins.

# Presentation/options update — 2026-09-22 (unreleased)

Latest user additions (trees, Oak lab, missing OPTIONS and Pokédex desk) were
handled in Battle Art and independent settings adapters in Wilds/Double/Ride.
Native 0.3.0 options tested across Yellow/Crystal/FireRed/LeafGreen. LeafGreen
was imported by the user and is available. Official 0.3.0 QA runtime and evidence
are under /tmp/source-art-030; see Battle Art PROJECT_HANDOFF.md. This is not
reverification of all multiplayer protocols on 0.3.0. Ride Gen3 and GB online
doubles remain unfinished. Crystal/Yellow source cart manifests now have only
five mods plus Running Shoes, but retain old published pins: unreleasable until
companion ports/release pins are ready. No releases/commits made this batch.

# Continuation update — 2026-09-22 (newest, uncommitted)

This section supersedes the older checkpoint below. Still NO releases/version
bumps/cart updates/commits in this batch. User's latest instruction is host-owned
visible encounters; original request remains all five mods and new carts.

New implementation since previous checkpoint:
- Wilds `lib/shared_ambient.lua`: host-owned town NPC roster, remote-map native
  ambient simulation; guest native update/facePlayer disabled, interpolated
  pose only. `shared_spawns.lua` separates ambient/wild rows; host restored
  off-map wild actors now receive Behavior.attach. Wire schema includes ambient
  pose/behavior fields. Host denies all ambient battle claims. Offline restored
  on disconnect. Actual Yellow/Crystal separate-town clients passed; IDs/species
  matched. Need rerun Crystal with phase=play, prior ambient drivers left phase
  at boot (input.step/remote simulation worked; local native NPC AI wasn't ticking).
- Online removed ~380-line obsolete HTTP species-only/client-wander spawner and
  its interaction hooks entirely. Optional Wilds owns encounters; legacy GTS/MMO
  service remains separate. Docs explicitly say use peer rooms for shared spawns.
- `lib/gb/link.lua`: Yellow native LinkState adopted virtual session, singles and
  trades. Single trade invitation returns after native animation/evolution.
- `lib/gen2/link.lua`: discovered actual engine0.2.73 has native LinkBattle2!
  Use normal Handshake + native packParty2 / seeded paired battle, native hashes,
  forced replacement, keepNetOpen. Old custom PVP modules remain legacy only.
- `lib/gen2/trade.lua`: native Trade.remote protocol with live handle, own simple
  Chrome party/confirm UI, native Gen2TradeAnim / Gen2EvolutionAnim. Uses ordinary
  Game2.writeSave; DOES NOT call or bypass launcher Trade.commit live-save guard.
  Strict native packing, no eggs/mail, consent, trade evo and held item consumption.
- Activities wait both endpoints and store lastActivity result; native completion
  closure bound to exact activity object so an old animation cannot finish a
  new connection's invitation. GB adapters release current after late abort finish.
  `tests/room_activities_test.lua` covers these and optional capability gate.
- GB remote draw fixed native Gen2 offset/scale contract. Busy state now considers
  native UI stack, so invitations cannot start over a menu. Chat bubble native
  GB projection now uses world.camera. Bubbles stack to avoid mutual overlap.
- Crystal walk-up A still being debugged: native blank NPC text occurred despite
  wrapping World.interact and then facade OverworldController.interact. Latest
  fix intercepts A pressQueue through supported input.step ONLY with phase=play,
  empty stack, facing a peer. Native test rerun currently latest chat-crystal logs.

New native evidence in `/tmp/crossgen-integration`:
- trade-host/guest.log: FireRed both PASS. Initial host failure was fixture auto-A
  offering before explicit offer flag; tap A only during native scene fixed it.
- link-double-host/guest.log + host/guest/link-double.png: AFTER HUD separation,
  actual doubles finish, parties restored; four distinct above-head cards inspected.
- gb-link-driver.lua / link-yellow-*.log: native singles both PASS, untouched parties.
- gb-trade-driver.lua / trade-yellow-*.log: native trade both PASS, unselected slot
  identical. Native animation/save complete; world still connected.
- crystal-link-driver.lua / link-crystal-*.log: native LinkBattle2 singles both PASS,
  no desync logs, untouched parties. Fixture still phase=boot but native battle UI
  pushed and completed, so world interaction itself wasn't tested here.
- crystal-trade-driver.lua / trade-crystal-*.log: both PASS. Initial fixture's new
  Pidgey lacked OT; native first save filled OT. Save fixture before baseline fixed
  false untouched-slot failure. No production save behavior changed for that.
- QA_EVOLVE=1 same driver / trade-evolution-crystal-*.log: both PASS, Machoke→
  Machamp, Metal Coat Onix→Steelix, item consumed, second party slot unchanged.
- chat-ui-driver.lua: FireRed and Yellow both PASS walk-up A, actual physical F9,
  game:textinput, Enter, peer chat. FireRed capture inspected: neighboring bubbles
  overlapped initially; now separated in render.hud (AFTER capture still pending).
  Crystal latest input fix still pending native result. Fixture phase MUST be play
  and stack empty. FireRed newGame overrides facing to down; fixture resets facing
  after native spawn. The before-A diagnostic logs are test-only.
- relay-driver.lua / relay-host/guest.log: actual PUBLIC default engine TCP relay
  `relay.gen1re.com:7778`, two game processes, PASS paired shared roster / chat /
  positions / guest spawn rejected. Room code was passed locally in scratch file;
  gameplay travelled through public relay. No other people's room/messages used.
- crystal-cancel-driver.lua created but NOT RUN yet. Test native B while both are
  at confirmation; assert both selected and untouched party slots unchanged.

`docs/CROSSGEN_ROOMS.md` and README now describe room ownership and distinguish
legacy GTS; docs need latest Crystal trade/public relay results added. Battle Art
root PROJECT_HANDOFF updated with inspected double HUD proof.
All 29 changed Lua files compiled before last trade/UI changes. Focused shared
world, activity and status layout tests PASS; Wilds existing gen2/random tests PASS.

Remaining: Gen1/2 online doubles (not advertised), FireRed Ride still untouched,
standalone/mixed mod handshake (Double affects_link=true), full cancellation /
disconnect/reconnect matrix, active Crystal ambient/UI, final five-mod carts and
releases. Do not claim full parity or publish partial carts as completed ports.

# Cross-generation multiplayer work — uncommitted, 2026-09-22

User wants all five companion mods working independently and together on Gen 1,
Crystal and FireRed; online singles/doubles, trading, presence, chat bubbles;
then new cart releases. Latest correction: HOST owns visible spawn population,
positions, AI and encounter claims. Guests must never roll/move independent
wilds. Do not publish carts or declare full parity yet.

## Implemented locally

- `lib/crossgen/shared_world.lua`: versioned host snapshots, exact encounter
  grants, pending-request matching, native failure release, duplicate/racing
  claim rejection, session/revision guards, disconnect recovery. Unit test.
- `lib/crossgen/session.lua`: persistent two-player engine Net ENet/room relay
  transport, same-game negotiation, world positions, chat, virtual channels.
  This is a new room mode alongside the old Crystal GTS/MMO service, NOT a
  replacement/verification of that old many-player HTTP server. Old service
  spawning suppressed while in a room. Public exports.multiplayer.
- `lib/gb/init.lua`: native Gen1/2 remote actor adapter. Gen1 early entry skips
  Crystal-specific legacy code; Crystal installs room adapter at factory end.
- `lib/gen3/init.lua`: native FireRed remote actors through Objects.forDraw;
  shared native/Battle Art rendering, no dependency on presentation mod.
- `lib/crossgen/ui.lua`: F8 room menu, F9 chat, native textinput wrapper,
  optional projected chat bubbles, walk-up interaction menu. Native/activity
  options only shown when supported by both endpoints. Needs visual/input QA.
- `lib/crossgen/activities.lua`: nearby invitation, acceptance, capability
  negotiation, native activity transport, wait for BOTH completions before
  closing virtual link. Actual world/chat socket survives.
- `lib/gen3/link.lua`: native Game3Link handshake and battle/trade services.
  Singles and doubles use native paired actions/targets, flags and shared seed;
  party saved before healing and restored after battle. Trade native menu,
  exchange, animation, save/evolution services. Disconnect handling needs
  more tests (especially trade after swap).

Wilds fork: `/home/admin/Projects/overworld-spawn-mod`
- Created notquiteog/overworld-spawn-mod fork; origin points there, upstream
  is YoDrehDenSwagAuf. No new commits/releases yet.
- New Gen3 adapter/actors; ROM encounter tables, own already-shipped follower
  sprites with proper 6->9 native frame conversion, native battle seam.
- All three generations export sharedSpawns(version=1): configure/snapshot/
  apply/beginEncounter/remoteSnapshot. Guest spawner/AI disabled. Native
  followers remain local. Shared overworld catching currently disabled to
  prevent bypassing host claim; catching inside the granted battle works.
- Host-only unloaded-map simulation reads imported map geometry/tables without
  swapping live world/collision. Stable IDs/cache survive host joining guest.
- Gen3 follower placement remains simplistic; needs ride suppression and trail.
- Ambient town Pokemon aren't shared yet; battleable Wilds are.

Double Battles: `/home/admin/Projects/double-battles-gen2`
- Gen3 early native adapter, native original doubles preserved, optional extra
  trainer doubles (off), public online double capability (on).
- No conversion of visible wild into trainer/double battle. Native engine
  explicitly excludes wild doubles (BattleBridge AND Battle.start).
- `affects_link` still true; must address optional mod mixed singles using
  actual native handshake rather than bypass checks. Gen1/2 online doubles
  still unfinished; no false capability advertised there.

Battle Art: `/home/admin/Projects/DramaticShapeVoxelMod`
- New pure BattleTheme.layoutStatusCards to prevent paired card overlap.
- Gen3BattleHud uses it. Unit test passes. Native BEFORE screenshots show all
  four actors but overlapping status cards. Need rerun/inspect AFTER.

Dramatic Ride: no Gen3 edits yet. Existing 0.2.23 Gen1/2 remains untouched.
No source version bumps, commits, pushes, new releases/cart repins this batch.

## Real native evidence (0.2.73 AppImage)

Scratch `/tmp/crossgen-integration`. Runner:
`bash /tmp/firered-hd2d/run-native.sh <game> <driver> <shots> <log> <identity>`
set QA_ROLE=host/guest, QA_MODE=single/double as applicable.
Two SEPARATE LOVE processes, actual localhost ENet, isolated profiles, not
in-memory loopback. No public relay test messages or user saves touched.

Profiles:
- crossgen-world-{host,guest}-qa: FireRed, symlinked source Online/Wilds/
  Double/Battle Art; imported data symlink only, isolated saves.
- crossgen-{yellow,crystal}-{host,guest}-qa: Online/Wilds, native flat rendering.

Drivers/logs:
- world-driver.lua / host.log + guest.log: FireRed six identical IDs/species/
  levels; position and chat exchange; guest spawn rejected. Captures inspected.
- claim-driver.lua / claim-{host,guest}.log: guest granted exact Pidgey native
  wild battle; removed on both; host never enters guest battle. Capture taken
  during intro (no sprites yet), so this proves native battle state, not full UI.
  First run fixture raced with contact encounter; second passed. Tighten fixture.
- gb-world-driver.lua: Yellow + Crystal same-map tests PASS; same session and
  roster/species/levels compared in JSON. Gen1 remote NPC needed def metadata
  to avoid trainer-sight nil crash; fixed, rerun PASS.
- QA_REMOTE=1 gb-world-driver.lua: separate maps PASS both games; host waits
  for guest's checked message to avoid premature disconnect. Remote rosters
  held by host. Native module guard rejects Gen2 Permissions in FireRed; fixed
  to use FRLG's imported collision bytes, no guard bypass.
- remote-map-driver.lua: FireRed host Route1, guest Route22; six spawns produced
  while host map/player unchanged; host joins Route22 retaining same IDs. PASS.
- native-link-driver.lua / link-single-{host,guest}.log: actual native singles
  completed, all party fields restored semantically, world/chat connected.
  Initial JSON-string equality was wrong due to key order; decoded comparison
  PASS on both, party-single.json also independently compared in Python.
- Same driver QA_MODE=double / link-double-*.log: actual native doubles complete
  both clients, original parties restored, room/chat retained. All four native
  sprites visible in inspected captures. BEFORE HUD spacing fix.
- native-trade-driver.lua / trade-*.log: guest PASS; host process still running
  at time of this checkpoint, check latest log. Uses native menu/offer/confirm,
  native scene, swap/save; expects exact received personality/species and
  untouched second party member. Not yet evolution/disconnect test.

Focused tests PASS: Online shared_world_test.lua; Wilds gen2_wilds_unit_test.lua
and random_enc_unit_test.lua; Battle Art battle_status_layout_test.lua. Changed
Lua compiled with LuaJIT before latest UI/link additions; recompile all later.

## Next work (not exhaustive)

1. Check trade host log, capture/inspect native trade/room/chat bubbles and
   verify real input; rerun doubles for new HUD positions.
2. Gen1 native single/trade room adapter can adopt LinkState.newFromSession.
   Current Gen1/2 room capability is empty (no battle/trade yet). Existing
   Crystal pvp modules run legacy service only; Gen2 trade absent there.
3. Gen1/2 doubles online paired actions/targets/forced switches/KO/residuals;
   no AI choosing the remote commands. Canonical RNG order needs careful work.
4. FireRed Ride port, standalone follower/native sprite fallback and optional
   Wilds/Battle Art integration; no duplicate player masquerading as a mount.
5. Negative/standalone/mixed-mod matrix, reconnect, disconnect/cancel trade,
   double target choice/spread/effects/switches; head-to-head state comparison.
6. Existing GTS/MMO still has client-side spawn wandering when used outside
   room mode. Need migrate/default menu to host rooms or implement host authority
   there too; cannot claim ALL multiplayer spawning fixed yet.
7. Complete docs/version bump/tests/native five-mod matrix, then publish source
   and repin/release ALL carts. Kanto Gear must remain absent.
