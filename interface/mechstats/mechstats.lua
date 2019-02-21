require "/vehicles/modularmech/mechpartmanager.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

previewStates = {
  power = "active",
  boost = "idle",
  frontFoot = "preview",
  backFoot = "preview",
  leftArm = "idle",
  rightArm = "idle"
}

function init()
  local getUnlockedMessage = world.sendEntityMessage(player.id(), "mechUnlocked")
  if getUnlockedMessage:finished() and getUnlockedMessage:succeeded() then
    local unlocked = getUnlockedMessage:result()
    if not unlocked then
      self.disabled = true
      
    else

    end
  end

  self.partManager = MechPartManager:new()

  self.itemSet = {}
  local getItemSetMessage = world.sendEntityMessage(player.id(), "getMechItemSet")
  if getItemSetMessage:finished() and getItemSetMessage:succeeded() then
    self.itemSet = getItemSetMessage:result()
  else
    sb.logError("Mech stats interface unable to fetch player mech parts!")
  end

  self.primaryColorIndex = 0
  self.secondaryColorIndex = 0
  local getColorIndexesMessage = world.sendEntityMessage(player.id(), "getMechColorIndexes")
  if getColorIndexesMessage:finished() and getColorIndexesMessage:succeeded() then
    local res = getColorIndexesMessage:result()
    self.primaryColorIndex = res.primary
    self.secondaryColorIndex = res.secondary
  else
    sb.logError("Mech stats interface unable to fetch player mech paint colors!")
  end

  self.previewCanvas = widget.bindCanvas("cvsPreview")

  for partType, itemDescriptor in pairs(self.itemSet) do
    widget.setItemSlotItem("itemSlot_" .. partType, itemDescriptor)
  end

  self.chips = {}
  self.chipsMessage = world.sendEntityMessage(player.id(), "getMechUpgradeItems")
  self.chips = self.chipsMessage:result()
  self.chipsMessage = nil

  for chipName, itemDescriptor in pairs(self.chips) do
    widget.setItemSlotItem("itemSlot_" .. chipName, itemDescriptor)
  end

  updatePreview()
end

function update(dt)

end

function updatePreview()
  -- assemble vehicle and animation config
  local params = self.partManager:buildVehicleParameters(self.itemSet, self.primaryColorIndex, self.secondaryColorIndex)
  local animationConfig = root.assetJson("/vehicles/modularmech/modularmech.animation")
  util.mergeTable(animationConfig, params.animationCustom)

  -- build list of parts to preview
  local previewParts = {}
  for partName, partConfig in pairs(animationConfig.animatedParts.parts) do
    local partImageSet = params.partImages
    if partName:sub(1, 7) == "leftArm" and params.parts.leftArm and params.parts.leftArm.backPartImages then
      partImageSet = util.replaceTag(params.parts.leftArm.backPartImages, "armName", "leftArm")
    elseif partName:sub(1, 7) == "rightArm" and params.parts.rightArm and params.parts.rightArm.backPartImages then
      partImageSet = util.replaceTag(params.parts.rightArm.frontPartImages, "armName", "rightArm")
    end

    if partImageSet[partName] and partImageSet[partName] ~= "" then
      local partProperties = partConfig.properties or {}
      if partConfig.partStates then
        for stateName, stateConfig in pairs(partConfig.partStates) do
          if previewStates[stateName] and stateConfig[previewStates[stateName]] then
            partProperties = util.mergeTable(partProperties, stateConfig[previewStates[stateName]].properties or {})
            break
          end
        end
      end

      if partProperties.image then
        local partImage = "/vehicles/modularmech/" .. util.replaceTag(partProperties.image, "partImage", partImageSet[partName])
        table.insert(previewParts, {
            centered = partProperties.centered,
            zLevel = partProperties.zLevel or 0,
            image = partImage,
            offset = vec2.mul(partProperties.offset or {0, 0}, 8)
          })
      end
    end
  end

  table.sort(previewParts, function(a, b) return a.zLevel < b.zLevel end)

  -- replace directive tags in preview images
  previewParts = util.replaceTag(previewParts, "directives", "")
  for partName, directives in pairs(params.partDirectives) do
    previewParts = util.replaceTag(previewParts, partName.."Directives", directives)
  end

  -- draw preview images
  self.previewCanvas:clear()

  local canvasCenter = vec2.mul(widget.getSize("cvsPreview"), 0.5)

  for _, part in ipairs(previewParts) do
    local pos = vec2.add(canvasCenter, part.offset)
    self.previewCanvas:drawImage(part.image, pos, nil, nil, part.centered)
  end

  if self.partManager:itemSetComplete(self.itemSet) then

    local healthMax = params.parts.body.healthMax + params.parts.body.healthBonus
    local speedPenaltyPercent = math.floor((params.parts.body.speedNerf or 0) * 100)
    local energyMax = params.parts.body.energyMax
    local energyDrain = params.parts.body.energyDrain + params.parts.leftArm.energyDrain + params.parts.rightArm.energyDrain
	  energyDrain = energyDrain * 0.6
    energyDrain = energyDrain + params.parts.body.energyPenalty
    local mass = params.parts.body.totalMass

    widget.setText("lblHealth", string.format("Health: %d", healthMax))
    widget.setText("lblEnergy", string.format("Fuel: %d", energyMax))
    widget.setText("lblDrain", string.format("Fuel usage: %.02f F/s", energyDrain))

  end
end
