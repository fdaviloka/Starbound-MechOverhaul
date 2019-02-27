require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  local playerId = player.id()
  local getUnlockedMessage = world.sendEntityMessage(playerId, "mechUnlocked")
  local mechParamsMessage = world.sendEntityMessage(playerId, "getMechParams")
  if getUnlockedMessage:finished() and getUnlockedMessage:succeeded() and mechParamsMessage:finished() and mechParamsMessage:succeeded() then
    local unlocked = getUnlockedMessage:result()
    local mechParams = mechParamsMessage:result()
    if not unlocked or not mechParams then
      local label = "^red;Unauthorized user"
      if not mechParams and unlocked then
        label = "^red;Build incomplete"
      end
      self.disabled = true
      widget.setVisible("imgLockedOverlay", true)
      widget.setButtonEnabled("btnUpgrade", false)
      widget.setText("lblLocked", label)
    else
      widget.setVisible("imgLockedOverlay", false)
    end
  else
    sb.logError("Mech fuel interface unable to check player mech enabled state!")
  end

  self.effeciencySet = false

  self.fuelsById = {
    liquidoil = { multiplier = 1.0, name = "Oil", textColor = "gray" },
    liquidfuel = { multiplier = 1.8, name = "Erchius", textColor = "#bf2fe2" },
    solidfuel = { multiplier = 3.6, name = "Erchius", textColor = "#bf2fe2" },
    unrefinedliquidmechfuel = { multiplier = 4.0, name = "Unrefined Fuel", textColor = "orange" },
    liquidmechfuel = { multiplier = 8.0, name = "Mech Fuel", textColor = "yellow" }
  }
  self.fuelColorsByName = {}
  for _, v in pairs(self.fuelsById) do
    self.fuelColorsByName[v.name] = v.textColor
  end
end

function update(dt)
  if self.disabled then return end

  local playerId = player.id()
  -- If the dialog is open during beaming, there's a chance player.id
  -- returns 0, which segfaults world.sendEntityMessage.
  if playerId == 0 then return end

  if not self.currentFuelMessage then
    self.currentFuelMessage = world.sendEntityMessage(playerId, "getQuestFuelCount")
  end

  if self.currentFuelMessage and self.currentFuelMessage:finished() then
    if self.currentFuelMessage:succeeded() then
      self.currentFuel = self.currentFuelMessage:result()
    end
    self.currentFuelMessage = nil
  end

  if not self.maxFuelMessage then
    self.maxFuelMessage = world.sendEntityMessage(playerId, "getMechParams")
  end

  if self.maxFuelMessage and self.maxFuelMessage:finished() then
    if self.maxFuelMessage:succeeded() then
      if self.maxFuelMessage:result() then
        local params = self.maxFuelMessage:result()
        self.maxFuel = math.floor(params.parts.body.energyMax)
      end
    end
  end

  if self.maxFuel and self.currentFuel then
    widget.setText("lblModuleCount", string.format("%.02f", self.currentFuel) .. " / " .. self.maxFuel)
  end

  if self.setItemMessage and self.setItemMessage:finished() then
    self.setItemMessage = nil
  end

  if not self.getItemMessage then
    self.getItemMessage = world.sendEntityMessage(playerId, "getFuelSlotItem")
  end
  if self.getItemMessage and self.getItemMessage:finished() then
    if self.getItemMessage:succeeded() then
      local item = self.getItemMessage:result()
      widget.setItemSlotItem("itemSlot_fuel", item)
      fuelCountPreview(item)

      if not self.efficiencySet then
        setEfficiencyText(item)
        self.efficiencySet = true
      end
    end
    self.getItemMessage = nil
  end

  if not self.fuelTypeMessage then
    self.fuelTypeMessage = world.sendEntityMessage(playerId, "getFuelType")
  end
  if self.fuelTypeMessage and self.fuelTypeMessage:finished() then
    if self.fuelTypeMessage:succeeded() then
      local fuelType = self.fuelTypeMessage:result()
      self.currentFuelType = fuelType
      setFuelTypeText(fuelType)
    end
    self.fuelTypeMessage = nil
  end
end

function insertFuel()
  if self.disabled then return end

  swapItem("itemSlot_fuel")
end

function fuel()
  if self.disabled then return end

  local item = widget.itemSlotItem("itemSlot_fuel")
  if not item then return end

  local fuelClass = self.fuelsById[item.name]

  if self.currentFuelType and fuelClass.name ~= self.currentFuelType then
    widget.setText("lblEfficiency", "^red;The tank has a different type of fuel, empty it first.^white;")
    return
  end

  local addFuelCount = self.currentFuel + (item.count * fuelClass.multiplier)

  local id = player.id()
  if addFuelCount > self.maxFuel then
    item.count = math.floor((addFuelCount - self.maxFuel) / fuelClass.multiplier)
    self.setItemMessage = world.sendEntityMessage(id, "setFuelSlotItem", item)
    addFuelCount = self.maxFuel
  else
    self.setItemMessage = world.sendEntityMessage(id, "setFuelSlotItem", nil)
    widget.setText("lblEfficiency", "")
  end

  world.sendEntityMessage(id, "setFuelType", fuelClass.name)
  world.sendEntityMessage(id, "setQuestFuelCount", addFuelCount)
end

function swapItem(widgetName)
  local currentItem = widget.itemSlotItem(widgetName)
  local swapItem = player.swapSlotItem()
  if swapItem and not self.fuelsById[swapItem.name] then
    return
  end

  if currentItem and swapItem and currentItem.name == swapItem.name then
    local itemCount = currentItem.count + swapItem.count

    if itemCount > 1000 then
      currentItem.count = itemCount - 1000
      swapItem.count = 1000
    else
      currentItem = nil
      swapItem.count = itemCount
    end
  end

  player.setSwapSlotItem(currentItem)
  widget.setItemSlotItem(widgetName, swapItem)

  setEfficiencyText(swapItem)

  local id = player.id()
  if not self.setItemMessage then
    self.setItemMessage = world.sendEntityMessage(id, "setFuelSlotItem", swapItem)
  end
end

function setEfficiencyText(currentItem)
  if not currentItem then
    widget.setText("lblEfficiency", "")
    return
  end

  local fuelClass = self.fuelsById[currentItem.name]

  widget.setText("lblEfficiency", "Detected fuel type: ^" .. fuelClass.textColor .. ";" .. fuelClass.name .. "^white;, " .. "Efficiency: " .. string.format("%.01f", fuelClass.multiplier))
end

function fuelCountPreview(item)
  if not item then
    widget.setText("lblModuleCount", string.format("%.02f", self.currentFuel) .. " / " .. math.floor(self.maxFuel))
    return
  end

  local fuelClass = self.fuelsById[item.name]

  local addFuelCount = self.currentFuel + (item.count * fuelClass.multiplier)
  if addFuelCount > self.maxFuel then addFuelCount = self.maxFuel end

  widget.setText("lblModuleCount", "^" .. fuelClass.textColor .. ";" .. string.format("%.02f", addFuelCount) .. "^white; / " .. math.floor(self.maxFuel))
end

function setFuelTypeText(type)
  local textColor = self.fuelColorsByName[type]

  if textColor then
    widget.setText("lblFuelType", "TYPE: ^" .. textColor .. ";" .. type)
  else
    widget.setText("lblFuelType", "TYPE: EMPTY")
  end
end
