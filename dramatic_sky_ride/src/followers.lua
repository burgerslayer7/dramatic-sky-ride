local mod = ...

local Followers = {}
local runtime, compat, settings
local hidden = setmetatable({}, { __mode="k" })

local function speciesOf(e)
  if not e then return nil end
  local mon=e.pokepcMon or e.mon or e.pokemon
  return e._wildsFollowerSpecies or e._pokepcFollowerSpecies
    or e.pokepcFollowerSpecies or e.wildsFollowerSpecies
    or e.followerSpecies or (type(mon)=="table" and mon.species) or nil
end

local function follower(e,player)
  if not e or e==player then return false end
  local def=e.sprite and e.sprite.def
  local id=tostring(e.id or ""):lower()
  local sid=tostring(e.spriteId or (def and def.id) or ""):upper()
  return e.wildsFollower==true or e.pikachuFollower==true
    or e.isPokemonFollower==true or e.pokepcTrailer==true
    or e.pokepcMon~=nil or e._wildsFollowerSpecies~=nil
    or e._pokepcFollowerSpecies~=nil or e.pokepcFollowerSpecies~=nil
    or id=="pikachu" or id:find("pokepc",1,true)~=nil
    or sid=="SPRITE_PIKACHU" or sid:find("POKEPC",1,true)~=nil
    or sid:find("WILDS_FOLLOWER",1,true)~=nil
end

local function hide(e)
  if hidden[e] or type(e.draw)~="function" then return end
  hidden[e]=e.draw
  e.draw=function() end
end

local function show(e)
  local draw=hidden[e]
  if draw then
    e.draw=draw
    hidden[e]=nil
  end
end

local function restoreAll()
  for e,draw in pairs(hidden) do
    if e then e.draw=draw end
    hidden[e]=nil
  end
end

local function shouldHide(s,e)
  if not s.mode then return false end
  if s.mode=="flight" or s.mode=="surf" or s.amphibious then return true end
  if s.mode~="ground" then return true end
  if not settings.bool("show_followers_while_mounted",false) then return true end
  local sp=speciesOf(e)
  return sp~=nil and tostring(sp):upper()==tostring(s.species or ""):upper()
end

local function sync(game)
  local s=runtime.public.state()
  if not s.mode then return restoreAll() end
  local world=compat.world(game)
  local player=world and world.player
  if not world then return restoreAll() end
  local seen=setmetatable({}, {__mode="k"})
  local function visit(list)
    for _,e in ipairs(list or {}) do
      if not seen[e] and follower(e,player) then
        seen[e]=true
        if shouldHide(s,e) then hide(e) else show(e) end
      end
    end
  end
  visit(world.entities)
  visit(world.npcs)
  for e,draw in pairs(hidden) do
    if not seen[e] then
      if e then e.draw=draw end
      hidden[e]=nil
    end
  end
end

function Followers.install(deps)
  runtime,compat,settings=deps.runtime,deps.compat,deps.settings
  mod.hooks:wrap("core.update",function(nextFn,game,dt)
    nextFn(game,dt)
    sync(game)
  end,960)
  mod.events:on("battle.started",restoreAll)
  mod.events:on("map.entered",function() restoreAll() end)
  mod.exports.mountedFollowerPolicy={
    landGroundOnly=function()
      local s=runtime.public.state()
      return s.mode=="ground" and not s.amphibious
    end,
    hiddenInAirOrWater=function()
      local s=runtime.public.state()
      return s.mode=="flight" or s.mode=="surf" or s.amphibious==true
    end,
  }
end

return Followers
