-- @ Ziuta
-- @ 27.02.2015
-- @ v1.0
--
-- http://landwirtschafts-simulator.pl/
-- Thanks for you help Koper :P
--
-- You can use and edit but keep the original author ;)
--
-- @ 50keda
-- @ 12.12.2016
-- @ v2.0
--
-- Script converted to FS17 to support new "fillUnits" and custom filling volume shapes for each capacity.
-- There is also added support for preventing capacity change until all fasten belts are deactivated.
-- You can use it and edit but keep the original author ;)

changeCapacity = {}

function changeCapacity.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations) and SpecializationUtil.hasSpecialization(Fillable, specializations)
end

function changeCapacity:load(savegame)
	self.isAnyBeltFasten = changeCapacity.isAnyBeltFasten
	self.updateCapacities = changeCapacity.updateCapacities
	self.setMode = changeCapacity.setMode
	
	self.mode = 1
	self.volumeNode = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.fillVolumes.volumes.volume(0)#index"))
	self.fillUnitCapacity = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.fillUnits.fillUnit(0)#capacity"), 0.0)
	self.extraCapacities = {}
    local i = 0
    while true do
		local key = string.format("vehicle.extraCapacities.extraCapacity(%d)", i)
		if not hasXMLProperty(self.xmlFile, key) then
            break
        end
		
		local extraCapacity = {}		

		local j = 0
		while true do
			local unitKey = key .. string.format(".fillUnit(%d)", j)
			if not hasXMLProperty(self.xmlFile, unitKey) then
				break
			end

			local capacity = Utils.getNoNil(getXMLFloat(self.xmlFile, string.format("vehicle.fillUnits.fillUnit(%d)#capacity", j)), 0.0)
			local volumeNodeIndex = Utils.indexToObject(self.components, getXMLString(self.xmlFile, unitKey.."#volumeNodeIndex"))
		  	local newCapacity = Utils.getNoNil(getXMLFloat(self.xmlFile, unitKey .. "#capacity"), capacity)
			local animationName = getXMLString(self.xmlFile, unitKey .. "#animationName")

			table.insert(extraCapacity, {volumeNodeIndex=volumeNodeIndex, newCapacity=newCapacity, animationName=animationName})
			j = j + 1
		end

		table.insert(self.extraCapacities, extraCapacity)
		i = i + 1		
	end

	if savegame ~= nil then
		self.mode = Utils.getNoNil(getXMLInt(savegame.xmlFile, savegame.key.."#changeCapacity"),1)
    end

    -- as last update capacities, this has to be called otherwise clients without savegame
    -- won't have properly visualized capacities
    self:updateCapacities(true)
end

function changeCapacity:delete()end

function changeCapacity:readStream(streamId, connection)
	self.mode = streamReadInt8(streamId)
end

function changeCapacity:writeStream(streamId, connection)
	streamWriteInt8(streamId, self.mode)
end

function changeCapacity:getSaveAttributesAndNodes(nodeIdent)
	local attributes = 'changeCapacity="'..tostring(self.mode)..'"'
	return attributes, nil
end

function changeCapacity:mouseEvent(posX, posY, isDown, isUp, button)end

function changeCapacity:keyEvent(unicode, sym, modifier, isDown)end

function changeCapacity:update(dt)
	if self.isClient then
		if self:getFillLevel() == 0 and self:getIsActiveForInput() then
			if InputBinding.hasEvent(InputBinding.changeCapacity) then
				if self:isAnyBeltFasten() then					
					g_currentMission:showBlinkingWarning(g_i18n:getText("warning_beltsAreFasten"));
				else
					if self.mode < table.getn(self.extraCapacities) then
						self.mode = self.mode + 1
					else 
						self.mode = 1
					end
					self:setMode(self.mode)
				end
			end
		end

		self:updateCapacities()
	end
end

function changeCapacity:updateCapacities(force)
	local force = force ~= nil and force

	for k, extraCapacity in pairs(self.extraCapacities) do
		-- set new capacity only if unit has different capacity as it should have 
		-- (for performance reasons we are checking only first unit & assuming that once first is reset others will be too)
		if k == self.mode and (self:getUnitCapacity(1) ~= extraCapacity[1].newCapacity or force) then
			
			for k1, unit in pairs(self.extraCapacities[k]) do				

				-- set new unit capacity
				self:setUnitCapacity(k1, unit.newCapacity);
			
				-- setup new fill volume and recreate fill plane shape
				local fillVolume = self.fillVolumes[k1]
				fillVolume.baseNode = unit.volumeNodeIndex;
				fillVolume.volume = createFillPlaneShape(fillVolume.baseNode, "fillPlane", unit.newCapacity, fillVolume.maxDelta, fillVolume.maxSurfaceAngle, math.rad(35), fillVolume.maxSubDivEdgeLength, fillVolume.allSidePlanes);
				link(fillVolume.baseNode, fillVolume.volume);
		
				-- play switch animation
				self:playAnimation(unit.animationName, 1, self:getAnimationTime(unit.animationName), true)
			end
		end
	end
end

function changeCapacity:updateTick(dt)end

function changeCapacity:draw()
	g_currentMission:addHelpButtonText(g_i18n:getText("changeCapacity"), InputBinding.changeCapacity)
	if self:getFillLevel() ~= 0 and InputBinding.isPressed(InputBinding.changeCapacity) then
		g_currentMission:showBlinkingWarning(g_i18n:getText("warning"))
	end
end

function changeCapacity:isAnyBeltFasten()
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

function changeCapacity:setMode(mode, noEventSend)
	self.mode = mode
	setModeEvent.sendEvent(self, mode, noEventSend)
end

--
-- MP ready
--

setModeEvent = {}
setModeEvent_mt = Class(setModeEvent, Event)

InitEventClass(setModeEvent, "setModeEvent")

function setModeEvent:emptyNew()
    local self = Event:new(setModeEvent_mt)
    return self
end

function setModeEvent:new(object, changeMode)
    local self = setModeEvent:emptyNew()
    self.object = object
	self.changeMode = changeMode
    return self
end

function setModeEvent:readStream(streamId, connection)
    -- local id = streamReadInt32(streamId)
	self.object = readNetworkNodeObject(streamId);
	self.changeMode = streamReadInt8(streamId)
    --self.object = networkGetObject(id)
    self:run(connection)
end

function setModeEvent:writeStream(streamId, connection)
    -- streamWriteInt32(streamId, networkGetObjectId(self.object))
	writeNetworkNodeObject(streamId, self.object);
	streamWriteInt8(streamId, self.changeMode)
end;

function setModeEvent:run(connection)
	self.object:setMode(self.changeMode, true)
    if not connection:getIsServer() then
        g_server:broadcastEvent(setModeEvent:new(self.object, self.changeMode), nil, connection, self.object)
    end
end

function setModeEvent.sendEvent(vehicle, changeMode, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(setModeEvent:new(vehicle, changeMode), nil, nil, vehicle)
		else
			g_client:getServerConnection():sendEvent(setModeEvent:new(vehicle, changeMode))
		end
	end
end
