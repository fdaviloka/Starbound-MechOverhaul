function init()
  message.setHandler("setLoadout1", function(_, _, value, chips)
    storage.loadout1 = value
    storage.chips1 = chips
  end)
  message.setHandler("setLoadout2", function(_, _, value, chips)
    storage.loadout2 = value
    storage.chips2 = chips
  end)
  message.setHandler("setLoadout3", function(_, _, value, chips)
    storage.loadout3 = value
    storage.chips3 = chips
  end)
  message.setHandler("setCurrentLoadout", function(_, _, value)
    storage.currentLoadout = value
  end)
  message.setHandler("getLoadouts", function()
    local loadouts = {}
    loadouts.loadout1 = storage.loadout1
    loadouts.loadout2 = storage.loadout2
    loadouts.loadout3 = storage.loadout3
    loadouts.chips1 = storage.chips1
    loadouts.chips2 = storage.chips2
    loadouts.chips3 = storage.chips3
    loadouts.currentLoadout = storage.currentLoadout
    return loadouts
  end)

  if not storage.currentLoadout then
    storage.currentLoadout = 1
  end
end

function update(dt)

end
