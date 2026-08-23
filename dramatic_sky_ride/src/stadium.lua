local mod = ...

local Stadium = {}
local runtime, compat, presentation
local taggedPlayer = nil
local taggedSpecies = nil
local providerId = nil
local tagger = nil

local PROVIDERS = { "STADIUM2_OVERWORLD_MODELS", "STADIUM_OVERWORLD_MODELS" }

local function clearTag()
  if taggedPlayer and tagger then pcall(tagger, taggedPlayer, nil) end
  taggedPlayer, taggedSpecies = nil, nil
end

local function resolveTagger()
  tagger, providerId = nil, nil
  for _, id in ipairs(PROVIDERS) do
    local h = compat.find(id)
    local ex = h and h.exports
    local lib = ex and ex.lib
    if lib and type(lib.require) == "function" then
      local ok, ow = pcall(lib.require, "OverworldStadium")
      if ok and ow and type(ow.tag) == "function" then
        tagger = ow.tag
        providerId = id
        return true
      end
    end
  end
  return false
end

local function sync(game)
  local s = runtime.public.state()
  local player = compat.player(game)
  local should = s.mode ~= nil and presentation.rendererWantsStadium()
  if not should or not player then
    clearTag()
    return
  end
  if not tagger then resolveTagger() end
  if not tagger then return end
  if taggedPlayer == player and taggedSpecies == s.species then return end
  clearTag()
  local ok, accepted = pcall(tagger, player, s.species or s.dex)
  if ok and accepted ~= false then
    taggedPlayer, taggedSpecies = player, s.species
  end
end

function Stadium.install(deps)
  runtime, compat, presentation = deps.runtime, deps.compat, deps.presentation
  mod.events:on("mods.loaded", function() clearTag(); resolveTagger() end)
  mod.events:on("game.ready", function() clearTag(); resolveTagger() end)
  mod.hooks:wrap("core.update", function(nextFn, game, dt)
    nextFn(game, dt)
    sync(game)
  end, 930)
end

function Stadium.status()
  return {
    provider = providerId,
    taggerAvailable = tagger ~= nil,
    tagged = taggedPlayer ~= nil,
    species = taggedSpecies,
  }
end

return Stadium
