local mod = ...

local Safety = {}
local runtime, compat, settings, progression
local reachedCache = nil
local overrides = {}
local lastNoticeAt = -100

local function now()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.clock()
end

local function gated(mapId)
  if type(mapId) ~= "string" or mapId == "" then return false end
  if overrides[mapId] ~= nil then return overrides[mapId] end
  return true
end

local function reached()
  if type(reachedCache) == "table" then return reachedCache end
  local value={}
  if mod.save and type(mod.save.get)=="function" then
    local ok,saved=pcall(mod.save.get,mod.save,"legitimately_reached_maps",{})
    if ok and type(saved)=="table" then value=saved end
  end
  reachedCache=value
  return value
end

local function persist()
  if mod.save and type(mod.save.set)=="function" then
    pcall(mod.save.set,mod.save,"legitimately_reached_maps",reached())
  end
end

local function mark(mapId)
  if type(mapId) ~= "string" or mapId == "" then return false end
  local r=reached()
  if r[mapId] then return false end
  r[mapId]=true
  persist()
  return true
end

local function isReached(mapId)
  if not gated(mapId) then return true end
  return reached()[mapId] == true
end

local function notice(game,text)
  local t=now()
  if t-lastNoticeAt < 1.0 then return end
  lastNoticeAt=t
  compat.say(game,text)
  compat.rumble(0.18,0.35,0.12)
end

local function blocks(game,target)
  if not runtime.public.isFlying() then return false end
  if settings.bool("discovery_gates",true) and gated(target) and not isReached(target) then
    return true,"AREA NOT VISITED"
  end
  if settings.bool("story_gates",true) and progression.storyGateBlocks(game,target) then
    return true,"STORY PROGRESSION BLOCKS THIS AREA"
  end
  return false
end

local function installGen1ConnectionGuard()
  local ok,OW=pcall(require,"src.world.OverworldController")
  if not (ok and OW and type(OW.crossConnection)=="function") then return false end
  if OW.dramaticSkyRideCleanSafetyGate then return true end
  local native=OW.crossConnection
  function OW:crossConnection(dir,conn,...)
    local game=compat.game(nil)
    local target=conn and (conn.mapId or conn.map)
    local blocked,reason=blocks(game,target)
    if blocked then
      notice(game,reason)
      return false
    end
    return native(self,dir,conn,...)
  end
  OW.dramaticSkyRideCleanSafetyGate=true
  return true
end

local function installGen2ConnectionGuard()
  local ok,World=pcall(require,"src.world.gen2.World")
  if not (ok and World and type(World.tryConnection)=="function") then return false end
  if World.dramaticSkyRideCleanSafetyGate then return true end
  local native=World.tryConnection
  local keys={up="north",down="south",left="west",right="east"}
  function World:tryConnection(dir,...)
    local conn=self.map and type(self.map.connection)=="function"
      and self.map:connection(keys[dir]) or nil
    local game=compat.game(self.game)
    local blocked,reason=blocks(game,conn and conn.mapId)
    if blocked then
      notice(game,reason)
      return false
    end
    return native(self,dir,...)
  end
  World.dramaticSkyRideCleanSafetyGate=true
  return true
end

local function installGen1AirSafety()
  local ok,OW=pcall(require,"src.world.OverworldController")
  if not (ok and OW) then return false end
  if OW.dramaticSkyRideCleanAirSafety then return true end
  if type(OW.checkTrainerSight)=="function" then
    local native=OW.checkTrainerSight
    function OW:checkTrainerSight(...)
      if runtime.public.isFlying() then return end
      return native(self,...)
    end
  end
  local stepName="onStep".."Complete"
  if type(OW[stepName])=="function" then
    local native=OW[stepName]
    OW[stepName]=function(self,...)
      if runtime.public.isFlying() then
        self.boulderTried=nil
        local p=self.player
        local entry=self.warpEntryCell
        if entry and p and (p.cellX ~= entry.x or p.cellY ~= entry.y) then
          self.warpEntryCell=nil
        end
        self.standingOnWarp=false
        return
      end
      return native(self,...)
    end
  end
  OW.dramaticSkyRideCleanAirSafety=true
  return true
end

local function installGen2AirSafety()
  local ok,World=pcall(require,"src.world.gen2.World")
  if not (ok and World) then return false end
  if World.dramaticSkyRideCleanAirSafety then return true end
  local methods={
    "checkTrainerBattle","checkWarpOnArrive","checkCarpetWhileStanding",
    "tryCoordScript","countStep","tryWildEncounter",
  }
  local function guard(name,native)
    World[name]=function(self,...)
      if runtime.public.isFlying() then return false end
      return native(self,...)
    end
  end
  for _,name in ipairs(methods) do
    local native=World[name]
    if type(native)=="function" then
      guard(name,native)
    end
  end
  if type(World.trySceneScript)=="function" then
    local native=World.trySceneScript
    function World:trySceneScript(...)
      if runtime.public.isFlying() then
        self.pendingSceneScript=true
        return false
      end
      return native(self,...)
    end
  end
  World.dramaticSkyRideCleanAirSafety=true
  return true
end

function Safety.install(deps)
  runtime,compat,settings,progression=deps.runtime,deps.compat,deps.settings,deps.progression
  installGen1ConnectionGuard()
  installGen2ConnectionGuard()
  installGen1AirSafety()
  installGen2AirSafety()

  mod.events:on("save.loaded",function() reachedCache=nil end)
  mod.events:on("save.created",function() reachedCache=nil end)
  mod.events:on("game.ready",function(ev)
    reachedCache=nil
    if not runtime.public.isFlying() then
      mark(compat.mapId(ev and ev.game or nil))
    end
  end)
  mod.events:on("map.entered",function(ev)
    if runtime.public.isFlying() then return end
    mark(ev and ev.mapId or compat.mapId(nil))
  end)

  mod.exports.flightRules=mod.exports.flightRules or {}
  mod.exports.flightRules.discoveryGates=function() return settings.bool("discovery_gates",true) end
  mod.exports.flightRules.isMapReached=isReached
  mod.exports.flightRules.markMapReached=mark
  mod.exports.flightRules.registerDiscoveryGate=function(mapId,enabled)
    if type(mapId)~="string" or mapId=="" then return false end
    overrides[mapId]=enabled ~= false
    return true
  end
  mod.exports.flightRules.clearDiscoveryGateOverride=function(mapId)
    if type(mapId)~="string" or mapId=="" then return false end
    overrides[mapId]=nil
    return true
  end
end

return Safety
