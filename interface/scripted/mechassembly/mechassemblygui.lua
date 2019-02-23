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
  --fist itemslot update
  self.itemChanged = true

  self.disabledText = config.getParameter("disabledText")
  self.completeText = config.getParameter("completeText")
  self.incompleteText = config.getParameter("incompleteText")

  --set health and mess format from config
  self.healthFormat = config.getParameter("healthFormat")
  self.massFormat = config.getParameter("massFormat")
  self.energyFormat = config.getParameter("energyFormat")
  self.drainFormat = config.getParameter("drainFormat")

  self.imageBasePath = config.getParameter("imageBasePath")

  local getUnlockedMessage = world.sendEntityMessage(player.id(), "mechUnlocked")
  if getUnlockedMessage:finished() and getUnlockedMessage:succeeded() then
    local unlocked = getUnlockedMessage:result()
    if not unlocked then
      self.disabled = true
      widget.setVisible("imgDisabledOverlay", true)
      widget.setVisible("imgLockedExpansion", true)
      widget.setVisible("itemSlot_expansion", false)
      widget.setButtonEnabled("btnPrevPrimaryColor", false)
      widget.setButtonEnabled("btnNextPrimaryColor", false)
      widget.setButtonEnabled("btnPrevSecondaryColor", false)
      widget.setButtonEnabled("btnNextSecondaryColor", false)
    else
      widget.setVisible("imgDisabledOverlay", false)
      widget.setVisible("imgLockedExpansion", false)
      widget.setVisible("itemSlot_expansion", true)
    end
  else
    sb.logError("Mech assembly interface unable to check player mech enabled state!")
  end

  self.partManager = MechPartManager:new()

  self.itemSet = {}
  local getItemSetMessage = world.sendEntityMessage(player.id(), "getMechItemSet")
  if getItemSetMessage:finished() and getItemSetMessage:succeeded() then
    self.itemSet = getItemSetMessage:result()
  else
    sb.logError("Mech assembly interface unable to fetch player mech parts!")
  end

  self.primaryColorIndex = 0
  self.secondaryColorIndex = 0
  local getColorIndexesMessage = world.sendEntityMessage(player.id(), "getMechColorIndexes")
  if getColorIndexesMessage:finished() and getColorIndexesMessage:succeeded() then
    local res = getColorIndexesMessage:result()
    self.primaryColorIndex = res.primary
    self.secondaryColorIndex = res.secondary
  else
    sb.logError("Mech assembly interface unable to fetch player mech paint colors!")
  end

  self.previewCanvas = widget.bindCanvas("cvsPreview")

  for partType, itemDescriptor in pairs(self.itemSet) do
    widget.setItemSlotItem("itemSlot_" .. partType, itemDescriptor)
  end

  widget.setImage("imgPrimaryColorPreview", colorPreviewImage(self.primaryColorIndex))
  widget.setImage("imgSecondaryColorPreview", colorPreviewImage(self.secondaryColorIndex))

  self.chips = {}
  self.chipsMessage = world.sendEntityMessage(player.id(), "getMechUpgradeItems")
  self.chips = self.chipsMessage:result()
  self.chipsMessage = nil

  updatePreview()
  updateComplete()
end

function update(dt)
  if self.disabled then return end

  if not self.itemSetChangedMessage then
    self.itemSetChangedMessage = world.sendEntityMessage(player.id(), "getMechLoadoutItemSetChanged")
  end
  if self.itemSetChangedMessage and self.itemSetChangedMessage:finished() then
    if self.itemSetChangedMessage:succeeded() then
      local itemSetChanged = self.itemSetChangedMessage:result()
      if itemSetChanged then
        remoteItemSetChanged()
        world.sendEntityMessage(player.id(), "setMechLoadoutItemSetChanged", false)
      end
    end
    self.itemSetChangedMessage = nil
  end

  --update item slots based on dummy quest
  if not self.chipsMessage and self.itemChanged then
    self.chipsMessage = world.sendEntityMessage(player.id(), "getMechUpgradeItems")
  end
  if self.chipsMessage and self.chipsMessage:finished() then
    if self.chipsMessage:succeeded() then
      self.chips = self.chipsMessage:result()
      local chips = self.chips
      widget.setItemSlotItem("itemSlot_upgrade1", chips.chip1)
      widget.setItemSlotItem("itemSlot_upgrade2", chips.chip2)
      widget.setItemSlotItem("itemSlot_upgrade3", chips.chip3)
      widget.setItemSlotItem("itemSlot_expansion", chips.expansion)

      local expansionItem = widget.itemSlotItem("itemSlot_expansion")

      if expansionItem then
        if expansionItem.name == "mechchipexpansion1" then
          widget.setVisible("imgLocked1", false)
          widget.setVisible("itemSlot_upgrade1", true)

          widget.setVisible("imgLocked2", true)
          widget.setVisible("itemSlot_upgrade2", false)
          widget.setVisible("imgLocked3", true)
          widget.setVisible("itemSlot_upgrade3", false)
        elseif expansionItem.name == "mechchipexpansion2" then
          widget.setVisible("imgLocked1", false)
          widget.setVisible("itemSlot_upgrade1", true)
          widget.setVisible("imgLocked2", false)
          widget.setVisible("itemSlot_upgrade2", true)

          widget.setVisible("imgLocked3", true)
          widget.setVisible("itemSlot_upgrade3", false)
        elseif expansionItem.name == "mechchipexpansion3" then
          widget.setVisible("imgLocked1", false)
          widget.setVisible("itemSlot_upgrade1", true)
          widget.setVisible("imgLocked2", false)
          widget.setVisible("itemSlot_upgrade2", true)
          widget.setVisible("imgLocked3", false)
          widget.setVisible("itemSlot_upgrade3", true)
        end
      else
        widget.setVisible("imgLocked1", true)
        widget.setVisible("itemSlot_upgrade1", false)
        widget.setVisible("imgLocked2", true)
        widget.setVisible("itemSlot_upgrade2", false)
        widget.setVisible("imgLocked3", true)
        widget.setVisible("itemSlot_upgrade3", false)
      end
    end
    self.chipsMessage = nil
    self.itemChanged = false
    itemSetChanged()
  end

end

function setExpansion()
  if self.disabled then return end

  swapItemChips("itemSlot_expansion", true, "setMechExpansionSlotItem")
end

function setChip1()
  if self.disabled then return end

  swapItemChips("itemSlot_upgrade1", false, "setMechUpgradeItem1")
end

function setChip2()
  if self.disabled then return end

  swapItemChips("itemSlot_upgrade2", false, "setMechUpgradeItem2")
end

function setChip3()
  if self.disabled then return end

  swapItemChips("itemSlot_upgrade3", false, "setMechUpgradeItem3")
end

function swapItemChips(slotName, expansion, messageName)
  if self.disabled then return end

  local currentItem = widget.itemSlotItem(slotName)
  local swapItem = player.swapSlotItem()

  local upgrades = {}
  upgrades.upgrade1 = widget.itemSlotItem("itemSlot_upgrade1")
  upgrades.upgrade2 = widget.itemSlotItem("itemSlot_upgrade2")
  upgrades.upgrade3 = widget.itemSlotItem("itemSlot_upgrade3")

  if swapItem and ((upgrades.upgrade1 and swapItem.name == upgrades.upgrade1.name)
  or (upgrades.upgrade2 and swapItem.name == upgrades.upgrade2.name)
  or (upgrades.upgrade3 and swapItem.name == upgrades.upgrade3.name)) then return end

  if not swapItem or (not expansion and string.find(swapItem.name, "mechchip")) or
  (expansion and string.find(swapItem.name, "mechchipexpansion")) then
    player.setSwapSlotItem(currentItem)
    widget.setItemSlotItem(slotName, swapItem)

    world.sendEntityMessage(player.id(), messageName, swapItem)

    currentItem = widget.itemSlotItem("itemSlot_expansion")

    if not currentItem and expansion then
      if upgrades.upgrade1 then
        player.giveItem(upgrades.upgrade1)
        world.sendEntityMessage(player.id(), "setMechUpgradeItem1", nil)
      end
      if upgrades.upgrade1 then
        player.giveItem(upgrades.upgrade1)
        world.sendEntityMessage(player.id(), "setMechUpgradeItem2", nil)
      end
      if upgrades.upgrade3 then
        player.giveItem(upgrades.upgrade3)
        world.sendEntityMessage(player.id(), "setMechUpgradeItem3", nil)
      end
    elseif currentItem and expansion then
      if currentItem.name == "mechchipexpansion2" then
        if upgrades.upgrade3 then
          player.giveItem(upgrades.upgrade3)
          world.sendEntityMessage(player.id(), "setMechUpgradeItem3", nil)
        end
      elseif currentItem.name == "mechchipexpansion1" then
        if upgrades.upgrade1 then
          player.giveItem(upgrades.upgrade1)
          world.sendEntityMessage(player.id(), "setMechUpgradeItem2", nil)
        end
        if upgrades.upgrade3 then
          player.giveItem(upgrades.upgrade3)
          world.sendEntityMessage(player.id(), "setMechUpgradeItem3", nil)
        end
      end
    end

    self.itemChanged = true
  end
end

function swapItem(widgetName)
  if self.disabled then return end

  local partType = string.sub(widgetName, 10)

  local currentItem = self.itemSet[partType]
  local swapItem = player.swapSlotItem()

  if not swapItem or self.partManager:partConfig(partType, swapItem) then
    player.setSwapSlotItem(currentItem)
    widget.setItemSlotItem(widgetName, swapItem)

    self.itemSet[partType] = swapItem

    itemSetChanged()
  end
end

function remoteItemSetChanged()
  self.itemSet = {}
  local getItemSetMessage = world.sendEntityMessage(player.id(), "getMechItemSet")
  if getItemSetMessage:finished() and getItemSetMessage:succeeded() then
    self.itemSet = getItemSetMessage:result()

    for partType,_ in pairs({rightArm = "", leftArm = "", body = "", booster = "", legs = ""}) do
      widget.setItemSlotItem("itemSlot_" .. partType, nil)
    end

    for partType, itemDescriptor in pairs(self.itemSet) do
      widget.setItemSlotItem("itemSlot_" .. partType, itemDescriptor)
    end
  else
    sb.logError("Mech assembly interface unable to fetch player mech parts!")
  end

  updatePreview()
  updateComplete()
end

function itemSetChanged()
  world.sendEntityMessage(player.id(), "setMechItemSet", self.itemSet)
  updatePreview()
  updateComplete()
end

function nextPrimaryColor()
  self.primaryColorIndex = self.partManager:validateColorIndex(self.primaryColorIndex + 1)
  colorSelectionChanged()
end

function prevPrimaryColor()
  self.primaryColorIndex = self.partManager:validateColorIndex(self.primaryColorIndex - 1)
  colorSelectionChanged()
end

function nextSecondaryColor()
  self.secondaryColorIndex = self.partManager:validateColorIndex(self.secondaryColorIndex + 1)
  colorSelectionChanged()
end

function prevSecondaryColor()
  self.secondaryColorIndex = self.partManager:validateColorIndex(self.secondaryColorIndex - 1)
  colorSelectionChanged()
end

function colorSelectionChanged()
  widget.setImage("imgPrimaryColorPreview", colorPreviewImage(self.primaryColorIndex))
  widget.setImage("imgSecondaryColorPreview", colorPreviewImage(self.secondaryColorIndex))
  world.sendEntityMessage(player.id(), "setMechColorIndexes", self.primaryColorIndex, self.secondaryColorIndex)
  updatePreview()
end

function updateComplete()
  if self.disabled then
    widget.setVisible("imgIncomplete", true)
    widget.setText("lblStatus", self.disabledText)
  elseif self.partManager:itemSetComplete(self.itemSet) then
    widget.setVisible("imgIncomplete", false)
    widget.setText("lblStatus", self.completeText)
  else
    widget.setVisible("imgIncomplete", true)
    widget.setText("lblStatus", self.incompleteText)
  end

  for _, partName in ipairs(self.partManager.requiredParts) do
    widget.setVisible("imgMissing_"..partName, not self.itemSet[partName])
  end
end

function colorPreviewImage(colorIndex)
  if colorIndex == 0 then
    return self.imageBasePath .. "paintbar_default.png"
  else
    local img = self.imageBasePath .. "paintbar.png"
    local toColors = self.partManager.paletteConfig.swapSets[colorIndex]
    for i, fromColor in ipairs(self.partManager.paletteConfig.primaryMagicColors) do
      img = string.format("%s?replace=%s=%s", img, fromColor, toColors[i])
    end
    return img
  end
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
    --health visible
    widget.setVisible("imgHealthBar", true)
    widget.setVisible("lblHealth", true)
    widget.setVisible("lblMass", true)
    widget.setVisible("lblHealthBonus", true)
    widget.setVisible("lblSpeedPenalty", true)
    widget.setVisible("lblEnergyPenalty", true)
    widget.setVisible("imgEnergyBar", true)
    widget.setVisible("lblEnergy", true)
    widget.setVisible("lblDrain", true)

    params = MechPartManager.calculateTotalMass(params, self.chips)

    local healthMax = params.parts.body.healthMax + params.parts.body.healthBonus
    local speedPenaltyPercent = math.floor((params.parts.body.speedNerf or 0) * 100)
    local energyMax = params.parts.body.energyMax
    local energyDrain = params.parts.body.energyDrain + params.parts.leftArm.energyDrain + params.parts.rightArm.energyDrain
	  energyDrain = energyDrain * 0.6
    energyDrain = energyDrain + params.parts.body.energyPenalty
    local mass = params.parts.body.totalMass

    if speedPenaltyPercent <= 0 then
      widget.setVisible("lblSpeedPenalty", false)
    else
      widget.setVisible("lblSpeedPenalty", true)
    end

    if params.parts.body.healthBonus and params.parts.body.healthBonus <= 0 then
      widget.setVisible("lblHealthBonus", false)
    else
      widget.setVisible("lblHealthBonus", true)
    end

    if params.parts.body.energyPenalty and params.parts.body.energyPenalty <= 0 then
      widget.setVisible("lblEnergyPenalty", false)
    else
      widget.setVisible("lblEnergyPenalty", true)
    end
	  --set healthmax and mass text
	  widget.setText("lblHealth", string.format(self.healthFormat, healthMax))
    widget.setText("lblMass", string.format(self.massFormat, mass))
    widget.setText("lblHealthBonus", string.format("Health bonus: %d", params.parts.body.healthBonus))
    widget.setText("lblSpeedPenalty", "Speed penalty: -" .. string.format("%d", speedPenaltyPercent) .. "%")
    widget.setText("lblEnergyPenalty", "Drain penalty:+" .. string.format("%.2f", params.parts.body.energyPenalty or 0) .. "F/s")
    widget.setText("lblEnergy", string.format(self.energyFormat, energyMax))
    widget.setText("lblDrain", string.format(self.drainFormat, energyDrain))
  else
    --health invisible
    widget.setVisible("imgHealthBar", false)
    widget.setVisible("lblHealth", false)
    widget.setVisible("lblMass", false)
    widget.setVisible("lblHealthBonus", false)
    widget.setVisible("lblSpeedPenalty", false)
    widget.setVisible("lblEnergyPenalty", false)
    widget.setVisible("imgEnergyBar", false)
    widget.setVisible("lblEnergy", false)
    widget.setVisible("lblDrain", false)
  end
end
