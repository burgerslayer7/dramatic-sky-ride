local mod = ...

local Ground = {}
local runtime, compat, settings
local opposite = { up="down", down="up", left="right", right="left" }

local function riding()
  local s = runtime.public.state()
  return s and s.mode == "ground"
end

local function occupied(entities, x, y, except)
  for _, e in ipairs(entities or {}) do
    if e ~= except and not e.passable then
      if (e.cellX == x and e.cellY == y)
          or (e.moving and e.targetX == x and e.targetY == y) then return true end
    end
  end
  return false
end

local function installGen1()
  local okOW, OW = pcall(require, "src.world.OverworldController")
  local okCollision, Collision = pcall(require, "src.world.Collision")
  local okMap, Map = pcall(require, "src.world.Map")
  if not (okOW and okCollision and okMap and type(OW.checkLedgeHop) == "function") then return false end
  if OW.dramaticSkyRideCleanReverseLedge then return true end

  local native = OW.checkLedgeHop
  function OW:checkLedgeHop(dir)
    if native(self, dir) then return true end
    if not riding() or not settings.bool("reverse_ledge_jumps", true) then return false end
    local p, map = self.player, self.map
    local reverse = opposite[dir]
    if not (p and map and reverse) then return false end
    local fx, fy = Collision.target(p.cellX, p.cellY, dir)
    if not map:inBounds(fx, fy) then return false end
    local front = map:cellTile(fx, fy)
    local game = compat.game(nil)
    local field = game and game.data and game.data.field
    local official = false
    for _, ledge in ipairs((field and field.ledges) or {}) do
      if (ledge.tileset or "OVERWORLD") == map.def.tileset
          and ledge.facing == reverse and ledge.input == reverse
          and ledge.ledgeTile == front then
        official = true
        break
      end
    end
    if not official then return false end

    local lx, ly = Collision.target(fx, fy, dir)
    if not map:inBounds(lx, ly) then return false end
    if map.isWaterCell and map:isWaterCell(lx, ly) then return false end
    if Collision.occupied(self.entities, lx, ly, p) then return false end
    if not map:isWalkableCell(lx, ly) then return false end
    for _, warp in ipairs((map.def and map.def.warps) or {}) do
      if tonumber(warp.x) == lx and tonumber(warp.y) == ly then return false end
    end

    p.hopFrames, p.hopTotal = 32, 32
    if type(self.scriptMove) == "function" then
      self:scriptMove(p, dir, 2)
      compat.rumble(0.14,0.24,0.12)
      return true
    end
    return false
  end
  OW.dramaticSkyRideCleanReverseLedge = true
  return true
end

local function installGen2()
  local okWorld, World = pcall(require, "src.world.gen2.World")
  local okMap, Map = pcall(require, "src.world.gen2.Map")
  local okPerm, Permissions = pcall(require, "src.world.gen2.Permissions")
  if not (okWorld and okMap and okPerm and type(World.tryLedgeJump) == "function") then return false end
  if World.dramaticSkyRideCleanReverseLedge then return true end

  local native = World.tryLedgeJump
  function World:tryLedgeJump(dir, ...)
    if native(self, dir, ...) then return true end
    if not riding() or not settings.bool("reverse_ledge_jumps", true) then return false end
    local p, map = self.player, self.map
    local reverse = opposite[dir]
    local delta = Map.DELTA and Map.DELTA[dir]
    if not (p and map and reverse and delta) then return false end

    local frontX, frontY = p.cellX + delta[1], p.cellY + delta[2]
    local landX, landY = p.cellX + delta[1]*2, p.cellY + delta[2]*2
    if not (map:inBounds(frontX,frontY) and map:inBounds(landX,landY)) then return false end
    local facings = Permissions.ledgeFacings(map:cellCollision(landX,landY))
    if not (facings and facings[reverse]) then return false end
    if not map:isWalkable(landX,landY) then return false end
    if map.isWaterCell and map:isWaterCell(landX,landY) then return false end
    if map.warpAt and (map:warpAt(frontX,frontY) or map:warpAt(landX,landY)) then return false end
    if occupied(self.entities,frontX,frontY,p) or occupied(self.entities,landX,landY,p) then return false end

    p.targetX,p.targetY=landX,landY
    p.moving,p.jumping=true,true
    p.inGrass,p.grassShake=false,nil
    p.progress=0
    p.stepFrames=p.stepFrames or 16
    if type(self.playSfxNamed) == "function" then pcall(self.playSfxNamed,self,"Sfx_JumpOverLedge") end
    compat.rumble(0.14,0.24,0.12)
    return true
  end
  World.dramaticSkyRideCleanReverseLedge = true
  return true
end

function Ground.install(deps)
  runtime, compat, settings = deps.runtime, deps.compat, deps.settings
  local g1 = installGen1()
  local g2 = installGen2()
  mod.exports.groundInterop = { gen1ReverseLedge=g1, gen2ReverseLedge=g2 }
end

return Ground
