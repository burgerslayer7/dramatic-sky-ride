local generation = 2
local player = {}
local world = {
  player=player,
  playerState="normal",
  applyPlayerState=function(self,state) self.playerState=state end,
}
local mod = {
  world={overworld=function() return world end},
  log={info=function() end},
}

package.loaded["src.core.GameVersion"]={generation=function() return generation end}
local chunk=assert(loadfile(arg[1]))
local Compat=assert(chunk(mod))

local function eq(a,b,msg)
  if a ~= b then error((msg or "mismatch") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
end

player.surfing=true
eq(Compat.isSurfing(nil),false,"gen2 ignores stale gen1 surfing field")
eq(Compat.setSurfing(nil,true,nil),true,"gen2 starts surf")
eq(world.playerState,"surf","gen2 player state starts surf")
eq(Compat.isSurfing(nil),true,"gen2 reads player state")
world.playerState="normal"
eq(Compat.isSurfing(nil),false,"gen2 observes native surf exit")

generation=1
eq(Compat.isSurfing(nil),true,"gen1 reads player surfing field")

print("compat-contract-ok")
