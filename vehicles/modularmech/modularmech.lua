require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/vehicles/modularmech/mechpartmanager.lua"

function init()

  message.setHandler("despawnMech", despawn)

  message.setHandler("currentEnergy", function()
      if not alive() then
        return 0
      end

      return storage.energy / self.energyMax
    end)

  message.setHandler("currentHealth", function()
      if not alive() then
        return 0
      end

      return storage.health / self.healthMax
    end)

  message.setHandler("restoreEnergy", function(_, _, base, percentage)
      if alive() then
        local restoreAmount = (base or 0) + self.healthMax * (percentage or 0)
        storage.health = math.min(storage.health + (restoreAmount*0.75), self.healthMax)
		    world.sendEntityMessage(self.ownerEntityId, "setQuestFuelCount", math.min(storage.energy + (restoreAmount * 0.15), self.energyMax))
        animator.playSound("restoreEnergy")
      end
    end)

  self.ownerUuid = config.getParameter("ownerUuid")
  self.ownerEntityId = config.getParameter("ownerEntityId")

  --setting current chips
  local currentLoadoutMessage = world.sendEntityMessage(self.ownerEntityId, "getCurrentLoadout")
  self.currentLoadout = currentLoadoutMessage:result() or 1

  local chipsMessage = world.sendEntityMessage(self.ownerEntityId, "getChips" .. self.currentLoadout)
  self.chips = chipsMessage:result()
  if not self.chips then
    self.chips = {}
  end

  self.chip1 = self.chips.chip1 and self.chips.chip1.name or nil
  self.chip2 = self.chips.chip2 and self.chips.chip2.name or nil
  self.chip3 = self.chips.chip3 and self.chips.chip3.name or nil

  -- initialize configuration parameters

  self.movementSettings = config.getParameter("movementSettings")
  self.walkingMovementSettings = config.getParameter("walkingMovementSettings")
  self.flyingMovementSettings = config.getParameter("flyingMovementSettings")

  -- common (not from parts) config

  self.damageFlashTimer = 0
  self.damageFlashTime = config.getParameter("damageFlashTime")
  self.damageFlashDirectives = config.getParameter("damageFlashDirectives")

  self.jumpBoostTimer = 0

  self.fallThroughTimer = 0
  self.fallThroughTime = config.getParameter("fallThroughTime")
  self.fallThroughSustain = false

  self.onGroundTimer = 0
  self.onGroundTime = config.getParameter("onGroundTime")

  self.frontFoot = config.getParameter("frontFootOffset")
  self.backFoot = config.getParameter("backFootOffset")
  self.footCheckXOffsets = config.getParameter("footCheckXOffsets")

  self.legRadius = config.getParameter("legRadius")
  self.legVerticalRatio = config.getParameter("legVerticalRatio")
  self.legCycle = 0.25
  self.reachGroundDistance = config.getParameter("reachGroundDistance")

  self.flightLegOffset = config.getParameter("flightLegOffset")

  self.stepSoundLimitTime = config.getParameter("stepSoundLimitTime")
  self.stepSoundLimitTimer = 0

  self.walkBobMagnitude = config.getParameter("walkBobMagnitude")

  self.landingBobMagnitude = config.getParameter("landingBobMagnitude")
  self.landingBobTime = config.getParameter("landingBobTime")
  self.landingBobTimer = 0
  self.landingBobThreshold = config.getParameter("landingBobThreshold")

  self.boosterBobDelay = config.getParameter("boosterBobDelay")
  self.armBobDelay = config.getParameter("armBobDelay")

  self.armFlipOffset = config.getParameter("armFlipOffset")

  self.flightOffsetFactor = config.getParameter("flightOffsetFactor")
  self.flightOffsetClamp = config.getParameter("flightOffsetClamp")
  self.currentFlightOffset = {0, 0}

  self.boostDirection = {0, 0}

  self.despawnTime = config.getParameter("despawnTime")
  self.explodeTime = config.getParameter("explodeTime")
  self.explodeProjectile = config.getParameter("explodeProjectile")

  self.materialKind = "robotic"

  -- set part image tags

  self.partImages = config.getParameter("partImages")

  for k, v in pairs(self.partImages) do
    animator.setPartTag(k, "partImage", v)
  end

  -- set part directives

  self.partDirectives = config.getParameter("partDirectives")

  for k, v in pairs(self.partDirectives) do
    animator.setGlobalTag(k .. "Directives", v)
  end

  -- setup part functional config

  self.parts = config.getParameter("parts")

  local params = {}
  params.parts = self.parts
  params = MechPartManager.calculateTotalMass(params, self.chips)
  self.parts = params.parts

  -- setup body

  self.protection = self.parts.body.protection

 --setup speed nerf
  self.currentSpeed = 1 - self.parts.body.speedNerf

  -- setup boosters

  self.airControlSpeed = self.parts.booster.airControlSpeed * self.currentSpeed
  self.airControlForce = self.parts.booster.airControlForce
  self.flightControlSpeed = self.parts.booster.flightControlSpeed * self.currentSpeed
  self.flightControlForce = self.parts.booster.flightControlForce

  -- setup legs

  self.groundSpeed = self.parts.legs.groundSpeed * self.currentSpeed
  self.groundControlForce = self.parts.legs.groundControlForce
  self.jumpVelocity = self.parts.legs.jumpVelocity * self.currentSpeed
  self.jumpAirControlSpeed = self.parts.legs.jumpAirControlSpeed
  self.jumpAirControlForce = self.parts.legs.jumpAirControlForce
  self.jumpBoostTime = self.parts.legs.jumpBoostTime

  -- setup arms
  require(self.parts.leftArm.script)
  self.leftArm = _ENV[self.parts.leftArm.armClass]:new(self.parts.leftArm, "leftArm", {2.375, 2.0}, self.ownerUuid)

  require(self.parts.rightArm.script)
  self.rightArm = _ENV[self.parts.rightArm.armClass]:new(self.parts.rightArm, "rightArm", {-2.375, 2.0}, self.ownerUuid)

  -- setup energy pool --modded
  --set up health pool
  self.healthMax = self.parts.body.healthMax + self.parts.body.healthBonus
  storage.health = storage.health or (config.getParameter("startHealthRatio", 1.0) * self.healthMax)

  self.energyMax = self.parts.body.energyMax
  storage.energy = 0

  self.energyDrain = self.parts.body.energyDrain + (self.parts.leftArm.energyDrain or 0) + (self.parts.rightArm.energyDrain or 0)
  --self.energyDrain = self.energyDrain*0.6
  --adding mass energy drain penalty
  self.energyDrain = self.energyDrain + (self.parts.body.energyPenalty or 0)

  local chips = self.chips or {}
  for _, chip in pairs(chips) do
    if chip.name == "mechchiprefueler" then
      local mult = 0.75
      self.energyDrain = self.energyDrain * mult

      local leftPower = self.leftArm:getArmPower()
      if leftPower then
        leftPower = leftPower * mult
        self.leftArm:setArmPower(leftPower)
      end

      local rightPower = self.rightArm:getArmPower()
      if rightPower then
        rightPower = rightPower * mult
        self.rightArm:setArmPower(rightPower)
      end
    end

    if chip.name == "mechchippower" then
      local leftPower = self.leftArm:getArmPower()
      if leftPower then
        leftPower = leftPower * 2
        self.leftArm:setArmPower(leftPower)
      end

      local rightPower = self.rightArm:getArmPower()
      if rightPower then
        rightPower = rightPower * 2
        self.rightArm:setArmPower(rightPower)
      end
    end
  end
  --end

  -- check for environmental hazards / protection

  local hazards = config.getParameter("hazardVulnerabilities")
  for _, statusEffect in pairs(self.parts.body.hazardImmunities or {}) do
    hazards[statusEffect] = nil
  end

  local applyEnvironmentStatuses = config.getParameter("applyEnvironmentStatuses")
  local seatStatusEffects = config.getParameter("loungePositions.seat.statusEffects")

  for _, statusEffect in pairs(world.environmentStatusEffects(mcontroller.position())) do
    if hazards[statusEffect] then
      self.energyDrain = self.energyDrain + hazards[statusEffect].energyDrain
      world.sendEntityMessage(self.ownerEntityId, "queueRadioMessage", hazards[statusEffect].message, 1.5)
    end

    for _, applyEffect in ipairs(applyEnvironmentStatuses) do
      if statusEffect == applyEffect then
        table.insert(seatStatusEffects, statusEffect)
      end
    end
  end

  vehicle.setLoungeStatusEffects("seat", seatStatusEffects)

  self.liquidVulnerabilities = config.getParameter("liquidVulnerabilities")

  -- initialize persistent and last frame state data

  self.facingDirection = 1

  self.lastWalking = false

  self.lastPosition = mcontroller.position()
  self.lastVelocity = mcontroller.velocity()
  self.lastOnGround = mcontroller.onGround()

  self.lastControls = {
    left = false,
    right = false,
    up = false,
    down = false,
    jump = false,
    PrimaryFire = false,
    AltFire = false,
    Special1 = false
  }

  setFlightMode(world.gravity(mcontroller.position()) == 0)

  message.setHandler("deploy", function()
    self.deploy = config.getParameter("deploy")
    self.deploy.fadeTime = self.deploy.fadeInTime + self.deploy.fadeOutTime

    self.deploy.fadeTimer = self.deploy.fadeTime
    self.deploy.deployTimer = self.deploy.deployTime
    mcontroller.setVelocity({0, self.deploy.initialVelocity})
  end)

  --New values here
  --manual flight mode
  self.manualFlightMode = false;
  self.doubleJumpCount = 0
  self.doubleJumpDelay = 0

  --dash values
  self.maxDashDist = 20
  self.doubleDirCount = 0
  self.doubleDirDelay = 0

  self.crouch = 0.0 -- 0.0 ~ 1.0
  self.crouchTarget = 0.0
  self.crouchCheckMax = 7.0
  self.bodyCrouchMax = -4.0
  self.hipCrouchMax = 2.0

  self.crouchSettings = config.getParameter("crouchSettings")
  self.noneCrouchSettings = config.getParameter("noneCrouchSettings")

  self.doubleTabBoostOn = false
  self.doubleTabBoostDirection = "null"
  self.doubleTabCount = 0
  self.doubleTabCheckDelay = 0.0
  self.doubleTabCheckDelayTime = 0.3
  self.doubleTabBoostCrouchTargetTo = 0.15
  self.doubleTabBoostSpeedMultTarget = 2.5
  self.doubleTabBoostSpeedMult = 1.0

  self.doubleTabBoostJump = false
end

function update(dt)
  --chips setup
  for _,chip in pairs(self.chips) do

  end

  -- despawn if owner has left the world
  if not self.ownerEntityId or world.entityType(self.ownerEntityId) ~= "player" then
    despawn()
  end

  --set storage.energy based on fuel in dummy quest
  if not self.currentFuelMessage then
    self.currentFuelMessage = world.sendEntityMessage(self.ownerEntityId, "getQuestFuelCount")
  end

  if self.currentFuelMessage and self.currentFuelMessage:finished() and storage.energy then
    if self.currentFuelMessage:succeeded() and self.currentFuelMessage:result() then
	     storage.energy = self.currentFuelMessage:result()
	  end
	self.currentFuelMessage = nil
  end
  --end

  if self.explodeTimer then
    self.explodeTimer = math.max(0, self.explodeTimer - dt)
    if self.explodeTimer == 0 then
      local params = {
        referenceVelocity = mcontroller.velocity(),
        damageTeam = {
          type = "enemy",
          team = 9001
        }
      }
      world.spawnProjectile(self.explodeProjectile, mcontroller.position(), nil, nil, false, params)
      animator.playSound("explode")
      vehicle.destroy()
    else
      local fade = 1 - (self.explodeTimer / self.explodeTime)
      animator.setGlobalTag("directives", string.format("?fade=FCC93C;%.1f", fade))
    end
    return
  elseif self.despawnTimer then
    self.despawnTimer = math.max(0, self.despawnTimer - dt)
    if self.despawnTimer == 0 then
      vehicle.destroy()
    else
      local multiply, fade, light
      if self.despawnTimer > 0.5 * self.despawnTime then
        fade = 1.0 - (self.despawnTimer - 0.5 * self.despawnTime) / (0.5 * self.despawnTime)
        light = fade
        multiply = 255
      else
        fade = 1.0
        light = self.despawnTimer / (0.5 * self.despawnTime)
        multiply = math.floor(255 * light)
      end
      animator.setGlobalTag("directives", string.format("?multiply=ffffff%02x?fade=ffffff;%.1f", multiply, fade))
      animator.setLightActive("deployLight", true)
      animator.setLightColor("deployLight", {light, light, light})
    end
    return
  end

  --manual flight mode
  if self.manualFlightMode then
	  setFlightMode(true)
  else
    setFlightMode(world.gravity(mcontroller.position()) == 0)-- or world.liquidAt(mcontroller.position()))--lpk:add liquidMovement
  end

  if self.manualFlightMode and world.gravity(mcontroller.position()) == 0 then
    self.manualFlightMode = false
  end

  -- update positions and movement

  self.boostDirection = {0, 0}

  local newPosition = mcontroller.position()
  local newVelocity = mcontroller.velocity()

  -- decrement timers

  self.stepSoundLimitTimer = math.max(0, self.stepSoundLimitTimer - dt)
  self.landingBobTimer = math.max(0, self.landingBobTimer - dt)
  self.jumpBoostTimer = math.max(0, self.jumpBoostTimer - dt)
  self.fallThroughTimer = math.max(0, self.fallThroughTimer - dt)
  self.onGroundTimer = math.max(0, self.onGroundTimer - dt)

  -- track onGround status
  if mcontroller.onGround() then
    self.onGroundTimer = self.onGroundTime
  end
  local onGround = self.onGroundTimer > 0

  -- hit ground

  if onGround and not self.lastOnGround and newVelocity[2] - self.lastVelocity[2] > self.landingBobThreshold then
    self.landingBobTimer = self.landingBobTime
    triggerStepSound()
  end

  -- update driver if energy > 0

  local driverId = vehicle.entityLoungingIn("seat")
  if driverId and not self.driverId and storage.energy > 0 then
    animator.setAnimationState("power", "activate")
  elseif self.driverId and not driverId and storage.energy > 0 then
    animator.setAnimationState("power", "deactivate")
  end
  self.driverId = driverId

  -- read controls or do deployment

  local newControls = {}
  local oldControls = self.lastControls

  if self.deploy then
    self.deploy.fadeTimer = math.max(0.0, self.deploy.fadeTimer - dt)
    self.deploy.deployTimer = math.max(0.0, self.deploy.deployTimer - dt)

    -- visual fade in
    local multiply = math.floor(math.min(1.0, (self.deploy.fadeTime - self.deploy.fadeTimer) / self.deploy.fadeInTime) * 255)
    local fade = math.min(1.0, self.deploy.fadeTimer / self.deploy.fadeOutTime)
    animator.setGlobalTag("directives", string.format("?multiply=ffffff%02x?fade=ffffff;%.1f", multiply, fade))
    animator.setLightActive("deployLight", true)
    animator.setLightColor("deployLight", {fade, fade, fade})

    -- boost to a stop
    if self.deploy.deployTimer < self.deploy.boostTime then
      mcontroller.approachYVelocity(0, math.abs(self.deploy.initialVelocity) / self.deploy.boostTime * mcontroller.parameters().mass)
      boost({0, util.toDirection(-self.deploy.initialVelocity)})
    end

    if self.deploy.deployTimer == 0.0 then
      self.deploy = nil
      animator.setLightActive("deployLight", false)
    end
  else
    self.damageFlashTimer = math.max(0, self.damageFlashTimer - dt)
    if self.damageFlashTimer == 0 then
      animator.setGlobalTag("directives", "")
    end

    local walking = false
    if self.driverId then
      for k, _ in pairs(self.lastControls) do
        newControls[k] = vehicle.controlHeld("seat", k)
      end

      self.aimPosition = vehicle.aimPosition("seat")

      if newControls.Special1 and not self.lastControls.Special1 and storage.energy > 0 then
        animator.playSound("horn")

        for _,chip in pairs(self.chips) do
          if chip.name == "mechchiplight" then
            self.mechLightActive = not self.mechLightActive
            animator.setLightActive("mechChipLight", self.mechLightActive)
          end
        end
      end

      if self.flightMode then
	      --disable manual flight mode on no energy
	      if storage.energy <= 0 and self.manualFlightMode then
		      setFlightMode(false)
		      self.manualFlightMode = false
		    end

		    if self.manualFlightMode and mcontroller.yVelocity() > 0 and mcontroller.isColliding() then
          self.manualFlightMode = false
          setFlightMode(false)
        end

		    if not hasTouched(newControls) and not hasTouched(oldControls) and self.manualFlightMode then
		      local vel = mcontroller.velocity()
            if vel[1] ~= 0 or vel[2] ~= 0 then
              mcontroller.approachVelocity({0, 0}, self.flightControlForce*1.5)
              boost(vec2.mul(vel, -1))
            end
	    	end

		    --set controls to only work on positive energy
        if newControls.jump then
          local vel = mcontroller.velocity()
          if vel[1] ~= 0 or vel[2] ~= 0 then
            mcontroller.approachVelocity({0, 0}, self.flightControlForce)
            boost(vec2.mul(vel, -1))
          end
        else
          if newControls.right and storage.energy > 0 then
            mcontroller.approachXVelocity(self.flightControlSpeed, self.flightControlForce)
            boost({1, 0})
          end

          if newControls.left and storage.energy > 0 then
            mcontroller.approachXVelocity(-self.flightControlSpeed, self.flightControlForce)
            boost({-1, 0})
          end

          if newControls.up and storage.energy > 0 then
            mcontroller.approachYVelocity(self.flightControlSpeed, self.flightControlForce)
            boost({0, 1})
          end

          if newControls.down and storage.energy > 0 then
		        if self.manualFlightMode then
              mcontroller.approachYVelocity(-self.flightControlSpeed*2, self.flightControlForce*2)
			      else
			        mcontroller.approachYVelocity(-self.flightControlSpeed, self.flightControlForce)
			      end
            boost({0, -1})
          end
        end
      else
        if not newControls.jump and storage.energy > 0 then
          self.fallThroughSustain = false
        end

        if onGround then
          if newControls.right and storage.energy > 0 then
            mcontroller.approachXVelocity(self.groundSpeed, self.groundControlForce)
            walking = true
          end

          if newControls.left and storage.energy > 0 then
            mcontroller.approachXVelocity(-self.groundSpeed, self.groundControlForce)
            walking = true
          end

          if newControls.jump and self.jumpBoostTimer > 0 and storage.energy > 0 then
            mcontroller.setYVelocity(self.jumpVelocity)
          elseif newControls.jump and not self.lastControls.jump then
            if newControls.down and storage.energy > 0 then
              self.fallThroughTimer = self.fallThroughTime
              self.fallThroughSustain = true
            else
              jump()

			        self.doubleTabBoostJump = self.doubleTabBoostOn
            end
          else
            self.jumpBoostTimer = 0
          end

		  --crouch code is here
		  local dist = self.crouchCheckMax
		  self.crouchTarget = 0.0
		  self.crouchOn = false

		  while dist > 0 do
        if (newControls.down and not self.fallThroughSustain) or (
          world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), {-2.5, dist})) or
          world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), {0, dist})) or
          world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), {2.5, dist}))
          ) then
          self.crouchOn = true
          self.crouchTarget = 1.0 - dist / self.crouchCheckMax
        else
          break
        end
        dist = dist - 1
		  end
		  --end

        else
          local controlSpeed = self.jumpBoostTimer > 0 and self.jumpAirControlSpeed or self.airControlSpeed
          local controlForce = self.jumpBoostTimer > 0 and self.jumpAirControlForce or self.airControlForce

          local boostSpeedMult = self.doubleTabBoostJump and self.doubleTabBoostSpeedMultTarget or 1.0

          if newControls.right and storage.energy > 0 then
            mcontroller.approachXVelocity(controlSpeed * boostSpeedMult, controlForce)
            boost({1, 0})
          end

          if newControls.left and storage.energy > 0 then
            mcontroller.approachXVelocity(-controlSpeed * boostSpeedMult, controlForce)
            boost({-1, 0})
          end

          if newControls.jump and storage.energy > 0 then
            if self.jumpBoostTimer > 0 then
              mcontroller.setYVelocity(self.jumpVelocity)
            end
          else
            self.jumpBoostTimer = 0
          end

		  --crouch code is here
		  self.crouchTarget = 0.0
		  self.crouchOn = false
		  --end
        end

		    doubleTabBoost(dt, newControls, oldControls)
      end

      self.facingDirection = world.distance(self.aimPosition, mcontroller.position())[1] > 0 and 1 or -1

      self.lastControls = newControls
    else
      for k, _ in pairs(self.lastControls) do
        self.lastControls[k] = false
      end

      newControls = self.lastControls
      oldControls = self.lastControls

      self.aimPosition = nil
    end
  end

  --manual flight mode
  if not self.driverId then
    setFlightMode(false)
    self.manualFlightMode = false
  end

  if newControls.up and not oldControls.up then
    self.doubleJumpCount = self.doubleJumpCount + 1
    self.doubleJumpDelay = self.doubleTabCheckDelayTime
  end

  if self.doubleJumpCount >= 2 then
    if self.manualFlightMode == true and world.gravity(mcontroller.position()) ~= 0 then
      self.manualFlightMode = false
    elseif self.manualFlightMode == false and world.gravity(mcontroller.position()) ~= 0 then
      self.manualFlightMode = true
    end

    self.doubleJumpCount = 0
  end

  self.doubleJumpDelay = self.doubleJumpDelay - dt
  if self.doubleJumpDelay < 0 then
    self.doubleJumpCount = 0
  end
  --end

  --dash code--to be implemented
  if newControls.left and not oldControls.left then
    self.doubleDirCount = self.doubleDirCount - 1
    self.doubleDirDelay = self.doubleTabCheckDelayTime
  end

  if newControls.right and not oldControls.right then
    self.doubleDirCount = self.doubleDirCount + 1
    self.doubleDirDelay = self.doubleTabCheckDelayTime
  end

  if self.doubleDirCount >= 2 or self.doubleDirCount <= -2 then

  else

  end

  self.doubleDirDelay = self.doubleDirDelay - dt
  if self.doubleDirDelay < 0 then
    self.doubleDirCount = 0
  end
  --end

  --crouch code is here
  if storage.energy > 0 then
    self.crouch = self.crouch + (self.crouchTarget - self.crouch) * 0.1
  end

  if not self.flightMode then --lpk - dont set while in 0g
    if self.crouchOn then
	     mcontroller.applyParameters(self.crouchSettings)
    else
	     mcontroller.applyParameters(self.noneCrouchSettings)
    end
  end
  --end

  -- update damage team (don't take damage without a driver)
  -- also anything else that depends on a driver's presence

  if self.driverId then
    vehicle.setDamageTeam(world.entityDamageTeam(self.driverId))
    vehicle.setInteractive(false)
    vehicle.setForceRegionEnabled("itemMagnet", true)
    vehicle.setDamageSourceEnabled("bumperGround", not self.flightMode)
    animator.setLightActive("activeLight", true)
  else
    vehicle.setDamageTeam({type = "ghostly"})
    vehicle.setInteractive(true)
    vehicle.setForceRegionEnabled("itemMagnet", false)
    vehicle.setDamageSourceEnabled("bumperGround", false)
    animator.setLightActive("activeLight", false)
    animator.setLightActive("boostLight", false)
  end

  -- decay and check energy

--  if self.driverId then
--    storage.energy = math.max(0, storage.energy - self.energyDrain * dt)
--  end
-- lpk - regen while idle, no drain while coasting
  if self.driverId then
	--energy drain
   local energyDrain = self.energyDrain

	--set energy drain to 0 if null movement
    if not hasTouched(newControls) and not hasTouched(oldControls) and not self.manualFlightMode then --(not hasFired) then
      energyDrain = 0
    end
    storage.energy = math.max(0, storage.energy - energyDrain * dt)
	--set new fuel count on dummy quest
  	world.sendEntityMessage(self.ownerEntityId, "setQuestFuelCount", storage.energy)
  end

  local inLiquid = world.liquidAt(mcontroller.position())
  if inLiquid then
    local liquidName = root.liquidName(inLiquid[1])
    if self.liquidVulnerabilities[liquidName] then
	  --lower health and explode on liquid hazard
      storage.health = math.max(0, storage.health - self.liquidVulnerabilities[liquidName].energyDrain * dt)
      if storage.health == 0 then
        explode()
        return
      end

      if not self.liquidVulnerabilities[liquidName].warned then
        world.sendEntityMessage(self.ownerEntityId, "queueRadioMessage", self.liquidVulnerabilities[liquidName].message)
        self.liquidVulnerabilities[liquidName].warned = true
      end
    end
  end

  --explode on 0 health
  if storage.health == 0 then
    explode()
	  return
  end

  --lock arms and set sounds on 0 energy
  if storage.energy <= 0 then
    self.energyBackPlayed = false
    self.leftArm.bobLocked = true
	  self.rightArm.bobLocked = true
	  animator.setAnimationState("boost", "idle")
		animator.setLightActive("boostLight", false)
    animator.stopAllSounds("step")
    animator.stopAllSounds("jump")
    if not self.energyOutPlayed then
      animator.setAnimationState("power", "deactivate")
      animator.playSound("energyout")
      self.energyOutPlayed = true
    end
    animator.setLightActive("mechChipLight", false)

    for _, arm in pairs({"left", "right"}) do
      local fireControl = (arm == "left") and "PrimaryFire" or "AltFire"

      animator.resetTransformationGroup(arm .. "Arm")
      animator.resetTransformationGroup(arm .. "ArmFlipper")

      self[arm .. "Arm"]:updateBase(dt, self.driverId, false, false, self.aimPosition, self.facingDirection, self.crouch * self.bodyCrouchMax)
      self[arm .. "Arm"]:update(dt)
    end
	  return
  else
    self.energyOutPlayed = false
    self.leftArm.bobLocked = false
	  self.rightArm.bobLocked = false
    if not self.energyBackPlayed then
      animator.setAnimationState("power", "activate")
      animator.playSound("energyback")
      self.energyBackPlayed = true
    end

    if self.mechLightActive then
      animator.setLightActive("mechChipLight", true)
    end
  end

  -- set appropriate movement parameters for walking/falling conditions

  if not self.flightMode then
    if walking ~= self.lastWalking then
      self.lastWalking = walking
      if self.lastWalking then
        mcontroller.applyParameters(self.walkingMovementSettings)
      else
        mcontroller.resetParameters(self.movementSettings)
      end
    end

    if self.fallThroughTimer > 0 or self.fallThroughSustain then
      mcontroller.applyParameters({ignorePlatformCollision = true})
    else
      mcontroller.applyParameters({ignorePlatformCollision = false})
    end
  end

  -- flip to match facing direction

  if storage.energy > 0 then
    animator.setFlipped(self.facingDirection < 0)
  end

  -- compute leg cycle

  if onGround then
    local newLegCycle = self.legCycle
    newLegCycle = self.legCycle + ((newPosition[1] - self.lastPosition[1]) * self.facingDirection) / (4 * self.legRadius)

    if math.floor(self.legCycle * 2) ~= math.floor(newLegCycle * 2) then
      triggerStepSound()
    end

    self.legCycle = newLegCycle
  end

  -- animate legs, leg joints, and hips

  if self.flightMode then
    -- legs stay locked in place for flight
  else
    local legs = {
      front = {},
      back = {}
    }
    local legCycleOffset = 0

    for _, legSide in pairs({"front", "back"}) do
      local leg = legs[legSide]

      leg.offset = legOffset(self.legCycle + legCycleOffset)
      legCycleOffset = legCycleOffset + 0.5

      leg.onGround = leg.offset[2] <= 0

      -- put foot down when stopped
      if not walking and math.abs(newVelocity[1]) < 0.5 then
        leg.offset[2] = 0
        leg.onGround = true
      end

      local footGroundOffset = findFootGroundOffset(leg.offset, self[legSide .. "Foot"])
      if footGroundOffset then
        leg.offset[2] = leg.offset[2] + footGroundOffset
      else
        leg.offset[2] = self.reachGroundDistance[2]
        leg.onGround = false
      end

      animator.setAnimationState(legSide .. "Foot", leg.onGround and "flat" or "tilt")
      animator.resetTransformationGroup(legSide .. "Leg")
      animator.translateTransformationGroup(legSide .. "Leg", leg.offset)
      animator.resetTransformationGroup(legSide .. "LegJoint")
      animator.translateTransformationGroup(legSide .. "LegJoint", {0.6 * leg.offset[1], 0.5 * leg.offset[2]})
    end

    if math.abs(newVelocity[1]) < 0.5 and math.abs(self.lastVelocity[1]) >= 0.5 then
      triggerStepSound()
    end

    animator.resetTransformationGroup("hips")
    local hipsOffset = math.max(-0.375, math.min(0, math.min(legs.front.offset[2] + 0.25, legs.back.offset[2] + 0.25))) + (self.crouch * self.hipCrouchMax)
    animator.translateTransformationGroup("hips", {0, hipsOffset})
  end

  -- update and animate arms

  for _, arm in pairs({"left", "right"}) do
    local fireControl = (arm == "left") and "PrimaryFire" or "AltFire"

    animator.resetTransformationGroup(arm .. "Arm")
    animator.resetTransformationGroup(arm .. "ArmFlipper")

    self[arm .. "Arm"]:updateBase(dt, self.driverId, newControls[fireControl], oldControls[fireControl], self.aimPosition, self.facingDirection, self.crouch * self.bodyCrouchMax)
    self[arm .. "Arm"]:update(dt)

    if self.facingDirection < 0 then
      animator.translateTransformationGroup(arm .. "ArmFlipper", {(arm == "right") and self.armFlipOffset or -self.armFlipOffset, 0})
    end
  end

  -- animate boosters and boost flames

  animator.resetTransformationGroup("boosters")

  if self.jumpBoostTimer > 0 then
    boost({0, 1})
  end

  if self.manualFlightMode then
    boost({0, 1})
  end

  if storage.energy <= 0 then
	  animator.setAnimationState("boost", "idle")
      animator.setLightActive("boostLight", false)
  end

  if self.boostDirection[1] == 0 and self.boostDirection[2] == 0 then
    animator.setAnimationState("boost", "idle")
    animator.setLightActive("boostLight", false)
  else
    local stateTag = "boost"
    if self.boostDirection[2] > 0 then
      stateTag = stateTag .. "N"
    elseif self.boostDirection[2] < 0 then
      stateTag = stateTag .. "S"
    end
    if self.boostDirection[1] * self.facingDirection > 0 then
      stateTag = stateTag .. "E"
    elseif self.boostDirection[1] * self.facingDirection < 0 then
      stateTag = stateTag .. "W"
    end
    animator.setAnimationState("boost", stateTag)
    animator.setLightActive("boostLight", true)
  end

  -- animate bobbing and landing

  animator.resetTransformationGroup("body")
  if self.flightMode then
    local newFlightOffset = {
        math.max(-self.flightOffsetClamp, math.min(self.boostDirection[1] * self.facingDirection * self.flightOffsetFactor, self.flightOffsetClamp)),
        math.max(-self.flightOffsetClamp, math.min(self.boostDirection[2] * self.flightOffsetFactor, self.flightOffsetClamp))
      }

    self.currentFlightOffset = vec2.div(vec2.add(newFlightOffset, vec2.mul(self.currentFlightOffset, 4)), 5)

    animator.translateTransformationGroup("boosters", self.currentFlightOffset)
    animator.translateTransformationGroup("rightArm", self.currentFlightOffset)
    animator.translateTransformationGroup("leftArm", self.currentFlightOffset)
  elseif not onGround or self.jumpBoostTimer > 0 then
    -- TODO: bob while jumping?
  elseif self.landingBobTimer == 0 then
    local bodyCycle = (self.legCycle * 2) % 1
    local bodyOffset = {0, self.walkBobMagnitude * math.sin(math.pi * bodyCycle) + (self.crouch * self.bodyCrouchMax)}
    animator.translateTransformationGroup("body", bodyOffset)

    local boosterCycle = ((self.legCycle * 2) - self.boosterBobDelay) % 1
    local boosterOffset = {0, self.walkBobMagnitude * math.sin(math.pi * boosterCycle) + (self.crouch * self.bodyCrouchMax)}
    animator.translateTransformationGroup("boosters", boosterOffset)

    local armCycle = ((self.legCycle * 2) - self.armBobDelay) % 1
    local armOffset = {0, self.walkBobMagnitude * math.sin(math.pi * armCycle) + (self.crouch * self.bodyCrouchMax)}
    animator.translateTransformationGroup("rightArm", self.rightArm.bobLocked and boosterOffset or armOffset)
    animator.translateTransformationGroup("leftArm", self.leftArm.bobLocked and boosterOffset or armOffset)
  else
    -- TODO: make this less complicated
    local landingCycleTotal = 1.0 + math.max(self.boosterBobDelay, self.armBobDelay)
    local landingCycle = landingCycleTotal * (1 - (self.landingBobTimer / self.landingBobTime))

    local bodyCycle = math.max(0, math.min(1.0, landingCycle))
    local bodyOffset = {0, -self.landingBobMagnitude * math.sin(math.pi * bodyCycle) + (self.crouch * self.bodyCrouchMax)}
    animator.translateTransformationGroup("body", bodyOffset)

    local legJointOffset = {0, 0.5 * bodyOffset[2]}
    animator.translateTransformationGroup("frontLegJoint", legJointOffset)
    animator.translateTransformationGroup("backLegJoint", legJointOffset)

    local boosterCycle = math.max(0, math.min(1.0, landingCycle + self.boosterBobDelay))
    local boosterOffset = {0, -self.landingBobMagnitude * 0.5 * math.sin(math.pi * boosterCycle) + (self.crouch * self.bodyCrouchMax)}
    animator.translateTransformationGroup("boosters", boosterOffset)

    local armCycle = math.max(0, math.min(1.0, landingCycle + self.armBobDelay))
    local armOffset = {0, -self.landingBobMagnitude * 0.25 * math.sin(math.pi * armCycle) + (self.crouch * self.bodyCrouchMax)}
    animator.translateTransformationGroup("rightArm", self.rightArm.bobLocked and boosterOffset or armOffset)
    animator.translateTransformationGroup("leftArm", self.leftArm.bobLocked and boosterOffset or armOffset)
  end

  self.lastPosition = newPosition
  self.lastVelocity = newVelocity
  self.lastOnGround = onGround
end

function onInteraction(args)
  local playerUuid = world.entityUniqueId(args.sourceId)
  if not self.driverId and playerUuid ~= self.ownerUuid then
    return "None"
  end
end

--replaced energy with health
function applyDamage(damageRequest)
  local energyLost = math.min(storage.health, damageRequest.damage * (1 - self.protection))

  storage.health = storage.health - energyLost

  if storage.health == 0 then
    explode()
  else
    self.damageFlashTimer = self.damageFlashTime
    animator.setGlobalTag("directives", self.damageFlashDirectives)
  end

  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damageRequest.damage,
    healthLost = energyLost,
    hitType = damageRequest.hitType,
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health == 0
  }}
end

function jump()
  self.jumpBoostTimer = self.jumpBoostTime

  --jump only if energy > 0
  if storage.energy <= 0 then
    return
  end

  mcontroller.setYVelocity(self.jumpVelocity)
  animator.playSound("jump")
end

function armRotation(armSide)
  local absoluteOffset = animator.partPoint(armSide .. "BoosterFront", "shoulder")
  local relativeOffset = vec2.mul(absoluteOffset, {self.facingDirection, 1})
  local shoulderPosition = vec2.add(mcontroller.position(), absoluteOffset)
  local aimVec = world.distance(self.aimPosition, shoulderPosition)
  local rotation = vec2.angle(aimVec)
  if self.facingDirection == -1 then
    rotation = math.pi - rotation
  end
end

function legOffset(legCycle)
  legCycle = legCycle % 1
  if legCycle < 0.5 then
    return {util.lerp(legCycle * 2, self.legRadius - 0.1, -self.legRadius - 0.1), 0}
  else
    local angle = (legCycle - 0.5) * 2 * math.pi
    local offset = vec2.withAngle(math.pi - angle, self.legRadius)
    offset[2] = offset[2] * self.legVerticalRatio
    return offset
  end
end

function findFootGroundOffset(legOffset, footOffset)
  local footBaseOffset = {self.facingDirection * (legOffset[1] + footOffset[1]), footOffset[2]}
  local footPos = vec2.add(mcontroller.position(), footBaseOffset)

  local bestGroundPos
  for _, offset in pairs(self.footCheckXOffsets) do
    world.debugPoint(vec2.add(footPos, {offset, 0}), "yellow")
    local groundPos = world.lineCollision(vec2.add(footPos, {offset, self.reachGroundDistance[1]}), vec2.add(footPos, {offset, self.reachGroundDistance[2]}), {"Null", "Block", "Dynamic", "Platform", "Slippery"})
    if groundPos and bestGroundPos then
      bestGroundPos = bestGroundPos[2] > groundPos[2] and bestGroundPos or groundPos
    elseif groundPos then
      bestGroundPos = groundPos
    end
  end
  if bestGroundPos then
    return world.distance(bestGroundPos, footPos)[2]
  end
end

function triggerStepSound()
  if self.stepSoundLimitTimer == 0 then
    animator.playSound("step")
    self.stepSoundLimitTimer = self.stepSoundLimitTime
  end
end

function resetAllTransformationGroups()
  for _, groupName in ipairs({"frontLeg", "backLeg", "frontLegJoint", "backLegJoint", "hips", "body", "rightArm", "leftArm", "boosters"}) do
    animator.resetTransformationGroup(groupName)
  end
end

function setFlightMode(enabled)
  if self.flightMode ~= enabled then
    self.flightMode = enabled
    resetAllTransformationGroups()
    self.jumpBoostTimer = 0
    self.currentFlightOffset = {0, 0}
    self.fallThroughSustain = false

    mcontroller.resetParameters(self.movementSettings)

	local vel = mcontroller.velocity()
    if vel[1] ~= 0 or vel[2] ~= 0 then
      mcontroller.approachVelocity({0, 0}, self.flightControlForce)
      boost(vec2.mul(vel, -1))
    end
    if enabled then
      mcontroller.applyParameters(self.flyingMovementSettings)
      animator.setAnimationState("frontFoot", "tilt")
      animator.setAnimationState("backFoot", "tilt")
      animator.translateTransformationGroup("frontLeg", self.flightLegOffset)
      animator.translateTransformationGroup("backLeg", self.flightLegOffset)
      animator.translateTransformationGroup("frontLegJoint", vec2.mul(self.flightLegOffset, 0.5))
      animator.translateTransformationGroup("backLegJoint", vec2.mul(self.flightLegOffset, 0.5))
    else

    end
  end
end

function boost(newBoostDirection)
  self.boostDirection = vec2.add(self.boostDirection, newBoostDirection)
end

function alive()
  return not self.explodeTimer and not self.despawnTimer
end

function explode()
  if alive() then
    self.explodeTimer = self.explodeTime
    vehicle.setLoungeEnabled("seat", false)
    vehicle.setInteractive(false)
    animator.setParticleEmitterActive("explode", true)
    animator.playSound("explodeWindup")
  end
end

function despawn()
  if alive() then
    self.despawnTimer = self.despawnTime
    vehicle.setLoungeEnabled("seat", false)
    vehicle.setInteractive(false)
    animator.burstParticleEmitter("despawn")
    animator.setParticleEmitterActive("despawn", true)
    animator.playSound("despawn")
  end
end


function doubleTabBoost(dt, newControls, oldControls)
	if self.doubleTabBoostOn and storage.energy > 0 then

		self.doubleTabBoostSpeedMult = self.doubleTabBoostSpeedMultTarget
		self.crouch = self.doubleTabBoostCrouchTargetTo
		self.facingDirection = self.doubleTabBoostDirection == "right" and 1 or -1
		mcontroller.approachXVelocity(self.groundSpeed * self.doubleTabBoostSpeedMult * self.facingDirection, self.groundControlForce)
		mcontroller.setYVelocity(math.min(mcontroller.yVelocity(), -10))
		self.crouchOn = false

		if (not newControls.right and self.doubleTabBoostDirection == "right") or
		   (not newControls.left  and self.doubleTabBoostDirection == "left") or
		   newControls.jump then
			self.doubleTabBoostOn = false
		end

	elseif self.lastOnGround and not self.crouchOn then

		self.doubleTabBoostSpeedMult = 1.0

		if newControls.right and not oldControls.right then
			self.doubleTabCount = math.max(self.doubleTabCount, 0)
			self.doubleTabCount = self.doubleTabCount + 1
			self.doubleTabCheckDelay = self.doubleTabCheckDelayTime
		end
		if newControls.left and not oldControls.left then
			self.doubleTabCount = math.min(self.doubleTabCount, 0)
			self.doubleTabCount = self.doubleTabCount - 1
			self.doubleTabCheckDelay = self.doubleTabCheckDelayTime
		end

		if self.doubleTabCount >= 2 or self.doubleTabCount <= -2 then
			self.doubleTabBoostOn = true

			if self.doubleTabCount >= 2 then
				self.doubleTabBoostDirection = "right"
			else
				self.doubleTabBoostDirection = "left"
			end

			self.doubleTabCount = 0
		end

	end

	self.doubleTabCheckDelay = self.doubleTabCheckDelay - dt
	if self.doubleTabCheckDelay < 0 then
		self.doubleTabCount = 0
	end
end

--check if controls are being touched
function hasTouched(controls)
  for _,control in pairs(controls) do
    if control then return true end
  end
  return false
end

--target position for dash
function findTargetPosition(dir, maxDist)
  local dist = 1
  local targetPosition
  local collisionPoly = mcontroller.collisionPoly()
  local testPos = mcontroller.position()
  while dist <= maxDist do
    testPos[1] = testPos[1] + dir
    if not world.polyCollision(collisionPoly, testPos, {"Null", "Block", "Dynamic", "Slippery"}) then
      local oneDown = {testPos[1], testPos[2] - 1}
      if not world.polyCollision(collisionPoly, oneDown, {"Null", "Block", "Dynamic", "Platform"}) and not self.flightMode then
        testPos = oneDown
      end
    else
      local oneUp = {testPos[1], testPos[2] + 1}
      if not world.polyCollision(collisionPoly, oneUp, {"Null", "Block", "Dynamic", "Slippery"}) then
        testPos = oneUp
      else
        break
      end
    end
    targetPosition = testPos
    dist = dist + 1
  end

  if targetPosition then
    local towardGround = {testPos[1], testPos[2] - 0.8}
    local groundPosition = world.resolvePolyCollision(collisionPoly, towardGround, 0.8, {"Null", "Block", "Dynamic", "Platform"})
    if groundPosition and not (groundPosition[1] == towardGround[1] and groundPosition[2] == towardGround[2]) then
      targetPosition = groundPosition
    end
  end

  return targetPosition
end
