local mod = ...

local SpriteRenderer = require("src.render.SpriteRenderer")
local Sprites = {}
local sources = {}

local STADIUM_IDS = { "STADIUM2_OVERWORLD_MODELS", "STADIUM_OVERWORLD_MODELS" }

local function find(id)
  if not mod.find then return nil end
  local ok, h = pcall(mod.find, mod, id)
  return ok and h or nil
end

local function normalize(def, provider, species, dex)
  if type(def) ~= "table" or type(def.image) ~= "string" then return nil end
  local frames = tonumber(def.frames) or 1
  if frames < 1 then return nil end
  return {
    id = def.id or ("DSR_" .. tostring(species or dex or "MOUNT")),
    image = def.image,
    frames = frames,
    walker = def.walker ~= false,
    trueColor = def.trueColor ~= false,
    frameWidth = def.frameWidth,
    frameHeight = def.frameHeight,
    anchorX = def.anchorX,
    anchorY = def.anchorY,
    providerId = def.providerId or provider,
  }
end

function Sprites.register(source)
  if type(source) ~= "table" or type(source.resolve) ~= "function" then
    return false, "source.resolve function required"
  end
  local id = source.id or source.mod
  if not id then return false, "source id required" end
  Sprites.unregister(id)
  table.insert(sources, 1, source)
  return true
end

function Sprites.unregister(id)
  for i = #sources, 1, -1 do
    if sources[i].id == id or sources[i].mod == id then table.remove(sources, i) end
  end
  return true
end

local function registered(game, species, dex, kind)
  for _, source in ipairs(sources) do
    local ex = nil
    local available = true
    if source.mod then
      local h = find(source.mod)
      if not h then available = false else ex = h.exports end
    end
    if available then
      local ok, def = pcall(source.resolve, ex, game, species, dex, kind)
      if ok then
        def = normalize(def, source.id or source.mod, species, dex)
        if def then return def end
      end
    end
  end
end

local function stadium(game, species, dex, kind)
  for _, id in ipairs(STADIUM_IDS) do
    local h = find(id)
    local ex = h and h.exports
    if ex then
      for _, name in ipairs({"resolveMountSprite", "resolveFollowerSprite"}) do
        local fn = ex[name]
        if type(fn) == "function" then
          local ok, def = pcall(fn, {
            game=game, species=species, speciesId=dex, dex=dex,
            role="dramatic_sky_ride_" .. tostring(kind),
            surface=kind == "surf" and "water" or "land",
          })
          if ok then
            def = normalize(def, id, species, dex)
            if def then return def end
          end
        end
      end
    end
  end
  return nil
end

local function wilds(game, species, dex, kind)
  local h = find("overworld_wild_spawns")
  local ex = h and h.exports
  local fn = ex and ex.resolveFollowerSprite
  if type(fn) ~= "function" then return nil end
  local ok, def = pcall(fn, {
    game=game, species=species, speciesId=dex, dex=dex,
    role="dramatic_sky_ride_" .. tostring(kind),
    surface=kind == "surf" and "water" or "land",
  })
  if not ok then return nil end
  return normalize(def, "overworld_wild_spawns", species, dex)
end

local function bundled(species, dex)
  if not dex then return nil end
  local rel = string.format("assets/pokepc/follower_%03d.png", dex)
  local path = mod.assets and mod.assets.path and mod.assets:path(rel) or (mod.path .. "/" .. rel)
  local def = normalize({ image=path, frames=6, walker=true, trueColor=true },
    "bundled_pokepc", species, dex)
  if not def then return nil end
  local ok = pcall(SpriteRenderer.new, def, "dsr_probe_" .. tostring(dex))
  return ok and def or nil
end

local function installedPokePC(game, species, dex, kind)
  for _, id in ipairs({"PokePCFollowers_VoxelMerge", "pokepcfollowers"}) do
    local h = find(id)
    local ex = h and h.exports
    if ex and type(ex.resolveFollowerSprite) == "function" then
      local ok, def = pcall(ex.resolveFollowerSprite, {
        game=game, species=species, speciesId=dex, dex=dex,
        role="dramatic_sky_ride_" .. tostring(kind),
        surface=kind == "surf" and "water" or "land",
      })
      if ok then
        def = normalize(def, id, species, dex)
        if def then return def end
      end
    end
  end
end

function Sprites.resolve(game, species, dex, kind)
  return registered(game, species, dex, kind)
    or stadium(game, species, dex, kind)
    or wilds(game, species, dex, kind)
    or bundled(species, dex)
    or installedPokePC(game, species, dex, kind)
end

function Sprites.build(game, species, dex, kind)
  local def = Sprites.resolve(game, species, dex, kind)
  if not def then return nil, "no sprite provider" end
  local ok, sprite = pcall(SpriteRenderer.new, def,
    "dramatic_sky_ride_" .. tostring(kind) .. "_" .. tostring(dex))
  if not ok then return nil, tostring(sprite) end
  return sprite, def
end

function Sprites.wildsStatus()
  local h = find("overworld_wild_spawns")
  local ex = h and h.exports
  return {
    active=h ~= nil,
    version=ex and ex.version or nil,
    resolver=ex and type(ex.resolveFollowerSprite)=="function" or false,
  }
end

function Sprites.stadiumStatus()
  local providers = {}
  for _, id in ipairs(STADIUM_IDS) do
    local h=find(id)
    local ex=h and h.exports
    if h then
      providers[#providers+1]={
        id=id,
        version=ex and ex.version or nil,
        rendererInstalled=ex and ex.rendererInstalled or nil,
        mountResolver=ex and (type(ex.resolveMountSprite)=="function"
          or type(ex.resolveFollowerSprite)=="function") or false,
        library=ex and ex.lib ~= nil or false,
      }
    end
  end
  return { active=#providers>0, providers=providers }
end

return Sprites
