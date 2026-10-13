# Online+ dedicated room server

A standalone, headless room host for the same **LAN / Direct Address** connection used in-game. It loads no Gen1Recomp engine, game ROM, extracted game assets or player save. All players in a room must select the **same game** and use the protocol-2 Online+ release. Other mods are optional.

## Run

Install LÖVE 11.x with its ENet networking module, then unpack this repository/release and run from a terminal:

```sh
./server/run.sh crystal 7777 64
./server/run.sh leafgreen 7777 64
./server/run.sh emerald 7777 64
```

Arguments: game, UDP port, maximum players (4–64). Supported game identifiers: `red`, `blue`, `yellow`, `gold`, `silver`, `crystal`, `firered`, `leafgreen`, `ruby`, `sapphire`, `emerald`. `LOVE_BIN=/path/to/love` selects another LÖVE executable. `ONLINE_SERVER_NAME='Friends Room'` names the LAN listing.

Players use Online → Join and select the discovered LAN room, or enter `server-ip:7777` in Direct Address. Internet hosting uses the same connection: forward the selected **UDP** port to this machine. LAN discovery uses UDP 7776 and LuaSocket; if LuaSocket is unavailable, Direct Address still works. No relay or account service is required.

Console commands:

- `list` — connected player IDs, names and maps.
- `kick p3` — disconnect that player; everyone else remains connected.
- `stop` — close the room and exit.

Players can select another nearby trainer for native singles/trading, or doubles when both clients provide Double Battles. Separate pairs can battle/trade concurrently while room presence and chat continue. The server has no trainer avatar.

## Shared encounters without a ROM on the server

The server owns ground/sky identities, claim arbitration and grants. It elects one capable connected game client per ecology domain to simulate maps using that client's imported game data and optional Wilds/Skies mods. That client also validates collision-dependent throws and sky contacts. All recipients receive the same accepted snapshots; other clients cannot submit populations or grants.

Each election has a monotonically increasing lease epoch. Departing simulation owners are replaced, expired-owner messages are ignored, committed ground identities remain reserved, and active claims still belong to their original player. With no capable simulator, populations pause rather than generating independent local spawns. The server does not independently validate ROM encounter tables: use a trusted simulation owner, as with an ordinary player-hosted room. It is not an anti-cheat server.

The room is ephemeral. Restarting it starts a new shared-world epoch; game saves remain entirely on clients. Never share a client's profile/save directory with another process.

## Verification and capacity

Automated localhost ENet tests cover four clients, guest-to-guest doubles alongside another pair's trade, private-channel sender checks, shared ground/sky encounters, kicking/rejoining, lease replacement and stale snapshot rejection. A separate **64 simultaneous client** transport/state-machine load test verifies complete rosters and room chat. These use mocked game adapters: they do not certify 64 rendered game instances, WAN bandwidth, or 64-player gameplay performance. Native battle/trade gameplay still requires the generation-specific game integration checks.

Packets, JSON nesting, event processing, per-client receive traffic and pending validation requests are bounded. Four handshakes are admitted per update to avoid a simultaneous-join UDP burst.

Release packages must retain `server/` and `lib/crossgen/` together. `server/run.sh` resolves those relative paths; copying only `server/` is insufficient.
