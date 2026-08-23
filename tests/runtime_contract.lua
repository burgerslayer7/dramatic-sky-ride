local hooks = {}
local opts = {
  story_safe=true, flight_speed=125, ground_speed=130,
  visible_surf_mounts=true, flight_feedback=false, mount_cries=false,
  mount_shortcut=false, manual_altitude=true, vertical_speed="normal",
  flight_boost=true, ground_gallop=true, remount_after_battle=true,
  air_encounters=true, show_followers_while_mounted=false,
}
local events = {}
local mod = {
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  log = { info=function() end, warn=function() end },
}

local chunk = assert(loadfile(arg[1]))
local Runtime = assert(chunk(mod))

local player = { sprite = "native_walk", moving=false }
local game = { save={party={}}, data={}, player=player }
local surfing = false
local party = game.save.party

local Compat = {
  game = function() return game end,
  player = function() return player end,
  party = function() return party end,
  healthy = function(mon) return mon and (mon.hp or 1) > 0 end,
  freeRoam = function() return true end,
  isSurfing = function() return surfing end,
  isWaterCell = function() return false end,
  setSurfing = function(_, enabled) surfing = enabled == true return true end,
  say = function() end,
  closeMenus = function() end,
  rumble = function() return false end,
  inputDown = function() return false end,
  gamepadDown = function() return false end,
  gamepadAxis = function() return 0 end,
}

local catalog = {
  flight = { CHARIZARD = { species="CHARIZARD", dex=6, speed=1 } },
  ground = {
    ARCANINE = { species="ARCANINE", dex=59, speed=1.15 },
    SUICUNE = { species="SUICUNE", dex=245, speed=1.20 },
  },
  surf = { LAPRAS = { species="LAPRAS", dex=131, speed=1 } },
}
function catalog.match(kind, _, mon)
  return catalog[kind] and catalog[kind][mon.species] or nil
end

local serial = 0
local Sprites = {
  build = function(_, species, _, kind)
    serial = serial + 1
    return { id="mount:" .. kind .. ":" .. species .. ":" .. serial, draw=function() end },
      { providerId = "test" }
  end,
}

local Settings = {}
Settings.get=function(key, fallback) if opts[key] ~= nil then return opts[key] end return fallback end
Settings.bool=function(key, fallback) return Settings.get(key,fallback) == true end
Settings.number=function(key, fallback) return tonumber(Settings.get(key,fallback)) or tonumber(fallback) or 0 end

local Progression = {
  canTakeOff=function() return true end,
  canLandOnWater=function() return true, party[1] end,
}
local Presentation = {
  decorate=function(_,_,_,sprite) return sprite end,
  scale=function() return 1 end,
  rendererWantsStadium=function() return false end,
}

Runtime.install({
  catalog=catalog, compat=Compat, sprites=Sprites,
  settings=Settings, progression=Progression, presentation=Presentation,
})

local function eq(a,b,msg)
  if a ~= b then error((msg or "mismatch") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
end
local function yes(v,msg) if not v then error(msg or "expected true") end end
local function no(v,msg) if v then error(msg or "expected false") end end

local arcanine = { species="ARCANINE", hp=10 }
party[1]=arcanine
yes(Runtime.public.start(game,"ground",arcanine), "ground start")
local groundMount = player.sprite
eq(Runtime.public.state().mode,"ground","ground mode")
no(groundMount == "native_walk", "ground visual changed")
yes(Runtime.public.stop(game,"test"), "ground stop")
eq(player.sprite,"native_walk","ground restore")

local charizard = { species="CHARIZARD", hp=10 }
party[1]=charizard
yes(Runtime.public.start(game,"flight",charizard), "flight start")
local collision = assert(hooks["movement.collision"])
local function downstream(allowed) return allowed end
yes(collision(downstream,false,{reason="tile"}) == true, "flight crosses terrain")
yes(collision(downstream,false,{reason="bounds"}) == false, "flight keeps bounds")
yes(collision(downstream,false,{reason="entity"}) == false, "story safe entity")
yes(collision(downstream,false,{reason="tile",mover={}}) == false, "flight does not alter npc collision")
local encounter = assert(hooks["encounter.roll"])
eq(encounter(function() return {species="PIDGEY"} end,{},{}),nil,"flight suppresses ground encounter")
local speed = assert(hooks["movement.speed"])(function(v) return v end,16,{})
eq(speed,13,"flight speed")

local flightMount = player.sprite
player.sprite = "skin_refresh"
assert(hooks["core.update"])(function() end, game, 1/60)
eq(player.sprite,flightMount,"flight re-applied")
Runtime.public.stop(game,"test")
eq(player.sprite,"skin_refresh","latest native visual restored")
yes(encounter(function() return {species="PIDGEY"} end,{},{}) ~= nil,
  "ground encounter restored after flight")

surfing = true
player.sprite = "native_surf"
local lapras = { species="LAPRAS", hp=10 }
party[1]=lapras
yes(Runtime.public.start(game,"surf",lapras,{auto=true}), "surf start")
local surfMount = player.sprite
no(surfMount == "native_surf", "surf visual changed")
surfing = false
player.sprite = "native_walk_after_surf"
assert(hooks["core.update"])(function() end, game, 1/60)
eq(Runtime.public.state().mode,nil,"surf stopped")
eq(player.sprite,"native_walk_after_surf","native dismount visual preserved")

-- Suicune remains a Ground Ride presentation while native Surf toggles.
local suicune={species="SUICUNE",hp=10}
party[1]=suicune
surfing=false
yes(Runtime.public.start(game,"ground",suicune),"suicune ground start")
surfing=true
assert(hooks["core.update"])(function() end,game,1/60)
eq(Runtime.public.state().mode,"ground","suicune retains ground ownership on water")
yes(Runtime.public.state().amphibious,"suicune amphibious marker")
Runtime.public.stop(game,"test")
surfing=false

-- Battle lifecycle retains a pending remount and restores it on free-roam update.
party[1]=arcanine
yes(Runtime.public.start(game,"ground",arcanine),"ground before battle")
assert(events["battle.started"])()
eq(Runtime.public.state().mode,nil,"battle clears active presentation")
yes(Runtime.public.state().pendingResume,"battle stores remount")
assert(hooks["core.update"])(function() end,game,1/60)
eq(Runtime.public.state().mode,"ground","ground remounted after battle")

print("runtime-contract-ok")
