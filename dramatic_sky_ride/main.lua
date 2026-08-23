local mod = ...

local function loadModule(name)
  local rel = "src/" .. name .. ".lua"
  local source, readErr = mod:read(rel)
  assert(source, ("Dramatic Sky Ride: missing %s: %s"):format(rel, tostring(readErr)))
  local loader = loadstring or load
  local chunk, compileErr = loader(source, "@" .. mod.path .. "/" .. rel)
  assert(chunk, ("Dramatic Sky Ride: %s did not compile: %s"):format(rel, tostring(compileErr)))
  local ok, value = pcall(chunk, mod)
  assert(ok, ("Dramatic Sky Ride: %s failed: %s"):format(rel, tostring(value)))
  return value
end

local catalog = loadModule("catalog")
local compat = loadModule("compat")
local settings = loadModule("settings")
local progression = loadModule("progression")
local sprites = loadModule("sprites")
local presentation = loadModule("presentation")
local runtime = loadModule("runtime")
local ground = loadModule("ground")
local safety = loadModule("safety")
local stadium = loadModule("stadium")
local interop = loadModule("interop")
local followers = loadModule("followers")
local hud = loadModule("hud")
local wildSkies = loadModule("wild_skies")
local music = loadModule("music")

settings.install({ catalog = catalog, compat = compat })
progression.install({ catalog = catalog, compat = compat, settings = settings })
presentation.install({ settings = settings, compat = compat, progression = progression })
runtime.install({
  catalog = catalog,
  compat = compat,
  sprites = sprites,
  settings = settings,
  progression = progression,
  presentation = presentation,
})
ground.install({ runtime = runtime, compat = compat, settings = settings })
safety.install({
  runtime = runtime,
  compat = compat,
  settings = settings,
  progression = progression,
})
stadium.install({ runtime = runtime, compat = compat, presentation = presentation })
interop.install({ runtime = runtime, compat = compat, settings = settings })
followers.install({ runtime = runtime, compat = compat, settings = settings })
hud.install({ runtime = runtime, settings = settings })
wildSkies.install({
  runtime = runtime,
  compat = compat,
  sprites = sprites,
  settings = settings,
})
music.install({ runtime = runtime, compat = compat, settings = settings })

mod.exports.version = "0.3.0-rc.2"
mod.exports.apiVersion = 2
mod.exports.catalog = catalog
mod.exports.runtime = runtime.public
mod.exports.settings = settings
mod.exports.progression = progression
mod.exports.presentation = presentation
mod.exports.compatibility = {
  wilds = sprites.wildsStatus,
  renderers = interop.status,
  stadium = stadium.status,
  stadiumSprites = sprites.stadiumStatus,
  crystal251 = compat.crystalStatus,
  wildSkies = wildSkies.status,
  music = music.status,
}
mod.exports.registerSpriteSource = sprites.register
mod.exports.unregisterSpriteSource = sprites.unregister
mod.exports.resolveMountSprite = sprites.resolve

mod.log:info("Dramatic Sky Ride 0.3.0-rc.2 clean parity runtime loaded")
