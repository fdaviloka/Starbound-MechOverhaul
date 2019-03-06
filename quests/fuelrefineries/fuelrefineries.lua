function init()
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

end

function update(dt)
  
end
