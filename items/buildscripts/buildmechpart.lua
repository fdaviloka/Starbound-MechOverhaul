require "/vehicles/modularmech/mechpartmanager.lua"

partFrames = {
  arm = {
    {"<armName>", ":idle"},
    {"<armName>Fullbright", ":idle"}
  },
  body = {
    {"bodyBack", ":active"},
    {"bodyFront", ":active"},
    {"bodyFullbright", ":active"}
  },
  booster = {
    {"frontBoosterBack", ":idle"},
    {"frontBoosterFront", ":idle"}
  },
  legs = {
    {"backLeg", ":flat", {11, -4}},
    {"backLegJoint", ":default", {5, -1}},
    {"hips", ":default", {2, 3}},
    {"frontLegJoint", ":default", {-6, -1}},
    {"frontLeg", ":flat", {-10, -4}}
  }
}

function build(directory, config, parameters, level, seed)
  if config.mechPart and partFrames[config.mechPart[1]] then
    local partFile = root.assetJson("/vehicles/modularmech/mechparts_" .. config.mechPart[1] .. ".config")
    local partConfig = partFile[config.mechPart[2]]

    local paletteConfig = root.assetJson("/vehicles/modularmech/mechpalettes.config")
    local directives = directiveString(paletteConfig, partConfig.defaultPrimaryColors, partConfig.defaultSecondaryColors)

    local basePath = "/vehicles/modularmech/"
    local drawables = {}

    for _, frameConfig in ipairs(partFrames[config.mechPart[1]]) do
      local baseImage = partConfig.partImages[frameConfig[1]]
      if baseImage and baseImage ~= "" then
        table.insert(drawables, {
            image = basePath .. baseImage .. frameConfig[2] .. directives,
            centered = true,
            position = frameConfig[3]
          })
      end
    end

    config.tooltipFields = config.tooltipFields or {}
    config.tooltipFields.objectImage = drawables

    if partConfig.stats then
      for statName, statValue in pairs(partConfig.stats) do
        local clampedValue = math.max(3, math.min(7, math.floor(statValue)))
        config.tooltipFields[statName .. "StatImage"] = "/interface/tooltips/statbar.png:" .. clampedValue
      end
    end

    local partContext = {}

    if config.mechPart[1] == "body" then
      partContext.protection = root.evalFunction("mechBodyProtection", partConfig.stats.protection or 0)
    elseif config.mechPart[1] == "legs" then
      partContext.legSpeed = root.evalFunction("mechLegsGroundSpeed", partConfig.stats.speed or 0)
      partContext.jump = root.evalFunction("mechLegsJumpVelocity", partConfig.stats.jump or 0)
    elseif config.mechPart[1] == "booster" then
      partContext.boosterSpeed = root.evalFunction("mechBoosterAirControlSpeed", partConfig.stats.speed or 0)
      partContext.control = root.evalFunction("mechBoosterAirControlForce", partConfig.stats.control or 0)
    elseif config.mechPart[1] == "arm" then
      partContext.power = partConfig.stats.power
    end

    local mass = MechPartManager.getPartMass(config.mechPart[1], partContext)
    config.tooltipFields.massStatLabel = "Mass: " .. string.format("%.01f", mass) .. "t"

    if config.mechPart[1] == "arm" then
      local energyDrain = root.evalFunction("mechArmEnergyDrain", partConfig.stats.energy or 0)
      config.tooltipFields.energyDrainStatLabel = string.format("%.02f F/s", energyDrain)
    end
  end

  return config, parameters
end

function directiveString(paletteConfig, primaryColors, secondaryColors)
  local result = ""
  for i, fromColor in ipairs(paletteConfig.primaryMagicColors) do
    result = string.format("%s?replace=%s=%s", result, fromColor, primaryColors[i])
  end
  for i, fromColor in ipairs(paletteConfig.secondaryMagicColors) do
    result = string.format("%s?replace=%s=%s", result, fromColor, secondaryColors[i])
  end
  return result
end
