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
	--current list:
	--1: Doom player
	--222: massive recoil
	--3/33/333: party
	-- x<10 fallback: alt-throttle:phoenix,alt-reg:cultistshield,primary-throttle:damagebonus,primary-reg:gregfreezeAOE
	--666: massive status effect spam. very likely to kill.
	--1000: Doom everything in range.

	if special == 1 then
		--someone just drew the third unluckiest card in the deck.
		if sayterE then
			sayterE=sayterE/2.0
		else
			sayterE=4.0
		end
		effectUtil.messageParticle(firePosition(),"Sayter.",{0,0,0},0.6,nil,4,nil)
	elseif special == 222 then
		local aimVec=aimVector(ability)
		local aimAngle=vec2.angle(vec2.mul(aimVec,-1))
		mcontroller.controlApproachVelocityAlongAngle(aimAngle, 1557*projectileCount, 1557*ability.fireTime*projectileCount, true)
		effectUtil.messageParticle(firePosition(),"Donkey!",{150,75,0},0.6,nil,4,nil)
	elseif special == 111 and throttle and not world.getProperty("ship.fuel") then
		--Marvin. Arguably worse than sayter. It will not end until the person dies.
		--Since they will have no resistances and will be immune to most healing, death is highly likely
		--unluckiest card in deck.
		effectUtil.messageParticle(firePosition(),"Marvin.",{0,1,0},0.6,nil,4,nil)
		effectUtil.effectSelf("marvinSkittles")
	elseif special == 3 or special == 33 or special == 333 then
		message="Gregga greg. Donkey...RAINBOW RAINBOW RAINBOW!!!"
		color={238,130,238}
		effectUtil.effectSelf("partytime2",special)
		effectUtil.messageParticle(firePosition(),message,color,0.6,nil,4,nil)
	elseif special == 666 then
		--second unluckiest card in deck
		--immune to healing, no resistances, a slew of horrible damaging statuses including one that is basically lava.
		special=math.floor(math.random(1,13))
		effectUtil.effectSelf("vulnerability",special)
		effectUtil.effectSelf("melting",special)
		effectUtil.effectSelf("negativemiasma",special)
		effectUtil.effectSelf("darkwaterpoison",special)
		effectUtil.effectSelf("moltenmetal3",special)
		effectUtil.effectSelf("radiationburn",special)
		effectUtil.effectSelf("nitrogenfreeze3",special)
		effectUtil.effectSelf("sulphuricacideffect",special)
		effectUtil.effectSelf("blacktarslow",special)
		effectUtil.effectSelf("fu_nooxygen",special)
		effectUtil.effectSelf("mad",special)
		effectUtil.messageParticle(firePosition(),"Kevin.",{0,0,0},0.6,nil,4,nil)
	elseif special < 10 then
		local aimVec=aimVector(ability)
		local projectileType=""
		local doProjectile=false
		local message
		local color

		if fireMode=="alt" then
			if throttle then
				doProjectile=true
				projectileType="phoenix"
		local projectileType
		if math.random(1,100) >= 99.0 then
			buffer=projectileData[fireMode]["rare"]
			projectileType=buffer[math.floor(math.random(1,#buffer))]
		else
			buffer=projectileData[fireMode]["common"]
			projectileType=buffer[math.floor(math.random(1,#buffer))]
		end

		local element
		if math.random(1,100) >= 90.0 then
			buffer2=elementData[fireMode]["rare"]
			element=buffer2[math.floor(math.random(1,#buffer2))]
		else
			buffer2=elementData[fireMode]["common"]
			element=buffer2[math.floor(math.random(1,#buffer2))]
		end

		projectileType=string.gsub(projectileType,"<element>",element)
		world.spawnProjectile(
			projectileType,
			firePosition(),
			activeItem.ownerEntityId(),
			aimVec,
			false,
			params
		)
		--doRecoil(ability,aimVec,projectileCount)
	end

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
