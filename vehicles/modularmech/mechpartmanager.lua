require "/scripts/util.lua"

MechPartManager = {}

function MechPartManager:new()
  local newPartManager = {}

  -- all possible types of parts
  newPartManager.partTypes = {
    "leftArm",
    "rightArm",
    "booster",
    "body",
    "legs",
    "horn"
  }

  -- parts required for a mech to launch
  newPartManager.requiredParts = {
    "leftArm",
    "rightArm",
    "body",
    "booster",
    "legs"
  }

  -- maps the stat levels in part configurations to functions which
  -- determine the numerical stats applied to each part
  newPartManager.partStatMap = {
    body = {
      energy = {
        energyMax = "mechBodyEnergyMax",
        energyDrain = "mechBodyEnergyDrain"
      },
      protection = {
        protection = "mechBodyProtection"
      }
    },
    booster = {
      speed = {
        airControlSpeed = "mechBoosterAirControlSpeed",
        flightControlSpeed = "mechBoosterFlightControlSpeed"
      },
      control = {
        airControlForce = "mechBoosterAirControlForce",
        flightControlForce = "mechBoosterFlightControlForce"
      }
    },
    legs = {
      speed = {
        groundSpeed = "mechLegsGroundSpeed",
        groundControlForce = "mechLegsGroundControlForce"
      },
      jump = {
        jumpVelocity = "mechLegsJumpVelocity",
        jumpAirControlSpeed = "mechLegsJumpAirControlSpeed",
        jumpAirControlForce = "mechLegsJumpAirControlForce",
        jumpBoostTime = "mechLegsJumpBoostTime"
      }
    },
    leftArm = {
      power = {
        power = "mechArmPower"
      },
      energy = {
        energyDrain = "mechArmEnergyDrain"
      }
    },
    rightArm = {
      power = {
        power = "mechArmPower"
      },
      energy = {
        energyDrain = "mechArmEnergyDrain"
      }
    }
  }

  -- load part configurations
  newPartManager.partTypeConfigs = {
    arm = root.assetJson("/vehicles/modularmech/mechparts_arm.config"),
    body = root.assetJson("/vehicles/modularmech/mechparts_body.config"),
    booster = root.assetJson("/vehicles/modularmech/mechparts_booster.config"),
    legs = root.assetJson("/vehicles/modularmech/mechparts_legs.config"),
    horn = root.assetJson("/vehicles/modularmech/mechparts_horn.config")
  }

  newPartManager.paletteConfig = root.assetJson("/vehicles/modularmech/mechpalettes.config")

  setmetatable(newPartManager, extend(self))
  return newPartManager
end

function MechPartManager:partConfig(partType, itemDescriptor)
  local typeKey = (partType == "leftArm" or partType == "rightArm") and "arm" or partType
  local itemConfig = root.itemConfig(itemDescriptor)
  if itemConfig then
    local mechPartConfig = itemConfig.parameters.mechPart or itemConfig.config.mechPart
    if type(mechPartConfig) == "table" and #mechPartConfig == 2 then
      if mechPartConfig[1] == typeKey and self.partTypeConfigs[typeKey] then
        return copy(self.partTypeConfigs[typeKey][mechPartConfig[2]])
      end
    end
  end
end

function MechPartManager:validateItemSet(itemSet)
  if type(itemSet) ~= "table" then return {} end

  local validSet = {}
  for _, partType in ipairs(self.partTypes) do
    if itemSet[partType] and self:partConfig(partType, itemSet[partType]) then
      validSet[partType] = itemSet[partType]
    -- else
    --   sb.logError("Item %s not valid for part type %s", itemSet[partType] or "nil", partType)
    end
  end
  return validSet
end

function MechPartManager:itemSetComplete(itemSet)
  for _, partName in ipairs(self.requiredParts) do
    if not itemSet[partName] then return false end
  end
  return true
end

function MechPartManager:missingParts(itemSet)
  local res = {}
  for _, partName in ipairs(self.requiredParts) do
    if not itemSet[partName] then
      table.insert(res, partName)
    end
  end
  return res
end

function MechPartManager:buildVehicleParameters(itemSet, primaryColorIndex, secondaryColorIndex)
  local params = {
    parts = {},
    partDirectives = {},
    partImages = {},
    animationCustom = {},
    damageSources = {},
    loungePositions = {},
    physicsForces = {},
    physicsCollisions = {}
  }

  for partType, itemDescriptor in pairs(itemSet) do
    local thisPartConfig = self:partConfig(partType, itemDescriptor)
    if partType == "leftArm" or partType == "rightArm" then
      thisPartConfig = util.replaceTag(thisPartConfig, "armName", partType)
    end

    if partType ~= "horn" then
      if self.partStatMap[partType] and thisPartConfig.stats then
        for stat, fMap in pairs(self.partStatMap[partType]) do
          for param, fName in pairs(fMap) do
            thisPartConfig.partParameters[param] = root.evalFunction(fName, thisPartConfig.stats[stat])
          end
        end
      end

      params.parts[partType] = thisPartConfig.partParameters

      primaryColorIndex = self:validateColorIndex(primaryColorIndex)
      secondaryColorIndex = self:validateColorIndex(secondaryColorIndex)
      params.partDirectives[partType] = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)

      params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
      params.damageSources = util.mergeTable(params.damageSources, thisPartConfig.damageSources or {})
      params.loungePositions = util.mergeTable(params.loungePositions, thisPartConfig.loungePositions or {})
      params.physicsForces = util.mergeTable(params.physicsForces, thisPartConfig.physicsForces or {})
      params.physicsCollisions = util.mergeTable(params.physicsCollisions, thisPartConfig.physicsCollisions or {})
    end

    params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
  end

  --calculating mech mass based on stats
  local mass = 0

  --body mass
  if params.parts.body then
    if params.parts.body.protection == 0.682 then
      params.parts.body.massValue = 1
    elseif params.parts.body.protection == 0.716 then
    params.parts.body.massValue = 1.5
    elseif params.parts.body.protection == 0.760 then
      params.parts.body.massValue = 2
    elseif params.parts.body.protection == 0.808 then
      params.parts.body.massValue = 3.5
    elseif params.parts.body.protection == 0.846 then
      params.parts.body.massValue = 4.5
    elseif params.parts.body.protection == 0.877 then
      params.parts.body.massValue = 6
    elseif params.parts.body.protection == 0.902 then
      params.parts.body.massValue = 8
    elseif params.parts.body.protection == 0.921 then
      params.parts.body.massValue = 10
    elseif params.parts.body.protection == 0.937 then
      params.parts.body.massValue = 12.5
    elseif params.parts.body.protection == 0.950 then
      params.parts.body.massValue = 15
    end
    mass = mass + params.parts.body.massValue
  end

  --calculating legs mass from 1 to 7 based on stats
  if params.parts.legs then
    local sec1 = (7 - 1) / (11 - 3.25)
    sec1 = sec1 * (params.parts.legs.groundSpeed - 3.25) + 1
    sec1 = math.floor(sec1 * 10) / 10

    local sec2 = (7 - 1) / (46 - 14)
    sec2 = sec2 * (params.parts.legs.jumpVelocity - 14) + 1
    sec2 = math.floor(sec2 * 10) / 10
    params.parts.legs.massValue = (sec1 + sec2) / 2
    mass = mass + params.parts.legs.massValue
  end

  --calculating booster mass from 1 to 6.5 based on stats
  if params.parts.booster then
    local sec1 = (6.5 - 1) / (10 - 2)
    sec1 = sec1 * (params.parts.booster.airControlSpeed - 2) + 1
    sec1 = math.floor(sec1 * 10) / 10

    local sec2 = (6.5 - 1) / (50 - 10)
    sec2 = sec2 * (params.parts.booster.airControlForce - 10) + 1
    sec2 = math.floor(sec2 * 10) / 10
    params.parts.booster.massValue = (sec1 + sec2) / 2
    mass = mass + params.parts.booster.massValue
  end

  --arms mass = arms power * 0.4
  if params.parts.leftArm then
    params.parts.leftArm.massValue = params.parts.leftArm.power * 0.40
    mass = mass + params.parts.leftArm.massValue
  end
  if params.parts.rightArm then
    params.parts.rightArm.massValue = params.parts.rightArm.power * 0.40
    mass = mass + params.parts.rightArm.massValue
  end

  mass = math.floor(mass * 10) / 10
  params.parts.body.totalMass = mass
  --end

  --calculating health bonus and speed nerf based on mass and protection
  --Mech body protection values
  --level3: 760
  --level4: 808
  --level5: 846
  --level6: 877
  --level7: 902
  if params.parts.body then
    local initialBonus = 10
    local maxHealthBonus = params.parts.body.energyMax * 0.5
    local initialMass = 12
    local maxMass = 18

    local sec = (maxHealthBonus - initialBonus) / (maxMass - initialMass)
    sec = sec * (params.parts.body.totalMass - initialMass) + initialBonus
    local healthBonus = math.floor(sec) + (math.floor(params.parts.body.protection * 100) * 10) - 750
    if params.parts.body.protection < 0.760 then
      healthBonus = math.floor(sec)
    end
    params.parts.body.healthBonus = healthBonus

    local initialNerf = 0.01
    local maxNerf = 0.4
    initialMass = 15
    maxMass = 18

    local sec = (maxNerf - initialNerf) / (maxMass - initialMass)
    sec = sec * (params.parts.body.totalMass - initialMass) + initialNerf
    params.parts.body.speedNerf = math.floor(sec * 100) / 100
  end

  return params
end

function MechPartManager:validateColorIndex(colorIndex)
  if type(colorIndex) ~= "number" then return 0 end

  if colorIndex > #self.paletteConfig.swapSets or colorIndex < 0 then
    colorIndex = colorIndex % (#self.paletteConfig.swapSets + 1)
  end
  return colorIndex
end

function MechPartManager:buildSwapDirectives(partConfig, primaryIndex, secondaryIndex)
  local result = ""
  local primaryColors = primaryIndex == 0 and partConfig.defaultPrimaryColors or self.paletteConfig.swapSets[primaryIndex]
  for i, fromColor in ipairs(self.paletteConfig.primaryMagicColors) do
    result = string.format("%s?replace=%s=%s", result, fromColor, primaryColors[i])
  end
  local secondaryColors = secondaryIndex == 0 and partConfig.defaultSecondaryColors or self.paletteConfig.swapSets[secondaryIndex]
  for i, fromColor in ipairs(self.paletteConfig.secondaryMagicColors) do
    result = string.format("%s?replace=%s=%s", result, fromColor, secondaryColors[i])
  end
  return result
end
