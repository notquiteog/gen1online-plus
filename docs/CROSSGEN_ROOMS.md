# Cross-generation rooms (unreleased)

Rooms are a persistent, two-player connection for players running the same
Generation 1 game, Crystal, or FireRed. F8 opens host/join options; F9 opens
chat. Face the other trainer and press A to open the interaction menu. Both
players must accept a battle or trade. Ending an activity keeps the world and
chat connection open. Internet rooms use the engine's relay, LAN uses ENet.

## Host owns the overworld population

The optional Wilds of Kanto provider owns rendering and encounter mechanics;
Online owns the room, snapshots, revisions and exclusive encounter claims.
Only the host rolls wild species/levels and moves their actors. The guest
renders those snapshots. Town Pokémon use the same host ownership but cannot
be claimed as wild encounters. Followers remain the local trainer's own party.

A guest visiting another map receives a host-generated population for that map.
Generating it does not load that map into the host's game or move the host.
Cached identities survive joining that map. Encounter requests contain a spawn
ID, never a guest-chosen species. The host checks the map, proximity and busy
state, removes the actor everywhere, and grants that exact encounter once.
Failed native starts release the reservation. Duplicate or competing claims,
stale snapshots and old sessions cannot create another encounter.

Shared overworld ball throwing is currently disabled; catching inside a granted
battle works normally. A host without Wilds has no visible-wild provider, and a
guest with Wilds cannot fill the room with an independent population. Leaving
the room restores offline spawning. No companion is a required dependency.

The historical HTTP GTS/MMO service does not provide this host protocol. Its
old species-only/client-positioned spawn path has been removed; it must not
present independent roaming actors as synchronized encounters. Use the room
mode for shared visible Pokémon. Legacy GTS/account features remain separate.

## Current validation

Actual 0.2.73 Linux runtime, two separate game processes over localhost ENet,
isolated saves, player saves untouched (public relay tested separately):

- Shared wild rosters, presence and chat: Yellow, Crystal, FireRed.
- Host generation of guest-only maps: all three games.
- Shared town Pokémon: Yellow and Crystal, including separate-map visits.
- Native singles: Yellow, Crystal and FireRed; original parties preserved.
- Native trade: Yellow and FireRed; selected species exchanged, other slots
  unchanged, world/chat connection retained.
- FireRed native doubles: four Pokémon, paired commands and native target
  selection; completed on both clients, parties preserved. Battle Art status
  cards spaced apart; rendered capture inspected.
- Crystal native trades completed on both clients, including Machoke to Machamp
  and Metal Coat Onix to Steelix; held item consumed and other slots preserved.
- Two-client FireRed public-relay pairing, shared rosters, positions and chat
  passed on relay.gen1re.com:7778 (separate from the localhost checks).

Remaining parity work: Gen1/2 online doubles, completed FireRed
Ride integration, mixed-mod compatibility, disconnect/cancel/evolution matrix,
remaining physical UI checks and full five-mod activity tests on current engines. These checks are not yet an all-feature parity claim.

The engine performs its normal battle/trade compatibility handshake; no
fingerprint or protected-module guard is bypassed. The old custom Crystal PVP
backend remains legacy; the new room uses native LinkBattle2 for singles.
