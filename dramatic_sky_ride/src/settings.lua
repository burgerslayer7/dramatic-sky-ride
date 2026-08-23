local mod = ...

local Settings = {}
local catalog

local SCHEMA = {
  { key="settings_view", type="choice", label="SETTINGS VIEW", default="advanced",
    choices={{"SIMPLE","simple"},{"ADVANCED","advanced"}},
    help="Simple shows the main controls. Advanced shows every DSR setting." },

  { key="show_rider", type="toggle", label="SHOW RIDER", default=true },
  { key="mount_cries", type="toggle", label="MOUNT CRIES", default=true },
  { key="mount_hints", type="toggle", label="MOUNT HINTS", default=true },
  { key="mount_menu", type="toggle", label="MOUNTS MENU", default=true },
  { key="show_followers_while_mounted", type="toggle", label="SHOW FOLLOWERS", default=false },
  { key="flight_feedback", type="toggle", label="SOUND & RUMBLE", default=true },

  { key="flight_speed", type="number", label="FLIGHT SPEED", default=100, min=50, max=200, step=10 },
  { key="manual_altitude", type="toggle", label="MANUAL ALTITUDE", default=true },
  { key="vertical_speed", type="choice", label="VERTICAL SPEED", default="normal",
    choices={{"SLOW","slow"},{"NORMAL","normal"},{"FAST","fast"}} },
  { key="altitude_display", type="choice", label="ALTITUDE DISPLAY", default="temporary",
    choices={{"TEMPORARY","temporary"},{"ALWAYS","always"},{"OFF","off"}} },
  { key="flight_boost", type="toggle", label="FLIGHT BOOST", default=true },
  { key="camera_follow", type="toggle", label="CAMERA FOLLOW", default=true },
  { key="camera_altitude", type="toggle", label="CAMERA ALTITUDE", default=true },
  { key="landing_marker", type="toggle", label="LANDING MARKER", default=true },
  { key="dynamic_shadow", type="toggle", label="DYNAMIC SHADOW", default=true },
  { key="air_encounters", type="toggle", label="AIR ENCOUNTERS", default=true },
  { key="mount_shortcut", type="toggle", label="MOUNT SHORTCUT", default=true },

  { key="ground_speed", type="number", label="GROUND SPEED", default=100, min=50, max=200, step=10 },
  { key="ground_gallop", type="toggle", label="GROUND GALLOP", default=true },
  { key="ground_hud", type="toggle", label="GALLOP HUD", default=true },
  { key="ground_dust", type="toggle", label="GROUND DUST", default=true },
  { key="reverse_ledge_jumps", type="toggle", label="TWO-WAY LEDGES", default=true },
  { key="remount_after_battle", type="toggle", label="REMOUNT AFTER BATTLE", default=true },

  { key="visible_surf_mounts", type="toggle", label="VISIBLE SURF MOUNTS", default=true },

  { key="require_fly_move", type="toggle", label="REQUIRE FLY", default=true },
  { key="badge_checks", type="toggle", label="BADGE CHECKS", default=true },
  { key="story_gates", type="toggle", label="STORY GATES", default=true },
  { key="discovery_gates", type="toggle", label="DISCOVERY GATES", default=true },
  { key="story_safe", type="toggle", label="QUEST COLLISIONS", default=true },

  { key="flight_mount_renderer", type="choice", label="MOUNT RENDERER", default="auto",
    choices={{"AUTO","auto"},{"2D","2d"},{"STADIUM 3D","stadium3d"}} },
  { key="pokedex_mount_sizes", type="toggle", label="REALISTIC MOUNT SIZES", default=true },
  { key="flying_music", type="choice", label="FLYING MUSIC", default="none",
    choices={{"NONE","none"},{"SURF THEME","surf"},{"BIKE THEME","bike"}} },
  { key="size_overrides", type="choice", label="SIZE OVERRIDES", default="hidden",
    choices={{"HIDDEN","hidden"},{"EDIT","edit"}} },
}

local schemaByKey = {}
local function add(row)
  if not schemaByKey[row.key] then
    SCHEMA[#SCHEMA + 1] = row
    schemaByKey[row.key] = row
  end
end
for _, row in ipairs(SCHEMA) do schemaByKey[row.key] = row end

local function value(key, fallback)
  if not (mod.options and mod.options.get) then return fallback end
  local ok, v = pcall(mod.options.get, mod.options, key)
  return ok and v ~= nil and v or fallback
end

function Settings.get(key, fallback) return value(key, fallback) end
function Settings.bool(key, fallback) return value(key, fallback) == true end
function Settings.number(key, fallback)
  return tonumber(value(key, fallback)) or tonumber(fallback) or 0
end

local SIMPLE = {
  settings_view=true, show_rider=true, flight_speed=true, ground_speed=true,
  manual_altitude=true, visible_surf_mounts=true, pokedex_mount_sizes=true,
  mount_hints=true, air_encounters=true, flying_music=true,
  flight_mount_renderer=true,
}

local ADVANCED_ORDER = {
  "settings_view","show_rider","mount_cries","mount_hints","mount_menu",
  "show_followers_while_mounted","flight_feedback","flight_speed",
  "manual_altitude","vertical_speed","altitude_display","flight_boost",
  "camera_follow","camera_altitude","landing_marker","dynamic_shadow",
  "air_encounters","mount_shortcut","ground_speed","ground_gallop",
  "ground_hud","ground_dust","reverse_ledge_jumps","remount_after_battle",
  "visible_surf_mounts","require_fly_move","badge_checks","story_gates",
  "discovery_gates","story_safe","flight_mount_renderer",
  "pokedex_mount_sizes","flying_music","size_overrides",
}
local rank = {}
for i, key in ipairs(ADVANCED_ORDER) do rank[key] = i end

local function sizeKey(key)
  return type(key) == "string" and key:match("^mount_size_") ~= nil
end

local function rowKey(row)
  if type(row) ~= "table" then return nil end
  for _, k in ipairs({row.id,row.key,row.optionKey,row.option_key}) do
    if type(k) == "string" and schemaByKey[k] then return k end
  end
  return nil
end

local function visible(key)
  if sizeKey(key) then return value("size_overrides", "hidden") == "edit" end
  if value("settings_view", "advanced") == "simple" then return SIMPLE[key] == true end
  return true
end

local function decorate(rows)
  if type(rows) ~= "table" then return rows end
  local ours, other = {}, {}
  for _, row in ipairs(rows) do
    local key = rowKey(row)
    if key then
      if visible(key) then ours[#ours+1] = {row=row,key=key} end
    else
      other[#other+1] = row
    end
  end
  table.sort(ours, function(a,b)
    local ar = rank[a.key] or (sizeKey(a.key) and 10000 or 5000)
    local br = rank[b.key] or (sizeKey(b.key) and 10000 or 5000)
    if ar ~= br then return ar < br end
    return a.key < b.key
  end)
  local out = {}
  for _, e in ipairs(ours) do out[#out+1] = e.row end
  for _, row in ipairs(other) do out[#out+1] = row end
  return out
end

function Settings.install(deps)
  catalog = deps.catalog
  local species = {}
  for _, kind in ipairs({"flight","ground","surf"}) do
    for name in pairs(catalog[kind] or {}) do species[name] = true end
  end
  local names = {}
  for name in pairs(species) do names[#names+1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    add({ key="mount_size_" .. name:lower(), type="number", label="SIZE " .. name,
      default=100, min=50, max=200, step=5,
      help="100 keeps this mount at its Pokedex-derived size." })
  end
  if mod.options and mod.options.define then mod.options:define(SCHEMA) end

  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
      return decorate(nextFn(game, rows))
    end, 950)
  end

  mod.exports.settingsUX = {
    simple = function() return value("settings_view","advanced") == "simple" end,
    sizeEditorVisible = function() return value("size_overrides","hidden") == "edit" end,
  }
end

function Settings.schema() return SCHEMA end

return Settings
