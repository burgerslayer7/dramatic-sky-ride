local mod = ...

local Catalog = {}

local function rows(list)
  local out, byDex = {}, {}
  for _, row in ipairs(list) do
    local item = { species = row[1], dex = row[2], label = row[3] or row[1], speed = row[4] or 1.0 }
    out[item.species] = item
    byDex[item.dex] = item
  end
  return out, byDex
end

Catalog.flight, Catalog.flightByDex = rows({
  {"CHARIZARD",6},{"PIDGEOT",18},{"FEAROW",22},{"GOLBAT",42},{"AERODACTYL",142},
  {"ARTICUNO",144},{"ZAPDOS",145},{"MOLTRES",146},{"DRAGONAIR",148},{"DRAGONITE",149},
  {"NOCTOWL",164},{"CROBAT",169},{"XATU",178},{"SKARMORY",227},{"LUGIA",249},{"HO_OH",250},
})

Catalog.ground, Catalog.groundByDex = rows({
  {"ARCANINE",59,nil,1.15},{"RAPIDASH",78,nil,1.20},{"DODRIO",85,nil,1.15},
  {"RHYHORN",111,nil,0.95},{"RHYDON",112,nil,1.00},{"KANGASKHAN",115,nil,1.00},
  {"TAUROS",128,nil,1.15},{"SNORLAX",143,nil,0.80},{"MEGANIUM",154,nil,1.00},
  {"GIRAFARIG",203,nil,1.05},{"URSARING",217,nil,0.95},{"DONPHAN",232,nil,1.05},
  {"STANTLER",234,nil,1.10},{"RAIKOU",243,nil,1.25},{"ENTEI",244,nil,1.20},
  {"SUICUNE",245,nil,1.20},{"TYRANITAR",248,nil,0.95},
})

Catalog.surf, Catalog.surfByDex = rows({
  {"BLASTOISE",9},{"TENTACRUEL",73},{"GYARADOS",130},{"LAPRAS",131},
  {"FERALIGATR",160},{"MANTINE",226},{"KINGDRA",230},{"LUGIA",249},
})

local function dexOf(game, mon)
  if not mon then return nil end
  local data = game and game.data
  local def = data and data.pokemon and data.pokemon[mon.species]
  return tonumber((def and def.dex) or mon.dex or mon.speciesId)
end

function Catalog.match(kind, game, mon)
  local set, byDex = Catalog[kind], Catalog[kind .. "ByDex"]
  if not (set and byDex and mon) then return nil end
  if set[mon.species] then return set[mon.species] end
  return byDex[dexOf(game, mon)]
end

function Catalog.dexOf(game, mon)
  return dexOf(game, mon)
end

return Catalog
