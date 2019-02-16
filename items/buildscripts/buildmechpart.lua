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

    local mass = generateMass(config.mechPart[1], partConfig)
    config.tooltipFields.massStatLabel = "Mass: " .. string.format("%.01f", mass) .. "t"

    if config.mechPart[1] == "arm" then
      local energyDrain = root.evalFunction("mechArmEnergyDrain", partConfig.stats.energy or 0)
      config.tooltipFields.energyDrainStatLabel = string.format("%.02f F/s", energyDrain)
    end
  end

  return config, parameters
end

function generateMass(partType, partConfig)
  local mass = 0

  if partType == "body" then
    --calculating mech mass based on stats

    local protection = root.evalFunction("mechBodyProtection", partConfig.stats.protection or 0)
    if protection == 0 then return 0 end

    --body mass
    if protection == 0.682 then
      mass = 1
    elseif protection == 0.716 then
      mass = 1.5
    elseif protection == 0.760 then
      mass = 2
    elseif protection == 0.808 then
      mass = 3.5
    elseif protection == 0.846 then
      mass = 4.5
    elseif protection == 0.877 then
      mass = 6
    elseif protection == 0.902 then
      mass = 8
    elseif protection == 0.921 then
      mass = 10
    elseif protection == 0.937 then
      mass = 12.5
    elseif protection == 0.950 then
      mass = 15
    end

    return mass

  elseif partType == "arm" then
    --arms mass = arms power * 0.4
    mass = partConfig.stats.power * 0.40

    return mass
  elseif partType == "legs" then
    --calculating legs mass from 1 to 7 based on stats
    local groundSpeed = root.evalFunction("mechLegsGroundSpeed", partConfig.stats.speed or 0)
    local jumpVelocity = root.evalFunction("mechLegsJumpVelocity", partConfig.stats.jump or 0)

    local sec1 = (6.5 - 1) / (11 - 3.25)
    sec1 = sec1 * (groundSpeed - 3.25) + 1
    sec1 = math.floor(sec1 * 10) / 10

    local sec2 = (6.5 - 1) / (46 - 14)
    sec2 = sec2 * (jumpVelocity - 14) + 1
    sec2 = math.floor(sec2 * 10) / 10

    mass = (sec1 + sec2) / 2
    return mass
  elseif partType == "booster" then
    --calculating booster mass from 1 to 6.5 based on stats
    local airControlSpeed = root.evalFunction("mechBoosterAirControlSpeed", partConfig.stats.speed or 0)
    local airControlForce = root.evalFunction("mechBoosterAirControlForce", partConfig.stats.control or 0)

    local sec1 = (7 - 1) / (10 - 2)
    sec1 = sec1 * (airControlSpeed - 2) + 1
    sec1 = math.floor(sec1 * 10) / 10

    local sec2 = (7 - 1) / (50 - 10)
    sec2 = sec2 * (airControlForce - 10) + 1
    sec2 = math.floor(sec2 * 10) / 10
    mass = (sec1 + sec2) / 2
    return mass
  else
    return 0
  end
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
