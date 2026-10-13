# Online+ dedicated room server

A standalone, headless room host for the same **LAN / Direct Address** connection used in-game. It loads no Gen1Recomp engine, game ROM, extracted game assets or player save. All players in a room must select the **same game** and use the protocol-2 Online+ release. Other mods are optional.

## Run

Install LÖVE 11.x with its ENet networking module, then unpack this repository/release and run from a terminal:

```sh
./server/run.sh crystal 7777 128
./server/run.sh leafgreen 7777 128
./server/run.sh emerald 7777 128
```

Arguments: game, UDP port, maximum players (4–128; default 128). Supported game identifiers: `red`, `blue`, `yellow`, `gold`, `silver`, `crystal`, `firered`, `leafgreen`, `ruby`, `sapphire`, `emerald`. `LOVE_BIN=/path/to/love` selects another LÖVE executable. `ONLINE_SERVER_NAME='Friends Room'` names the LAN listing. `ONLINE_PUBLIC_IP=203.0.113.10` sets a public IPv4 display override.

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

Automated localhost ENet tests cover four clients, guest-to-guest doubles alongside another pair's trade, private-channel sender checks, shared ground/sky encounters, kicking/rejoining, lease replacement and stale snapshot rejection. Separate **64 and 128 simultaneous client** transport/state-machine load tests verify complete rosters and room chat. These use mocked game adapters: they do not certify 128 rendered game instances, WAN bandwidth, or 128-player gameplay performance. Four actual Crystal clients on Gen1Recomp 0.3.85 also completed a guest-to-guest native double battle while the host and another guest observed; both fighters returned to the same room. Other editions and native trading still need separate completion checks.

Packets, JSON nesting, event processing, per-client receive traffic and pending validation requests are bounded. Four handshakes are admitted per update to avoid a simultaneous-join UDP burst.

Release packages must retain `server/` and `lib/crossgen/` together. `server/run.sh` resolves those relative paths; copying only `server/` is insufficient.

## VPS / bare-metal service

The supplied `online-plus.service` runs headlessly under a restricted service
account. Install LÖVE 11.x with ENet and LuaSocket, place the whole mod at
`/opt/online-plus`, then edit the unit's game, UDP port and capacity. Install it
with your service manager and enable/start `online-plus.service`. No desktop,
ROM, Gen1Recomp installation or second mod is required. Output goes to the
journal; stop/restart through the service manager. Interactive `list`/`kick`
commands are available when running `server/run.sh` in a terminal instead.

Permit the chosen UDP game port in the machine and provider firewalls. Forward
that port when the host is behind a router; a VPS with a public address normally
needs only firewall configuration. UDP 7776 discovery is local-network only;
Internet players use the public IP or DNS name and game port. Discovering a
public IP does not verify port forwarding or bypass carrier-grade NAT.

## Host addresses

The game host screen shows the game port, LAN IPv4, public IPv4 and player list.
The dedicated server logs its addresses. Public-IP lookup runs once per hosting
session on a background thread using [ipify](https://www.ipify.org/); it sends no
player, save or room data. TLS is used when LuaSec is available; stock LÖVE builds
without LuaSec use the provider's HTTP endpoint. This is display-only, never an
authentication signal. Lookup failure shows `Unavailable` and never blocks
hosting. Set `ONLINE_PUBLIC_IP` on the dedicated server to avoid the lookup.

Position updates are coalesced at 10 Hz into batches of at most 32 players,
reducing per-client packet/event overhead in large rooms. Battle/trade channels,
chat and authoritative encounter messages retain reliable delivery.
