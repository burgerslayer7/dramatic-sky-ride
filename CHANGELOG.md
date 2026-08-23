# Changelog

## 0.3.0-rc.2

- Restricts Flight collision overrides to the player so NPC movement stays native.
- Suppresses ground encounter rolls, step events, automatic warps and trainer sight while airborne in both generations.
- Adds Gen 2 connection discovery/story guards and defers scene scripts until landing.
- Uses the native Gen 2 player state as the sole Visible Surf authority, preventing stale Surf mounts.
- Adds a Gen 2 Surf compatibility contract and tests the encounter/NPC collision guards.

## 0.3.0-rc.1

- Clean rewrite for Gen1Recomp API 2 and shared Gen 1/Gen 2 hooks.
- Keeps Flight, Ground Ride and Visible Surf in the core runtime.
- Uses `movement.collision`, `movement.speed`, `core.update` and `ui.party.submenu` instead of a long chain of monkey-patches.
- Wilds of Kanto public follower resolver is the preferred 2D provider.
- Gen2-3D-Sprites is optional and only consumed through public exports.
- PokéPC 001-251 follower art is the bundled fallback in release packages.
- Crystal 251 remains optional; Gen II species become mountable whenever the active game data exposes them.
- Wild Skies coexistence and sprite-source handoff retained.
- Music packs remain compatible without private filesystem coupling.
