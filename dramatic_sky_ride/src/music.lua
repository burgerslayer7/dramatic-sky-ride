local mod = ...

local MusicCompat = {}
local runtime, compat, settings
local knownPackActive = false
local registeredTracks = {}
local wasFlying = false
local lastSelection = "none"

local CANONICAL = {
  surf = "Music_Surfing",
  bike = "Music_BikeRiding",
}

local function selectedKey()
  local key = tostring(settings and settings.get("flying_music", "none") or "none"):lower()
  if CANONICAL[key] or registeredTracks[key] then return key end
  return "none"
end

local function selectedSong()
  local key = selectedKey()
  local custom = registeredTracks[key]
  if custom then return custom.songId, key end
  return CANONICAL[key], key
end

local function refreshMapMusic(game)
  local ok, Music = pcall(require, "src.core.Music")
  if not (ok and Music and type(Music.restoreMap) == "function") then return false end
  local data = game and game.data
  local restored = pcall(Music.restoreMap, data)
  return restored == true
end

local function registerFlightTrack(id, songId, label)
  if type(id) ~= "string" or id == "" or id == "none" then return false end
  if type(songId) ~= "string" or songId == "" then return false end
  registeredTracks[id] = { songId = songId, label = label or id }
  return true
end

local function detectPacks()
  knownPackActive = compat.find("Music_FRLG") ~= nil
    or compat.find("Music_HGSS") ~= nil
    or compat.find("Music_LGPE") ~= nil
end

function MusicCompat.install(deps)
  runtime, compat, settings = deps.runtime, deps.compat, deps.settings
  mod.exports.registerFlightTrack = registerFlightTrack
  mod.exports.flyingMusicTracks = function()
    local out = {
      { key="surf", label="Surf Theme", songId=CANONICAL.surf, provider="engine/music override chain" },
      { key="bike", label="Bike Theme", songId=CANONICAL.bike, provider="engine/music override chain" },
    }
    local ids = {}
    for id in pairs(registeredTracks) do ids[#ids+1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local t = registeredTracks[id]
      out[#out+1] = { key=id, label=t.label, songId=t.songId, provider="registered" }
    end
    return out
  end

  detectPacks()
  mod.events:on("mods.loaded", detectPacks)

  -- Choose only map music while airborne. Battles, victories, jingles, cries
  -- and direct cues retain their normal priority. Music packs that override
  -- Music_Surfing / Music_BikeRiding automatically provide the audio here.
  mod.hooks:wrap("music.select", function(nextFn, chosen, ctx)
    local song = runtime.public.isFlying() and selectedSong() or nil
    if song and ctx and ctx.reason == "map" then
      return nextFn(song, ctx)
    end
    return nextFn(chosen, ctx)
  end, 900)

  -- Entering/leaving Flight asks the engine to reselect the map song. This
  -- goes through music.select above, so no private audio file is scanned or
  -- copied and normal map music returns immediately after landing.
  mod.hooks:wrap("core.update", function(nextFn, game, dt)
    nextFn(game, dt)
    local flying = runtime.public.isFlying()
    local selection = selectedKey()
    if flying ~= wasFlying or (flying and selection ~= lastSelection) then
      wasFlying = flying
      lastSelection = selection
      refreshMapMusic(game)
    end
  end, 1100)

  mod.events:on("mod.options_changed", function(payload)
    if payload and payload.mod == mod.id and payload.key == "flying_music" then
      lastSelection = "__refresh__"
    end
  end)
end

function MusicCompat.status()
  local names = {}
  for id in pairs(registeredTracks) do names[#names+1] = id end
  table.sort(names)
  local song, key = selectedSong()
  return {
    compatible = true,
    knownPackActive = knownPackActive,
    selected = key,
    activeSong = runtime and runtime.public.isFlying() and song or nil,
    registeredTracks = names,
    canonicalSurf = CANONICAL.surf,
    canonicalBike = CANONICAL.bike,
  }
end

return MusicCompat
