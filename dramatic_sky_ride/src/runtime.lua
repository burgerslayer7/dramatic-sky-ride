local mod = ...

local Runtime = { public = {} }
local C, Compat, Sprites, Settings, Progression, Presentation

local state = {
  mode=nil, species=nil, dex=nil, mon=nil, provider=nil,
  appliedPlayer=nil, mountSprite=nil, visualSlots={}, riderSprite=nil,
  altitude=34, stamina=1, gallop=false, boost=0, amphibious=false,
  lastShortcut={flight=false,ground=false,padFlight=false,padGround=false},
  surfAuto=false, pendingResume=nil, hints={},
}

local GROUND_GALLOP = {
  ARCANINE=1.34,RAPIDASH=1.42,DODRIO=1.31,RHYHORN=1.18,RHYDON=1.16,
  KANGASKHAN=1.23,TAUROS=1.39,SNORLAX=1.08,MEGANIUM=1.24,GIRAFARIG=1.28,
  URSARING=1.20,DONPHAN=1.25,STANTLER=1.32,RAIKOU=1.45,ENTEI=1.42,
  SUICUNE=1.42,TYRANITAR=1.18,
}
local GROUND_DRAIN = {
  SNORLAX=0.08,RHYHORN=0.18,RHYDON=0.18,KANGASKHAN=0.21,
  DODRIO=0.23,ARCANINE=0.25,RAPIDASH=0.27,TAUROS=0.28,
}

local function option(key, fallback) return Settings.get(key, fallback) end
local function bool(key, fallback) return Settings.bool(key, fallback) end

local function feedback(kind)
  if not bool("flight_feedback", true) then return end
  if kind == "blocked" then Compat.rumble(0.18,0.35,0.12)
  elseif kind == "mount" then Compat.rumble(0.08,0.18,0.08)
  elseif kind == "land" then Compat.rumble(0.12,0.20,0.10) end
end

local function playCry(game, species)
  if not bool("mount_cries", true) or not species then return end
  local ok, Sound = pcall(require, "src.core.Sound")
  if ok and Sound and type(Sound.playCry) == "function" then
    pcall(Sound.playCry, game and game.data, species)
  end
end

local function clearMarkers(player)
  if not player then return end
  player.dramaticSkyRide = nil
  player.dramaticSkyRideMode = nil
  player.dramaticSkyRideSpecies = nil
  player.dramaticSkyRideDex = nil
  player.dramaticSkyRideAltitude = nil
  player.dramaticSkyRideSurface = nil
  player.dramaticSkyRideStamina = nil
  player.dramaticSkyRideGallop = nil
  player.dramaticSkyRideBoost = nil
  player.dramaticSkyRideAirEncounters = nil
  player.dramaticSkyRideShowFollowers = nil
  player.dramaticSkyRideMountSpecies = nil
  player.skyRideMountSpecies = nil
  player._stadiumSkyRideSpecies = nil
  player.dramaticSkyRideMountScale = nil
  if player.dramaticSkyRideFreeFlying then
    player.freeFlying = nil
    player.dramaticSkyRideFreeFlying = nil
  end
end

local function stampMarkers(game, player, kind, row)
  if not player then return end
  local surface = (kind == "surf" or state.amphibious) and "water" or "land"
  player.dramaticSkyRide = {
    mode=kind, species=row.species, dex=row.dex, provider=state.provider,
    altitude=kind == "flight" and state.altitude or 0,
    surface=surface, gallop=state.gallop, boost=state.boost,
  }
  player.dramaticSkyRideMode = kind
  player.dramaticSkyRideSpecies = row.species
  player.dramaticSkyRideDex = row.dex
  player.dramaticSkyRideAltitude = kind == "flight" and state.altitude or 0
  player.dramaticSkyRideSurface = surface
  player.dramaticSkyRideStamina = state.stamina
  player.dramaticSkyRideGallop = state.gallop
  player.dramaticSkyRideBoost = state.boost
  player.dramaticSkyRideAirEncounters = bool("air_encounters", true)
  player.dramaticSkyRideShowFollowers = bool("show_followers_while_mounted", false)
  player.dramaticSkyRideMountScale = Presentation.scale(game, row.species, row.dex)

  -- Gen2-3D-Sprites / compatible Stadium renderers already consume these
  -- Pokemon-specific fields. AUTO and STADIUM 3D opt into that renderer;
  -- forcing 2D deliberately withholds them and keeps the normal card path.
  if Presentation.rendererWantsStadium() then
    player.dramaticSkyRideMountSpecies = row.species
    player.skyRideMountSpecies = row.species
    player._stadiumSkyRideSpecies = row.species
  else
    player.dramaticSkyRideMountSpecies = nil
    player.skyRideMountSpecies = nil
    player._stadiumSkyRideSpecies = nil
  end

  if kind == "flight" then
    player.freeFlying = true
    player.dramaticSkyRideFreeFlying = true
  elseif player.dramaticSkyRideFreeFlying then
    player.freeFlying = nil
    player.dramaticSkyRideFreeFlying = nil
  end
end

local function restoreVisual(player)
  if not player then return end
  for _, slot in ipairs(state.visualSlots) do
    if player[slot.name] == state.mountSprite then player[slot.name] = slot.original end
  end
end

local function clearPlayerVisual()
  local player = state.appliedPlayer
  if player then
    restoreVisual(player)
    clearMarkers(player)
  end
  state.appliedPlayer=nil
  state.mountSprite=nil
  state.visualSlots={}
  state.riderSprite=nil
end

local function controlledSlots(player, kind)
  if kind ~= "surf" then return {"sprite"} end
  local slots = {}
  if player.surfSprite ~= nil then slots[#slots+1] = "surfSprite" end
  if player.surfPikachuSprite ~= nil then slots[#slots+1] = "surfPikachuSprite" end
  if #slots == 0 then slots[1] = "sprite" end
  return slots
end

local function setPlayerVisual(game, kind, row)
  local player = Compat.player(game)
  if not player then return false, "no player" end
  local sprite, defOrErr = Sprites.build(game, row.species, row.dex, kind)
  if not sprite then return false, defOrErr end

  local rider = player.sprite
  clearPlayerVisual()
  state.provider = defOrErr.providerId
  state.appliedPlayer = player
  state.riderSprite = rider
  sprite = Presentation.decorate(game, row, kind, sprite, rider)
  state.mountSprite = sprite
  state.visualSlots = {}
  for _, name in ipairs(controlledSlots(player, kind)) do
    state.visualSlots[#state.visualSlots+1] = {name=name, original=player[name]}
    player[name] = sprite
  end
  stampMarkers(game, player, kind, row)
  return true
end

local function finishStop(reason)
  if not state.mode then return false end
  local oldMode, oldSpecies = state.mode, state.species
  clearPlayerVisual()
  state.mode,state.species,state.dex,state.mon,state.provider=nil,nil,nil,nil,nil
  state.surfAuto=false
  state.gallop=false
  state.boost=0
  state.amphibious=false
  mod.log:info("mount ended mode=%s species=%s reason=%s", tostring(oldMode), tostring(oldSpecies), tostring(reason or "manual"))
  feedback("land")
  return true
end

local function stop(game, reason, opts)
  if type(game) ~= "table" or (not game.save and not game.overworld and not game.world) then
    opts, reason, game = reason, game, Compat.game(nil)
  end
  opts = opts or {}
  if not state.mode then return false end

  if state.mode == "flight" and not opts.force and Compat.isWaterCell(game) and not Compat.isSurfing(game) then
    local ok, monOrReason = Progression.canLandOnWater(game)
    if not ok then
      Compat.say(game, tostring(monOrReason))
      feedback("blocked")
      return false
    end
    Compat.setSurfing(game, true, monOrReason)
  end
  return finishStop(reason)
end

local function start(game, kind, mon, opts)
  opts = opts or {}
  if not Compat.freeRoam(game) then return false, "not in overworld" end
  if not Compat.healthy(mon) then return false, "mount is unavailable" end
  local row = C.match(kind, game, mon)
  if not row then return false, "not a supported " .. tostring(kind) .. " mount" end

  if kind == "flight" then
    local ok, reason = Progression.canTakeOff(game, mon)
    if not ok then return false, reason end
  end

  local surfing = Compat.isSurfing(game)
  if kind == "surf" then
    if not surfing then return false, "start Surf through the game first" end
  elseif surfing and not (kind == "ground" and row.species == "SUICUNE") then
    return false, "leave the water first"
  end

  if state.mode then finishStop("mode change") end
  state.mode,state.species,state.dex,state.mon=kind,row.species,row.dex,mon
  state.stamina=1
  state.gallop=false
  state.boost=0
  state.amphibious = kind == "ground" and row.species == "SUICUNE" and surfing
  state.surfAuto = opts.auto == true

  local ok, err = setPlayerVisual(game, kind, row)
  if not ok then
    state.mode,state.species,state.dex,state.mon=nil,nil,nil,nil
    return false, err
  end
  playCry(game, row.species)
  feedback("mount")
  mod.log:info("mount started mode=%s species=%s provider=%s", kind, row.species, tostring(state.provider))
  return true
end

local function preferred(game, kind)
  for _, mon in ipairs(Compat.party(game)) do
    if Compat.healthy(mon) and C.match(kind, game, mon) then return mon end
  end
end

local function preferredSpecies(game, kind, species)
  for _, mon in ipairs(Compat.party(game)) do
    local row = C.match(kind, game, mon)
    if Compat.healthy(mon) and row and row.species == species then return mon end
  end
end

local function toggle(game, kind)
  if state.mode == kind then return stop(game, "toggle") end
  if state.mode then
    if not stop(game, "mode change") then return false end
  end
  local mon = preferred(game, kind)
  if not mon then
    Compat.say(game, "No healthy " .. string.upper(kind) .. " mount is available.")
    return false
  end
  local ok, err = start(game, kind, mon)
  if not ok then
    Compat.say(game, "Cannot mount: " .. tostring(err))
    feedback("blocked")
    return false
  end
  return true
end

local function syncSurf(game)
  local player = Compat.player(game)
  if not player then return end
  local surfing = Compat.isSurfing(game)

  -- Suicune keeps Ground Ride ownership through native Surf. The game remains
  -- authoritative for entering/leaving Surf; only DSR's presentation persists.
  if state.mode == "ground" and state.species == "SUICUNE" then
    state.amphibious = surfing
    local row = C.ground.SUICUNE
    if row then stampMarkers(game, player, "ground", row) end
    return
  end

  if surfing then
    if state.mode and state.mode ~= "surf" then finishStop("native surf started") end
    if state.mode == nil and bool("visible_surf_mounts", true) and Compat.freeRoam(game) then
      local mon = preferred(game, "surf")
      if mon then start(game, "surf", mon, {auto=true}) end
    end
  elseif state.mode == "surf" then
    finishStop("surf ended")
  end
end

local function refreshVisualOwnership(game)
  if not state.mode then return end
  local player = Compat.player(game)
  if not player then return end
  local row = C[state.mode] and C[state.mode][state.species]
  if not row then return finishStop("catalog entry disappeared") end

  if player ~= state.appliedPlayer then
    setPlayerVisual(game, state.mode, row)
    return
  end

  for _, slot in ipairs(state.visualSlots) do
    if player[slot.name] ~= state.mountSprite then
      slot.original = player[slot.name]
      player[slot.name] = state.mountSprite
    end
  end
  stampMarkers(game, player, state.mode, row)
end

local function keyboardDown(key)
  return love and love.keyboard and love.keyboard.isDown and love.keyboard.isDown(key) or false
end

local function edge(down, slot)
  local pressed = down and not state.lastShortcut[slot]
  state.lastShortcut[slot] = down
  return pressed
end

local function updateAltitude(game, dt)
  if state.mode ~= "flight" or not bool("manual_altitude", true) then return end
  local direction = 0
  if keyboardDown("pageup") then direction = direction + 1 end
  if keyboardDown("pagedown") then direction = direction - 1 end
  local rt = Compat.gamepadAxis("triggerright")
  local lt = Compat.gamepadAxis("triggerleft")
  if rt > 0.35 then direction = direction + rt end
  if lt > 0.35 then direction = direction - lt end
  if direction == 0 then return end
  local speedName = tostring(option("vertical_speed", "normal"))
  local rate = ({slow=24,normal=48,fast=72})[speedName] or 48
  state.altitude = math.max(20, math.min(96, state.altitude + direction * rate * (tonumber(dt) or 1/60)))
end

local function moving(game)
  local p = Compat.player(game)
  return p and (p.moving == true or p.stepLanded == true)
end

local function updateMotion(game, dt)
  dt = tonumber(dt) or 1/60
  if state.mode == "flight" then
    local wants = bool("flight_boost", true) and Compat.inputDown(game, "b") and moving(game)
    local rate = wants and 3.5 or 5.0
    state.boost = math.max(0, math.min(1, state.boost + (wants and 1 or -1) * rate * dt))
  else
    state.boost = 0
  end

  if state.mode == "ground" then
    local wants = bool("ground_gallop", true) and Compat.inputDown(game, "b") and moving(game)
    local drain = GROUND_DRAIN[state.species] or 0.22
    if wants and state.stamina > 0.02 then
      state.gallop = true
      state.stamina = math.max(0, state.stamina - drain * dt)
    else
      state.gallop = false
      state.stamina = math.min(1, state.stamina + 0.22 * dt)
    end
  else
    state.gallop=false
    state.stamina=math.min(1, state.stamina + 0.22 * dt)
  end
end

local function updateShortcuts(game, dt)
  if bool("mount_shortcut", true) then
    if edge(keyboardDown("h"), "flight") then toggle(game, "flight") end
    if edge(keyboardDown("g"), "ground") then toggle(game, "ground") end
    if edge(Compat.gamepadDown("x"), "padFlight") then toggle(game, "flight") end
    if edge(Compat.gamepadDown("y"), "padGround") then toggle(game, "ground") end
  end
  updateAltitude(game, dt)
end

local function tryPendingResume(game)
  local resume = state.pendingResume
  if not resume or state.mode or not Compat.freeRoam(game) then return end
  state.pendingResume = nil
  if resume.mode == "surf" then
    if Compat.isSurfing(game) then
      local mon = preferredSpecies(game, "surf", resume.species) or preferred(game, "surf")
      if mon then start(game, "surf", mon, {auto=true}) end
    end
    return
  end
  local mon = preferredSpecies(game, resume.mode, resume.species)
  if mon then
    local ok, err = start(game, resume.mode, mon, {resume=true})
    if not ok then mod.log:warn("remount skipped: %s", tostring(err)) end
  end
end

local function installMountMenu()
  if not (mod.content and mod.content.screens and mod.ui and mod.ui.ListMenu) then return end
  mod.content.screens:register("DramaticSkyRideMounts", {
    new=function(game)
      local items={}
      for _, mon in ipairs(Compat.party(game)) do
        if Compat.healthy(mon) then
          for _, spec in ipairs({{"flight","FLY"},{"ground","RIDE"}}) do
            local row=C.match(spec[1],game,mon)
            if row then
              items[#items+1]={label=spec[2] .. " " .. row.label, value={kind=spec[1],mon=mon}}
            end
          end
        end
      end
      return mod.ui.ListMenu.new(game,"MOUNTS",items,{
        pageJump=true,
        onChoose=function(item,menu)
          if menu and menu.close then menu:close() end
          Compat.closeMenus(game)
          local v=item and item.value
          if v then
            local ok,err=start(game,v.kind,v.mon)
            if not ok then Compat.say(game,"Cannot mount: " .. tostring(err)) end
          end
        end,
      })
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(nextFn, game, items)
    local out=nextFn(game,items)
    if type(out) ~= "table" or not bool("mount_menu",true) then return out end
    local row={label="MOUNTS",onSelect=function() mod.ui.push(game,"DramaticSkyRideMounts") end}
    if mod.ui.insertBefore then return mod.ui.insertBefore(out,"SAVE",row) end
    out[#out+1]=row
    return out
  end,900)
end

local function installHooks()
  mod.hooks:wrap("movement.collision", function(nextFn, allowed, ctx)
    local base=nextFn(allowed,ctx)
    if state.mode ~= "flight" or not ctx then return base end
    local player=Compat.player(nil)
    if ctx.mover and (not player or ctx.mover ~= player) then return base end
    if ctx.reason == "bounds" then return base end
    if ctx.reason == "entity" and bool("story_safe",true) then return base end
    return true
  end,900)

  mod.hooks:wrap("encounter.roll", function(nextFn,tables,ctx)
    if state.mode == "flight" then return nil end
    return nextFn(tables,ctx)
  end,900)

  mod.hooks:wrap("movement.speed", function(nextFn,frames,ctx)
    local base=tonumber(nextFn(frames,ctx)) or tonumber(frames) or 16
    local percent=100
    if state.mode == "flight" then
      percent=Settings.number("flight_speed",100) * (1 + state.boost)
    elseif state.mode == "ground" then
      local row=C.ground[state.species]
      percent=Settings.number("ground_speed",100) * ((row and row.speed) or 1)
      if state.gallop then percent=percent * (GROUND_GALLOP[state.species] or 1.25) end
    else
      return base
    end
    return math.max(1,math.floor(base*100/math.max(1,percent)+0.5))
  end,900)

  mod.hooks:wrap("core.update", function(nextFn,game,dt)
    nextFn(game,dt)
    syncSurf(game)
    updateMotion(game,dt)
    refreshVisualOwnership(game)
    updateShortcuts(game,dt)
    tryPendingResume(game)
  end,900)

  mod.hooks:wrap("ui.party.submenu", function(nextFn,game,items,mon,ctx)
    local out=nextFn(game,items,mon,ctx)
    if type(out) ~= "table" then out=items or {} end
    if ctx and ctx.battle then return out end
    local function add(kind,label)
      if C.match(kind,game,mon) then
        table.insert(out,1,{label=label,onSelect=function(selected,liveGame)
          Compat.closeMenus(liveGame)
          local ok,err=start(liveGame,kind,selected)
          if not ok then Compat.say(liveGame,"Cannot mount: " .. tostring(err)) end
        end})
      end
    end
    add("flight","RIDE & FLY")
    add("ground","RIDE")
    return out
  end,900)
end

function Runtime.install(deps)
  C,Compat,Sprites=deps.catalog,deps.compat,deps.sprites
  Settings,Progression,Presentation=deps.settings,deps.progression,deps.presentation
  installHooks()
  installMountMenu()

  mod.events:on("battle.started",function()
    if not state.mode then return end
    if bool("remount_after_battle",true) then
      state.pendingResume={mode=state.mode,species=state.species,dex=state.dex}
    end
    finishStop("battle")
  end)
  mod.events:on("battle.ended",function()
    -- core.update performs the actual remount only once free-roam is restored.
  end)
end

Runtime.public={
  start=start,
  stop=stop,
  toggle=toggle,
  state=function()
    return {mode=state.mode,species=state.species,dex=state.dex,provider=state.provider,
      altitude=state.altitude,surfAuto=state.surfAuto,stamina=state.stamina,
      gallop=state.gallop,boost=state.boost,amphibious=state.amphibious,
      pendingResume=state.pendingResume ~= nil}
  end,
  isFlying=function() return state.mode=="flight" end,
  isGroundRiding=function() return state.mode=="ground" end,
  isSurfing=function() return state.mode=="surf" end,
  altitude=function() return state.altitude end,
}

return Runtime
