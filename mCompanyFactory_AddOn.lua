local metadata = {
"## Interface: FS17 1.3.1.0 1.3.1RC10",
"## Title: mCompanyFactory_AddOn",
"## Notes: zusätzliche Trigger für Fabrikscript und AnimalFattening",
"## Author: kevink98 / Giants / Marhu (LiquideTrigger LS15)",
"## Version: 1.2.0",
"## Date: 30.09.2017",
"## Web: http://ls-modcompany.de " 
}
--[[
	## V1.0:
			- Add LiquideTrigger 
				- add setMove attribute (for shader)
				- add Support for Overloadpipe
			- Add SiloTrigger
				- add choose: manual or automatic unloading
	## V1.0.1:
			- LiquideTrigger: Fix tipping in InputTrigger
	## V1.0.2:
			- Fix SiloTrigger: Automatic when filling
	## V1.0.3:
			- Fix LiquideTrigger: more then one filltyp to unload
	## V1.0.4:
			- Fix FillSound SiloTrigger		
	## V1.1.0:
			- NEW: TankTrigger (for Output)
	## V1.2.0:
			- NEW: AnimalTriggers (for In- and Output)
]]--

local DebugEbene = 1;
local function getmdata(v) v="## "..v..": "; for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],v);if n then return (string.sub (metadata[i], n+1)); end;end;end;
local function Debug(e,s,...) if e <= DebugEbene then	print((getmdata("Title")).." v"..(getmdata("Version"))..": "..string.format(s,...)); end; end;
local function L(name) local t = getmdata("Title"); return g_i18n:hasText(t.."_"..name) and g_i18n:getText(t.."_"..name) or name; end

AdditionalTriggers = {}
function AdditionalTriggers:doPrint()
	Debug(0,"load!")
end;

local ModDir = g_currentModDirectory;

SiloTriggerFS = {};
local SiloTriggerFS_mt = Class(SiloTriggerFS);
InitObjectClass(SiloTriggerFS, "SiloTriggerFS");

function SiloTriggerFS:new(isServer, isClient)
	local self = {};
	setmetatable(self, SiloTriggerFS_mt)
	self.SiloTriggerFsTrailers = {}
	self.isFilling = false;
	self.isAutomaticFilling = false;
	self.activeTriggers = 0;
	self.isActiveActi = false;
	self.showOnHelpPlayer = false;
	self.showOnHelpVehicle = false;
	self.otherId = 0;
	self.SiloTriggerAutomaticFillActivatable = SiloTriggerAutomaticFillActivatable:new(self)
	self.SiloTriggerAutomaticActivatable = SiloTriggerAutomaticActivatable:new(self)
	self.isClient = isClient
	self.isServer = isServer
	return self;
end;

function SiloTriggerFS:load(id,tank)
	self.nodeId = id;
	self.triggerIds = {}
	local triggerRoot= Utils.indexToObject(id, getUserAttribute(id, "triggerIndex"));
    if triggerRoot == nil then
        triggerRoot = id;
	end
	self.Tank = tank;
	table.insert(self.triggerIds,triggerRoot);
	addTrigger(triggerRoot, "triggerCallback", self)
	self.triggerRoot = triggerRoot;
	self.changeTrigger = Utils.indexToObject(id,getUserAttribute(id,"automaticTriggerIndex"));
	self.firstRun = true;
	if self.changeTrigger ~= nil then
		addTrigger(self.changeTrigger,"automaticTrigger",self);
	else
		Debug(0,"no automaticTrigger in %s",getName(id));
	end;
	for i=0, 2 do
        local child = getChildAt(triggerRoot, i);
        table.insert(self.triggerIds, child);
        addTrigger(child, "triggerCallback", self);
	end;
		
	self.fillVolumeDischargeInfos = {};
    self.fillVolumeDischargeInfos.name = "fillVolumeDischargeInfo";
    self.fillVolumeDischargeInfos.nodes = {};
    local node = Utils.indexToObject(id, getUserAttribute(id, "fillVolumeDischargeNode"));
    local width = Utils.getNoNil( getUserAttribute(id, "fillVolumeDischargeNodeWidth"), 0.5 );
    local length = Utils.getNoNil( getUserAttribute(id, "fillVolumeDischargeNodeLength"), 0.5 );
    table.insert(self.fillVolumeDischargeInfos.nodes, {node=node, width=width, length=length, priority=1});
		
	local fillTypesStr = Utils.getNoNil(getUserAttribute(id, "fillType"),"wheat")
	fillTypesStr = Utils.getNoNil(getUserAttribute(id, "fillType"),fillTypesStr)
	local fillType = FillUtil.fillTypeNameToInt[fillTypesStr]
	if fillType then
		self.fillType = fillType;
	else
		Debug(-1,"ERROR: unknown fillType %s in %s",tostring(fillTypesStr),getName(id));
	end
	
	self.fillLitersPerSecond = Utils.getNoNil(getUserAttribute(id, "fillLitersPerSecond"), 50);
	
	
	self.SiloTriggerAutomaticActivatable.startFillText = Utils.getNoNil(L(getUserAttribute(id,"startText")),"start filling");
	self.SiloTriggerAutomaticActivatable.stopFillText = Utils.getNoNil(L(getUserAttribute(id,"stopText")),"stop filling");
	self.SiloTriggerAutomaticFillActivatable.toManualText = Utils.getNoNil(L(getUserAttribute(id,"toManualText")),"to manual filling");
	self.SiloTriggerAutomaticFillActivatable.toAutomaticText = Utils.getNoNil(L(getUserAttribute(id,"toAutomaticText")),"to automatic filling");
	
	self.helpBoxTextInfo = L("helpBoxTextInfo");
	self.helpBoxTextAuto = L("helpBoxTextAuto");
	self.helpBoxTextManual = L("helpBoxTextManual");
	
	if self.isClient then
		local SoundFileName  = getUserAttribute(id, "fillSoundFilename");
		if SoundFileName == nil then
			SoundFileName = "$data/maps/sounds/siloFillSound.wav";
		end;
		if SoundFileName ~= "" and SoundFileName ~= "none" then
			SoundFileName = Utils.getFilename(SoundFileName,  ModDir);	
			self.siloFillSound = createAudioSource("siloFillSound", SoundFileName, 30, 10, 1, 0);	
            link(id, self.siloFillSound);
            setVisibility(self.siloFillSound, false);
		end;
		local dropParticleSystem = Utils.indexToObject(id, getUserAttribute(id, "dropParticleSystemIndex"));
        if dropParticleSystem ~= nil then
            self.dropParticleSystems = {}
            for i=getNumOfChildren(dropParticleSystem)-1, 0, -1 do
                local child = getChildAt(dropParticleSystem, i)
                local ps = {}
                ParticleUtil.loadParticleSystemFromNode(child, ps, true, true)
                table.insert(self.dropParticleSystems, ps)
            end
        end
        local lyingParticleSystem = Utils.indexToObject(id, getUserAttribute(id, "lyingParticleSystemIndex"));
        if lyingParticleSystem ~= nil then
            self.lyingParticleSystems = {};
            for i=getNumOfChildren(lyingParticleSystem)-1, 0, -1 do
                local child = getChildAt(lyingParticleSystem, i)
                local ps = {}
                ParticleUtil.loadParticleSystemFromNode(child, ps, false, true)
                ParticleUtil.addParticleSystemSimulationTime(ps, ps.originalLifespan)
                ParticleUtil.setParticleSystemTimeScale(ps, 0);
                table.insert(self.lyingParticleSystems, ps)
            end
		end
		
		 if self.dropParticleSystems == nil then
            local effectsNode = Utils.indexToObject(id, getUserAttribute(id, "effectsNode"));
            if effectsNode ~= nil then
                self.dropEffects = EffectManager:loadFromNode(effectsNode, self);
            end
            if self.dropEffects == nil then
                local x,y,z = getTranslation(id);
                local particlePositionStr = getUserAttribute(id, "particlePosition");
                if particlePositionStr ~= nil then
                    local psx,psy,psz = Utils.getVectorFromString(particlePositionStr);
                    if psx ~= nil and psy ~= nil and psz ~= nil then
                        x = x + psx;
                        y = y + psy;
                        z = z + psz;
                    end;
                end;
                local psData = {};
                psData.psFile = getUserAttribute(id, "particleSystemFilename");
                if psData.psFile == nil then
                    local particleSystem = Utils.getNoNil(getUserAttribute(id, "particleSystem"), "unloadingSiloParticles");
                    psData.psFile = "$data/vehicles/particleAnimation/shared/" .. particleSystem .. ".i3d";
                end
                psData.posX, psData.posY, psData.posZ = x,y,z;
                psData.worldSpace = false;
                self.dropParticleSystems = {};
                local ps = {}
                ParticleUtil.loadParticleSystemFromData(psData, ps, nil, false, nil, g_currentMission.baseDirectory, getParent(id));
                table.insert(self.dropParticleSystems, ps)
            end;
        end
		
		self.scroller = Utils.indexToObject(id, getUserAttribute(id, "scrollerIndex"));
        if self.scroller ~= nil then
            self.scrollerShaderParameterName = Utils.getNoNil(getUserAttribute(self.scroller, "shaderParameterName"), "uvScrollSpeed");
            local scrollerScrollSpeed = getUserAttribute(self.scroller, "scrollSpeed");
            if scrollerScrollSpeed ~= nil then
                self.scrollerSpeedX, self.scrollerSpeedY = Utils.getVectorFromString(scrollerScrollSpeed);
            end
            self.scrollerSpeedX = Utils.getNoNil(self.scrollerSpeedX, 0);
            self.scrollerSpeedY = Utils.getNoNil(self.scrollerSpeedY, -0.75);
            setShaderParameter(self.scroller, self.scrollerShaderParameterName, 0, 0, 0, 0, false);
		end
	end
	g_currentMission:addUpdateable(self);
	return true;
end;

function SiloTriggerFS:delete()
	if self.isClient then
        EffectManager:deleteEffects(self.dropEffects);
        ParticleUtil.deleteParticleSystems(self.dropParticleSystems)
        ParticleUtil.deleteParticleSystems(self.lyingParticleSystems)
    end
    for i=1, table.getn(self.triggerIds) do
        removeTrigger(self.triggerIds[i]);
	end
	removeTrigger(self.triggerRoot);
	removeTrigger(self.changeTrigger);
end;

function SiloTriggerFS:TankCapacity() 
	return self.Tank.getCapacity(self.fillType)
end

function SiloTriggerFS:TankFillLevel()
	return self.Tank.getFillLevel()
end

function SiloTriggerFS:setTankFillLevel(lvl)
	self.Tank.setFillLevel(lvl, self.fillType)
end

function SiloTriggerFS:update(dt)
	if self.isServer then		
		local trailer = self.siloTrailer;
		local disableFilling = true;
		if self.activeTriggers >= 4 and trailer ~= nil then
			if self.isAutomaticFilling or self.isFilling then
				trailer:resetFillLevelIfNeeded(self.fillType);
				local TfillLvl = trailer:getFillLevel(self.fillType);
				local capacity = self:TankCapacity();
				local fillLvl = self:TankFillLevel();
				if fillLvl > 0 then
					local delta = math.min(self.fillLitersPerSecond*0.001*dt,fillLvl);
					trailer:setFillLevel(TfillLvl+delta,self.fillType,false,self.fillVolumeDischargeInfos);
					local newLvl = trailer:getFillLevel(self.fillType);
					if newLvl ~= TfillLvl then
						self:setTankFillLevel(math.max(fillLvl-(newLvl-TfillLvl)),0);
						disableFilling = false;
						if self.isAutomaticFilling then
							self:setFilling(true)
						end;
					end;
				else
					self:setFilling(false);
				end;
			end
		end;
		if self.isFilling and disableFilling then
			self:setFilling(false);
		end;
	end;
	if self.firstRun then
		self.firstRun = false;
		self.showOnHelpPlayer = false;
		self.showOnHelpVehicle = false;
	end;
	if self.showOnHelpPlayer and g_currentMission.controlPlayer and g_currentMission.controlPlayer and g_currentMission.player and self.otherId == g_currentMission.player.rootNode then
		if self.isAutomaticFilling then
			g_currentMission:addExtraPrintText(self.helpBoxTextAuto);
		else
			g_currentMission:addExtraPrintText(self.helpBoxTextManual);
		end;
		if g_currentMission.controlledVehicle == nil and not self.isActiveActi then
			self.isActiveActi = true;
			g_currentMission:addActivatableObject(self.SiloTriggerAutomaticFillActivatable);
		end;
	elseif self.showOnHelpVehicle then
		if self.siloTrailer ~= nil then
			if self.siloTrailer:getRootAttacherVehicle() == g_currentMission.controlledVehicle then
				if g_currentMission.controlledVehicle ~= nil then
					g_currentMission:addExtraPrintText(self.helpBoxTextInfo);
				end;
				if self.isAutomaticFilling then
					g_currentMission:addExtraPrintText(self.helpBoxTextAuto);
				else
					g_currentMission:addExtraPrintText(self.helpBoxTextManual);
				end;
			end;
		end;
	end;
end;

function SiloTriggerFS:setAutomaticFilling(isAutomaticFilling, noEventSend) 
	SiloTriggerAutomaticEvent.sendEvent(self.Tank.Parent,self.FS_SiloTriggerId, isAutomaticFilling, noEventSend)
	if self.isAutomaticFilling ~= isAutomaticFilling then
		self.isAutomaticFilling = isAutomaticFilling 
	end;
	if not self.isAutomaticFilling then
		self:setFilling(false)
	end;
end;

function SiloTriggerFS:setFilling(isFilling, noEventSend) 
	if self.isFilling ~= isFilling then
		self.isFilling = isFilling 
		SiloTriggerFillingEvent.sendEvent(self.Tank.Parent, self.FS_SiloTriggerId, isFilling, noEventSend)
	end;
	if self.isFilling then
		self:startFill();
	else
		self:stopFill();
	end;
end;

function SiloTriggerFS:startFill()
    if self.isFilling then
        if self.isClient then
            if not self.siloFillSoundEnabled and self.siloFillSound ~= nil then
                setVisibility(self.siloFillSound, true);
                self.siloFillSoundEnabled = true;
            end;
            if self.dropParticleSystems ~= nil then
                for _, ps in pairs(self.dropParticleSystems) do
                    ParticleUtil.setEmittingState(ps, true);
                end
            end
            if self.lyingParticleSystems ~= nil then
                for _, ps in pairs(self.lyingParticleSystems) do
                    ParticleUtil.setParticleSystemTimeScale(ps, 1.0);
                end
            end
            if self.dropEffects ~= nil then
                EffectManager:setFillType(self.dropEffects, self.fillType)
                EffectManager:startEffects(self.dropEffects);
            end;
            if self.scroller ~= nil then
                setShaderParameter(self.scroller, self.scrollerShaderParameterName, self.scrollerSpeedX, self.scrollerSpeedY, 0, 0, false);
            end
        end;
    end;
end;

function SiloTriggerFS:stopFill()
    if not self.isFilling then
        if self.isClient then
            if self.siloFillSoundEnabled then
                setVisibility(self.siloFillSound, false);
                self.siloFillSoundEnabled = false;
            end;
            if self.dropParticleSystems ~= nil then
                for _, ps in pairs(self.dropParticleSystems) do
                    ParticleUtil.setEmittingState(ps, false);
                end
            end
            if self.lyingParticleSystems ~= nil then
                for _, ps in pairs(self.lyingParticleSystems) do
                    ParticleUtil.setParticleSystemTimeScale(ps, 0);
                end
            end
            EffectManager:stopEffects(self.dropEffects);
            if self.scroller ~= nil then
                setShaderParameter(self.scroller, self.scrollerShaderParameterName, 0, 0, 0, 0, false);
            end
        end;
    end;
end;

function SiloTriggerFS:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    --if self.isEnabled then
        local trailer = g_currentMission.objectToTrailer[otherActorId];
        if trailer ~= nil and otherActorId == trailer.exactFillRootNode and trailer:allowFillType(self.fillType, false) then
            if onEnter and trailer.getAllowFillFromAir ~= nil then
                self.activeTriggers = self.activeTriggers + 1;
                self.siloTrailer = trailer;
                if self.activeTriggers >= 4 then
					g_currentMission:addActivatableObject(self.SiloTriggerAutomaticActivatable);
                    if self.siloTrailer.coverAnimation ~= nil and self.siloTrailer.autoReactToTrigger == true then
                        self.siloTrailer:setCoverState(true);
                    end
					if self.isAutomaticFilling then
						self:setFilling(true);
					end;
                end
				self.showOnHelpVehicle = true;
            elseif onLeave then
                if self.siloTrailer ~= nil and self.siloTrailer.coverAnimation ~= nil and self.siloTrailer.autoReactToTrigger == true then
                    self.siloTrailer:setCoverState(false);
                end
                self.activeTriggers = math.max(self.activeTriggers - 1, 0);
                self.siloTrailer = nil;
                self:setFilling(false);
                g_currentMission:removeActivatableObject(self.SiloTriggerAutomaticActivatable);
            end;
			if onStay then
				self.showOnHelpVehicle = true;
			end;
        end;
    --end;
end;

function SiloTriggerFS:automaticTrigger(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if g_currentMission.controlPlayer and g_currentMission.player and otherId == g_currentMission.player.rootNode then
		self.otherId = otherId;
		if onEnter then
			self.showOnHelpPlayer = true;
		elseif onLeave then
			self.showOnHelpPlayer = false;
			self.showOnHelpVehicle = false;
			if g_currentMission.controlledVehicle == nil then
				g_currentMission:removeActivatableObject(self.SiloTriggerAutomaticFillActivatable);
				self.isActiveActi = false;
			end;
		end;
	end;
end;

SiloTriggerAutomaticFillActivatable = {}
local SiloTriggerAutomaticFillActivatable_mt = Class(SiloTriggerAutomaticFillActivatable)
function SiloTriggerAutomaticFillActivatable:new(Trigger)
	local self = {}
	setmetatable(self, SiloTriggerAutomaticFillActivatable_mt)

	self.Trigger = Trigger
	self.activateText = "unknown"
	return self
end
function SiloTriggerAutomaticFillActivatable:getIsActivatable()
	if g_currentMission.controlledVehicle == nil and self.Trigger.showOnHelpPlayer then
		self.updateActivateText(self)
		return true;
	end;
	return false;
end
function SiloTriggerAutomaticFillActivatable:onActivateObject()
	self.Trigger:setAutomaticFilling(not self.Trigger.isAutomaticFilling);
	self.updateActivateText(self)
	g_currentMission:addActivatableObject(self)
end
function SiloTriggerAutomaticFillActivatable:drawActivate()
end
function SiloTriggerAutomaticFillActivatable:updateActivateText()
	if self.Trigger.isAutomaticFilling then
		self.activateText = self.toManualText;
	else	
		self.activateText = self.toAutomaticText;
	end;
end

SiloTriggerAutomaticActivatable = {}
local SiloTriggerAutomaticActivatable_mt = Class(SiloTriggerAutomaticActivatable)
function SiloTriggerAutomaticActivatable:new(Trigger)
	local self = {}
	setmetatable(self, SiloTriggerAutomaticActivatable_mt)

	self.Trigger = Trigger
	self.activateText = "unknown"

	return self
end
function SiloTriggerAutomaticActivatable:getIsActivatable()
	
	if self.Trigger.siloTrailer ~= nil and self.Trigger.activeTriggers >= 4 then
		local trailer = self.Trigger.siloTrailer;
		if trailer:getRootAttacherVehicle() ~= g_currentMission.controlledVehicle then
			return false;
		end;
		if not trailer:getAllowFillFromAir() then
			return false;
		end
		if trailer:getFillLevel() == 0 then
			self.updateActivateText(self)
			return true;
		else
			local fillTypes = trailer:getCurrentFillTypes();
			for _,fillType in pairs(fillTypes) do
				if fillType == self.Trigger.fillType and trailer:getFillLevel(fillType) < trailer:getCapacity() and self.Trigger:TankFillLevel(fillType) > 0 then
					self.updateActivateText(self)
					local r = false;
					if not self.Trigger.isAutomaticFilling then
						r = true;
					end;
					return r;
				end
			end	
		end;
	end;
	return false;
end
function SiloTriggerAutomaticActivatable:onActivateObject()
	self.Trigger:setFilling(not self.Trigger.isFilling);
	self.updateActivateText(self)
	g_currentMission:addActivatableObject(self)
end
function SiloTriggerAutomaticActivatable:drawActivate()
end
function SiloTriggerAutomaticActivatable:updateActivateText()
	if self.Trigger.isFilling then
		self.activateText = self.stopFillText;
	else	
		self.activateText = self.startFillText;
	end;
end

SiloTriggerAutomaticEvent = {}
SiloTriggerAutomaticEvent_mt = Class(SiloTriggerAutomaticEvent, Event)
InitEventClass(SiloTriggerAutomaticEvent, "SiloTriggerAutomaticEvent")
function SiloTriggerAutomaticEvent:emptyNew()
	local self = Event:new(SiloTriggerAutomaticEvent_mt)
	return self
end
function SiloTriggerAutomaticEvent:new(object, FS_SiloTriggerId, isFilling)
	local self = SiloTriggerAutomaticEvent:emptyNew()
	self.object = object
	self.FS_SiloTriggerId = FS_SiloTriggerId;
	self.isFilling = isFilling
	return self
end
function SiloTriggerAutomaticEvent:readStream(streamId, connection)
	self.object = readNetworkNodeObject(streamId)
	self.FS_SiloTriggerId = streamReadInt32(streamId)
	self.isFilling = streamReadBool(streamId)
	self:run(connection)
end
function SiloTriggerAutomaticEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object)
	streamWriteInt32(streamId,self.FS_SiloTriggerId)
	streamWriteBool(streamId, self.isFilling)
end
function SiloTriggerAutomaticEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.object ~= nil then
		self.object:setIsSiloTriggerAutomatic(self.FS_SiloTriggerId, self.isFilling,true)
	end;
end
function SiloTriggerAutomaticEvent.sendEvent(object, FS_SiloTriggerId, isFilling, noEventSend)
	if (noEventSend == nil or noEventSend == false) then
		if g_server ~= nil then
			g_server:broadcastEvent(SiloTriggerAutomaticEvent:new(object, FS_SiloTriggerId, isFilling), nil, nil, object)
		else
			g_client:getServerConnection():sendEvent(SiloTriggerAutomaticEvent:new(object, FS_SiloTriggerId, isFilling))
		end
	end
end

SiloTriggerFillingEvent = {}
SiloTriggerFillingEvent_mt = Class(SiloTriggerFillingEvent, Event)
InitEventClass(SiloTriggerFillingEvent, "SiloTriggerFillingEvent")
function SiloTriggerFillingEvent:emptyNew()
	local self = Event:new(SiloTriggerFillingEvent_mt)
	return self
end
function SiloTriggerFillingEvent:new(object, FS_SiloTriggerId, isFilling)
	local self = SiloTriggerFillingEvent:emptyNew()
	self.object = object
	self.FS_SiloTriggerId = FS_SiloTriggerId;
	self.isFilling = isFilling
	return self
end
function SiloTriggerFillingEvent:readStream(streamId, connection)
	self.object = readNetworkNodeObject(streamId)
	self.FS_SiloTriggerId = streamReadInt32(streamId)
	self.isFilling = streamReadBool(streamId)
	self:run(connection)
end
function SiloTriggerFillingEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object)
	streamWriteInt32(streamId,self.FS_SiloTriggerId)
	streamWriteBool(streamId, self.isFilling)
end
function SiloTriggerFillingEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.object ~= nil then
		self.object:setIsSiloTriggerFilling(self.FS_SiloTriggerId, self.isFilling,true)
	end;
end
function SiloTriggerFillingEvent.sendEvent(object, FS_SiloTriggerId, isFilling, noEventSend)
	if isFilling ~= object.isFilling then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(SiloTriggerFillingEvent:new(object, FS_SiloTriggerId, isFilling), nil, nil, object)
			else
				g_client:getServerConnection():sendEvent(SiloTriggerFillingEvent:new(object,FS_SiloTriggerId, isFilling))
			end
		end
	end;
end

--LiquideTrigger
LiquideTrigger = {}
local LiquideTrigger_mt = Class(LiquideTrigger);
InitObjectClass(LiquideTrigger, "LiquideTrigger");

function LiquideTrigger:new(isServer, isClient)
	local self = {};
	setmetatable(self, LiquideTrigger_mt)
	self.liquideTrailers = {}
	self.isLiquideTankFilling = false;
	self.liquideTrailerForOverloadPipe = nil;
	self.LiquideTankActivatable = LiquideTankActivatable:new(self)
	self.isClient = isClient
	self.isServer = isServer
	
	return self;
end;

function LiquideTrigger:load(id,tank)
	
	self.nodeId = id;
	self.triggerId = Utils.indexToObject(id, getUserAttribute(id, "triggerIndex"));
    if self.triggerId == nil then
        self.triggerId = id;
	end
	
	self.Tank = tank;

	addTrigger(self.triggerId, "triggerCallback", self)
		
	local fillTypesStr = Utils.getNoNil(getUserAttribute(self.triggerId, "fillType"),"water")
	fillTypesStr = Utils.splitString(" ", (Utils.getNoNil(getUserAttribute(id, "fillType"),fillTypesStr)));
	self.fillTypes = {};
	for k, Str in pairs(fillTypesStr) do
		local typ = FillUtil.fillTypeNameToInt[Str]
		if typ ~= nil then
			if not self.isInputTrigger then
				self.currentFillType = typ;
				break;
			else
				self.fillTypes[typ] = true;
			end;
		end;
	end;
	
	if self.fillTypes == nil and self.currentFillType == nil then
		Debug(-1,"ERROR: unknown fillType %s in %s",tostring(fillTypesStr),getName(id));
	end
	
	self.priceScale = Utils.getNoNil(getUserAttribute(id, "priceScale"), 0)
	self.fillLitersPerSecond = Utils.getNoNil(getUserAttribute(id, "fillLitersPerSecond"), 50);
	
	if self.isClient then
		local SoundFile  = Utils.getFilename("$data/maps/sounds/refuel.wav",  ModDir);	
		self.SourceRefuel = createAudioSource("RefuelSound", SoundFile, 30, 15, 0, 1);
		self.sampleRefuel = getAudioSourceSample(self.SourceRefuel);
		link(id, self.SourceRefuel);
	end
	
	local Name = Utils.getNoNil(getUserAttribute(self.triggerId, "L_Name"), "LiquideTriggerName") -- in der modDesc.xml, text name="TitelDesScriptes_Name"
	Name = Utils.getNoNil(getUserAttribute(id, "L_Name"), Name)
	local start = Name.."_start";
	local stop = Name.."_stop";
	self.LiquideTankActivatable.liquideTriggerNameStart = L(start)
	self.LiquideTankActivatable.liquideTriggerNameStop = L(stop)
	
	local movingIndex = getUserAttribute(id, "movingIndex")
	if movingIndex then
		local minY, maxY = Utils.getVectorFromString(getUserAttribute(id, "moveMinMaxY"));
		if minY ~= nil and maxY ~= nil then
			local maxAmount = tonumber(getUserAttribute(id, "moveMaxAmount")) or self:liquideTankCapacity();
			Debug(2,"maxAmount %.2f",maxAmount)
			if maxAmount ~= nil then
				self.movingIndex = Utils.indexToObject(id, movingIndex);
				self.moveMinY = minY;
				self.moveMaxY = maxY;
				self.moveMaxAmount = maxAmount;
			end;
			local setMove = getUserAttribute(id,"setMove");
			if setMove ~= nil then
				self.setMove = setMove;
			end;
		end;
	end;
				
	
	self.IsFilling = false
	self.isEnabled = true
	
	g_currentMission:addUpdateable(self);
	return true;
end;

function LiquideTrigger:delete()
	
	removeTrigger(self.triggerId)

end;

function LiquideTrigger:update(dt)
	
	if self.isLiquideTankFilling then
		local disableFilling = true;
		if self.liquideTankFillTrailer then
			if self.isClient and self.liquideTankFillTrailer.setOverloadPipe ~= nil and self.liquideTankFillTrailer.setTrigger ~= nil then
				self.liquideTankFillTrailer:setTrigger(self.triggerId);
				self.liquideTankFillTrailer:setOverloadPipe(self.triggerId);
			end
			if self.isServer then
				local liquideFillLevel = self.liquideTankFillTrailer:getFillLevel(self.currentFillType)
				local fillLitersPerSecond = self.liquideTankFillTrailer.fillLitersPerSecond or self.liquideTankFillTrailer.fuelFillLitersPerSecond or self.fillLitersPerSecond;
				local delta = fillLitersPerSecond*dt*0.001
				
				if self.isInputTrigger then
					delta = math.min(delta, liquideFillLevel, self:liquideTankCapacity()-self:liquideTankFillLevel())
				else
					delta = math.min(delta, self:liquideTankFillLevel())
				end
				
				if delta > 0 then
					if self.isInputTrigger then
						disableFilling = false
						self.liquideTankFillTrailer:setFillLevel(liquideFillLevel - delta, self.currentFillType, true);
					else
						self.liquideTankFillTrailer:setFillLevel(liquideFillLevel + delta, self.currentFillType)
						delta = liquideFillLevel - self.liquideTankFillTrailer:getFillLevel(self.currentFillType);
						if delta < 0 then disableFilling = false end;
					end;
					self:setLiquideTankFillLevel(self:liquideTankFillLevel() + delta)
				end;
			end;
		end
		if self.isServer and disableFilling then
			self:setIsLiquideTankFilling(false)
		end;
	end
	
	self.elapsed = (self.elapsed or 0) + dt;
	if self.elapsed >= 300 then self:updateTick(self.elapsed); end	
end;

function LiquideTrigger:updateTick(dt)
	self.elapsed = self.elapsed - dt
end;

function LiquideTrigger:addLiquideTrailer(trailer)
	if table.getn(self.liquideTrailers) == 0 then
		g_currentMission:addActivatableObject(self.LiquideTankActivatable)
	end
	if self.isInputTrigger then
		local types = trailer:getCurrentFillTypes();
		for k,fillType in pairs(types) do
			if self.fillTypes[fillType] then
				self.currentFillType = fillType;
			end;
		end;
	end;
	table.insert(self.liquideTrailers, trailer)
end

function LiquideTrigger:removeLiquideTrailer(trailer)
	for i = 1, table.getn(self.liquideTrailers), 1 do
		if self.liquideTrailers[i] == trailer then
			table.remove(self.liquideTrailers, i)
			break
		end
	end

	if table.getn(self.liquideTrailers) == 0 then
		g_currentMission:removeActivatableObject(self.LiquideTankActivatable)
	end
	
	if self.isServer and self.liquideTankFillTrailer == trailer then
		self:setIsLiquideTankFilling(false)
	end;
end

function LiquideTrigger:liquideTankCapacity() 
	return self.Tank.getCapacity(self.currentFillType)
end

function LiquideTrigger:liquideTankFillLevel()
	return self.Tank.getFillLevel()
end

function LiquideTrigger:setLiquideTankFillLevel(lvl)
	self.Tank.setFillLevel(lvl, self.currentFillType)
end

function LiquideTrigger:updateMoving(amount)
	Debug(5,"%s","updateMoving")
	if self.moveMaxAmount then
		if amount < 0.001 then
			amount = 0;
		end;
		local mover = 0;
		if self.movingIndex then
			mover = self.movingIndex
		elseif self.nodeId then
			mover = self.nodeId
		end
		local x,y,z = getTranslation(mover);
		
		if self:liquideTankFillLevel() == 0 then
			y = self.moveMinY;
		elseif self.setMove ~= nil and self.moveMinY + (self.moveMaxY - self.moveMinY)*Utils.clamp(amount, 0, self.moveMaxAmount)/(self.moveMaxAmount) <= self.setMove then
			y = self.setMove;
		else
			y = self.moveMinY + (self.moveMaxY - self.moveMinY)*Utils.clamp(amount, 0, self.moveMaxAmount)/(self.moveMaxAmount);
		end;
		Debug(6,"%s","setTranslation(mover)")	
		setTranslation(mover, x,y,z);
	end;
end

function LiquideTrigger:setIsLiquideTankFilling(isLiquideTankFilling, trailer, noEventSend)
	LiquideTriggerSetIsFillingEvent.sendEvent(self.Tank.Parent, self.FS_LiquideTriggerId, isLiquideTankFilling, trailer, noEventSend)
	if self.isLiquideTankFilling ~= isLiquideTankFilling then
		self.isLiquideTankFilling = isLiquideTankFilling
		self.liquideTankFillTrailer = trailer
	end

	if self.isClient and self.sampleRefuel ~= nil then
		if isLiquideTankFilling then
			playSample(self.sampleRefuel,0,1,0)
		else
			stopSample(self.sampleRefuel)
		end
	end
	if self.isClient then
		if self.liquideTrailerForOverloadPipe ~= nil and self.liquideTrailerForOverloadPipe.UpdateOverloadPipe then
			self.liquideTrailerForOverloadPipe.isFillingOverloadPipe = isLiquideTankFilling;
		end;
	end;
	return 
end

function LiquideTrigger:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	local trailer = g_currentMission.objectToTrailer[otherShapeId]
	if trailer ~= nil then
		if onEnter then
			self:addLiquideTrailer(trailer)
		else
			self:removeLiquideTrailer(trailer)
		end
	end
end

LiquideTankActivatable = {}
local LiquideTankActivatable_mt = Class(LiquideTankActivatable)
function LiquideTankActivatable:new(Trigger)
	local self = {}

	setmetatable(self, LiquideTankActivatable_mt)

	self.Trigger = Trigger
	self.activateText = "unknown"
	self.currentTrailer = nil

	return self
end
function LiquideTankActivatable:getIsActivatable()
	self.currentTrailer = nil
	if self.Trigger.isInputTrigger then
		if self.Trigger:liquideTankCapacity() <= self.Trigger:liquideTankFillLevel() then
			Debug(10,"%s","getIsActivatable Capacity < ")
			return false
		end
	elseif self.Trigger:liquideTankFillLevel() <= 0 then
		Debug(10,"%s","getIsActivatable liquideTankFillLevel < ")
		return false
	end

	for _, trailer in pairs(self.Trigger.liquideTrailers) do
		if trailer.getIsActiveForInput(trailer) then
			if self.Trigger.isInputTrigger then
				if 0 < trailer.getFillLevel(trailer, self.Trigger.currentFillType) and trailer:allowFillType(self.Trigger.currentFillType, false) then
					self.currentTrailer = trailer
					self.Trigger.liquideTrailerForOverloadPipe = trailer;
					self.updateActivateText(self)
					Debug(10,"%s","getIsActivatable trailer.getFillLevel ")	
					return true
				end
			elseif trailer:allowFillType(self.Trigger.currentFillType, false) then
				self.currentTrailer = trailer
				self.Trigger.liquideTrailerForOverloadPipe = trailer;
				self.updateActivateText(self)
				Debug(10,"%s","getIsActivatable trailer.allowFillType ")	
				return true
			end
		end
	end
	Debug(10,"%s","getIsActivatable false")
	return false
end
function LiquideTankActivatable:onActivateObject()
	self.Trigger:setIsLiquideTankFilling(not self.Trigger.isLiquideTankFilling, self.currentTrailer)
	self.updateActivateText(self)
	g_currentMission:addActivatableObject(self)
end
function LiquideTankActivatable:drawActivate()
end
function LiquideTankActivatable:updateActivateText()
	--local typeDesc = self.Trigger.isInputTrigger and self.liquideTriggerName or (self.currentTrailer and self.currentTrailer.typeDesc or "unknown");
	if self.Trigger.isLiquideTankFilling then
		self.activateText = self.liquideTriggerNameStop
						--string.format(g_i18n:getText("stop_refill_OBJECT"), (typeDesc or "unknown"))
	else
		self.activateText = self.liquideTriggerNameStart
						--string.format(g_i18n:getText("refill_OBJECT"), (typeDesc or "unknown"))
	end
end

LiquideTriggerSetIsFillingEvent = {}
LiquideTriggerSetIsFillingEvent_mt = Class(LiquideTriggerSetIsFillingEvent, Event)
InitEventClass(LiquideTriggerSetIsFillingEvent, "LiquideTriggerSetIsFillingEvent")
function LiquideTriggerSetIsFillingEvent:emptyNew()
	local self = Event:new(LiquideTriggerSetIsFillingEvent_mt)
	return self
end
function LiquideTriggerSetIsFillingEvent:new(object, FS_LiquideTriggerId, isFilling, trailer)
	local self = LiquideTriggerSetIsFillingEvent:emptyNew()
	self.object = object
	self.FS_LiquideTriggerId = FS_LiquideTriggerId;
	self.isFilling = isFilling
	self.trailer = trailer
	return self
end
function LiquideTriggerSetIsFillingEvent:readStream(streamId, connection)
	self.object = readNetworkNodeObject(streamId)
	self.FS_LiquideTriggerId = streamReadInt32(streamId);
	self.isFilling = streamReadBool(streamId)

	if self.isFilling then
		self.trailer = readNetworkNodeObject(streamId)
	end

	self:run(connection)
end
function LiquideTriggerSetIsFillingEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object)
	streamWriteInt32(streamId, self.FS_LiquideTriggerId)
	streamWriteBool(streamId, self.isFilling)

	if self.isFilling then
		writeNetworkNodeObject(streamId, self.trailer)
	end
end
function LiquideTriggerSetIsFillingEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.object ~= nil then
		self.object:setIsLiquideTankFilling(self.FS_LiquideTriggerId, self.isFilling, self.trailer, true)
		Debug(5,"%s","self.object ~= nil")
	else
		Debug(5,"%s","self.object == nil")
	end;
end
function LiquideTriggerSetIsFillingEvent.sendEvent(object, FS_LiquideTriggerId, isFilling, trailer, noEventSend)
	if (noEventSend == nil or noEventSend == false) then
		if g_server ~= nil then
			g_server:broadcastEvent(LiquideTriggerSetIsFillingEvent:new(object, FS_LiquideTriggerId, isFilling, trailer), nil, nil, object)
		else
			g_client:getServerConnection():sendEvent(LiquideTriggerSetIsFillingEvent:new(object, FS_LiquideTriggerId, isFilling, trailer))
		end
	end
end


--TankTrigger
TankTrigger = {};
local TankTrigger_mt = Class(TankTrigger);
InitObjectClass(TankTrigger, "TankTrigger");

function TankTrigger:new(isServer, isClient)
	local self = {};
	setmetatable(self, TankTrigger_mt);
	self.vehicles = {};
	self.isFilling = false;
	self.isClient = isClient;
	self.isServer = isServer;
	return self;
end;

function TankTrigger:load(id,tank)
	self.nodeId = id;
	self.triggerId = id
	
	addTrigger(self.triggerId, "tankTriggerCallback", self);
	self.Tank = tank;
	
	if self.isClient then
		local SoundFile  = Utils.getFilename("$data/maps/sounds/refuel.wav",  self.ModDir);	
		self.SourceRefuel = createAudioSource("RefuelSound", SoundFile, 30, 15, 0, 1);
		self.sampleRefuel = getAudioSourceSample(self.SourceRefuel);
		link(id, self.SourceRefuel);
	end
	
	self.appearsOnPDA = Utils.getNoNil(getUserAttribute(id, "appearsOnPDA"), true);
	if self.appearsOnPDA then
		local mapPosition = id;
		local mapPositionIndex = getUserAttribute(id, "mapPositionIndex");
		if mapPositionIndex ~= nil then
			mapPosition = Utils.indexToObject(id, mapPositionIndex);
			if mapPosition == nil then
				mapPosition = id;
			end;
		end; z = getWorldTranslation(mapPosition);
		local fullViewName = Utils.getNoNil(getUserAttribute(id, "stationName"), "map_fuelStation")
		if g_i18n:hasText(fullViewName) then
			fullViewName = g_i18n:getText(fullViewName)
		end
		self.mapHotspot = g_currentMission.ingameMap:createMapHotspot("fuelStation", fullViewName, nil, getNormalizedUVs({264, 520, 240, 240}), nil, x, z, nil, nil, false, false, false, id, nil, MapHotspot.CATEGORY_DEFAULT);
	end
	
	g_currentMission:addNonUpdateable(self);
	return true;	
end;

function TankTrigger:delete()
	for vehicle,count in pairs(self.vehicles) do
	        if count > 0 then
	            if vehicle.removeFuelFillTrigger ~= nil then
					vehicle:removeFuelFillTrigger(self);
	            end;
	        end;
	    end;
	
	    if self.mapHotspot ~= nil then
	        g_currentMission.ingameMap:deleteMapHotspot(self.mapHotspot);
	    end
	
	    removeTrigger(self.triggerId);
end;

function TankTrigger:onVehicleDeleted(vehicle)
	self.vehicles[vehicle] = nil;
end

function TankTrigger:update()
	
end

function TankTrigger:fillFuel(vehicle, delta)
	delta = math.min(delta, self.Tank.getFillLevel());
	
	if vehicle.setFuelFillLevel ~= nil then
		local oldFillLvl = vehicle.fuelFillLevel;
		vehicle:setFuelFillLevel(oldFillLvl + delta)
		delta = vehicle.fuelFillLevel - oldFillLvl;
	else
		if not vehicle:allowFillType(FillUtil.FILLTYPE_FUEL, false) then
			return 0;
		end;
		local oldFillLvl = vehicle:getFillLevel(FillUtil.FILLTYPE_FUEL);
		vehicle:setFillLevel(oldFillLvl + delta, FillUtil.FILLTYPE_FUEL);
		delta = vehicle:getFillLevel(FillUtil.FILLTYPE_FUEL) - oldFillLvl;
	end;
	
	if delta > 0 then
		self.Tank.setFillLevel(self.Tank.getFillLevel() - delta);
	end;
	return delta;
end;

function TankTrigger:getIsActivatable(vehicle)
	if vehicle.setFuelFillLevel == nil and not vehicle:allowFillType(FillUtil.FILLTYPE_FUEL, false) then
		return false;
	end
	if self.Tank.getFillLevel() <= 0 then
		return false;
	end;
	return true;
end;

function TankTrigger:tankTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (onEnter or onLeave) then
		local vehicle = g_currentMission.nodeToVehicle[otherId];
		if vehicle ~= nil and vehicle.addFuelFillTrigger ~= nil and vehicle.removeFuelFillTrigger ~= nil and vehicle ~= self then
			local count = Utils.getNoNil(self.vehicles[vehicle], 0);

			if onEnter then
				self.vehicles[vehicle] = count+1;
				self.vehicle = vehicle;
				if count == 0 then
					vehicle:addFuelFillTrigger(self);
				end
			else -- onLeave
				self.vehicles[vehicle] = count-1;
				if count == 1 then	                    
					self.vehicles[vehicle] = nil;
					vehicle:removeFuelFillTrigger(self);             
				end
			end;
		end;
	end;
end;


AnimalTrigger = {};
local AnimalTrigger_mt = Class(AnimalTrigger);
--ObjectsIds.OBJECT_ANIMAL_TRIGGER = ObjectIds.objectIdNext;
InitObjectClass(AnimalTrigger, "AnimalTrigger");

function AnimalTrigger:new(isServer, isClient)
	local self = {};
	setmetatable(self, AnimalTrigger_mt);
	self.isServer = isServer;
	self.isClient = isClient;
    return self;
end
function AnimalTrigger:load(id,parent,isInputTrigger, animals, animalsTS, nameF)
	self.nodeId = id;
	self.triggerId = id;
	
	self.animalTypesTS = animalsTS;
	self.animalTypes = animals;
	
	self.header = g_i18n:getText(Utils.getNoNil(getUserAttribute(id, "header"), "ui_farm"))
	self.title = g_i18n:getText(Utils.getNoNil(getUserAttribute(id, "title"), "ui_farm"))
	self.text = g_i18n:getText(Utils.getNoNil(getUserAttribute(id, "text"), "AnimalTrigger_Text"))
	
	addTrigger(id, "triggerCallback", self);
    self.loadingVehicle = nil;
    self.activateText = g_i18n:getText("animals_openAnimalScreen")
	self.isInputTrigger = isInputTrigger;
	self.isActivatableAdded = false;
	
	self.g_animalTriggerScreen = AnimalScreen:new();
	self.g_animalTriggerScreen.isDealer = false;
	self.g_animalTriggerScreen.fabrik = parent;
	self.g_animalTriggerScreen.onListSelectionChanged = Utils.appendedFunction(self.g_animalTriggerScreen.onListSelectionChanged, AnimalTrigger.onListSelectionChanged)	
	self.g_animalTriggerScreen.onOpen = Utils.appendedFunction(self.g_animalTriggerScreen.onOpen, AnimalTrigger.onOpen)	
	self.g_animalTriggerScreen.changeNumAnimals = Utils.appendedFunction(self.g_animalTriggerScreen.changeNumAnimals, AnimalTrigger.changeNumAnimals)	
	self.g_animalTriggerScreen.onCreatePriceBox = Utils.appendedFunction(self.g_animalTriggerScreen.onCreatePriceBox, AnimalTrigger.onCreatePriceBox)	
	local gui_animalTriggerScreen = g_gui:loadGui("dataS/gui/AnimalScreen.xml", "FS_AnimalScreen" .. nameF, self.g_animalTriggerScreen);
	gui_animalTriggerScreen.elements[2].elements[1].elements[2].elements[6].elements[4].text = self.text
	
	self.nameFabrik = nameF;
	self.fabrik = parent;
	
    return self;
end

function AnimalTrigger:delete()
   removeTrigger(self.triggerId);
end

function AnimalTrigger:onCreatePriceBox(element)
	element.elements[1].visible = false;
end;


function AnimalTrigger:changeNumAnimals()
	local v = self.transferData.left.target;
	if v == nil then
		self.transferData.left.target = true;
	end;
	self:updateData();
	self.transferData.left.target = v;
end;

function AnimalTrigger:onOpen()
	local v = self.transferData.left.target;
	if v == nil then
		self.transferData.left.target = true;
	end;
	self:updateData();
	self.transferData.left.target = v;
end;

function AnimalTrigger:onListSelectionChanged(rowIndex)
	if not self.animalItemList.ignoreUpdate then
		local animalDesc = self.currentAnimalList[rowIndex]
		self.transferData.left.numOfAnimals = self.fabrik.getFillLevel(animalDesc.index);
		self.transferData.left.baseNumOfAnimals = self.fabrik.getFillLevel(animalDesc.index);
		self.transferData.left.capacity = self.fabrik.getCapacity(animalDesc.index);
		local v = self.transferData.left.target;
		if v == nil then
			self.transferData.left.target = true;
		end;
		self:updateData();
		self.transferData.left.target = v;
	end;
end;

function AnimalTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if onEnter or onLeave then
		local vehicle = g_currentMission.nodeToVehicle[otherId];
        if vehicle ~= nil and vehicle.allowFillType ~= nil then
            local validFillType = false;
            for num,animalType  in pairs(self.animalTypes) do
                if vehicle:allowFillType(FillUtil.fillTypeNameToInt[self.animalTypes[num].fillType]) then
                    validFillType = true;
                    break;
                end
            end
            if validFillType then
                if onEnter then
                    local isValid = true;
                    local fillType = vehicle:getUnitFillType(vehicle.livestockTrailer.fillUnitIndex);
                    if fillType ~= nil and fillType ~= FillUtil.FILLTYPE_UNKNOWN then
                        isValid = false;
                        for num,animalType in pairs(self.animalTypes) do
							if FillUtil.fillTypeNameToInt[self.animalTypes[num].fillType] == fillType then
                                isValid = true;
                                break;
                            end
                        end
                    end
                    if isValid then
                        self:setLoadingTrailer(vehicle)
						
                    end
                elseif onLeave then
                    if vehicle == self.loadingVehicle then
                        self:setLoadingTrailer(nil)
                    end
                    if vehicle == self.activatedTarget then
                        g_animalScreen:onVehicleLeftTrigger()
                        self.objectActivated = false
                    end
                end
            end
        end
    end
end

function AnimalTrigger:updateActivatableObject()
    if self.loadingVehicle ~= nil then
        if not self.isActivatableAdded then
            self.isActivatableAdded = true
            g_currentMission:addActivatableObject(self);
        end
    else
        if self.isActivatableAdded and self.loadingVehicle == nil then
            g_currentMission:removeActivatableObject(self);
            self.isActivatableAdded = false
            self.objectActivated = false;
        end
    end
end

function AnimalTrigger:setLoadingTrailer(loadingVehicle)
    if self.loadingVehicle ~= nil then
        self.loadingVehicle.animalTrigger = nil
    end
    self.loadingVehicle = loadingVehicle
    if self.loadingVehicle ~= nil then
        self.loadingVehicle.animalTrigger = self
    end
    self:updateActivatableObject()
end

function AnimalTrigger:getIsActivatable(vehicle)
    if g_gui.currentGui == nil then
        local rootAttacherVehicle = nil
        if self.loadingVehicle ~= nil then
            rootAttacherVehicle = self.loadingVehicle:getRootAttacherVehicle();
        end
        return rootAttacherVehicle == g_currentMission.controlledVehicle
    end
    return false;
end

function AnimalTrigger:drawActivate()
end

function AnimalTrigger:onActivateObject()
    g_currentMission:addActivatableObject(self);
    self.objectActivated = true;
    self.activatedTarget = self.loadingVehicle;
	
	self.g_animalTriggerScreen:setData(false, self.title, self.animalTypesTS, self.loadingVehicle)
	self.g_animalTriggerScreen.boxHeaderText:setText(self.title)
	self.g_animalTriggerScreen.title:setText(self.header)
	self.g_animalTriggerScreen:setCallback(self.loadAnimals, self);
    g_gui:showGui("FS_AnimalScreen" .. self.nameFabrik);
end

function AnimalTrigger:loadAnimals(target, animalType, numAnimalsDiff, price)
    self.activatedTarget = nil
    self.objectActivated = false

    if not self.isServer then
        g_client:getServerConnection():sendEvent(AnimalTriggerEvent:new(self.fabrik.Parent, target, animalType, numAnimalsDiff, price));
    else
        self:doAnimalLoading(target, animalType, numAnimalsDiff, price);
    end
end

function AnimalTrigger:doAnimalLoading(target, animalType, numAnimalsDiff, price, userId)
	
	if not self.isServer then
        return;
    end
	local animalDesc = AnimalUtil.animalIndexToDesc[animalType]
	local num = math.abs(numAnimalsDiff);
		
	if numAnimalsDiff < 0 then --abladen
		self.fabrik.setFillLevel(self.fabrik.getFillLevel(animalType) - numAnimalsDiff,animalType)
	elseif numAnimalsDiff > 0 then --aufladen
		self.fabrik.setFillLevel(self.fabrik.getFillLevel(animalType) - numAnimalsDiff,animalType)
	end;
	
	
	target:setUnitFillLevel(target.livestockTrailer.fillUnitIndex, target:getUnitFillLevel(target.livestockTrailer.fillUnitIndex) + numAnimalsDiff, animalDesc.fillType)
	
	self.g_animalTriggerScreen:onClose();
end

AnimalTriggerEvent = {};
AnimalTriggerEvent_mt = Class(AnimalTriggerEvent, Event);

InitEventClass(AnimalTriggerEvent, "AnimalTriggerEvent");

function AnimalTriggerEvent:emptyNew()
    local self = Event:new(AnimalTriggerEvent_mt);
    return self;
end;

function AnimalTriggerEvent:new(trigger, target, animalType, numAnimalsDiff, price)
    local self = AnimalTriggerEvent:emptyNew()
    self.trigger = trigger;
    self.target = target;
    self.animalType = animalType;
    self.numAnimalsDiff = numAnimalsDiff;
    self.price = price;
    return self;
end;

function AnimalTriggerEvent:readStream(streamId, connection)
    self.trigger = readNetworkNodeObject(streamId);
    self.target = readNetworkNodeObject(streamId);
    self.animalType = streamReadUIntN( streamId, AnimalUtil.sendNumBits );
    self.numAnimalsDiff = streamReadInt32(streamId);
    self.price = streamReadFloat32(streamId);
    self:run(connection);
end;

function AnimalTriggerEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.trigger);
    writeNetworkNodeObject(streamId, self.target);
    streamWriteUIntN(streamId, self.animalType, AnimalUtil.sendNumBits);
    streamWriteInt32(streamId, self.numAnimalsDiff);
    streamWriteFloat32(streamId, self.price);
end;

function AnimalTriggerEvent:run(connection)
    if not connection:getIsServer() then
        self.trigger:doAnimalLoading(self.target, self.animalType, self.numAnimalsDiff, self.price);
    end;
end;

MoneyActivated = {};
local MoneyActivated_mt = Class(MoneyActivated);

function MoneyActivated:new(func, nameDialog, header, buttonR, onPasswordEntered)
	local self = {};
	setmetatable(self, MoneyActivated_mt);
	self.getActive = func;
	self.activateText = g_i18n:hasText("mCompanyFactory_AddOn_moneyInput") and g_i18n:getText("mCompanyFactory_AddOn_moneyInput") or "Geld einzahlen";
	self.nameDialog = nameDialog;
	self.header = header;
	self.buttonR = buttonR;
	self.onPasswordEntered = onPasswordEntered;
	self.passwordDialog = PasswordDialog:new();
	self.gui_PasswordDialog = g_gui:loadGui("dataS/gui/dialogs/PasswordDialog.xml", self.nameDialog, self.passwordDialog);
	FocusManager:setGui("MPLoadingScreen");
    return self;
end;

function MoneyActivated:getIsActivatable()
	if self.getActive() then
		return true;
	end;
	return false;
end;

function MoneyActivated:drawActivate() end;

function MoneyActivated:onActivateObject()
	g_currentMission:addActivatableObject(self)
	self.passwordDialog:setCallback(self.onPasswordEntered)
	self.gui_PasswordDialog.elements[2].elements[1].elements[1].text = self.header;
	self.gui_PasswordDialog.elements[2].elements[1].elements[3].elements[2].text = self.buttonR;
	self.passwordDialog.passwordElement:setText("");
    g_gui:showDialog(self.nameDialog);
	--g_gui:showPasswordDialog({callback=self.onPasswordEntered})
end;

MoneyActivatedEvent = {};
MoneyActivatedEvent_mt = Class(MoneyActivatedEvent, Event);

InitEventClass(MoneyActivatedEvent, "MoneyActivatedEvent");

function MoneyActivatedEvent:emptyNew()
    local self = Event:new(MoneyActivatedEvent_mt);
    return self;
end;

function MoneyActivatedEvent:new(price, fabrik, input)
    local self = MoneyActivatedEvent:emptyNew()
    self.price = price;
	self.fabrik = fabrik;
	self.input = input;
    return self;
end;

function MoneyActivatedEvent:readStream(streamId, connection)
    self.price = streamReadFloat32(streamId);
	self.fabrik = readNetworkNodeObject(streamId);
	self.input = streamReadString(streamId);
    self:run(connection);
end;

function MoneyActivatedEvent:writeStream(streamId, connection)
    streamWriteFloat32(streamId, self.price);
	writeNetworkNodeObject(streamId, self.fabrik)
	streamWriteString(streamId, self.input);
end;

function MoneyActivatedEvent:run(connection)
    g_currentMission:addSharedMoney(-self.price, "other")
	self.fabrik:setFillLevel(self.fabrik.Rohstoffe[self.input], self.fabrik.Rohstoffe[self.input].fillLevel + self.price);
end;




