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
    "horn",

    -------------------------
    -- Cosmetic_slots_for_Mechs
    "booster_social",
    "body_social",
    "legs_social"
    -------------------------
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

  -------------------------
  -- Cosmetic_slots_for_Mechs
  local typeKey = (partType == "leftArm" or partType == "rightArm") and "arm" or (partType == "body_social") and "body" or (partType == "legs_social") and "legs" or (partType == "booster_social") and "booster" or partType
  -------------------------

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

  -------------------------
  -- Cosmetic_slots_for_Mechs
  for partType, itemDescriptor in pairs(itemSet) do
    local thisPartConfig = self:partConfig(partType, itemDescriptor)
    if partType == "leftArm" or partType == "rightArm" then
      thisPartConfig = util.replaceTag(thisPartConfig, "armName", partType)
      primaryColorIndex = self:validateColorIndex(primaryColorIndex)
      secondaryColorIndex = self:validateColorIndex(secondaryColorIndex)
      params.partDirectives[partType] = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)
      params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
      params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
    end
    if partType == "leftArm" or partType == "rightArm" or partType == "body" or partType == "legs" or partType == "booster" then
      if self.partStatMap[partType] and thisPartConfig.stats then
        for stat, fMap in pairs(self.partStatMap[partType]) do
          for param, fName in pairs(fMap) do
            thisPartConfig.partParameters[param] = root.evalFunction(fName, thisPartConfig.stats[stat])
          end
        end
      end
      params.parts[partType] = thisPartConfig.partParameters
      params.damageSources = util.mergeTable(params.damageSources, thisPartConfig.damageSources or {})
      params.loungePositions = util.mergeTable(params.loungePositions, thisPartConfig.loungePositions or {})
      params.physicsForces = util.mergeTable(params.physicsForces, thisPartConfig.physicsForces or {})
      params.physicsCollisions = util.mergeTable(params.physicsCollisions, thisPartConfig.physicsCollisions or {})
    end
    if partType == "body" then
      if itemSet.body_social == nil then
        primaryColorIndex = self:validateColorIndex(primaryColorIndex)
        secondaryColorIndex = self:validateColorIndex(secondaryColorIndex)
        params.partDirectives[partType] = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)
        params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
        params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
      end
    end
    if partType == "legs" then
      if itemSet.legs_social == nil then
        primaryColorIndex = self:validateColorIndex(primaryColorIndex)
        secondaryColorIndex = self:validateColorIndex(secondaryColorIndex)
        params.partDirectives[partType] = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)
        params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
        params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
      end
    end
    if partType == "booster" then
      if itemSet.booster_social == nil then
        primaryColorIndex = self:validateColorIndex(primaryColorIndex)
        secondaryColorIndex = self:validateColorIndex(secondaryColorIndex)
        params.partDirectives[partType] = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)
        params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
        params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
      end
    end
    if partType == "horn" then
      params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
      params.parts.hornName = (itemSet.horn and itemSet.horn.name)
    end
    if partType == "body_social" then
      if itemSet.body ~= nil then
        params.partDirectives.body = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)
        params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
        params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
      end
    end
    if partType == "legs_social" then
      if itemSet.legs ~= nil then
        params.partDirectives.legs = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)
        params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
        params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
      end
    end
    if partType == "booster_social" then
      if itemSet.booster ~= nil then
        params.partDirectives.booster = self:buildSwapDirectives(thisPartConfig, primaryColorIndex, secondaryColorIndex)
        params.partImages = util.mergeTable(params.partImages, thisPartConfig.partImages or {})
        params.animationCustom = util.mergeTable(params.animationCustom, thisPartConfig.animationCustom or {})
      end
    end
  end
  -------------------------

  if params.parts.body then
    params.parts.body.healthMax = params.parts.body.energyMax
  end

  params = MechPartManager.calculateTotalMass(params)

  return params
end

function MechPartManager.calculateTotalMass(params, chips)
  local partContext = {}
  partContext.protection = params.parts.body and params.parts.body.protection or 0
  partContext.power = params.parts.leftArm and params.parts.leftArm.power or 0
  partContext.legSpeed = params.parts.legs and params.parts.legs.groundSpeed or 0
  partContext.jump = params.parts.legs and params.parts.legs.jumpVelocity or 0
  partContext.boosterSpeed = params.parts.booster and params.parts.booster.airControlSpeed or 0
  partContext.control = params.parts.booster and params.parts.booster.airControlForce or 0
  if params.parts.body then params.parts.body.massValue = MechPartManager.getPartMass("body", partContext) end
  if params.parts.leftArm then params.parts.leftArm.massValue = MechPartManager.getPartMass("arm", partContext) end
  partContext.power = params.parts.rightArm and params.parts.rightArm.power or 0
  if params.parts.rightArm then params.parts.rightArm.massValue = MechPartManager.getPartMass("arm", partContext) end
  if params.parts.booster then params.parts.booster.massValue = MechPartManager.getPartMass("booster", partContext) end
  if params.parts.legs then params.parts.legs.massValue = MechPartManager.getPartMass("legs", partContext) end

  local mass = 0
  mass = mass + (params.parts.body and params.parts.body.massValue or 0)
  mass = mass + (params.parts.leftArm and params.parts.leftArm.massValue or 0)
  mass = mass + (params.parts.rightArm and params.parts.rightArm.massValue or 0)
  mass = mass + (params.parts.booster and params.parts.booster.massValue or 0)
  mass = mass + (params.parts.legs and params.parts.legs.massValue or 0)

  if params.parts.body then params.parts.body.totalMass = mass end

  params = MechPartManager.calculateBonuses(params)

  if chips then
    for _,chip in pairs(chips) do
      if chip.name == "mechchiphealth" then
        params.parts.body.totalMass = params.parts.body.totalMass * 1.2
        params.parts.body.healthBonus  = params.parts.body.healthBonus * 1.6
      end
      if chip.name == "mechchipspeed" then
        params.parts.legs.groundSpeed  = params.parts.legs.groundSpeed * 1.4
        params.parts.legs.groundControlForce = params.parts.legs.groundControlForce * 1.3
        params.parts.booster.airControlSpeed = params.parts.booster.airControlSpeed * 1.4
        params.parts.booster.flightControlSpeed = params.parts.booster.flightControlSpeed * 1.3

        params.parts.legs.jumpVelocity = params.parts.legs.jumpVelocity * 0.7
        params.parts.booster.airControlForce = params.parts.booster.airControlForce * 0.6
        params.parts.booster.flightControlForce = params.parts.booster.flightControlForce * 0.6
      end
      if chip.name == "mechchipfeather" then
        params.parts.body.totalMass = params.parts.body.totalMass * 0.85
        local protection = params.parts.body.protection

        if protection == 0.682 then
          params.parts.body.protection = 0.635
        elseif protection == 0.716 then
          params.parts.body.protection = 0.675
        elseif protection == 0.760 then
          params.parts.body.protection = 0.705
        elseif protection == 0.808 then
          params.parts.body.protection = 0.755
        elseif protection == 0.846 then
          params.parts.body.protection = 0.800
        elseif protection == 0.877 then
          params.parts.body.protection = 0.840
        elseif protection == 0.902 then
          params.parts.body.protection = 0.872
        elseif protection == 0.921 then
          params.parts.body.protection = 0.897
        elseif protection == 0.937 then
          params.parts.body.protection = 0.915
        elseif protection == 0.950 then
          params.parts.body.protection = 0.932
        end
      end

      if chip.name == "mechchipdefense" then
        params.parts.body.totalMass = params.parts.body.totalMass * 1.15
        local protection = params.parts.body.protection

        if protection == 0.682 then
          params.parts.body.protection = 0.712
        elseif protection == 0.716 then
          params.parts.body.protection = 0.765
        elseif protection == 0.760 then
          params.parts.body.protection = 0.812
        elseif protection == 0.808 then
          params.parts.body.protection = 0.851
        elseif protection == 0.846 then
          params.parts.body.protection = 0.882
        elseif protection == 0.877 then
          params.parts.body.protection = 0.907
        elseif protection == 0.902 then
          params.parts.body.protection = 0.924
        elseif protection == 0.921 then
          params.parts.body.protection = 0.940
        elseif protection == 0.937 then
          params.parts.body.protection = 0.953
        elseif protection == 0.950 then
          params.parts.body.protection = 0.962
        end
      end

      if chip.name == "mechchipfuel" then
        params.parts.body.energyMax = params.parts.body.energyMax * 1.5
        params.parts.body.healthMax = params.parts.body.healthMax * 0.75
      end

      if chip.name == "mechchipcontrol" then
        params.parts.legs.groundSpeed  = params.parts.legs.groundSpeed * 0.9
        params.parts.legs.groundControlForce = params.parts.legs.groundControlForce * 0.9
        params.parts.booster.airControlSpeed = params.parts.booster.airControlSpeed * 0.9
        params.parts.booster.flightControlSpeed = params.parts.booster.flightControlSpeed * 0.9

        params.parts.legs.jumpVelocity = params.parts.legs.jumpVelocity * 1.3
        params.parts.booster.airControlForce = params.parts.booster.airControlForce * 1.3
        params.parts.booster.flightControlForce = params.parts.booster.flightControlForce * 1.3
      end
    end

    params = MechPartManager.calculateBonuses(params, chips)
  end

  return params
end

function MechPartManager.calculateBonuses(params, chips)
  --calculating health bonus, speed penalty and energy drain penalty based on mass and protection
  --Mech body protection values
  --level3: 760
  --level4: 808
  --level5: 846
  --level6: 877
  --level7: 902
  if params.parts.body then
    local initialBonus = 10
    local maxHealthBonus = params.parts.body.healthMax * 0.5
    local initialMass = 10
    local maxMass = 20

    local sec = (maxHealthBonus - initialBonus) / (maxMass - initialMass)
    sec = sec * (params.parts.body.totalMass - initialMass) + initialBonus
    local healthBonus = math.floor(sec) + (math.floor(params.parts.body.protection * 100) * 10) - 750
    if params.parts.body.protection < 0.760 then
      healthBonus = math.floor(sec)
    end
    if healthBonus < 0 then healthBonus = 0 end
    params.parts.body.healthBonus = healthBonus

    local initialNerf = 0.01
    local maxNerf = 0.4
    initialMass = 15
    maxMass = 20

    local sec = (maxNerf - initialNerf) / (maxMass - initialMass)
    sec = sec * (params.parts.body.totalMass - initialMass) + initialNerf
    if sec < 0 then sec = 0 end
    if sec > 0.7 then sec = 0.7 end
    params.parts.body.speedNerf = math.floor(sec * 100) / 100

    initialMass = 15
    maxMass = 22
    initialNerf = 0.01
    maxNerf = 0.35

    local sec = (maxNerf - initialNerf) / (maxMass - initialMass)
    sec = sec * (params.parts.body.totalMass - initialMass) + initialNerf

    local energyDrain = params.parts.body.energyDrain + (params.parts.leftArm and params.parts.leftArm.energyDrain or 0) + (params.parts.rightArm and params.parts.rightArm.energyDrain or 0)
    energyDrain = energyDrain * 0.6
    energyDrain = energyDrain * sec
    energyDrain = math.floor(energyDrain * 100) / 100
    if energyDrain < 0 then energyDrain = 0 end
    params.parts.body.energyPenalty = energyDrain
  end

  if chips then
    for _,chip in pairs(chips) do
      if chip.name == "mechchippower" then
        params.parts.body.energyPenalty = params.parts.body.energyPenalty + 0.35
      end

      if chip.name == "mechchiplight" then
        params.parts.body.energyPenalty = params.parts.body.energyPenalty + 0.05
      end
    end
  end

  return params
end

--calculating mech mass based on stats
function MechPartManager.getPartMass(partName, partContext)
  local mass = 0

  if partName == "body" then
    --calculating mech mass based on stats

    local protection = partContext.protection
    if not protection then return 0 end

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

  elseif partName == "arm" then
    if not partContext.power then return 0 end
    --arms mass = arms power * 0.4
    mass = partContext.power * 0.40

  elseif partName == "legs" then
    --calculating legs mass from 1 to 7 based on stats
    local groundSpeed = partContext.legSpeed
    local jumpVelocity =partContext.jump
    if not groundSpeed or not jumpVelocity then return 0 end

    local sec1 = (6.5 - 1) / (11 - 3.25)
    sec1 = sec1 * (groundSpeed - 3.25) + 1
    sec1 = math.floor(sec1 * 10) / 10

    local sec2 = (6.5 - 1) / (46 - 14)
    sec2 = sec2 * (jumpVelocity - 14) + 1
    sec2 = math.floor(sec2 * 10) / 10

    mass = (sec1 + sec2) / 2
  elseif partName == "booster" then
    --calculating booster mass from 1 to 6.5 based on stats
    local airControlSpeed = partContext.boosterSpeed
    local airControlForce = partContext.control
    if not airControlForce or not airControlSpeed then return 0 end

    local sec1 = (7 - 1) / (10 - 2)
    sec1 = sec1 * (airControlSpeed - 2) + 1
    sec1 = math.floor(sec1 * 10) / 10

    local sec2 = (7 - 1) / (50 - 10)
    sec2 = sec2 * (airControlForce - 10) + 1
    sec2 = math.floor(sec2 * 10) / 10
    mass = (sec1 + sec2) / 2
  end

  return mass
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
