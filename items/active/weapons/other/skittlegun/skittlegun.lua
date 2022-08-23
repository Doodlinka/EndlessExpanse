require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/epoch.lua"
require "/scripts/effectUtil.lua"

function init()
	local timeData=epoch.currentToTable()
	projectileData=config.getParameter("projectileData")--{primary={common={},rare={}},alt={common={},rare={}}}
	totalProjectileTypes={}
	for k,v in pairs(projectileData) do--k=primary,alt
		totalProjectileTypes[k]=(#v["common"] or 0)+(#v["rare"] or 0)
	end
	for k,_ in pairs(totalProjectileTypes) do--k=primary,alt
		while totalProjectileTypes[k] > 16 do
			totalProjectileTypes[k]=math.ceil(totalProjectileTypes[k]/2.0)
		end
	end
	elementData=config.getParameter("elementData")
	self.fireOffset = config.getParameter("fireOffset")
	updateAim()

	storage.fireTimer = config.getParameter("primaryAbility").fireTime or 1
	self.recoilTimer = 0

	activeItem.setCursor("/cursors/reticle0.cursor")

	setToolTipValues(config.getParameter("primaryAbility"))
end

function setToolTipValues(ability)
	activeItem.setInstanceValue("tooltipFields", {
		damagePerShotLabel = damagePerShot(ability,1),
		speedLabel = 1 / ability.fireTime,
		energyPerShotLabel = ability.energyUsage
	})
end

function update(dt, fireMode, shiftHeld)
	updateAim()

	storage.fireTimer = math.max(storage.fireTimer - dt, 0)
	self.recoilTimer = math.max(self.recoilTimer - dt, 0)
	if fireMode=="none" or not fireMode then return end

	local worldType=world.type()

	local abilString = fireMode.."Ability"
	if shiftHeld then

		abilString2 = abilString
		abilString = abilString.."Shift"
	end
	local ability = config.getParameter(abilString)
	if abilString2 and not ability then ability = config.getParameter(abilString2) end

	if ability and storage.fireTimer <= 0 and not world.pointTileCollision(firePosition()) and status.overConsumeResource("energy", ability.energyUsage) then
		storage.fireTimer = ability.fireTime or 1
		fire(ability,fireMode,shiftHeld)
	end

	activeItem.setRecoil(self.recoilTimer > 0)

end

function fire(ability,fireMode,throttle)
	local baseProjectileCount=totalProjectileTypes[fireMode]
	local projectileCount = throttle and 1 or math.max(1,math.floor(math.random(1,baseProjectileCount*baseProjectileCount)/baseProjectileCount))
	local params = {power = damagePerShot(ability,projectileCount), powerMultiplier = activeItem.ownerPowerMultiplier()}

	if fireMode=="alt" then
		params.controlForce=140
		params.ignoreTerrain=false
		params.pickupDistance=1.5
		params.snapDistance=4
	end

	for _ = 1, projectileCount do
		local buffer, buffer2
		local aimVec=aimVector(ability)

		local projectileType
		if math.random(1,20) >= 19.0 then
			buffer=projectileData[fireMode]["rare"]
			projectileType=buffer[math.floor(math.random(1,#buffer))]
		else
			buffer=projectileData[fireMode]["common"]
			projectileType=buffer[math.floor(math.random(1,#buffer))]
		end

		local element
		if math.random(1,20) >= 19.0 then
			buffer2=elementData[fireMode]["rare"]
			element=buffer2[math.floor(math.random(1,#buffer2))]
		else
			buffer2=elementData[fireMode]["common"]
			element=buffer2[math.floor(math.random(1,#buffer2))]
		end

		projectileType=string.gsub(projectileType,"<element>",element)
		id = world.spawnProjectile(
			projectileType,
			firePosition(),
			activeItem.ownerEntityId(),
			aimVec,
			false,
			params
		)
		sb.logInfo(id)
		--doRecoil(ability,aimVec,projectileCount)
	end
	

	-- projectileType=string.gsub(projectileType,"<element>",element)
	-- world.spawnProjectile(
	-- 	projectileType,
	-- 	firePosition(),
	-- 	activeItem.ownerEntityId(),
	-- 	aimVec,
	-- 	false,
	-- 	params
	-- )
	--doRecoil(ability,aimVec,projectileCount)

	animator.burstParticleEmitter("fireParticles")
	animator.playSound("fire")
	self.recoilTimer = ability.recoilTime or 0.12
end

function updateAim()
	self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
	activeItem.setArmAngle(self.aimAngle)
	activeItem.setFacingDirection(self.aimDirection)
end

function firePosition()
	return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function aimVector(ability)
	local aimVector = vec2.rotate({1, 0}, self.aimAngle + sb.nrand(ability.inaccuracy or 0, 0))
	aimVector[1] = aimVector[1] * self.aimDirection

	return aimVector
end

function damagePerShot(ability,projectileCount)
	return ability.baseDps
	* ability.fireTime
	* (self.baseDamageMultiplier or 1.0)
	* config.getParameter("damageLevelMultiplier", root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1)))
	/ projectileCount
end
