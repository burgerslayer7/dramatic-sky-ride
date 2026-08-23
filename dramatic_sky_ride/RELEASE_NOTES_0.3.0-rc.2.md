## Dramatic Sky Ride 0.3.0-rc.2

This candidate fixes the runtime issues found by loading the mod in the current
Gen1Recomp executable instead of relying only on CI contracts.

- Flight, Ground Ride and Visible Surf were exercised in Red and Gold.
- Flight now changes collision only for the player and suppresses ground
  encounters, trainer sight, step events and automatic warps while airborne.
- Gen 2 connection guards and deferred scene scripts now match the Gen 1 safety
  behavior.
- Visible Surf now follows the real Gen 2 player state after a native dismount.
- The import package contains the 251 pinned PokéPC fallback sprite sheets.

Gen1Recomp 0.1.86 or newer is required. Gen1Recomp 0.1.60 cannot load this API 2
mod and must be updated before importing this candidate.
