# Dramatic Sky Ride 0.3.0 clean rewrite

`release/0.3.0-clean-rewrite` replaces the historical layered runtime with a small Gen1Recomp API 2 implementation.

Requires Gen1Recomp 0.1.86 or newer. Older builds, including 0.1.60, cannot load this API 2 runtime.

Core scope remains **Flight + Ground Ride + Visible Surf** on both Gen 1 and Gen 2. Visible Surf is presentation-only: the base game remains authoritative for Surf progression, transitions and collision.

Sprite/provider order is: registered provider → Gen2-3D-Sprites public resolver (when available) → Wilds of Kanto public `resolveFollowerSprite` → bundled PokéPC fallback → installed PokéPC provider. The release package bundles the 251 PokéPC follower sheets; source checkouts can omit them and still use installed providers.

Optional compatibility remains for Crystal 251, Wild Skies, Gen2-3D-Sprites and the FRLG/HGSS/LGPE music mods. Integrations are isolated and never take ownership of another mod's private internals.

This branch is a release candidate and is not a published release/tag.
