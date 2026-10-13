# Four native clients

Run `four-client-gb.lua` or `four-client-gen3.lua` through the engine's
`POKEPORT_DRIVER` in four separate, disposable save identities ending in `-qa`.
Set `QA_ROLE=host`, `a`, `b`, or `c`, `QA_MODE=double`, and a distinct writable
`SHOT_DIR` for each process. Start all four concurrently on one machine. GB
uses UDP27991; GBA uses UDP27992. The host uses the reserved documentation IP
203.0.113.10 to suppress public-address lookup. Never point these drivers at
normal player saves: they replace the current party and location for testing.

Roles a and b invite/accept and play a native battle, while host and c remain
in the shared overworld. Each client checks three remote room members. Fighters
check command entry, native completion, retained room membership and send DONE;
observers wait for both messages. Native controls drive turn resolution; no
battle completion or damage outcome is injected. The GBA fixture uses Explosion
to shorten a match (the engine normalizes link-battle levels).

Verified with official Gen1Recomp 0.3.85 on 2026-10-13:

- Yellow: all four native processes completed, guest-to-guest double win/loss,
  target selection, native return and both room observers retained. Yellow
  profile used Online, Double Battles and Modern UI; no scenery mod.
- Crystal: same completed flow with the seven companion mods loaded.
- Emerald: four native processes reached commands, target selection and damage;
  completion remains under verification. Do not treat transport mocks as native
  Emerald battle completion evidence.
- Yellow host menu: separate LAN/public address and port title visually checked
  with the engine pixel font at 640x480.

These tests do not certify simultaneous trades, WAN/NAT traversal, controller
hardware, every game variant, or 128 native rendering clients. The separate
`multi_room_test.lua` tests high-capacity transport with lightweight adapters.
