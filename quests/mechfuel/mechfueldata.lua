require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("setQuestFuelCount", function(_, _, value)
    if storage.fuelCount then
	    storage.fuelCount = value
	  end
  end)

  message.setHandler("getQuestFuelCount", function()
    if storage.fuelCount then
	    return storage.fuelCount
	  end
  end)

  message.setHandler("addQuestFuelCount", function(_, _, value)
    if storage.fuelCount then
	    storage.fuelCount = storage.fuelCount + value
	  end
  end)

  message.setHandler("removeQuestFuelCount", function(_, _, value)
    if storage.fuelCount then
	    storage.fuelCount = storage.fuelCount - value
	  end
  end)

  message.setHandler("setFuelSlotItem", function(_, _, value)
	  storage.itemSlot = value
  end)

  message.setHandler("getFuelSlotItem", function()
	  return storage.itemSlot
  end)

  message.setHandler("setCurrentMaxFuel", function(_, _, value)
	  if value then
	    storage.currentMaxFuel = value
	  end
  end)

  message.setHandler("setFuelType", function(_, _, value)
	  storage.fuelType = value
  end)

  message.setHandler("getFuelType", function()
	  return storage.fuelType
  end)

  --refinery code
  message.setHandler("setRefineryInputItem", function(_, _, value)
	  storage.rInputItemSlot = value
  end)

  message.setHandler("getRefineryInputItem", function()
	  return storage.rInputItemSlot
  end)

  message.setHandler("setRefineryOutputItem", function(_, _, value)
	  storage.rOutputItemSlot = value
  end)

  message.setHandler("getRefineryOutputItem", function()
	  return storage.rOutputItemSlot
  end)

  message.setHandler("setCatalystInputItem1", function(_, _, value)
	  storage.cInputItemSlot1 = value
  end)

  message.setHandler("setCatalystInputItem2", function(_, _, value)
	  storage.cInputItemSlot2 = value
  end)

  message.setHandler("getCatalystInputItem1", function()
	  return storage.cInputItemSlot1
  end)

  message.setHandler("getCatalystInputItem2", function()
    return storage.cInputItemSlot2
  end)

  message.setHandler("setCatalystOutputItem", function(_, _, value)
	  storage.cOutputItemSlot = value
  end)

  message.setHandler("getCatalystOutputItem", function()
	  return storage.cOutputItemSlot
  end)

  --chip code
  message.setHandler("setMechExpansionSlotItem", function(_, _, value)
	  storage.expansionSlotItem = value
  end)

  message.setHandler("getMechExpansionSlotItem", function()
	  return storage.expansionSlotItem
  end)

  message.setHandler("setMechUpgradeItem1", function(_, _, value)
	  storage.upgradeItem1 = value
  end)

  message.setHandler("getMechUpgradeItem1", function()
	  return storage.upgradeItem1
  end)

  message.setHandler("setMechUpgradeItem2", function(_, _, value)
	  storage.upgradeItem2 = value
  end)

  message.setHandler("getMechUpgradeItem2", function()
	  return storage.upgradeItem2
  end)

  message.setHandler("setMechUpgradeItem3", function(_, _, value)
	  storage.upgradeItem3 = value
  end)

  message.setHandler("getMechUpgradeItem3", function()
	  return storage.upgradeItem3
  end)

  message.setHandler("getMechUpgradeItems", function()
	  local chips = {}
    chips.chip1 = storage.upgradeItem1
    chips.chip2 = storage.upgradeItem2
    chips.chip3 = storage.upgradeItem3
    chips.expansion = storage.expansionSlotItem
    return chips
  end)
  --end

  if not storage.currentMaxFuel then
    storage.currentMaxFuel = 0
  end

  if not storage.fuelCount then
    storage.fuelCount = 0
  end
end

function update(dt)

  if storage.currentMaxFuel and storage.fuelCount then
    if storage.fuelCount > storage.currentMaxFuel then
	    storage.fuelCount = storage.currentMaxFuel
  	end
  end

  if storage.fuelCount and storage.fuelCount < 0 then
    storage.fuelCount = 0
  end

  if storage.fuelType and storage.fuelCount and storage.fuelCount <= 0 then
    storage.fuelType = nil
  end
end
