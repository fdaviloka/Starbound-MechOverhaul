require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  local getUnlockedMessage = world.sendEntityMessage(player.id(), "mechUnlocked")
  local mechParamsMessage = world.sendEntityMessage(player.id(), "getMechParams")
  if getUnlockedMessage:finished() and getUnlockedMessage:succeeded()
  and mechParamsMessage:finished() and mechParamsMessage:succeeded() then
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
  self.fuels = config.getParameter("fuels")
  self.fuelTypes = config.getParameter("fuelTypes")
end

function update(dt)
  if self.disabled then return end
  if not world.entityExists(player.id()) then return end

  if not self.currentFuelMessage then
    local id = player.id()
    self.currentFuelMessage = world.sendEntityMessage(id, "getQuestFuelCount")
  end

  if self.currentFuelMessage and self.currentFuelMessage:finished() then
    if self.currentFuelMessage:succeeded() then
	  self.currentFuel = self.currentFuelMessage:result()
	end
	self.currentFuelMessage = nil
  end

  if not self.maxFuelMessage then
    local id = player.id()
    self.maxFuelMessage = world.sendEntityMessage(id, "getMechParams")
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
    local id = player.id()
    self.getItemMessage = world.sendEntityMessage(id, "getFuelSlotItem")
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
    local id = player.id()
    self.fuelTypeMessage = world.sendEntityMessage(id, "getFuelType")
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
  local id = player.id()

  local fuelMultiplier = 1
  local localFuelType = ""

  local fuelData = self.fuels[item.name]
  if fuelData then
    fuelMultiplier = fuelData.fuelMultiplier
    localFuelType = fuelData.fuelType
  end

  if self.currentFuelType and localFuelType ~= self.currentFuelType then
    widget.setText("lblEfficiency", "^red;The tank has a different type of fuel, empty it first.^white;")
    return
  end

  local addFuelCount = self.currentFuel + (item.count * fuelMultiplier)

  if addFuelCount > self.maxFuel then
    item.count = math.floor((addFuelCount - self.maxFuel) / fuelMultiplier)
	  self.setItemMessage = world.sendEntityMessage(id, "setFuelSlotItem", item)
	  addFuelCount = self.maxFuel
  else
    self.setItemMessage = world.sendEntityMessage(id, "setFuelSlotItem", nil)
    widget.setText("lblEfficiency", "")
  end

  world.sendEntityMessage(id, "setFuelType", localFuelType)
  world.sendEntityMessage(id, "setQuestFuelCount", addFuelCount)
end

function swapItem(widgetName)
  local currentItem = widget.itemSlotItem(widgetName)
  local swapItem = player.swapSlotItem()
  if swapItem and not self.fuels[swapItem.name] then
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

  local fuelData = self.fuels[currentItem.name]
  local fuelMultiplier = fuelData.fuelMultiplier
  local fuelType = fuelData.fuelType
  local textColor = fuelData.textColor

  if not fuelData or not fuelMultiplier or not fuelType or not textColor then return end

  widget.setText("lblEfficiency", "Detected fuel type: ^" .. textColor .. ";" .. fuelType .. "^white;, Efficiency: x".. fuelMultiplier)
end

function fuelCountPreview(item)
  if not item then
    widget.setText("lblModuleCount", string.format("%.02f", self.currentFuel) .. " / " .. math.floor(self.maxFuel))
    return
  end

  local fuelMultiplier = 1
  local textColor = "white"

  local fuelData = self.fuels[item.name]

  if fuelData then
    fuelMultiplier = fuelData.fuelMultiplier
    textColor = fuelData.textColor
  end

  local addFuelCount = self.currentFuel + (item.count * fuelMultiplier)

  if addFuelCount > self.maxFuel then
    addFuelCount = self.maxFuel
  end

  widget.setText("lblModuleCount", "^" .. textColor .. ";" .. string.format("%.02f", addFuelCount) .. "^white; / " .. math.floor(self.maxFuel))
end

function setFuelTypeText(type)
  local textColor = "white"

  local fuelType = self.fuelTypes[type]

  if fuelType then
    textColor = fuelType.textColor
  end

  if not type then
    type = "EMPTY"
    textColor = "red"
  end

  if textColor then
    widget.setText("lblFuelType", "FUEL TYPE: ^" .. textColor .. ";" .. type)
  else
    widget.setText("lblFuelType", "FUEL TYPE: EMPTY")
  end
end
