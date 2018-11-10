-- @ 50keda
-- @ 23.12.2016
-- @ v1.0
--
-- Script prevents user to trigger tipping if any fasten belts are mounted
--
-- You can use it and edit but keep the original author ;)


fastenBeltsChecker = {}

function fastenBeltsChecker.prerequisitesPresent(specializations)
   return (	
			SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations) and 
			SpecializationUtil.hasSpecialization(Trailer, specializations) and
			SpecializationUtil.hasSpecialization(TensionBelts, specializations)
		  )
end

function fastenBeltsChecker:load(savegame)	
	self.isAnyBeltFasten = fastenBeltsChecker.isAnyBeltFasten
	
	self.onStartTip = Utils.appendedFunction(Trailer.onStartTip, fastenBeltsChecker.onStartTip)
	self.setTensionBeltsActive = Utils.appendedFunction(TensionBelts.setTensionBeltsActive, fastenBeltsChecker.setTensionBeltsActive)

	self.fbc_tipSides = {}
	local i = 0
    while true do
		local key = string.format("vehicle.fastenBeltsChecker.tipSide(%d)", i)
		if not hasXMLProperty(self.xmlFile, key) then
            break
        end
		self.fbc_tipSides[i+1] = getXMLBool(self.xmlFile, key.."#check")
		
		i = i + 1
	end
end

function fastenBeltsChecker:delete()
end

function fastenBeltsChecker:readStream(streamId, connection)
end

function fastenBeltsChecker:writeStream(streamId, connection)
end

function fastenBeltsChecker:mouseEvent(posX, posY, isDown, isUp, button)
end

function fastenBeltsChecker:keyEvent(unicode, sym, modifier, isDown)
end

function fastenBeltsChecker:update(dt)
end

function fastenBeltsChecker:onStartTip(tipTrigger, tipReferencePointIndex, noEventSend)
	
	if self:isAnyBeltFasten() and self.fbc_tipSides[tipReferencePointIndex] then
		if self.isClient then
			g_currentMission:showBlinkingWarning(g_i18n:getText("warning_beltsAreFasten"))
		end
		-- as tipping process started already we have to cancel it, as it's forbidden to tip on this side with fasten belts
		self:onEndTip()
	end
end

function fastenBeltsChecker:setTensionBeltsActive(isActive, beltId, noEventSend)
	
	if isActive and self.tipState ~= Trailer.TIPSTATE_CLOSED and self.fbc_tipSides[self.currentTipReferencePointIndex] then
		if self.isClient then
			g_currentMission:showBlinkingWarning(g_i18n:getText("warning_fbc_tippingInProgress"))
		end
		-- immidiately remove all tension belts as we do not support belts during tipping on this side
		self:setTensionBeltsActive(false)
	end
end

function fastenBeltsChecker:draw()
end

function fastenBeltsChecker:isAnyBeltFasten()
	local fastenBelts = false
	if self.tensionBelts ~= nil then
		for _, belt in pairs(self.tensionBelts.singleBelts) do
			if belt.mesh ~= nil then
				fastenBelts = true
				break
			end
		end
	end
	return fastenBelts
end
