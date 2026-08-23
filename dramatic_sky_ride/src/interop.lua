local mod = ...

local Interop = {}
local runtime, compat, settings
local lastJ = false

local function keyboardDown(key)
  return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(key) or false
end

local function clear(player)
  if not player then return end
  player.dramaticSkyRideCameraFollow=nil
  player.dramaticSkyRideCameraAltitude=nil
  player.dramaticSkyRideLandingMarker=nil
  player.dramaticSkyRideDynamicShadow=nil
  player.dramaticSkyRideGroundDust=nil
end

local function sync(game)
  local player=compat.player(game)
  if not player then return end
  local s=runtime.public.state()
  if not s.mode then return clear(player) end
  player.dramaticSkyRideCameraFollow=settings.bool("camera_follow",true)
  player.dramaticSkyRideCameraAltitude=settings.bool("camera_altitude",true)
  player.dramaticSkyRideLandingMarker=settings.bool("landing_marker",true)
  player.dramaticSkyRideDynamicShadow=settings.bool("dynamic_shadow",true)
  player.dramaticSkyRideGroundDust=settings.bool("ground_dust",true)
end

local function dramalessActive()
  return compat.find("DRAMALESS_SHAPE") ~= nil
end

function Interop.install(deps)
  runtime,compat,settings=deps.runtime,deps.compat,deps.settings
  mod.hooks:wrap("core.update",function(nextFn,game,dt)
    nextFn(game,dt)
    sync(game)

    -- Dramaless historically uses G in its own free-camera controls. Keep the
    -- universal G shortcut, but restore J as the conflict-free Ground Ride
    -- alias whenever Dramaless is installed.
    local down=dramalessActive() and settings.bool("mount_shortcut",true) and keyboardDown("j")
    if down and not lastJ then runtime.public.toggle(game,"ground") end
    lastJ=down
  end,940)
end

function Interop.status()
  return {
    battleArt=compat.find("BATTLE_ART_VOXEL_FORK") ~= nil,
    dramaless=dramalessActive(),
    otfPlayerSwitcher=compat.find("otf-player-switcher") ~= nil,
  }
end

return Interop
