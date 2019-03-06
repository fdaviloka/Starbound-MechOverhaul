function init()
  if not player.hasQuest("fuelrefineriesslots") then
    player.startQuest( { questId = "fuelrefineriesslots" , templateId = "fuelrefineriesslots", parameters = {}} )
  end
  
  self.playerId = player.id()

  self.itemsLeft = 0
  self.timer = 0
  self.maxTimer = 15
end

function update(dt)
  if not self.item1Message then
    self.item1Message = world.sendEntityMessage(self.playerId, "getCatalystInputItem1")
  end
  if self.item1Message and self.item1Message:finished()then
    if self.item1Message:succeeded() then
      self.currentFuelSlot = self.item1Message:result()
      widget.setItemSlotItem("itemSlot_input", self.currentFuelSlot)
    end
    self.item1Message = nil
  end

  if not self.item2Message then
    self.item2Message = world.sendEntityMessage(self.playerId, "getCatalystInputItem2")
  end
  if self.item2Message and self.item2Message:finished()then
    if self.item2Message:succeeded() then
      self.currentCatalystSlot = self.item2Message:result()
      widget.setItemSlotItem("itemSlot_catalystInput", self.currentCatalystSlot)
    end
    self.item2Message = nil
  end

  if not self.outputItemMessage then
    self.outputItemMessage = world.sendEntityMessage(self.playerId, "getCatalystOutputItem")
  end
  if self.outputItemMessage and self.outputItemMessage:finished()then
    if self.outputItemMessage:succeeded() then
      self.currentOutputSlot = self.outputItemMessage:result()
      widget.setItemSlotItem("itemSlot_output", self.currentOutputSlot)
    end
    self.outputItemMessage = nil
  end

  if self.itemsLeft > 0 then
    self.disabled = true
    self.timer = self.timer + 1
    widget.setText("toggleCrafting", "Cancel")
    widget.setProgress("progressArrow", self.timer * (self.maxTimer / 100))
    if self.timer >= self.maxTimer then
      self.timer = 0
      craftItem()
    end
  else
    widget.setProgress("progressArrow", 0)
    widget.setText("toggleCrafting", "Refine")
    self.disabled = false
  end
end

function insertFuel()
  if self.disabled then return end

  swapItem("itemSlot_input")
end

function insertCatalyst()
  if self.disabled then return end

  swapItem("itemSlot_catalystInput", false, "fuelcatalyst", "setCatalystInputItem2")
end

function getFuel()
  swapItem("itemSlot_output", true)
end

function refine()
  if self.disabled then
    self.itemsLeft = 0
    return
  end

  local fuelInput = widget.itemSlotItem("itemSlot_input")
  local catalystInput = widget.itemSlotItem("itemSlot_catalystInput")

  if not fuelInput or fuelInput.count < 10 or not catalystInput or catalystInput.count < 1 then return end

  local fuelInputCount = math.floor(fuelInput.count / 10)
  if catalystInput.count >= fuelInputCount then
    self.itemsLeft = fuelInputCount
  else
    self.itemsLeft = catalystInput.count
  end
end

function swapItem(widgetName, output, inputItem, message)
  local currentItem = widget.itemSlotItem(widgetName)
  local swapItem = player.swapSlotItem()
  if swapItem and ((inputItem and swapItem.name == inputItem) or (not inputItem and swapItem.name == "unrefinedliquidmechfuel")) and not output then
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
  elseif not swapItem and not output then
    player.setSwapSlotItem(currentItem)
    widget.setItemSlotItem(widgetName, swapItem)
  elseif output then
    if currentItem then
      player.setSwapSlotItem(currentItem)
    end
    widget.setItemSlotItem(widgetName, nil)
  end

  currentItem = widget.itemSlotItem(widgetName)
  local id = player.id()
  if output then
    world.sendEntityMessage(id, "setCatalystOutputItem", currentItem)
  elseif not message then
    world.sendEntityMessage(id, "setCatalystInputItem1", currentItem)
  elseif message then
    world.sendEntityMessage(id, message, currentItem)
  end
end

function craftItem()
  local fuelItem = widget.itemSlotItem("itemSlot_input")
  local catalystItem = widget.itemSlotItem("itemSlot_catalystInput")
  local outputItem = widget.itemSlotItem("itemSlot_output")

  if not fuelItem or not catalystItem then
    self.itemsLeft = 0
    return
  end

  if fuelItem.count > 10 then
    fuelItem.count = fuelItem.count - 10
  elseif fuelItem.count == 10 then
    fuelItem = nil
  else
    self.itemsLeft = 0
    return
  end

  if catalystItem.count > 1 then
    catalystItem.count = catalystItem.count - 1
  elseif catalystItem.count == 1 then
    catalystItem = nil
  else
    self.itemsLeft = 0
    return
  end

  if not outputItem then
    outputItem = {name = "liquidmechfuel", count = 10}
  elseif outputItem.count <= 990 then
    outputItem.count = outputItem.count + 10
  else
    self.itemsLeft = 0
    return
  end

  world.sendEntityMessage(self.playerId, "setCatalystInputItem1", fuelItem)
  world.sendEntityMessage(self.playerId, "setCatalystInputItem2", catalystItem)
  world.sendEntityMessage(self.playerId, "setCatalystOutputItem", outputItem)
  self.itemsLeft = self.itemsLeft - 1
end
