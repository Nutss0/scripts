-- 
-- FarmSiloSystem 
-- 
-- @Interface: 1.4.4.0 1.4.4RC8
-- @Author: kevink98 
-- @Date: 09.08.2017
-- @Version: 1.1.0a edit by Mach1--Andy
-- 
-- @Support: http://ls-modcompany.com
-- @mCompanyInfo: http://mcompany-info.de/
-- 

--[[
	## V1.0.0:
			- Release
	## V1.0.1:
			- Fix: Error with AdditionalTriggers.lua
	## V1.0.2:
			- Fix: Problem with Courseplay
	## V1.1.0:
			- Fix: Problem with SiloTrigger
			- Add: Texturchange at unloading
			- Add: You can't unload any more, when the door is closed
	## V1.1.0a:
			- Add: drywheat and pigFood
]]--
 
local DebugEbene = 0;
local function Debug(e,s,...) if e <= DebugEbene then print("FarmSiloSystem v1.1.0"..": "..string.format(s,...)); end;end;
local function get_i18n(name) return g_i18n:hasText(name) and g_i18n:getText(name) or name; end

FarmSiloSystem = {};
ModDir = g_currentModDirectory
FarmSiloSystem_mt = nil

local nBeginn, nEnde = string.find(ModDir,"placeable");
if nBeginn then
	FarmSiloSystem_mt = Class(FarmSiloSystem, Placeable);
else
	FarmSiloSystem.RunAsGE = true;
	FarmSiloSystem_mt = Class(FarmSiloSystem, Object);
end

InitObjectClass(FarmSiloSystem, "FarmSiloSystem");

function FarmSiloSystem.onCreate(id)
	local object = FarmSiloSystem:new(g_server ~= nil, g_client ~= nil)
	g_currentMission:addOnCreateLoadedObject(object);
	if object:load(id) then
		g_currentMission:addOnCreateLoadedObjectToSave(object);
        object:register(true);
		Debug(1,"FarmSiloSystem.onCreate(%d) load %s",id,getName(id));
    else
        object:delete();
    end;
		
end;

function FarmSiloSystem:new(isServer, isClient, customMt)
  
	local mt = customMt;
    if mt == nil then
          mt = FarmSiloSystem_mt;
    end;
  
	local self = {};
	if FarmSiloSystem.RunAsGE then
		self = Object:new(isServer, isClient, mt)
	else
		self = Placeable:new(isServer, isClient, mt);
		registerObjectClassName(self, "FarmSiloSystem");
	end;
	
	return self;
end;
 
function FarmSiloSystem:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)

	if FarmSiloSystem.RunAsGE then
		self.saveId = getUserAttribute(xmlFilename,"saveId");
		if self.saveId == nil then
			self.saveId = "FarmSiloSystem_"..getName(xmlFilename)
		end
	end;
	
	self.nodeId = xmlFilename;
	
	self.isActiveMove = false;
	self.isActiveForFilling = false;
	
	self.isSiloTriggerReady = false;
	self.isFillingActive = false;
	self.isMovingRohr = false;
	self.isMovingSiloTrigger = false;
	self.blinkTimer = 0;
	self.toSendMove = false;
	
	self.sendEvent = true;
	
	if not self.RunAsGE then
		if not FarmSiloSystem:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
			return false;
		end;
		return true;
	else
		self.nodeId = xmlFilename;
		if not self:finalizePlacement() then return false; end;
	end;
	
	return true;
end;

function FarmSiloSystem:finalizePlacement(x, y, z, rx, ry, rz, initRandom)
	
	if not self.RunAsGE then
		FarmSiloSystem:superClass().finalizePlacement(self)
	end
	
	if g_currentMission.numFarmSiloSystemsMod == nil then
		g_currentMission.numFarmSiloSystemsMod = 1;
	else
		g_currentMission.numFarmSiloSystemsMod = g_currentMission.numFarmSiloSystemsMod + 1;
	end;
	
	self.capacity = Utils.getNoNil(getUserAttribute(self.nodeId, "capacity"),200000);
	
	--wheat rape barley maize sunflower soybean
	self.fillTypes = Utils.splitString(" ", getUserAttribute(self.nodeId, "fillTypes"));
	if self.fillTypes == nil then
		Debug(0,true,"fillTypes are nil in %s",getName(self.nodeId));
		return false
	end;
	self.fillLvls = {};
	self.synchObject = {};
	self.synchObjectEvent = {};
	
	self.stationName = Utils.getNoNil(get_i18n(getUserAttribute(self.nodeId,"stationName")),get_i18n(getName(self.nodeId)))
	
	local addNumberToName = getUserAttribute(self.nodeId,"addNumberToName");
	if addNumberToName then
		self.stationName = self.stationName.." "..tostring(g_currentMission.numFarmSiloSystemsMod);
	end;
	
	local InputIndex = getUserAttribute(self.nodeId, "inputIndex");
	local OutputIndex = getUserAttribute(self.nodeId, "outputIndex");
	local DisplayIndex = getUserAttribute(self.nodeId, "displayIndex");
	local SwitcherIndex = getUserAttribute(self.nodeId, "switcherIndex");
	local LightIndex = getUserAttribute(self.nodeId, "lightIndex");
	local SoundIndex = getUserAttribute(self.nodeId, "soundIndex");
	local PlayerIndex = getUserAttribute(self.nodeId, "playerTriggerIndex");
	local DoorIndex = getUserAttribute(self.nodeId,"doorIndex");
	
	local InputId = Utils.indexToObject(self.nodeId,InputIndex);
	local OutputId = Utils.indexToObject(self.nodeId,OutputIndex);
	local DisplayId = Utils.indexToObject(self.nodeId,DisplayIndex);
	local SwitcherId = Utils.indexToObject(self.nodeId,SwitcherIndex);
	local LightId = Utils.indexToObject(self.nodeId,LightIndex);
	local SoundId = Utils.indexToObject(self.nodeId,SoundIndex);
	local PlayerTriggerId = Utils.indexToObject(self.nodeId,PlayerIndex);
	local DoorTriggerId = Utils.indexToObject(self.nodeId,DoorIndex);
	
	if InputId and InputId ~= 0 then
		local TipTriggerId = getChild(InputId,"TipTrigger")
		self.InputTrigger = TipTrigger:new(self.isServer,self.isClient)
		local allowedToolTypes = {TipTrigger.TOOL_TYPE_TRAILER, TipTrigger.TOOL_TYPE_SHOVEL, TipTrigger.TOOL_TYPE_PIPE};
		if self.InputTrigger:load(TipTriggerId) then
			self.InputTrigger:register(true);
			for k, Str in pairs(self.fillTypes) do
				local typ = FillUtil.fillTypeNameToInt[Str]
				if typ ~= nil then
					self.fillLvls[typ] = 0;
					self.InputTrigger:addAcceptedFillType(typ,0,false,true,allowedToolTypes)
				end;
			end;
			self.InputTrigger.nodeId = TipTriggerId;
			self.InputTrigger.addFillLevelFromTool = function (...) return self:addFillLevelFromTool(...) end;
			self.InputTrigger.name = getName(self.nodeId);
			self.InputTrigger.TipTriggerCallback = function(...) return self:TipTriggerCallback(...) end;
			removeTrigger(self.InputTrigger.triggerId);
			addTrigger(self.InputTrigger.triggerId , "TipTriggerCallback", self);
		end;
		
		self.inputMove = {};
		self.inputMove.movingId = Utils.indexToObject(InputId,getUserAttribute(InputId,"movingIndex"));
		self.inputMove.movingId2 = Utils.indexToObject(InputId,getUserAttribute(InputId,"movingIndex"));
		if self.inputMove.movingId ~= nil then
			self.inputMove.minY = getUserAttribute(InputId,"moveMin");
			self.inputMove.maxY = getUserAttribute(InputId,"moveMax");
			if self.inputMove.movingId ~= nil and self.inputMove.minY ~= nil and self.inputMove.maxY ~= nil then
				self.inputMove.isActive = true;
				self.inputMove.isMoving = false;
				self.inputMove.isTipFinish = false;
				local x,_,z = getTranslation(self.inputMove.movingId)
				setTranslation(self.inputMove.movingId,x,self.inputMove.minY,z);
				self.inputMove.movingScaleInput = 0.002;
				self.inputMove.movingScaleOutput = 0.00005;
			end;
		end;
		
	end;
	
	if OutputId and OutputId ~= 0 then
		local id = Utils.indexToObject(OutputId,getUserAttribute(OutputId,"triggerIndex"))
		self.OutputSiloTrigger = {};
		if id and id ~= 0 then
			local S_TriggerFunktionen = {}
			S_TriggerFunktionen.getFillLevel = function(...) return self:getFillLevel(...) end;
			S_TriggerFunktionen.setFillLevel = function(...) return self:setFillLevel(...) end;
			S_TriggerFunktionen.getCapacity = function(...) return self:getCapacity(...) end;
			S_TriggerFunktionen.getAllFillLvl = function(...) return self:getAllFillLvl(...) end;
			S_TriggerFunktionen.getPlayerInRange = function(...) return self:getPlayerInRange(...) end;
			S_TriggerFunktionen.getStationName = function(...) return self:getStationName(...) end;
			S_TriggerFunktionen.setFillingSilo = function (...) return self:setFillingSilo(...) end;
			S_TriggerFunktionen.Parent = self;
			local Trigger = SiloTriggerFarmSiloSystem:new(g_server ~= nil, g_client ~= nil)
			Trigger:load(id,S_TriggerFunktionen)
			self.OutputSiloTrigger.id = id;
			self.OutputSiloTrigger.Trigger = Trigger;
			self.OutputSiloTrigger.Trigger.fillTypes = self.fillTypes;
			self.OutputSiloTrigger.Trigger.isPlayerInRange = false;
			Debug(3,"Input add SiloTrigger %d",id);
		else
			return false
		end;
		local x,_,z = getTranslation(self.OutputSiloTrigger.id);
		setTranslation(self.OutputSiloTrigger.id,x,-1,z);
		self.OutputRohr = Utils.indexToObject(OutputId,getUserAttribute(OutputId,"rotateIndex"))
		setRotation(self.OutputRohr,0,math.rad(90),0);		
	end;
	
	if DisplayId and DisplayId ~= 0 then
		self.Display = {};
		self.Display.offId = Utils.indexToObject(DisplayId,getUserAttribute(DisplayId,"offIndex"));
		self.Display.onId = Utils.indexToObject(DisplayId,getUserAttribute(DisplayId,"onIndex"));
		setVisibility(self.Display.offId,getUserAttribute(self.Display.offId,"default"));
		setVisibility(self.Display.onId,getUserAttribute(self.Display.onId,"default"));	
		
		self.Indicator = {};
		local fillLvls = getChild(DisplayId,"Anzeige");
		local num = getNumOfChildren(fillLvls);
		self.Indicator.Display = {};
		for i=1,num do
			local name = getName(getChildAt(fillLvls,i-1));
			local typInt = FillUtil.fillTypeNameToInt[name]
			local desc = FillUtil.fillTypeNameToDesc[name]
			if self.fillLvls[typInt] ~= nil then
				self.Indicator.Display[typInt] = {};
				self.Indicator.Display[typInt].node = getChildAt(fillLvls,i-1);
				Utils.setNumberShaderByValue(self.Indicator.Display[typInt].node, math.floor(self.fillLvls[typInt]), 0, true)
				setVisibility(self.Indicator.Display[typInt].node,false)
			end;
		end;
		
	end;	

	if SwitcherId and SwitcherId ~= 0 then
		self.switcher = {};
		self.switcher.first = {};
		self.switcher.second = {};
		self.switcher.first.id = Utils.indexToObject(SwitcherId,getUserAttribute(SwitcherId,"onOffIndex"));
		self.switcher.second.id = Utils.indexToObject(SwitcherId,getUserAttribute(SwitcherId,"fillIndex"));
		setRotation(self.switcher.first.id,0,0,0);
		setRotation(self.switcher.second.id,-70,0,0);
	end;	

	if LightId and LightId ~= 0 then
		self.light = {};
		self.light.first = {};
		self.light.second = {};
		self.light.first.idTG = Utils.indexToObject(LightId,getUserAttribute(LightId,"onOffIndex"));
		self.light.second.idTG = Utils.indexToObject(LightId,getUserAttribute(LightId,"fillIndex"));
		
		self.light.first.green = Utils.indexToObject(self.light.first.idTG,getUserAttribute(self.light.first.idTG,"greenIndex"))
		self.light.first.red = Utils.indexToObject(self.light.first.idTG,getUserAttribute(self.light.first.idTG,"redIndex"))
		self.light.second.green = Utils.indexToObject(self.light.second.idTG,getUserAttribute(self.light.second.idTG,"greenIndex"))
		self.light.second.red = Utils.indexToObject(self.light.second.idTG,getUserAttribute(self.light.second.idTG,"redIndex"))
		setVisibility(self.light.first.green,false)
		setVisibility(self.light.first.red,false)
		setVisibility(self.light.second.green,false)
		setVisibility(self.light.second.red,false)
	end;
	
	if SoundId and SoundId ~= 0 then
		self.sound = {};
		
		local num = getNumOfChildren(SoundId)
		for i=1,num do
			local sound = getChildAt(SoundId,i-1);
			self.sound[i] = sound;
			setVisibility(self.sound[i],false);			
		end;
	end;
	
	if PlayerTriggerId and PlayerTriggerId ~= 0 then
		self.playerTrigger = PlayerTriggerId;
		addTrigger(self.playerTrigger,"PlayerTriggerCallback",self);
	end;
	
	if DoorTriggerId and DoorTriggerId ~= 0 then
		local scale = Utils.getNoNil(getUserAttribute(DoorTriggerId,"scale"),0.015);
		self.dor = {};
		self.dor.state = false;
		self.dormoving = false;
		self.dor.right = {};
		self.dor.right.node = getChildAt(DoorTriggerId,0);
		self.dor.right.moveTo = getUserAttribute(DoorTriggerId,"moveZ")
		self.dor.right.scale = scale;
		self.dor.left = {};
		self.dor.left.node = getChildAt(DoorTriggerId,1);
		self.dor.left.moveTo = (getUserAttribute(DoorTriggerId,"moveZ"))*-1;
		self.dor.left.scale = scale * -1;
		self.dor.doorTrigger = Utils.indexToObject(DoorTriggerId,getUserAttribute(DoorTriggerId,"triggerIndex"));
		addTrigger(self.dor.doorTrigger,"DoorTriggerCallback",self);
		
		self.dor.audio = Utils.indexToObject(DoorTriggerId,getUserAttribute(DoorTriggerId,"audioIndex"))
		setVisibility(self.dor.audio,false);
	end;
	
	self.materials = {};
	self.materials[FillUtil.fillTypeNameToInt["wheat"]] = getMaterial(self.inputMove.movingId2, 0);
	self.materials[FillUtil.fillTypeNameToInt["barley"]] = getMaterial(self.inputMove.movingId2, 1);
	self.materials[FillUtil.fillTypeNameToInt["rape"]] = getMaterial(self.inputMove.movingId2, 2);
	self.materials[FillUtil.fillTypeNameToInt["sunflower"]] = getMaterial(self.inputMove.movingId2, 4);
	self.materials[FillUtil.fillTypeNameToInt["soybean"]] = getMaterial(self.inputMove.movingId2, 5);
	self.materials[FillUtil.fillTypeNameToInt["maize"]] = getMaterial(self.inputMove.movingId2, 3);
	self.materials[FillUtil.fillTypeNameToInt["drywheat"]] = getMaterial(self.inputMove.movingId2, 6);
	self.materials[FillUtil.fillTypeNameToInt["pigFood"]] = getMaterial(self.inputMove.movingId2, 7);
		
	if self.RunAsGE then
		g_currentMission:addNodeObject(self.nodeId, self)
	end;
	
	self.FarmSiloSystemDirtyFlag = self:getNextDirtyFlag();
	
	return true;
end;

function FarmSiloSystem:getSaveAttributesAndNodes(nodeIdent)
	
	local attributes, nodes = "","";
			
	if not self.RunAsGE then
		attributes, nodes = FarmSiloSystem:superClass().getSaveAttributesAndNodes(self, nodeIdent);
	end;
	
	for k,v in pairs(self.fillLvls) do
		if 0 < nodes.len(nodes) then
			nodes = nodes .. "\n";
		end;
		nodes = nodes..nodeIdent..'<FillLevel fillType="'..k..'" Lvl="'..v..'"/>'
	end;
	  
    return attributes,nodes;
end

function FarmSiloSystem:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	
	if not self.RunAsGE and not FarmSiloSystem:superClass().loadFromAttributesAndNodes(self, xmlFile, key, resetVehicles) then
		return false
	end
	
	local i = 0;
	while true do
		local key = key..string.format(".FillLevel(%d)",i);
		if not hasXMLProperty(xmlFile,key) then
			break;
		end;
		
		local fillType = getXMLInt(xmlFile, key.."#fillType");
		local lvl = getXMLInt(xmlFile,key.."#Lvl");
		
		self:setFillLevel(fillType,lvl);
		self.updateDisplay = true;		
		i = i + 1;
	end;
	
	return true;
end
	
function FarmSiloSystem:writeStream(streamId, connection)
	FarmSiloSystem:superClass().writeStream(self, streamId, connection)
	
	self:getSynchObject();
		
	streamWriteBool(streamId, self.synchObject.isActiveMove);
	streamWriteBool(streamId, self.synchObject.isActiveForFilling);
	streamWriteBool(streamId, self.synchObject.isSiloTriggerReady);
	streamWriteBool(streamId, self.synchObject.isFillingActive);
	streamWriteBool(streamId, self.synchObject.isMovingRohr);
	streamWriteBool(streamId, self.synchObject.isMovingSiloTrigger);
	streamWriteBool(streamId, self.synchObject.dormoving);
	
	streamWriteFloat32(streamId, self.synchObject.inputMovePosX);
	streamWriteFloat32(streamId, self.synchObject.inputMovePosY);
	streamWriteFloat32(streamId, self.synchObject.inputMovePosZ);
	streamWriteFloat32(streamId, self.synchObject.outputSiloTriggerPosX);
	streamWriteFloat32(streamId, self.synchObject.outputSiloTriggerPosY);
	streamWriteFloat32(streamId, self.synchObject.outputSiloTriggerPosZ);
	streamWriteFloat32(streamId, self.synchObject.outputRohrPosX);
	streamWriteFloat32(streamId, self.synchObject.outputRohrPosY);
	streamWriteFloat32(streamId, self.synchObject.outputRohrPosZ);
	
	streamWriteBool(streamId, self.synchObject.offIdVis);
	streamWriteBool(streamId, self.synchObject.onIdVis);	
	
	streamWriteFloat32(streamId, self.synchObject.switcher_first_rotX);
	streamWriteFloat32(streamId, self.synchObject.switcher_first_rotY);
	streamWriteFloat32(streamId, self.synchObject.switcher_first_rotZ);
	streamWriteFloat32(streamId, self.synchObject.switcher_second_rotX);
	streamWriteFloat32(streamId, self.synchObject.switcher_second_rotY);
	streamWriteFloat32(streamId, self.synchObject.switcher_second_rotZ);
	
	local num = table.getn(self.synchObject.sounds);
	streamWriteInt8(streamId, num);
	for i=1, num do
		streamWriteBool(streamId, self.synchObject.sounds[i]);
	end;
	
	streamWriteFloat32(streamId, self.synchObject.door_right_rotX);
	streamWriteFloat32(streamId, self.synchObject.door_right_rotY);
	streamWriteFloat32(streamId, self.synchObject.door_right_rotZ);
	streamWriteFloat32(streamId, self.synchObject.door_left_rotX);
	streamWriteFloat32(streamId, self.synchObject.door_left_rotY);
	streamWriteFloat32(streamId, self.synchObject.door_left_rotZ);
	
	local y = 0;
	_,y,_ = getTranslation(self.inputMove.movingId)
	streamWriteFloat32(streamId,y)
	
	for typ, lvl in pairs(self.fillLvls) do
		streamWriteInt8(streamId,typ);
		streamWriteFloat32(streamId,lvl);
	end;
end
function FarmSiloSystem:readStream(streamId, connection)
	FarmSiloSystem:superClass().readStream(self, streamId, connection)

	local data = {};
	
	data.isActiveMove = streamReadBool(streamId);
	data.isActiveForFilling = streamReadBool(streamId);
	data.isSiloTriggerReady = streamReadBool(streamId);
	data.isFillingActive = streamReadBool(streamId);
	data.isMovingRohr = streamReadBool(streamId);
	data.isMovingSiloTrigger = streamReadBool(streamId);
	data.dormoving = streamReadBool(streamId);
	
	data.inputMovePosX = streamReadFloat32(streamId);
	data.inputMovePosY = streamReadFloat32(streamId);
	data.inputMovePosZ = streamReadFloat32(streamId);
	
	data.outputSiloTriggerPosX = streamReadFloat32(streamId);
	data.outputSiloTriggerPosY = streamReadFloat32(streamId);
	data.outputSiloTriggerPosZ = streamReadFloat32(streamId);
	
	data.outputRohrPosX = streamReadFloat32(streamId);
	data.outputRohrPosY = streamReadFloat32(streamId);
	data.outputRohrPosZ = streamReadFloat32(streamId);
	
	data.offIdVis = streamReadBool(streamId);
	data.onIdVis = streamReadBool(streamId);
	
	data.numVis = data.onIdVis;
	
	data.switcher_first_rotX = streamReadFloat32(streamId);
	data.switcher_first_rotY = streamReadFloat32(streamId);
	data.switcher_first_rotZ = streamReadFloat32(streamId);
	data.switcher_second_rotX = streamReadFloat32(streamId);
	data.switcher_second_rotY = streamReadFloat32(streamId);
	data.switcher_second_rotZ = streamReadFloat32(streamId);
	
	data.sounds = {};
	local num = streamReadInt8(streamId);
	for i=1, num do
		local vis = streamReadBool(streamId);
		data.sounds[i] = vis	
	end;
	
	data.door_right_rotX = streamReadFloat32(streamId);
	data.door_right_rotY = streamReadFloat32(streamId);
	data.door_right_rotZ = streamReadFloat32(streamId);
	data.door_left_rotX = streamReadFloat32(streamId);
	data.door_left_rotY = streamReadFloat32(streamId);
	data.door_left_rotZ = streamReadFloat32(streamId);	
	
	self:setMP(data);
	
	_,y,_ = getTranslation(self.inputMove.movingId)
	streamReadFloat32(streamId,y)
	
	for _,_ in pairs(self.fillLvls) do
		local typ = streamReadInt8(streamId);
		local lvl = streamReadFloat32(streamId);
		self.fillLvls[typ] = lvl;
	end;
	self.updateDisplay = true;
end;

function FarmSiloSystem:writeUpdateStream(streamId, connection, dirtyMask)
	FarmSiloSystem:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	
	_,y,_ = getTranslation(self.inputMove.movingId)
	streamWriteFloat32(streamId,y)
	
	for typ, lvl in pairs(self.fillLvls) do
		streamWriteInt8(streamId,typ);
		streamWriteInt32(streamId,lvl);
	end;
end;
function FarmSiloSystem:readUpdateStream(streamId, timestamp, connection)
	FarmSiloSystem:superClass().readUpdateStream(self, streamId, timestamp, connection);
	
	local y = streamReadFloat32(streamId);
	local x,_,z = getTranslation(self.inputMove.movingId)
	setTranslation(self.inputMove.movingId,x,y,z);
	
	for _,_ in pairs(self.fillLvls) do
		local typ = streamReadInt8(streamId);
		local lvl = streamReadInt32(streamId);
		self.fillLvls[typ] = lvl;
	end;
	self.updateDisplay = true;
end;

function FarmSiloSystem:setMPEvent(object)
	
	self.isActiveMove = object.isActiveMove;
	self.isActiveForFilling = object.isActiveForFilling;
	self.isSiloTriggerReady = object.isSiloTriggerReady;
	self.isFillingActive = object.isFillingActive;
	self.isMovingRohr = object.isMovingRohr;
	self.isMovingSiloTrigger = object.isMovingSiloTrigger;
	self.dormoving = object.dormoving;
	self.dormovingState = object.dormovingState;
		
end;

function FarmSiloSystem:setMP(object,noEventSend)
	
	self.isActiveMove = object.isActiveMove;
	self.isActiveForFilling = object.isActiveForFilling;
	self.isSiloTriggerReady = object.isSiloTriggerReady;
	self.isFillingActive = object.isFillingActive;
	self.isMovingRohr = object.isMovingRohr;
	self.isMovingSiloTrigger = object.isMovingSiloTrigger;
	self.dormoving = object.dormoving;
	
	setTranslation(self.inputMove.movingId,object.inputMovePosX,object.inputMovePosY,object.inputMovePosZ)
	
	setRotation(self.OutputSiloTrigger.id,object.outputSiloTriggerPosX,object.outputSiloTriggerPosY,object.outputSiloTriggerPosZ);
	setRotation(self.OutputRohr,object.outputRohrPosX,object.outputRohrPosY,object.outputRohrPosZ)
	
	setVisibility(self.Display.offId,object.offIdVis)
	setVisibility(self.Display.onId,object.onIdVis)
	
	for k,_ in pairs(self.Indicator.Display) do
		setVisibility(self.Indicator.Display[k].node,object.numVis);
	end;
	
	setRotation(self.switcher.first.id,object.switcher_first_rotX,object.switcher_first_rotY,object.switcher_first_rotZ)
	setRotation(self.switcher.second.id,object.switcher_second_rotX,object.switcher_second_rotY,object.switcher_second_rotZ)
		
	for i,vis in pairs(object.sounds) do
		setVisibility(self.sound[i],vis);			
	end;
	
	setRotation(self.dor.right.node,object.door_right_rotX,object.door_right_rotY,object.door_right_rotZ)
	setRotation(self.dor.left.node,object.door_left_rotX,object.door_left_rotY,object.door_left_rotZ)
	
end;

function FarmSiloSystem:toMoveRohrOn()
	if self.sendEvent then
		self.sendEvent = false;
		self:getObjectToSynch();
		FarmSiloSystemEvent:sendEvent(self);
	end;
	
	local _,y,_ = getRotation(self.OutputRohr);
	y = math.min(y-0.01,0+y);			
	setRotation(self.OutputRohr,0,y,0)
	if y <= 0 then
		setRotation(self.OutputRohr,0,0,0)
		self.isMovingRohr = false;
		self.isMovingSiloTrigger = true;
	end;
	
	local _,y,z = getRotation(self.switcher.first.id);
	setRotation(self.switcher.first.id,math.rad(-90),y,z);
	for k,sound in pairs(self.sound) do
		if not getVisibility(sound) then
			setVisibility(sound,true);
		end;
	end;
	for typInt,_ in pairs(self.Indicator.Display) do
		setVisibility(self.Indicator.Display[typInt].node,true)
	end;
	setVisibility(self.Display.offId,false)
	setVisibility(self.Display.onId,true)
	setVisibility(self.light.second.red,true)
	setVisibility(self.light.second.green,false)
	self.toSendMove = true;
end;

function FarmSiloSystem:toMoveTriggerOn()
	local x,_,z = getTranslation(self.OutputSiloTrigger.id);
	setTranslation(self.OutputSiloTrigger.id,x,5.2,z);
	self.isMovingSiloTrigger = false;
	self.isActiveMove = false;
	self.isActiveForFilling = true;
	setVisibility(self.light.second.red,false)
	setVisibility(self.light.second.green,true)
	self.toSendMove = true;
		self.sendEvent = true;
end;

function FarmSiloSystem:toMoveRohrOff()
	if self.sendEvent then
		self.sendEvent = false;
		self:getObjectToSynch();
		FarmSiloSystemEvent:sendEvent(self);
	end;

	local _,y,_ = getRotation(self.OutputRohr);
	y = math.min(y+0.01,90-y)
	setRotation(self.OutputRohr,0,y,0)
	if math.deg(y) >= 90 then
		setRotation(self.OutputRohr,0,math.rad(90),0)
		self.isMovingRohr = false;
		self.isMovingSiloTrigger = true;
		setVisibility(self.light.second.red,true)
		setVisibility(self.light.second.green,false)
		self.sendEvent = true;
	end;
	local _,y,z = getRotation(self.switcher.first.id);
	setRotation(self.switcher.first.id,math.rad(0),y,z);
	for typInt,_ in pairs(self.Indicator.Display) do
		setVisibility(self.Indicator.Display[typInt].node,false)
	end;
	setVisibility(self.Display.offId,true)
	setVisibility(self.Display.onId,false)
	setVisibility(self.light.second.red,false)
	setVisibility(self.light.second.green,false)
	self.toSendMove = true;
end;

function FarmSiloSystem:toMoveTriggerOff()
	local x,y,z = getTranslation(self.OutputSiloTrigger.id);
	setTranslation(self.OutputSiloTrigger.id,x,-1,z);
	self.isMovingSiloTrigger = false;
	self.isActiveMove = false;
	self.isActiveForFilling = false;
	for k,sound in pairs(self.sound) do
		setVisibility(sound,false);
	end;
	self.toSendMove = true;
	self.sendEvent = true;
end;

function FarmSiloSystem:doorOn()
	if self.sendEvent then
		self.sendEvent = false;
		self:getObjectToSynch();
		FarmSiloSystemEvent:sendEvent(self);
	end;

	local xR,yR,zR = getRotation(self.dor.right.node);
	local xL,yL,zL = getRotation(self.dor.left.node);
	setVisibility(self.dor.audio,true);
	local deltaR = zR+self.dor.right.scale;
	local deltaL = zL+self.dor.left.scale;
	setRotation(self.dor.right.node,xR,yR,deltaR);
	setRotation(self.dor.left.node,xL,yL,deltaL);
	
	if math.deg(deltaR) >= self.dor.right.moveTo then
		setRotation(self.dor.right.node,xR,yR,math.rad(self.dor.right.moveTo));
		setRotation(self.dor.left.node,xL,yL,math.rad(self.dor.left.moveTo));
		self.dor.state = true;
		self.dormoving = false;
		setVisibility(self.dor.audio,false);
		self.sendEvent = true;
	end;
	self.toSendMove = true;
end;

function FarmSiloSystem:doorOff()
	if self.sendEvent then
		self.sendEvent = false;
		self:getObjectToSynch();
		FarmSiloSystemEvent:sendEvent(self);
	end;

	local xR,yR,zR = getRotation(self.dor.right.node);
	local xL,yL,zL = getRotation(self.dor.left.node);
	setVisibility(self.dor.audio,true);	
	local deltaR = zR-self.dor.right.scale;
	local deltaL = zL-self.dor.left.scale;
	setRotation(self.dor.right.node,xR,yR,deltaR);
	setRotation(self.dor.left.node,xL,yL,deltaL);
	if math.deg(deltaR) <= 0 then
		setRotation(self.dor.right.node,xR,yR,math.rad(0));
		setRotation(self.dor.left.node,xL,yL,math.rad(0));
		self.dor.state = false;
		self.dormoving = false;
		setVisibility(self.dor.audio,false);
		self.sendEvent = true;
	end;
	self.toSendMove = true;
end;

function FarmSiloSystem:setPlaneMaterial(fillType)
	setMaterial(self.inputMove.movingId, self.materials[fillType],0);
end;

function FarmSiloSystem:deleteMap()
	self:delete();
end;

function FarmSiloSystem:delete()
	unregisterObjectClassName(self)
	g_currentMission:removeOnCreateLoadedObjectToSave(self)
	
	if self.playerTrigger then
		removeTrigger(self.playerTrigger)
	end
	if self.dor and self.dor.doorTrigger then
		removeTrigger(self.dor.doorTrigger)
	end
	if self.InputTrigger and self.InputTrigger.isRegistered then
		self.InputTrigger:unregister()
		self.InputTrigger:delete()
	end
	if self.OutputSiloTrigger and self.OutputSiloTrigger.Trigger then
		self.OutputSiloTrigger.Trigger:delete();
	end;
	
	if not self.RunAsGE then FarmSiloSystem:superClass().delete(self) end;
end;

function FarmSiloSystem:update(dt)
	if self.playerInTrigger or self.isActiveMove then
		if g_currentMission.controlledVehicle ~= nil then
			self.playerInTrigger = false;
		end;
		if self.isActiveMove then
			if not self.isActiveForFilling then
				if self.isMovingRohr then
					self:toMoveRohrOn();					
				end;
				if self.isMovingSiloTrigger then
					self:toMoveTriggerOn();
				end;
			else
				if self.isMovingRohr then
					self:toMoveRohrOff();					
				end;
				if self.isMovingSiloTrigger then
					self:toMoveTriggerOff();
				end;
			end;
		elseif not self.isActiveMove and not self.isActiveForFilling then 
			if self.otherId == g_currentMission.player.rootNode and self.sendEvent  then
				g_currentMission:addHelpButtonText(get_i18n("input_FarmSiloSystem_on"), InputBinding.FarmSiloSystem_on);
				if InputBinding.isPressed(InputBinding.FarmSiloSystem_on) then
					self.isActiveMove = true;
					self.isMovingRohr = true;
					self.toSendMove = true;
				end;
			end;
		elseif not self.isActiveMove and self.isActiveForFilling then 
			if self.otherId == g_currentMission.player.rootNode and self.sendEvent  then
				g_currentMission:addHelpButtonText(get_i18n("input_FarmSiloSystem_off"), InputBinding.FarmSiloSystem_off);
				if InputBinding.isPressed(InputBinding.FarmSiloSystem_off) then
					self.isActiveMove = true;
					self.isMovingRohr = true;
					self.toSendMove = true;
				end;
			end;
		end;	
	end;
	
	--Lights
	if not self.isActiveMove and not self.isActiveForFilling then 
		setVisibility(self.light.first.red,true);
		setVisibility(self.light.first.green,false);
		setVisibility(self.light.second.red,false);
		setVisibility(self.light.second.green,false);
	elseif self.isActiveForFilling and not self.isActiveMove and not self.isFillingActive then 
		setVisibility(self.light.first.red,false);
		setVisibility(self.light.first.green,true);
	elseif self.isActiveMove then 								
		setVisibility(self.light.first.green,false);
		self.blinkTimer = self.blinkTimer + 1;
		if self.blinkTimer >= 20 then
			setVisibility(self.light.first.red,not(getVisibility(self.light.first.red)));
			self.blinkTimer = 0;
		end;	
	elseif self.isFillingActive then
		setVisibility(self.light.second.red,false);
		self.blinkTimer = self.blinkTimer + 1;
		if self.blinkTimer >= 20 then
			setVisibility(self.light.second.green,not(getVisibility(self.light.second.green)));
			self.blinkTimer = 0;
		end;
	end;
	
	if self.updateDisplay then
		for typInt,_ in pairs(self.Indicator.Display) do
			Utils.setNumberShaderByValue(self.Indicator.Display[typInt].node, math.floor(self.fillLvls[typInt]), 0, true)
		end;
		self.updateDisplay = false;
	end;
	
	if self.inputMove.isActive and self.inputMove.isMoving and self.inputMove.isTipFinish then
		local x,y,z = getTranslation(self.inputMove.movingId)
		if y <= self.inputMove.minY then
			setTranslation(self.inputMove.movingId,x,self.inputMove.minY,z);
			self.inputMove.isMoving = false;
		else
			local delta = math.max(y-self.inputMove.movingScaleOutput,self.inputMove.minY);
			setTranslation(self.inputMove.movingId,x,delta,z);
		end;
		self.toSendMove = true;
	end;
	if not self.inputMove.isTipFinish then
		self.inputMove.isTipFinish = true;
	end;
	if self.dorPlayerEnter or self.dormoving then
		if not self.dormoving then
			if self.dor.state then
				if self.otherId == g_currentMission.player.rootNode and self.sendEvent  then
					g_currentMission:addHelpButtonText(get_i18n("FarmSiloSystem_moveDoorClose"), InputBinding.FarmSiloSystem_moveDoor);
					if InputBinding.hasEvent(InputBinding.FarmSiloSystem_moveDoor) then
						self.dormoving = true;
						self.toSendMove = true;
					end;
				end;
			else
				if self.otherId == g_currentMission.player.rootNode and self.sendEvent then
					g_currentMission:addHelpButtonText(get_i18n("FarmSiloSystem_moveDoorOpen"), InputBinding.FarmSiloSystem_moveDoor);
					if InputBinding.hasEvent(InputBinding.FarmSiloSystem_moveDoor) then
						self.dormoving = true;
						self.toSendMove = true;
					end;
				end;
			end;
		elseif self.dormoving then
			if self.dor.state then
				self:doorOff();
			else
				self:doorOn();
			end;
		end;
	end;
	
	if g_server ~= nil and self.toSendMove then
		self:raiseDirtyFlags(self.FarmSiloSystemDirtyFlag);
		self.toSendMove = false;
	--elseif g_client ~= nil and self.toSendMove and self.sendEvent then
	--	self:getObjectToSynch();
	--	FarmSiloSystemEvent:sendEvent(self);
	--	self.toSendMove = false;
	end;
	
end;

function FarmSiloSystem:getObjectToSynch()
	self.synchObjectEvent.isActiveMove = self.isActiveMove;
	self.synchObjectEvent.isActiveForFilling = self.isActiveForFilling;
	self.synchObjectEvent.isSiloTriggerReady = self.isSiloTriggerReady;
	self.synchObjectEvent.isFillingActive = self.isFillingActive;
	self.synchObjectEvent.isMovingRohr = self.isMovingRohr;
	self.synchObjectEvent.isMovingSiloTrigger = self.isMovingSiloTrigger;
	self.synchObjectEvent.dormoving = self.dormoving;
	
	self.synchObjectEvent.dormovingState = self.dor.state;	
end;

function FarmSiloSystem:getSynchObject()
	self.synchObject.isActiveMove = self.isActiveMove;
	self.synchObject.isActiveForFilling = self.isActiveForFilling;
	self.synchObject.isSiloTriggerReady = self.isSiloTriggerReady;
	self.synchObject.isFillingActive = self.isFillingActive;
	self.synchObject.isMovingRohr = self.isMovingRohr;
	self.synchObject.isMovingSiloTrigger = self.isMovingSiloTrigger;
	self.synchObject.dormoving = self.dormoving;
	
	self.synchObject.fillLvls = {};
	for typ,lvl in pairs(self.fillLvls) do
		self.synchObject.fillLvls[typ] = lvl;
	end;
	
	self.synchObject.inputMovePosX,self.synchObject.inputMovePosY,self.synchObject.inputMovePosZ = getTranslation(self.inputMove.movingId);
	
	self.synchObject.outputSiloTriggerPosX,self.synchObject.outputSiloTriggerPosY,self.synchObject.outputSiloTriggerPosZ = getRotation(self.OutputSiloTrigger.id);
	self.synchObject.outputRohrPosX,self.synchObject.outputRohrPosY,self.synchObject.outputRohrPosZ = getRotation(self.OutputRohr);
	
	self.synchObject.offIdVis = getVisibility(self.Display.offId)
	self.synchObject.onIdVis = getVisibility(self.Display.onId)
	self.synchObject.numVis = self.synchObject.onIdVis;
	
	self.synchObject.switcher_first_rotX,self.synchObject.switcher_first_rotY,self.synchObject.switcher_first_rotZ = getRotation(self.switcher.first.id);
	self.synchObject.switcher_second_rotX,self.synchObject.switcher_second_rotY,self.synchObject.switcher_second_rotZ = getRotation(self.switcher.second.id);
	
	self.synchObject.sounds = {};
	for i,vis in pairs(self.sound) do
		self.synchObject.sounds[i] = getVisibility(self.sound[i]);			
	end;
	
	self.synchObject.door_right_rotX,self.synchObject.door_right_rotY,self.synchObject.door_right_rotZ = getRotation(self.dor.right.node)
	self.synchObject.door_left_rotX,self.synchObject.door_left_rotY,self.synchObject.door_left_rotZ = getRotation(self.dor.left.node)
	
end;

function FarmSiloSystem:updateTick(dt)
	--if g_server ~= nil and self.toSendMove then
		--self:raiseDirtyFlags(self.FarmSiloSystemDirtyFlag);
	--end
end;

function FarmSiloSystem:setIsSiloTriggerFilling(isFilling,fillType,noEventSend)
	self.OutputSiloTrigger.Trigger:setFilling(isFilling,fillType,noEventSend);
end;

function FarmSiloSystem:addFillLevelFromTool(trailer,fillDelta,fillType, val)
	if type(fillDelta) == "table" then
		trailer = fillDelta;
		fillDelta = fillType;
		fillType = val;
	end;
	if fillDelta > 0 and fillType ~= nil then
		if self.fillLvls[fillType] ~= nil then
			local maxFillDelta = math.min(fillDelta,self.capacity-self.fillLvls[fillType])
			self:setFillLevel(fillType,self.fillLvls[fillType] + maxFillDelta);
			self.inputMove.isMoving = true;
			self.inputMove.isTipFinish = false;
			local x,y,z = getTranslation(self.inputMove.movingId)
			local delta = math.min(y+self.inputMove.movingScaleInput,self.inputMove.maxY);
			setTranslation(self.inputMove.movingId,x,delta,z);
			self:setPlaneMaterial(fillType);
			return maxFillDelta;
		else
			return 0;
		end;
	else
		return 0;
	end;
end;

function FarmSiloSystem:setFillingSilo(value)
	self.isFillingActive = value;
	if value then
		setRotation(self.switcher.second.id,0,0,0);
	else
		setRotation(self.switcher.second.id,-70,0,0);
	end;
end;

function FarmSiloSystem:allowFillType(art,FillType)
	return art.acceptedFillTypes[FillType];
end;

function FarmSiloSystem:PlayerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (g_currentMission.controlPlayer and g_currentMission.player and otherId == g_currentMission.player.rootNode) then
		if (onEnter) then 
            self.playerInTrigger = true;
			self.OutputSiloTrigger.Trigger.isPlayerInRange = true;
			self.otherId = otherId;
        elseif (onLeave) then
            self.playerInTrigger = false;
			self.OutputSiloTrigger.Trigger.isPlayerInRange = false;
        end;
	end;
end;

function FarmSiloSystem:DoorTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (g_currentMission.controlPlayer and g_currentMission.player and otherId == g_currentMission.player.rootNode) then
		if (onEnter) then 
            self.dorPlayerEnter = true;
			self.otherId = otherId;
        elseif (onLeave) then
            self.dorPlayerEnter = false;
        end;
	end;
end;

function FarmSiloSystem:TipTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	Debug(8,"TipTriggerCallback triggerId %s otherId %s onEnter %s onLeave %s onStay %s otherShapeId %s", tostring(triggerId), tostring(otherId), tostring(onEnter), tostring(onLeave), tostring(onStay), tostring(otherShapeId));
	
	local trailer = g_currentMission.objectToTrailer[otherShapeId];
	if trailer ~= nil and trailer.allowTipDischarge then
		if onEnter and self.dor.state then
			if g_currentMission.trailerTipTriggers[trailer] == nil then
				g_currentMission.trailerTipTriggers[trailer] = {};
			end;
			table.insert(g_currentMission.trailerTipTriggers[trailer], self);
			if trailer.coverAnimation ~= nil and trailer.autoReactToTrigger == true then
                trailer:setCoverState(true);
			end
		elseif onLeave then
			local triggers = g_currentMission.trailerTipTriggers[trailer];
			if triggers ~= nil then
				for i=1, table.getn(triggers) do
					if triggers[i] == self then
						table.remove(triggers, i);
						if table.getn(triggers) == 0 then
							g_currentMission.trailerTipTriggers[trailer] = nil;
						end;
						break;
					end;
				end;
			end;
			if trailer.coverAnimation ~= nil and trailer.autoReactToTrigger == true then
                trailer:setCoverState(false);
			end
		end;
	end;
end;

function FarmSiloSystem:getTipInfoForTrailer(trailer, tipReferencePointIndex)
	local isAllowed, minDistance, bestPoint = true, math.huge, nil;
	isAllowed, minDistance, bestPoint = self.InputTrigger:getTipInfoForTrailer(trailer, tipReferencePointIndex);
    return isAllowed, minDistance, bestPoint;
end

function FarmSiloSystem:getNotAllowedText(fillable,toolType)
	local text = ""
	text = self.InputTrigger:getNotAllowedText(fillable,toolType);
    return text;
end

function FarmSiloSystem:getCapacity(typ)
	return self.capacity
end;

function FarmSiloSystem:getStationName()
	return self.stationName
end;

function FarmSiloSystem:getAllFillLvl()
	return self.fillLvls
end;

function FarmSiloSystem:getFillLevel(typ)
	return self.fillLvls[typ]
end;

function FarmSiloSystem:setFillLevel(typ,lvl)
	self.fillLvls[typ] = lvl;
	self.updateDisplay = true;
	self.toSendMove = true;
end;

function FarmSiloSystem:getPlayerInRange()
	return self.playerInTrigger
end;

if FarmSiloSystem.RunAsGE then
	g_onCreateUtil.addOnCreateFunction("FarmSiloSystem", FarmSiloSystem.onCreate);
else
	registerPlaceableType("FarmSiloSystem", FarmSiloSystem);
end;

FarmSiloSystemEvent = {}
FarmSiloSystemEvent_mt = Class(FarmSiloSystemEvent, Event)
InitEventClass(FarmSiloSystemEvent, "FarmSiloSystemEvent")
function FarmSiloSystemEvent:emptyNew()
	local self = Event:new(FarmSiloSystemEvent_mt)
	self.synchObjectEvent = {};
	return self
end
function FarmSiloSystemEvent:new(object)
	local self = FarmSiloSystemEvent:emptyNew()
	
	self.object = object;
	self.synchObjectEvent = object.synchObjectEvent;
	return self
end
function FarmSiloSystemEvent:readStream(streamId, connection)
	local idObject = streamReadInt32(streamId);
	self.object = networkGetObject(idObject);
	
	local data = {};
	
	data.isActiveMove = streamReadBool(streamId);
	data.isActiveForFilling = streamReadBool(streamId);
	data.isSiloTriggerReady = streamReadBool(streamId);
	data.isFillingActive = streamReadBool(streamId);
	data.isMovingRohr = streamReadBool(streamId);
	data.isMovingSiloTrigger = streamReadBool(streamId);
	data.dormoving = streamReadBool(streamId);
	data.dormovingState = streamReadBool(streamId);
	
	self.synchObjectEvent = data;
	
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end;
	
	if self.object ~= nil and data ~= nil then
		self.object:setMPEvent(data)
	end;
end

function FarmSiloSystemEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, networkGetObjectId(self.object));
	
	streamWriteBool(streamId, self.synchObjectEvent.isActiveMove);
	streamWriteBool(streamId, self.synchObjectEvent.isActiveForFilling);
	streamWriteBool(streamId, self.synchObjectEvent.isSiloTriggerReady);
	streamWriteBool(streamId, self.synchObjectEvent.isFillingActive);
	streamWriteBool(streamId, self.synchObjectEvent.isMovingRohr);
	streamWriteBool(streamId, self.synchObjectEvent.isMovingSiloTrigger);
	streamWriteBool(streamId, self.synchObjectEvent.dormoving);
	streamWriteBool(streamId, self.synchObjectEvent.dormovingState);
	
end
function FarmSiloSystemEvent:sendEvent(object)
	if g_server ~= nil then
		g_server:broadcastEvent(FarmSiloSystemEvent:new(object), nil, nil, object)
	else
		g_client:getServerConnection():sendEvent(FarmSiloSystemEvent:new(object))
	end
end

SiloTriggerFarmSiloSystem = {};
local SiloTriggerFS_mt = Class(SiloTriggerFarmSiloSystem);
InitObjectClass(SiloTriggerFarmSiloSystem, "SiloTriggerFarmSiloSystem");

function SiloTriggerFarmSiloSystem:new(isServer, isClient)
	local self = {};
	setmetatable(self, SiloTriggerFS_mt)
	self.SiloTriggerFsTrailers = {}
	self.isFilling = false;
	self.activeTriggers = 0;
	self.otherId = 0;
	self.SiloTriggerFarmSiloSystemActivatable = SiloTriggerFarmSiloSystemActivatable:new(self)
	self.isClient = isClient
	self.isServer = isServer
	return self;
end;

function SiloTriggerFarmSiloSystem:load(id,tank)
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
		
	--local fillTypesStr = Utils.getNoNil(getUserAttribute(id, "fillType"),"wheat")
	--fillTypesStr = Utils.getNoNil(getUserAttribute(id, "fillType"),fillTypesStr)
	--local fillType = FillUtil.fillTypeNameToInt[fillTypesStr]
	--if fillType then
	--	self.fillType = fillType;
	--else
	--	Debug(-1,"ERROR: unknown fillType %s in %s",tostring(fillTypesStr),getName(id));
	--end
	
	self.fillLitersPerSecond = Utils.getNoNil(getUserAttribute(id, "fillLitersPerSecond"), 50);
	
	self.SiloTriggerFarmSiloSystemActivatable.startFillText = Utils.getNoNil(get_i18n("FarmSiloSystem_startFill"));
	self.SiloTriggerFarmSiloSystemActivatable.stopFillText = Utils.getNoNil(get_i18n("FarmSiloSystem_stopFill"));
		
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

function SiloTriggerFarmSiloSystem:deleteMap()
	self:delete();
end;

function SiloTriggerFarmSiloSystem:delete()
	if self.isClient then
        --if self.siloFillSound ~= nil then
        --    delete(self.siloFillSound);
        --end
        EffectManager:deleteEffects(self.dropEffects);
        ParticleUtil.deleteParticleSystems(self.dropParticleSystems)
        ParticleUtil.deleteParticleSystems(self.lyingParticleSystems)
    end
    for i=1, table.getn(self.triggerIds) do
        removeTrigger(self.triggerIds[i]);
	end
	removeTrigger(self.triggerRoot);
end;

function SiloTriggerFarmSiloSystem:TankCapacity(typ) 
	return self.Tank.getCapacity(typ)
end

function SiloTriggerFarmSiloSystem:TankName() 
	return self.Tank.getStationName()
end

function SiloTriggerFarmSiloSystem:TankFillLevel(typ)
	return self.Tank.getFillLevel(typ)
end

function SiloTriggerFarmSiloSystem:TankPlayerInRange()
	return self.Tank.getPlayerInRange()
end

function SiloTriggerFarmSiloSystem:setTankFillLevel(lvl,typ)
	self.Tank.setFillLevel(typ, lvl)
end

function SiloTriggerFarmSiloSystem:getAllFillLvl()
	return self.Tank.getAllFillLvl()
end

function SiloTriggerFarmSiloSystem:update(dt)
	if self.isServer then		
		local trailer = self.siloTrailer;
		local disableFilling = true;
		if self.activeTriggers >= 4 and trailer ~= nil and self.selectedFillType ~= nil then
			if self.isFilling then
				trailer:resetFillLevelIfNeeded(self.selectedFillType);
				local TfillLvl = trailer:getFillLevel(self.selectedFillType);
				local capacity = self:TankCapacity(self.selectedFillType);
				local fillLvl = self:TankFillLevel(self.selectedFillType);
				if fillLvl > 0 then
					local delta = math.min(self.fillLitersPerSecond*0.001*dt,fillLvl);
					trailer:setFillLevel(TfillLvl+delta,self.selectedFillType,false,self.fillVolumeDischargeInfos);
					local newLvl = trailer:getFillLevel(self.selectedFillType);
					if newLvl ~= TfillLvl then
						self:setTankFillLevel(math.max(fillLvl-(newLvl-TfillLvl),0),self.selectedFillType);
						disableFilling = false
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
end;

function SiloTriggerFarmSiloSystem:setFilling(isFilling,fillType, noEventSend) 
	SiloTriggerFarmSiloSystemFillingEvent.sendEvent(self.Tank.Parent, isFilling,fillType, noEventSend)
	if self.isFilling ~= isFilling then
		self.isFilling = isFilling 
	end;
	if self.isFilling then
		self:startFill(fillType);
	else
		self:stopFill();
	end;
end;

function SiloTriggerFarmSiloSystem:startFill(fillType)
    if self.isFilling then
		self.selectedFillType = fillType;
		
		self.Tank.setFillingSilo(true);
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
                EffectManager:setFillType(self.dropEffects, self.selectedFillType)
                EffectManager:startEffects(self.dropEffects);
            end;
            if self.scroller ~= nil then
                setShaderParameter(self.scroller, self.scrollerShaderParameterName, self.scrollerSpeedX, self.scrollerSpeedY, 0, 0, false);
            end
        end;
    end;
end;

function SiloTriggerFarmSiloSystem:stopFill()
    if not self.isFilling then
		self.Tank.setFillingSilo(false);
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
		self.selectedFillType = nil;
    end;
end;

function SiloTriggerFarmSiloSystem:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    --if self.isEnabled then
        local trailer = g_currentMission.objectToTrailer[otherActorId];
        if trailer ~= nil and otherActorId == trailer.exactFillRootNode then
            if onEnter and trailer.getAllowFillFromAir ~= nil then
                self.activeTriggers = self.activeTriggers + 1;
                self.siloTrailer = trailer;
                if self.activeTriggers >= 4 then
					g_currentMission:addActivatableObject(self.SiloTriggerFarmSiloSystemActivatable);
                    if self.siloTrailer.coverAnimation ~= nil and self.siloTrailer.autoReactToTrigger == true then
                        self.siloTrailer:setCoverState(true);
                    end
                end
				self.showOnHelpVehicle = true;
            elseif onLeave then
                if self.siloTrailer ~= nil and self.siloTrailer.coverAnimation ~= nil and self.siloTrailer.autoReactToTrigger == true then
                    self.siloTrailer:setCoverState(false);
                end
                self.activeTriggers = math.max(self.activeTriggers - 1, 0);
                self.siloTrailer = nil;
                self:setFilling(false);
                g_currentMission:removeActivatableObject(self.SiloTriggerFarmSiloSystemActivatable);
				self.selectedFillType = nil;
            end;
        end;
    --end;
end;

SiloTriggerFarmSiloSystemActivatable = {}
local SiloTriggerAutomaticActivatable_mt = Class(SiloTriggerFarmSiloSystemActivatable)
function SiloTriggerFarmSiloSystemActivatable:new(Trigger)
	local self = {}
	setmetatable(self, SiloTriggerAutomaticActivatable_mt)
	self.Trigger = Trigger
	self.activateText = "unknown"

	return self
end
function SiloTriggerFarmSiloSystemActivatable:getIsActivatable()
	local inRange = self.Trigger:TankPlayerInRange();
	if self.Trigger.siloTrailer ~= nil and self.Trigger.activeTriggers >= 4 and inRange then
		local trailer = self.Trigger.siloTrailer;
		--if trailer:getRootAttacherVehicle() ~= g_currentMission.controlledVehicle then
		--	return false;
		--end;
		if not trailer:getAllowFillFromAir() then
			return false;
		end
		if trailer:getFillLevel() == 0 then
			self.updateActivateText(self)
			return true;
		else
			local fillTypes = trailer:getCurrentFillTypes();
			for _,fillType in pairs(fillTypes) do
				if self.Trigger.fillTypes[fillType] ~= nil and trailer:getFillLevel(fillType) < trailer:getCapacity() and self.Trigger:TankFillLevel(fillType) > 0 then
					self.updateActivateText(self)
					return true;
				end
			end	
		end;
	end;
	return false;
end
function SiloTriggerFarmSiloSystemActivatable:onActivateObject()
	local trailer = self.Trigger.siloTrailer;
	local fillLevels = self.Trigger:getAllFillLvl();
	local capacity = self.Trigger:TankCapacity();
	local name = self.Trigger:TankName()
	if not self.Trigger.isFilling and trailer:getFillLevel() == 0 then 
		g_gui:showSiloDialog({title=string.format("%s (%d %s)", name, g_i18n:getFluid(capacity, 0), g_i18n:getText("unit_literShort")), fillLevels=fillLevels, capacity=capacity, callback=self.onFillTypeSelection, target=self})
    elseif trailer:getFillLevel() ~= 0 then
		local fillTypes = trailer:getCurrentFillTypes();
		for _,fillType in pairs(fillTypes) do
			if self.Trigger.fillTypes[fillType] ~= nil then
				self.Trigger:setFilling(not self.Trigger.isFilling,fillType)
				break;
			end;
		end;
		
	else
		self.Trigger:setFilling(false);
	end;
	self.updateActivateText(self)
	g_currentMission:addActivatableObject(self)
end
function SiloTriggerFarmSiloSystemActivatable:drawActivate()
end
function SiloTriggerFarmSiloSystemActivatable:updateActivateText()
	if self.Trigger.isFilling then
		self.activateText = self.stopFillText;
	else	
		self.activateText = self.startFillText;
	end;
end
function SiloTriggerFarmSiloSystemActivatable:onFillTypeSelection(fillType)
	if fillType ~= nil and fillType ~= FillUtil.FILLTYPE_UNKNOWN then
        if self.Trigger.siloTrailer ~= nil then
            self.Trigger:setFilling(not self.Trigger.isFilling,fillType);
        end;
    end;
end;

SiloTriggerFarmSiloSystemFillingEvent = {}
SiloTriggerFarmSiloSystemFillingEvent_mt = Class(SiloTriggerFarmSiloSystemFillingEvent, Event)
InitEventClass(SiloTriggerFarmSiloSystemFillingEvent, "SiloTriggerFarmSiloSystemFillingEvent")
function SiloTriggerFarmSiloSystemFillingEvent:emptyNew()
	local self = Event:new(SiloTriggerFarmSiloSystemFillingEvent_mt)
	return self
end
function SiloTriggerFarmSiloSystemFillingEvent:new(object, isFilling,fillType)
	local self = SiloTriggerFarmSiloSystemFillingEvent:emptyNew()
	self.object = object
	self.isFilling = isFilling
	self.fillType = fillType
	if self.fillType == nil then
		self.fillType = FillUtil.FILLTYPE_UNKNOWN;
	end;
	return self
end
function SiloTriggerFarmSiloSystemFillingEvent:readStream(streamId, connection)
	self.object = readNetworkNodeObject(streamId)
	self.isFilling = streamReadBool(streamId)
	self.fillType = streamReadInt16(streamId)
	self:run(connection)
end
function SiloTriggerFarmSiloSystemFillingEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isFilling)
	streamWriteInt16(streamId,self.fillType)
end
function SiloTriggerFarmSiloSystemFillingEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.object ~= nil then
		self.object:setIsSiloTriggerFilling(self.isFilling,self.fillType,true)
	end;
end
function SiloTriggerFarmSiloSystemFillingEvent.sendEvent(object, isFilling,fillType, noEventSend)
	if isFilling ~= object.isFilling then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(SiloTriggerFarmSiloSystemFillingEvent:new(object, isFilling,fillType), nil, nil, object)
			else
				g_client:getServerConnection():sendEvent(SiloTriggerFarmSiloSystemFillingEvent:new(object, isFilling,fillType))
			end
		end
	end;
end