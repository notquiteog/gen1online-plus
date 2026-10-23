# Portable API 3 audit — 2026-10-23

Engine baseline: official gen1recomp **0.3.96**, release commit `0e92b58`.
Manifest selects API 3 and requires `>=0.3.96 <2.0.0`; the mod version is unchanged.
References: [release](https://github.com/bryanthaboi/gen1recomp/releases/tag/v0.3.96),
[modding documentation](https://github.com/bryanthaboi/gen1recomp/blob/v0.3.96/docs/modding.md).
Audited Loader/UnifiedWorld, callback and canonical-record adapters, Storage,
Fetch, native link/party adapters and the documented Gen2 compatibility facade.

## Corrected public boundaries

- All portable Gen1/2/3 world, party, link and room UI code now obtains the
  live service from public `mod.game`. API3 UnifiedWorld does not expose the
  old `mod.world.game` field. Native link/party handles remain generation-native.
- Public storage requires `(game, key[, value])`. Room server lists load lazily
  after a live game exists, reload on `game.ready`, and write only to that
  playthrough. Storage accepts data-only tables; scalar URL/chat preferences
  use a versioned envelope and existing save/account tables remain intact.
  Server/save/account/chat persistence in the older Gen2 GTS
  path uses the same explicit current game scope. A failed write is not
  reported as a successful online save. The old GTS prefill filesystem read/
  write now uses the public `gts_server_url` storage key, which also fixes its
  earlier forward-reference bug. `gts_config.txt` remains own-file mod:read.
- Display-only public IPv4 discovery now uses `mod.fetch:get` over HTTPS,
  `available`, nonblocking `poll`, `cancel` and `release`. No raw thread or
  silent HTTP downgrade remains in that helper. Overrides, unavailable
  networking, invalid/oversized bodies, errors, timeout/restart/disconnect
  all retain hosting and clean up handles. The obsolete compute permission
  is removed; network and necessary engine_internals remain declared.
- Public input, HUD, start-menu and game.ready hooks/events remain the common
  room lifecycle. API3 canonical Pokémon event payloads are not treated as
  native Gen3 numeric structs. Existing battle/trade handlers consume the
  native context/party handle and generation-specific wire serializer.
- Optional doubles, skies, riding, visible wilds and UI providers retain
  feature/protocol checks; standalone room support does not depend on them.

## Necessary internal seams / API gaps

- Remote players need subpixel interpolation, per-frame mount/rider poses,
  imported native graphics IDs and controlled insertion into draw lists.
  Public world NPC operations expose integer cells and validated sprite
  references, not this renderer contract. Existing native peer rendering stays.
- Native link battle/trade transport adoption, party backup/restore and the
  Gen2/Gen3 wire serializers have no equivalent public transport-injection
  API. Replacing them with a public battle snapshot would lose multiplayer.
- The legacy Gen2 GTS/quests/arcade still uses the documented Gen1-shaped
  Gen2Compat Game/class facade. A raw Game2 service cannot replace the shim's
  `overworld` and legacy state layouts. Portable room adapters use mod.game.
- GTS JSON POST/request-response and persistent socket transport remain:
  public fetch only supports GET; postLog targets a fixed manifest log URL
  and deliberately hides responses. Neither implements that protocol.
- Talking to a rendered remote peer on otherwise empty ground needs the
  native interaction seam; public world.talk is not an empty-ground input
  interception event. Native transport/render functionality is preserved.

## Evidence and limits

- All 23 test suites, including the new portable storage test, pass.
  The Gen2 live trade suite uses actual 0.3.96 Mon/Wire modules; the multi-room
  suite uses the 0.3.96 LÖVE runtime and real ENet (**78 checks**), including
  concurrent channels, authenticated routing, roster/render dispatch, chat,
  guest-to-guest doubles/trades, shared encounters and rejoin.
- Public-fetch tests exercise lifecycle cleanup, failure and unavailable
  service behavior; storage tests exercise separate live game/playthrough
  scopes, game.ready reload, legacy GTS save/address keys and write refusal.
- Native 0.3.96 standalone loads pass Red, Gold, Crystal, FireRed and Emerald
  with exit 0, no loader errors and zero legacyReport entries on those paths.
- Native saved-server UI read/remove passes all eleven editions. Gold,
  Silver and Crystal additionally set/read the legacy GTS server prefill
  through real engine Storage, verifying its table-valued scalar envelope.
- This is not evidence of completed live network battles/trades in all eleven
  native editions, nor a claim that engine internals are fully replaceable.
  Broader standalone/combined native checks are coordinated at integration.
