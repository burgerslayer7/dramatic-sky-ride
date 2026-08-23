local mod = ...

local WildSkies = {}
local runtime, compat, sprites, settings
local SOURCE_ID = "dramatic_sky_ride_fallback"
local registered = false
local cooldown = 0
local battleRest = 0
local interceptCount = 0
local lastIntercept = nil

local function handle()
  return compat and compat.find("wild_skies") or nil
end

local function syncAirborne()
  local p = compat and compat.player()
  if not p then return end
  local flying = runtime and runtime.public.isFlying()
  if flying then
    p.freeFlying = true
    p.dramaticSkyRideFreeFlying = true
  elseif p.dramaticSkyRideFreeFlying then
    p.freeFlying = nil
    p.dramaticSkyRideFreeFlying = nil
  end
end

local function registerFallback()
  local h = handle()
  local ex = h and h.exports
  if not ex then return false end
  if type(ex.unregisterSpriteSource) == "function" then pcall(ex.unregisterSpriteSource, SOURCE_ID) end
  if type(ex.registerSpriteSource) ~= "function" then return false end
  local ok, accepted = pcall(ex.registerSpriteSource, {
    id = SOURCE_ID,
    resolve = function(_, game, species, dex)
      local def = sprites.resolve(game, species, dex, "flight")
      if def and def.providerId ~= "wild_skies" then return def end
      return nil
    end,
  })
  registered = ok and accepted ~= false
  return registered
end

local function queueBattle(game, hit)
  if not (hit and hit.species and mod.world and type(mod.world.queueScript) == "function") then return false end
  local level = math.max(2, tonumber(hit.level) or 5)
  local ok, queued = pcall(mod.world.queueScript, mod.world, {
    { "start_battle", "wild", hit.species, level },
  })
  if ok and queued == true then
    interceptCount = interceptCount + 1
    lastIntercept = {
      species=hit.species,
      level=level,
      altitude=runtime.public.altitude(),
      mount=runtime.public.state().species,
    }
    cooldown = 2.0
    battleRest = 0.75
    pcall(function()
      mod.events:emit("mod.dramatic_sky_ride.flyer_intercepted", lastIntercept)
    end)
    return true
  end
  return false
end

local function tryIntercept(game)
  if not runtime.public.isFlying() or not settings.bool("air_encounters",true) then return end
  if cooldown > 0 or battleRest > 0 or not compat.freeRoam(game) then return end
  local h=handle()
  local ex=h and h.exports
  local take=ex and ex.takeFlyer
  local p=compat.player(game)
  if not (p and type(take)=="function" and mod.world and type(mod.world.queueScript)=="function") then return end

  -- takeFlyer is Wild Skies' public atomic removal seam. Only consume the
  -- flyer when DSR can immediately hand it to the engine's script/battle API.
  local ok, hit=pcall(take,p.cellX,p.cellY,1)
  if not (ok and type(hit)=="table" and hit.species) then return end
  if not queueBattle(game,hit) then
    mod.log:warn("Wild Skies flyer %s was claimed but battle queue rejected",tostring(hit.species))
  end
end

function WildSkies.install(deps)
  runtime,compat,sprites,settings=deps.runtime,deps.compat,deps.sprites,deps.settings
  mod.events:on("mods.loaded",function() registerFallback(); syncAirborne() end)
  mod.events:on("game.ready",function() registerFallback(); syncAirborne() end)
  mod.events:on("battle.ended",function() battleRest=1.5 end)
  mod.hooks:wrap("core.update",function(nextFn,game,dt)
    nextFn(game,dt)
    local frame=tonumber(dt) or 1/60
    cooldown=math.max(0,cooldown-frame)
    battleRest=math.max(0,battleRest-frame)
    syncAirborne()
    tryIntercept(game)
  end,910)
end

function WildSkies.status()
  local h=handle()
  local ex=h and h.exports
  return {
    active=h ~= nil,
    version=ex and ex.version or nil,
    spriteSourceRegistered=registered,
    takeFlyer=ex and type(ex.takeFlyer)=="function" or false,
    sharedSky=ex and type(ex.sharedSkyFieldSnapshot)=="function" or false,
    airEncounters=settings and settings.bool("air_encounters",true) or true,
    interceptCount=interceptCount,
    lastIntercept=lastIntercept,
  }
end

return WildSkies
