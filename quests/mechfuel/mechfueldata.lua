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

  if not storage.currentMaxFuel then
    storage.currentMaxFuel = 0
  end

  if not storage.fuelCount then
    storage.fuelCount = 0
  end
end

function update(dt)
  if storage.currentMaxFuel and storage.lastMaxFuel and storage.fuelType then
    if storage.currentMaxFuel < storage.lastMaxFuel and storage.fuelCount == storage.lastMaxFuel then
      local itemName = ""

      if storage.fuelType == "Oil" then
        itemName = "liquidoil"
      elseif storage.fuelType == "Erchius" then
        itemName = "liquidfuel"
      elseif storage.fuelType == "Unrefined" then
        itemName = "unrefinedliquidmechfuel"
      elseif storage.fuelType == "Mech fuel" then
        itemName = "liquidmechfuel"
      end

      local itemCount = storage.lastMaxFuel - storage.currentMaxFuel

      if itemName and itemCount then
        local item = {}
        item.name = itemName
        item.count = itemCount
        player.giveItem(item)
      end
    end
  end

  storage.lastMaxFuel = storage.currentMaxFuel

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
