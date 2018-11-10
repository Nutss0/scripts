-- @ 50keda, Ziuta
-- @ 23.12.2016
-- @ v1.0
--
-- Script was developed upon "animXML.lua" script from FS 15 used for playing animations with triggers.
-- However script evolved into specialized one, used for opening trailer doors.
--
-- Features:
-- 1. opening/closing trailer doors by key
-- 2. if door is opened and user start tipping, then afterwards doors will stay open (this wasn't the case in old script)
-- 3. if there are any fasten belts used on trailer then, you won't be able to switch doors animations
-- 4. if user starts to fill trailer then all doors will be automatically closed when "closeWhenFilling" attribute is used
--
-- Thanks to Ziuta, for initial script created for FS 15
--
-- You can use it and edit but keep the original author ;)


trailerAnimateDoors = {}

function trailerAnimateDoors.prerequisitesPresent(specializations)
   return SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations) and SpecializationUtil.hasSpecialization(Trailer, specializations)
end

function trailerAnimateDoors:load(savegame)	
	self.isAnyBeltFasten = trailerAnimateDoors.isAnyBeltFasten
	self.isAnyUnitFilled = trailerAnimateDoors.isAnyUnitFilled
	self.isInRangeAndCanInteract = trailerAnimateDoors.isInRangeAndCanInteract
	self.setAnim = trailerAnimateDoors.setAnim

	self.tad_objects = {}
	local i = 0
    while true do
		local key = string.format("vehicle.trailerAnimateDoors.object(%d)", i)
		if not hasXMLProperty(self.xmlFile, key) then
            break
        end
		local ob = {}
		ob.index = Utils.indexToObject(self.components, getXMLString(self.xmlFile, key.."#index"))
		ob.animationName = getXMLString(self.xmlFile, key.."#animationName")
		ob.tipAnimationName = getXMLString(self.xmlFile, key.."#tipAnimationName")
      	ob.minDistance = Utils.getNoNil(getXMLFloat(self.xmlFile, key.."#distance"), 1.0)
		ob.closeWhenFilling = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#closeWhenFilling"), false)
		ob.interactDuringTipping = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#interactDuringTipping"), false)
		ob.checkFastenBelts = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#checkFastenBelts"), false)
		
		ob.isInOpenState = false
		table.insert(self.tad_objects, ob)
		i = i + 1
	end

	if savegame ~= nil then
		local animChange = getXMLString(savegame.xmlFile, savegame.key.."#animationChange")
		local obj = false
		if animChange ~= nil then
			local ob = Utils.splitString(" ", animChange)		
			for i=1, table.getn(self.tad_objects) do
				if ob[i] == "true" then
					obj = true
				elseif ob[i] == "false" then
					obj = false
				end
				local state = obj
				self:setAnim(i, state)
			end
		elseif animChange == nil then
			for i=1, table.getn(self.tad_objects) do
				self:setAnim(i, obj)
			end
		end	
	end
end

function trailerAnimateDoors:delete()
end

function trailerAnimateDoors:readStream(streamId, connection)
	for i=1, table.getn(self.tad_objects) do
		local state = streamReadBool(streamId)
		self:setAnim(i, state, true)
	end
end

function trailerAnimateDoors:writeStream(streamId, connection)
	for i=1, table.getn(self.tad_objects) do
		local ob = self.tad_objects[i]
		local state = ob.isInOpenState
		streamWriteBool(streamId, state)
	end
end

function trailerAnimateDoors:getSaveAttributesAndNodes(nodeIdent)
	local attributes = 'animationChange="'
	for i=1, table.getn(self.tad_objects) do
		local ob = self.tad_objects[i]
		local state = ob.isInOpenState
		attributes = attributes..tostring(state).." "
	end
	attributes = attributes..'"'
	return attributes, ""
end

function trailerAnimateDoors:mouseEvent(posX, posY, isDown, isUp, button)
end

function trailerAnimateDoors:keyEvent(unicode, sym, modifier, isDown)
end

function trailerAnimateDoors:update(dt)
	if self.isClient then
		for i=1, table.getn(self.tad_objects) do
			local ob = self.tad_objects[i]
			local stayClosed = self:isAnyUnitFilled() and ob.closeWhenFilling
			
			-- if current vehicle is having fill units then make sure all animations are on start	
			if stayClosed and ob.isInOpenState then 
				self:setAnim(i, false)

			-- if user pressed button and is in range try try to play animation
			elseif self:isInRangeAndCanInteract(i) then
				if InputBinding.hasEvent(InputBinding.tad_triggerAnimation) then
					if self:isAnyBeltFasten() and ob.checkFastenBelts then
						g_currentMission:showBlinkingWarning(g_i18n:getText("warning_beltsAreFasten"))
					elseif stayClosed then
						g_currentMission:showBlinkingWarning(g_i18n:getText("warning_fillUnitNotEmpty"))
					else
						self:setAnim(i, not ob.isInOpenState)
					end
				end

				-- properly set texts depending on animation time				
				local animTime = self:getAnimationTime(ob.animationName)
				if animTime > 0 then
					g_currentMission:addHelpButtonText(g_i18n:getText("tad_close"), InputBinding.tad_triggerAnimation)
				elseif animTime < 1 then
					g_currentMission:addHelpButtonText(g_i18n:getText("tad_open"), InputBinding.tad_triggerAnimation)
				end
			end

			-- if doors are opened and tipping is closing then it will automatically close doors afterwards
			-- that's why during closing state we only notify our object to fix state after.
			-- Once trailer tip state is closed we can again propagate our open door state
			if ob.isInOpenState and self.tipState == Trailer.TIPSTATE_CLOSING then
				ob.fixState = true
			elseif self.tipState == Trailer.TIPSTATE_CLOSED and ob.fixState ~= nil then
				self:setAnim(i, true)
				ob.fixState = nil
			end
		end
	end
end

function trailerAnimateDoors:draw()
end

function trailerAnimateDoors:isAnyBeltFasten()
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

function trailerAnimateDoors:isAnyUnitFilled()
	if self.getFillLevel ~= nil then
		return self:getFillLevel() > 0
	end
	return false
end

function trailerAnimateDoors:isInRangeAndCanInteract(i)
	local rx, ry, rz = getWorldTranslation(g_currentMission.player.rootNode)
	local ox, oy, oz = getWorldTranslation(self.tad_objects[i].index)
	local distance = Utils.vector3Length(rx-ox, ry-oy, rz-oz)

	if distance <= self.tad_objects[i].minDistance and (self.tipState == Trailer.TIPSTATE_CLOSED or self.tad_objects[i].interactDuringTipping) then
		return true
	else
		return false
	end
end

function trailerAnimateDoors:setAnim(index, state, noEventSend)
	setAnimEvent.sendEvent(self, index, state, noEventSend)
	local ob = self.tad_objects[index]
	local animTime = self:getAnimationTime(ob.animationName)

	if state and animTime < 1 then
		self:playAnimation(ob.animationName, 1, animTime, true)
	elseif state and animTime >= 1 then
		self:playAnimation(ob.animationName, 1, 0, true)
	elseif animTime > 0 then
		self:playAnimation(ob.animationName, -1, animTime, true)
	end
	ob.isInOpenState = state
end

--
-- MP ready
--

setAnimEvent = {}
setAnimEvent_mt = Class(setAnimEvent, Event)

InitEventClass(setAnimEvent, "setAnimEvent")

function setAnimEvent:emptyNew()
    local self = Event:new(setAnimEvent_mt)
    return self
end

function setAnimEvent:new(object, index, state)
    local self = setAnimEvent:emptyNew()
    self.object = object
    self.index = index
	self.state = state
    return self
end

function setAnimEvent:readStream(streamId, connection)
	self.object = readNetworkNodeObject(streamId);
	self.index = streamReadInt8(streamId)
	self.state = streamReadBool(streamId)	
    self:run(connection)
end

function setAnimEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object);
	streamWriteInt8(streamId, self.index)
	streamWriteBool(streamId, self.state)
end;

function setAnimEvent:run(connection)
    self.object:setAnim(self.index, self.state, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(setAnimEvent:new(self.object, self.index, self.state), nil, connection, self.object)
    end
end

function setAnimEvent.sendEvent(vehicle, index, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(setAnimEvent:new(vehicle, index, state), nil, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(setAnimEvent:new(vehicle, index, state))
		end
	end
end
