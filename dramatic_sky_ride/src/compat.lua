local mod = ...

local Compat = {}
local GameVersion
pcall(function() GameVersion = require("src.core.GameVersion") end)

local function liveGame(game)
  return game or mod.game or (mod.world and mod.world.game)
end

function Compat.game(game) return liveGame(game) end

function Compat.world(game)
  if mod.world and type(mod.world.overworld) == "function" then
    local ok, world = pcall(mod.world.overworld, mod.world)
    if ok and world then return world end
  end
  game = liveGame(game)
  return game and (game.overworld or game.world) or nil
end

function Compat.player(game)
  local world = Compat.world(game)
  return world and world.player or nil
end

function Compat.generation(game)
  game = liveGame(game)
  if GameVersion and type(GameVersion.generation) == "function" then
    local ok, value = pcall(GameVersion.generation)
    if ok and tonumber(value) then return tonumber(value) end
  end
  if game and game.world and not game.overworld then return 2 end
  return 1
end

function Compat.isGen1(game) return Compat.generation(game) == 1 end
function Compat.isGen2(game) return Compat.generation(game) == 2 end

function Compat.isSurfing(game)
  local world = Compat.world(game)
  local player = world and world.player
  if Compat.isGen2(game) then
    local state = world and world.playerState
    return state == "surf" or state == "surf_pika"
  end
  return player and player.surfing == true or false
end

function Compat.setSurfing(game, enabled, mon)
  local world = Compat.world(game)
  local player = world and world.player
  if not (world and player) then return false end
  enabled = enabled == true

  if Compat.isGen2(game) and type(world.applyPlayerState) == "function" then
    if enabled then
      local state = "surf"
      local okMoves, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
      if okMoves and FieldMoves and type(FieldMoves.surfType) == "function" then
        local ok, value = pcall(FieldMoves.surfType, mon)
        if ok and (value == "surf" or value == "surf_pika") then state = value end
      end
      pcall(world.applyPlayerState, world, state)
    elseif world.playerState == "surf" or world.playerState == "surf_pika" then
      pcall(world.applyPlayerState, world, "normal")
    end
    return true
  end

  if player.surfing ~= nil then
    player.surfing = enabled
    return true
  end
  return false
end

function Compat.isWaterCell(game, x, y)
  local world = Compat.world(game)
  local map, player = world and world.map, world and world.player
  if not map then return false end
  x = x ~= nil and x or (player and player.cellX)
  y = y ~= nil and y or (player and player.cellY)
  if x == nil or y == nil then return false end
  if type(map.isWaterCell) == "function" then
    local ok, yes = pcall(map.isWaterCell, map, x, y)
    return ok and yes == true
  end
  return false
end

function Compat.mapId(game)
  local world = Compat.world(game)
  local map = world and world.map
  local def = map and map.def
  return (def and (def.id or def.mapId or def.name)) or (world and world.mapId) or nil
end

function Compat.freeRoam(game)
  game = liveGame(game)
  local world = Compat.world(game)
  if not (game and world and world.player) then return false end
  if type(world.acceptsMenuInput) == "function" then
    local ok, yes = pcall(world.acceptsMenuInput, world)
    if ok then return yes == true end
  end
  local stack = game.stack
  if not stack or type(stack.top) ~= "function" then return true end
  return stack:top() == world
end

function Compat.party(game)
  game = liveGame(game)
  return (game and game.save and game.save.party) or {}
end

function Compat.healthy(mon)
  return mon ~= nil and not mon.isEgg and not mon.egg and (tonumber(mon.hp) or 1) > 0
end

function Compat.find(id)
  if not mod.find then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

function Compat.say(game, text)
  game = liveGame(game)
  if mod.ui and type(mod.ui.message) == "function" then
    local ok = pcall(mod.ui.message, mod.ui, text)
    if ok then return end
  end
  mod.log:info("%s", tostring(text):gsub("\n", " "))
end

function Compat.closeMenus(game)
  game = liveGame(game)
  local stack = game and game.stack
  if not stack then return end
  if Compat.isGen2(game) and type(stack.clear) == "function" then
    pcall(stack.clear, stack)
  elseif type(stack.pop) == "function" and type(stack.top) == "function" and stack:top() ~= nil then
    pcall(stack.pop, stack)
  end
end

function Compat.inputDown(game, action)
  game = liveGame(game)
  local input = game and game.input
  local state = input and input.state
  return type(state) == "table" and state[action] == true
end

function Compat.gamepadDown(button)
  local js = love and love.joystick
  if not (js and js.getJoysticks) then return false end
  local ok, pads = pcall(js.getJoysticks)
  if not ok or type(pads) ~= "table" then return false end
  for _, pad in ipairs(pads) do
    if pad and type(pad.isGamepad) == "function" and pad:isGamepad()
        and type(pad.isGamepadDown) == "function" then
      local downOk, down = pcall(pad.isGamepadDown, pad, button)
      if downOk and down then return true end
    end
  end
  return false
end

function Compat.gamepadAxis(axis)
  local js = love and love.joystick
  if not (js and js.getJoysticks) then return 0 end
  local ok, pads = pcall(js.getJoysticks)
  if not ok or type(pads) ~= "table" then return 0 end
  for _, pad in ipairs(pads) do
    if pad and type(pad.isGamepad) == "function" and pad:isGamepad()
        and type(pad.getGamepadAxis) == "function" then
      local axisOk, value = pcall(pad.getGamepadAxis, pad, axis)
      if axisOk and math.abs(tonumber(value) or 0) > 0.01 then return tonumber(value) or 0 end
    end
  end
  return 0
end

function Compat.rumble(low, high, seconds)
  local js = love and love.joystick
  if not (js and js.getJoysticks) then return false end
  local ok, pads = pcall(js.getJoysticks)
  if not ok or type(pads) ~= "table" then return false end
  local used = false
  for _, pad in ipairs(pads) do
    if pad and type(pad.setVibration) == "function" then
      local vok = pcall(pad.setVibration, pad, low or 0, high or low or 0, seconds or 0.08)
      used = used or vok
    end
  end
  return used
end

function Compat.crystalStatus()
  local handle = Compat.find("CRYSTAL_251")
  local ex = handle and handle.exports
  return {
    active = handle ~= nil,
    version = ex and ex.version or nil,
    dexSize = ex and tonumber(ex.dexSize) or nil,
    fingerprint = ex and ex.fingerprint or nil,
  }
end

return Compat
