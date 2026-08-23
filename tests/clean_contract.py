from pathlib import Path
import json
import re

root = Path(__file__).parents[1]
mod = root / "dramatic_sky_ride"
src = mod / "src"
manifest = json.loads((mod / "manifest.json").read_text(encoding="utf-8"))

assert manifest["api"] == 2
assert set(manifest["games"]) == {"gen1", "gen2"}
assert manifest["version"].startswith("0.3.0")
assert "engine_internals" in manifest.get("permissions", [])
assert "filesystem" not in manifest.get("permissions", [])
assert not list(src.glob("main_*.lua")), "legacy layered runtime must stay deleted"
assert not (src / "parts.txt").exists(), "legacy parts loader must stay deleted"

for name in [
    "catalog", "compat", "settings", "progression", "sprites", "presentation",
    "runtime", "ground", "safety", "stadium", "interop", "hud", "wild_skies", "music",
]:
    assert (src / f"{name}.lua").is_file(), name

text = "\n".join(p.read_text(encoding="utf-8") for p in src.glob("*.lua"))
for hook in [
    "movement.collision", "movement.speed", "core.update", "ui.party.submenu",
    "ui.start_menu.items", "render.hud", "music.select",
]:
    assert hook in text, hook

catalog = (src / "catalog.lua").read_text(encoding="utf-8")
for feature in ["flight", "ground", "surf"]:
    assert feature in catalog.lower()
for species in ["CHARIZARD", "HO_OH", "ARCANINE", "SUICUNE", "LAPRAS", "LUGIA"]:
    assert species in catalog, species
assert len(re.findall(r'\{"[A-Z0-9_]+",\d+', catalog)) == 41

settings = (src / "settings.lua").read_text(encoding="utf-8")
for key in [
    "settings_view", "show_rider", "mount_cries", "mount_hints", "mount_menu",
    "show_followers_while_mounted", "flight_speed", "ground_speed",
    "manual_altitude", "flight_boost", "ground_gallop", "ground_hud",
    "ground_dust", "reverse_ledge_jumps", "remount_after_battle",
    "visible_surf_mounts", "require_fly_move", "badge_checks", "story_gates",
    "discovery_gates", "story_safe", "flight_mount_renderer",
    "pokedex_mount_sizes", "flying_music", "size_overrides",
]:
    assert f'key="{key}"' in settings or f'key = "{key}"' in settings, key

progression = (src / "progression.lua").read_text(encoding="utf-8")
for token in ["THUNDERBADGE", "SOULBADGE", "STORM", "FOG", "fieldmove.eligibility", "badgeGates"]:
    assert token in progression, token

sprites = (src / "sprites.lua").read_text(encoding="utf-8")
assert "resolveFollowerSprite" in sprites
assert "STADIUM2_OVERWORLD_MODELS" in sprites
assert "STADIUM_OVERWORLD_MODELS" in sprites
assert "bundled_pokepc" in sprites

compat = (src / "compat.lua").read_text(encoding="utf-8")
assert "mod.world.current" not in compat
assert "mod.world.overworld" in compat
assert 'state == "surf" or state == "surf_pika"' in compat
assert "applyPlayerState" in compat

runtime = (src / "runtime.lua").read_text(encoding="utf-8")
for token in [
    "mountSprite", "native surf started", "start Surf through the game first",
    "dramaticSkyRideMountSpecies", "_stadiumSkyRideSpecies", "freeFlying",
    "amphibious", "pendingResume", "triggerright", "triggerleft", "MOUNTS",
]:
    assert token in runtime, token

presentation = (src / "presentation.lua").read_text(encoding="utf-8")
for token in ["REF_METERS", "dynamic_shadow", "landing_marker", "ground_dust", "show_rider", "visualAltitude"]:
    assert token in presentation, token

ground = (src / "ground.lua").read_text(encoding="utf-8")
assert "checkLedgeHop" in ground and "tryLedgeJump" in ground

safety = (src / "safety.lua").read_text(encoding="utf-8")
assert "legitimately_reached_maps" in safety
assert "crossConnection" in safety
assert "AREA NOT VISITED" in safety

stadium = (src / "stadium.lua").read_text(encoding="utf-8")
assert "OverworldStadium" in stadium and "tagger" in stadium

interop = (src / "interop.lua").read_text(encoding="utf-8")
for token in ["DRAMALESS_SHAPE", "BATTLE_ART_VOXEL_FORK", "otf-player-switcher", 'keyboardDown("j")']:
    assert token in interop, token

hud = (src / "hud.lua").read_text(encoding="utf-8")
assert "mount_hints" in hud and "altitude_display" in hud and "ground_hud" in hud

wild = (src / "wild_skies.lua").read_text(encoding="utf-8")
assert "takeFlyer" in wild and "queueScript" in wild

music = (src / "music.lua").read_text(encoding="utf-8")
assert "Music_Surfing" in music and "Music_BikeRiding" in music
assert "music.select" in music
assert "filesystem" not in music

optional = manifest["optional_dependencies"]
for dep in [
    "wild_skies", "CRYSTAL_251", "Music_FRLG", "BATTLE_ART_VOXEL_FORK",
    "DRAMALESS_SHAPE", "STADIUM2_OVERWORLD_MODELS", "otf-player-switcher",
]:
    assert any(dep in x for x in optional), dep

workflow = (root / ".github/workflows/clean-rewrite.yml").read_text(encoding="utf-8")
assert "78c80f61e166e67efd92d929207caa92e896e789" in workflow
assert "pokepc-fallback" in workflow
assert "follower_[0-9][0-9][0-9]" in workflow
assert "dramatic_sky_ride/manifest.json" in workflow
assert "dramatic_sky_ride/main.lua" in workflow

print("clean-contract-ok")
