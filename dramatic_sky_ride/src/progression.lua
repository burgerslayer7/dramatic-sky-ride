local mod = ...

local Progression = {}
local C, Compat, Settings

local JOHTO_BADGES = {"ZEPHYR","HIVE","PLAIN","FOG","MINERAL","STORM","GLACIER","RISING"}

local function knows(mon, moveId)
  for _, move in ipairs((mon and mon.moves) or {}) do
    local id = type(move) == "table" and move.id or move
    if id == moveId then return true end
  end
  return false
end

local function gen1Badge(game, badge)
  local bag = game and game.save and game.save.inventory or {}
  local v = bag and bag[badge]
  return v ~= nil and v ~= false and v ~= 0
end

local function gen2Badge(game, badge)
  local owned = game and game.save and game.save.player and game.save.player.badges
  if type(owned) ~= "table" then return false end
  if owned[badge] == true then return true end
  for i, name in ipairs(JOHTO_BADGES) do
    if name == badge then return owned[i] == true end
  end
  return false
end

function Progression.hasBadge(game, badge)
  if Compat.isGen2(game) then return gen2Badge(game, badge) end
  return gen1Badge(game, badge)
end

local function canLearn(game, mon, moveId)
  local data = game and game.data
  local def = data and data.pokemon and mon and data.pokemon[mon.species]
  for _, id in ipairs((def and def.tmhm) or {}) do
    if id == moveId then return true end
  end
  return false
end

local function relaxedFieldMove(game, mon, moveId)
  local okRuntime, Runtime = pcall(require, "src.mods.Runtime")
  if not (okRuntime and Runtime and Runtime.wantsHook
      and Runtime.wantsHook("fieldmove.eligibility")) then return false end
  if not canLearn(game, mon, moveId) then return false end
  local world = Compat.world(game)
  if world and type(world.partyKnows) == "function" then
    local ok, user = pcall(world.partyKnows, world, moveId)
    return ok and user ~= nil
  end
  return false
end

function Progression.canTakeOff(game, mon)
  if not Compat.freeRoam(game) then return false, "not in overworld" end
  if not Compat.healthy(mon) then return false, "mount is unavailable" end
  if not C.match("flight", game, mon) then return false, "not a supported flight mount" end

  if Settings.bool("require_fly_move", true)
      and not knows(mon, "FLY") and not relaxedFieldMove(game, mon, "FLY") then
    return false, "FLY REQUIRED"
  end

  if Settings.bool("badge_checks", true) then
    local badge = Compat.isGen2(game) and "STORM" or "THUNDERBADGE"
    if not Progression.hasBadge(game, badge) then
      return false, Compat.isGen2(game) and "STORM BADGE REQUIRED" or "THUNDERBADGE REQUIRED"
    end
  end
  return true
end

function Progression.surfUser(game)
  for _, mon in ipairs(Compat.party(game)) do
    if Compat.healthy(mon) and knows(mon, "SURF") then return mon end
  end
  return nil
end

function Progression.canLandOnWater(game)
  local mon = Progression.surfUser(game)
  if not mon then return false, "SURF REQUIRED" end
  if Settings.bool("badge_checks", true) then
    local badge = Compat.isGen2(game) and "FOG" or "SOULBADGE"
    if not Progression.hasBadge(game, badge) then
      return false, Compat.isGen2(game) and "FOG BADGE REQUIRED" or "SOULBADGE REQUIRED"
    end
  end
  return true, mon
end

function Progression.storyGateBlocks(game, mapId)
  if not Settings.bool("story_gates", true) or type(mapId) ~= "string" then return false end
  local field = game and game.data and game.data.field
  local entry = field and field.badgeGates and field.badgeGates[mapId]
  if not entry then return false end
  local save = game and game.save or {}
  local flags = save.flags or {}
  local bag = save.inventory or {}
  if flags[entry.passedFlag or ("PASSED_" .. mapId)] then return false end
  if entry.badge then return not bag[entry.badge] end
  for _, guard in ipairs(entry.guards or {}) do
    if not (flags[guard.event] or (guard.badge and bag[guard.badge])) then return true end
  end
  return false
end

function Progression.install(deps)
  C, Compat, Settings = deps.catalog, deps.compat, deps.settings
  mod.exports.flightRules = {
    canTakeOff = Progression.canTakeOff,
    hasBadge = Progression.hasBadge,
    storyGateBlocks = Progression.storyGateBlocks,
    flyBadge = function(game) return Compat.isGen2(game) and "STORM" or "THUNDERBADGE" end,
    surfBadge = function(game) return Compat.isGen2(game) and "FOG" or "SOULBADGE" end,
  }
end

return Progression
