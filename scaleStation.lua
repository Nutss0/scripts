-- 
-- Scale Station with Statistics (single way)
-- Script: Blacky_BPG
-- 
-- Models: 
--    Scale 26 meter - Marc-Modding
--    Scale 18 meter - Repi
--    Scale displays - Blacky_BPG
--    Traffic lights - Marc-Modding
-- 
-- Idea:
--    Eifok-Team for FS11
--    Blacky_BPG for FS13
--    Blacky_BPG for FS17
-- 
-- 
-- 
-- 1.4.0.0      10.02.2017    fixed scale overallMass on gameLoad bug
-- 1.3.1.0 D    01.02.2017    fixed scale sum calculation
-- 1.3.1.0 C    01.02.2017    fixed normal multiplayer mode for reset options
-- 1.3.1.0 B    29.01.2017    restriction for reset functions only to master user / admins in multiplayer mode
-- 1.3.1.0 A    02.01.2017    multiplayer synchronization fixed
-- 1.3.1.0      17.12.2016    multiplayer fixed and tested
-- 1.3.0.0      06.12.2016    add workling lights for scale status
-- 1.2.1.1 A    18.11.2016    fixed errors for negative page count
-- 1.2.1.1      16.11.2016    fixed errors for array tables
-- 1.2.1.0      12.11.2016    initial Version for FS17
-- 

scaleStation = {}
scaleStation.version = "1.4.0.0  -  10.02.2017"
scaleStation.modDir = g_currentModDirectory
scaleStation_mt = Class(scaleStation, Object)
InitObjectClass(scaleStation, "scaleStation");

timerDef = 75;

function scaleStation.onCreate(id)
	local object = scaleStation:new(g_server ~= nil, g_client ~= nil);
	local loaded, saveId = object:load(id)
	if loaded == true then
		if g_currentMission.scaleStation == nil then
			g_currentMission.scaleStation = {};
			g_currentMission.scaleStation.scaleCount = 0;
		end;

		g_currentMission:addOnCreateLoadedObject(object);
		g_currentMission:addOnCreateLoadedObjectToSave(object);
		object:register(true);
		g_currentMission.scaleStation.scaleCount = g_currentMission.scaleStation.scaleCount + 1;
		g_currentMission.scaleStation[saveId] = object;

		if g_currentMission.scaleStation.players == nil then
			g_currentMission.scaleStation.players = {};
			g_currentMission.scaleStation.playerCount = 0;
		end;
		if g_currentMission.scaleStation.fruits == nil then
			g_currentMission.scaleStation.fruits = {};
			g_currentMission.scaleStation.numFruits = 0;
		end;

	else
		object:delete();
	end;
end;

function scaleStation:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = scaleStation_mt;
	end;
	local self = Object:new(isServer, isClient, customMt);
	self.nodeId = 0;
	self.rootNode = 0;
	self.customEnvironment = g_currentMission.loadingMapModName;
	-- self.scaleStationDirtyFlag = self:getNextDirtyFlag();
	return self;
end;

function scaleStation:load(id)
	self.triggerId = id;
	addTrigger(self.triggerId, "triggerCallback", self);

	self.saveId = getUserAttribute(id, "saveId");
	if self.saveId == nil then
		self.saveId = "scaleStation_"..getName(id);
	end;
	self.i18n = _G[self.customEnvironment].g_i18n;
	self.name = self.i18n:getText(self.saveId);

	self.showHud = false;
	self.overallMass = 0;
	self.playerCount = 0;
	self.player = {};
	self.playerFruits = {};

	self.warnMessage= nil;
	self.showWarn = false;

	self.timerSet = 0;
	self.timerSetLast = 1;

	self.timerCnt = 0;
	self.sumMass = 0;
	self.sumMassLoad = 0;
	self.zwMass = 0;
	self.playerName = nil;
	self.fillTypes = {};

	self.plate = {};
	self.plate.index = nil;
	self.plate.mass = 0;
	self.plate.massOld = 0;
	self.plate.max = Utils.getNoNil(getUserAttribute(id, "plateMaxY"),0.14);
	self.plate.min = Utils.getNoNil(getUserAttribute(id, "plateMinY"),0);
	local plateId = getUserAttribute(id, "plateIndex");
	if plateId ~= nil then
		self.plate.index = Utils.indexToObject(id, plateId);
	end;

	local workingLights = getUserAttribute(id, "workingLights");
	self.workLights = {};
	if workingLights ~= nil and workingLights ~= 0 then
		workingLights = Utils.indexToObject(id, workingLights);
		local workingOn = getChild(workingLights,"workingOn");
		local workingOff = getChild(workingLights,"workingOff");
		if workingOn ~= nil then self.workLights.on = workingOn end;
		if workingOff ~= nil then self.workLights.off= workingOff end;
	end;
	local displayIndex = Utils.getNoNil(getUserAttribute(id, "displayIndex"),getUserAttribute(id, "displayIndex1"));
	self.display1 = {};
	self.display1.defaultOff = Utils.getNoNil(getUserAttribute(id, "defaultOff"),"11");
	self.display1.defaultK = Utils.getNoNil(getUserAttribute(id, "defaultK"),"15");
	self.display1.defaultG = Utils.getNoNil(getUserAttribute(id, "defaultG"),"14");
	self.display1.defaultMinus = Utils.getNoNil(getUserAttribute(id, "defaultMinus"),"13");
	self.display1.defaultE = Utils.getNoNil(getUserAttribute(id, "defaultE"),"12");
	if displayIndex ~= nil then
		local digitGroup = Utils.indexToObject(id,displayIndex);
		local num = getNumOfChildren(digitGroup);
		local digiK = getChild(digitGroup,"digiK");
		local digiG = getChild(digitGroup,"digiG");
		local digiOff = getChild(digitGroup,"digiOff");
		local digiE = getChild(digitGroup,"digiE");
		self.display1.digits = {};
		self.display1.digits[0] = {};
		local workLights = getChild(digitGroup,"workLight");
		self.display1.workLights = {};
		if workLights ~= nil and workLights ~= 0 then
			self.display1.workLights.ok = getChild(workLights,"green");
			self.display1.workLights.fault = getChild(workLights,"red");
		end;
		local shifter = 0;
		for i=1, num do
			local child = getChildAt(digitGroup, i-1);
			if child ~= nil and child ~= 0 then
				if child == digiK then
					self.display1.digits[0].digiK = child;
					shifter = shifter + 1;
				elseif child == digiG then
					self.display1.digits[0].digiG = child;
					shifter = shifter + 1;
				elseif child == digiOff then
					self.display1.digits[0].digiOff = child;
					shifter = shifter + 1;
				elseif child == digiE then
					self.display1.digits[0].digiE = child;
					shifter = shifter + 1;
				elseif child == workLights then
					-- skip this child
					shifter = shifter + 1;
				else
					self.display1.digits[i-shifter] = {};
					self.display1.digits[i-shifter].id = child;
					local numDot = getNumOfChildren(child);
					if numDot ~= 0 then
						self.display1.digits[i-shifter].dot = getChildAt(child, 0);
					end;
				end;
			end;
		end;
	end;
	self:setScaleDisplay(self.display1,0)

	local displayIndex2 = getUserAttribute(id, "displayIndex2");
	self.display2 = {};
	self.display2.defaultOff = Utils.getNoNil(getUserAttribute(id, "defaultOff2"),self.display1.defaultOff);
	self.display2.defaultK = Utils.getNoNil(getUserAttribute(id, "defaultK2"),self.display1.defaultK);
	self.display2.defaultG = Utils.getNoNil(getUserAttribute(id, "defaultG2"),self.display1.defaultG);
	self.display2.defaultMinus = Utils.getNoNil(getUserAttribute(id, "defaultMinus2"),self.display1.defaultMinus);
	self.display2.defaultE = Utils.getNoNil(getUserAttribute(id, "defaultE2"),self.display1.defaultE);
	if displayIndex2 ~= nil then
		local digitGroup = Utils.indexToObject(id,displayIndex2);
		local num = getNumOfChildren(digitGroup);
		local digiK = getChild(digitGroup,"digiK");
		local digiG = getChild(digitGroup,"digiG");
		local digiOff = getChild(digitGroup,"digiOff");
		local digiE = getChild(digitGroup,"digiE");
		self.display2.digits = {};
		self.display2.digits[0] = {};
		local workLights = getChild(digitGroup,"workLight");
		self.display2.workLights = {};
		if workLights ~= nil and workLights ~= 0 then
			self.display2.workLights.ok = getChild(workLights,"green");
			self.display2.workLights.fault = getChild(workLights,"red");
		end;
		local shifter = 0;
		for i=1, num do
			local child = getChildAt(digitGroup, i-1);
			if child ~= nil and child ~= 0 then
				if child == digiK then
					self.display2.digits[0].digiK = child;
					shifter = shifter + 1;
				elseif child == digiG then
					self.display2.digits[0].digiG = child;
					shifter = shifter + 1;
				elseif child == digiOff then
					self.display2.digits[0].digiOff = child;
					shifter = shifter + 1;
				elseif child == digiE then
					self.display2.digits[0].digiE = child;
					shifter = shifter + 1;
				elseif child == workLights then
					-- skip this child
					shifter = shifter + 1;
				else
					self.display2.digits[i-shifter] = {};
					self.display2.digits[i-shifter].id = child;
					local numDot = getNumOfChildren(child);
					if numDot ~= 0 then
						self.display2.digits[i-shifter].dot = getChildAt(child, 0);
					end;
				end;
			end;
		end;
	end;
	self:setScaleDisplay(self.display2,0)

	self.trafficSignEntry = {};
	local trafficSignEntry = getUserAttribute(id, "trafficSignEntry");
	if trafficSignEntry ~= nil then
		local trafficSignEntryId = Utils.indexToObject(id, trafficSignEntry);
		self.trafficSignEntry.redLight = getChild(trafficSignEntryId,"redLight");
		self.trafficSignEntry.yellowLight = getChild(trafficSignEntryId,"yellowLight");
		self.trafficSignEntry.greenLight = getChild(trafficSignEntryId,"greenLight");
	end;
	self.trafficSignExit = {};
	local trafficSignExit = getUserAttribute(id, "trafficSignExit");
	if trafficSignExit ~= nil then
		local trafficSignExitId = Utils.indexToObject(id, trafficSignExit);
		self.trafficSignExit.redLight = getChild(trafficSignExitId,"redLight");
		self.trafficSignExit.yellowLight = getChild(trafficSignExitId,"yellowLight");
		self.trafficSignExit.greenLight = getChild(trafficSignExitId,"greenLight");
	end;
	self:setLightState(1,100);

	self.vehiclesInTrigger = {};
	self.vehiclesInTriggerCount = 0;
	self.requestSend = 0;
	self.requestTimer = 30;
	self.overweight = false;
	
	self.dataSend = {};
	self.dataSend.sync = 0;
	self.dataSend.player = nil;
	self.dataSend.saveId = nil;
	self.dataSend.mass = 0;
	self.dataSend.fillType = 0;
	self.isSender = false;

--	self.scaleStationDirtyFlag = self:getNextDirtyFlag();
	self.isEnabled = true;
	return true, self.saveId;
end;

function scaleStation:addPlayerOrFruit(saveId,pName,fType,fTypeMass, pId)
	if pId == nil then pId = 0 end;
	if pId > 0 and g_currentMission.playerUserId ~= pId then
		return;
	end;
	fTypeMass = Utils.getNoNil(fTypeMass,0)

	if pName == "NONE" then pName = nil end;

	local scale = g_currentMission.scaleStation;
	local players = scale.players;
	local mustRecalculate = false;

	if saveId ~= nil and saveId ~= "EMPTY" then
		if pName ~= nil and pName ~= "FRUIT" then
			-- add to scale
			if scale[saveId].player[pName] == nil then
				scale[saveId].player[pName] = {};
				scale[saveId].player[pName].name = pName;
				scale[saveId].player[pName].numFillTypes = 0;
				scale[saveId].player[pName].mass = 0
				scale[saveId].player[pName].fillTypes = {};
				scale[saveId].playerCount = scale[saveId].playerCount + 1;
			end;

			-- add to player table
			if players[pName] == nil then
				players[pName] = {};
				players[pName].name = pName;
				players[pName].fillTypes = {};
				players[pName].numFillTypes = 0;
				players[pName].scales = {};
				players[pName].numScales = 0;
				players[pName].overallMass = 0;
				scale.playerCount = scale.playerCount + 1;
			end;
			if players[pName].scales[saveId] == nil then
				players[pName].numScales = players[pName].numScales + 1;
				players[pName].scales[saveId] = scale[saveId];
			end;

			if fType == 0 then
				scale[saveId].player[pName].mass = fTypeMass;
				players[pName].overallMass = players[pName].overallMass + fTypeMass;
			else
				-- add to fruit table

				if scale[saveId].playerFruits == nil then
					scale[saveId].playerFruits = {};
				end;
				scale[saveId].playerFruits[fType] = Utils.getNoNil(scale[saveId].playerFruits[fType],0) + fTypeMass;
				if scale[saveId].player[pName].fillTypes[fType] == nil then
					scale[saveId].player[pName].numFillTypes = scale[saveId].player[pName].numFillTypes + 1
				end;
				scale[saveId].player[pName].fillTypes[fType] = Utils.getNoNil(scale[saveId].player[pName].fillTypes[fType],0) + fTypeMass;
				scale[saveId].overallMass = scale[saveId].overallMass + fTypeMass;
				if players[pName].fillTypes[fType] == nil then
					players[pName].numFillTypes = players[pName].numFillTypes + 1;
				end;
				players[pName].fillTypes[fType] = Utils.getNoNil(players[pName].fillTypes[fType],0) + fTypeMass;

				scale[saveId].player[pName].mass = scale[saveId].player[pName].mass + fTypeMass;
				players[pName].overallMass = players[pName].overallMass + fTypeMass;
			end;
			mustRecalculate = true;
		elseif pName ~= nil and pName == "FRUIT" then
			if fType ~= 0 then
				if scale[saveId].playerFruits == nil then
					scale[saveId].playerFruits = {};
				end;

				scale[saveId].playerFruits[fType] = fTypeMass;
			end;
			mustRecalculate = true;
		end;
	end;
	if mustRecalculate == true then
		g_currentMission.scaleStation.fruits = {};
		local fruits = g_currentMission.scaleStation.fruits;
		scale.numFruits = 0;
		for sId,sscale in pairs(scale) do
			if sId ~= nil and type(sscale) == "table" and sscale.saveId ~= nil and sscale.saveId == sId then
				for fillType,fillTypeMass in pairs(sscale.playerFruits) do
					if fruits[fillType] == nil then
						scale.numFruits = Utils.getNoNil(scale.numFruits,0) + 1;
						fruits[fillType] = {};
						fruits[fillType].name = FillUtil.fillTypeIndexToDesc[fillType].nameI18N;
						fruits[fillType].fillType = fillType;
						fruits[fillType].mass = 0;
						fruits[fillType].scales = {};
						fruits[fillType].numScales = 0;
						fruits[fillType].player = {};
						fruits[fillType].numPlayer = 0;
					end;
					if fruits[fillType].scales[sId] == nil then
						fruits[fillType].scales[sId] = scale[sId];
						fruits[fillType].numScales = fruits[fillType].numScales + 1;
					end;
					fruits[fillType].mass = fruits[fillType].mass + fillTypeMass;
					for pN,pTable in pairs(players) do
						if pTable.fillTypes ~= nil and pTable.fillTypes[fillType] ~= nil and pTable.fillTypes[fillType] > 0 then
							if fruits[fillType].player[pN] == nil then
								fruits[fillType].player[pN] = pTable;
								fruits[fillType].numPlayer = fruits[fillType].numPlayer + 1;
							end;
						end;
					end;
				end;
			end
		end
	end;
end;

function scaleStation:setLightState(entryVal,exitVal)
	if exitVal ~= nil then
		if exitVal >= 0 then
			local lR = math.floor(exitVal / 100);
			local lY = math.floor(exitVal / 10) - (lR * 10);
			local lG = exitVal - (lY * 10) - (lR * 100);
			local rOn, yOn, gOn = false, false, false;
			if lR > 0 then rOn = true end;
			if lY > 0 then yOn = true end;
			if lG > 0 then gOn = true end;

			if self.trafficSignExit.redLight ~= nil then setVisibility(self.trafficSignExit.redLight, rOn) end;
			if self.trafficSignExit.yellowLight ~= nil then setVisibility(self.trafficSignExit.yellowLight, yOn) end;
			if self.trafficSignExit.greenLight ~= nil then setVisibility(self.trafficSignExit.greenLight, gOn) end;
		end;
	end;
	if entryVal ~= nil then
		if entryVal >= 0 then
			local lR = math.floor(entryVal / 100);
			local lY = math.floor(entryVal / 10) - (lR * 10);
			local lG = entryVal - (lY * 10) - (lR * 100);
			local rOn, yOn, gOn = false, false, false;
			if lR > 0 then rOn = true end;
			if lY > 0 then yOn = true end;
			if lG > 0 then gOn = true end;

			if self.trafficSignEntry.redLight ~= nil then setVisibility(self.trafficSignEntry.redLight, rOn) end;
			if self.trafficSignEntry.yellowLight ~= nil then setVisibility(self.trafficSignEntry.yellowLight, yOn) end;
			if self.trafficSignEntry.greenLight ~= nil then setVisibility(self.trafficSignEntry.greenLight, gOn) end;
		end;
	end;
end;

function scaleStation:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self)
	if self.triggerId ~= nil and self.triggerId > 0 then
		removeTrigger(self.triggerId);
	end;
	if self.rootNode ~= nil and self.rootNode > 0 then
		delete(self.rootNode);
	end;
	scaleStation:superClass().delete(self);
end;

function scaleStation:readStream(streamId, connection)
	scaleStation:superClass().readStream(self, streamId);
	if connection:getIsServer() then 		-- Client wenn TRUE
		local saveId = streamReadString(streamId);
		local pName = streamReadString(streamId);
		local fType = streamReadInt32(streamId);
		local fTypeMass = streamReadFloat32(streamId);
		scaleStation:addPlayerOrFruit(saveId,pName,fType,fTypeMass,0)
	end;
end;

function scaleStation:writeStream(streamId, connection)
	scaleStation:superClass().writeStream(self, streamId);
	if not connection:getIsServer() then 	-- Server wenn FALSE
		self.dataSend.sync = 2;
		streamWriteString(streamId, Utils.getNoNil(self.dataSend.saveId,self.saveId));
		streamWriteString(streamId, Utils.getNoNil(self.dataSend.player,"NONE"));
		streamWriteInt32(streamId, Utils.getNoNil(self.dataSend.fillType,0));
		streamWriteFloat32(streamId, Utils.getNoNil(self.dataSend.mass,0));
	end;
end;

function scaleStation:readUpdateStream(streamId, timestamp, connection)
	scaleStation:superClass().readUpdateStream(self, streamId, timestamp, connection);
	if connection:getIsServer() then 		-- Client wenn TRUE
		local saveId = streamReadString(streamId);
		local pName = streamReadString(streamId);
		local fType = streamReadInt32(streamId);
		local fTypeMass = streamReadFloat32(streamId);
		scaleStation:addPlayerOrFruit(saveId,pName,fType,fTypeMass,0)
	end;
end;

function scaleStation:writeUpdateStream(streamId, connection, dirtyMask)
	scaleStation:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	if not connection:getIsServer() then 	-- Server wenn FALSE
		self.dataSend.sync = 2;
		streamWriteString(streamId, Utils.getNoNil(self.dataSend.saveId,self.saveId));
		streamWriteString(streamId, Utils.getNoNil(self.dataSend.player,"NONE"));
		streamWriteInt32(streamId, Utils.getNoNil(self.dataSend.fillType,0));
		streamWriteFloat32(streamId, Utils.getNoNil(self.dataSend.mass,0));
	end;
end;

function scaleStation:update(dt)
	if self.isEnabled  then
		if g_currentMission:getIsServer() then
			if self.requestSend == 1 then
				self.requestSend = 2;
				for a,b in pairs(self.player) do
					if a ~= nil and b.name == a then
						for c,d in pairs(b.fillTypes) do
							if c ~= nil and d ~= nil and d > 0 then
								g_server:broadcastEvent(syncRequestSend:new(self, self.saveId, b.name, c, d, Utils.getNoNil(self.playerUserId,0)), nil, nil, self);
							end;
						end;
					end;
				end;
				for c,d in pairs(self.playerFruits) do
					if c ~= nil and d ~= nil and d > 0 then
						g_server:broadcastEvent(syncRequestSend:new(self, self.saveId, "FRUIT", c, d, Utils.getNoNil(self.playerUserId,0)), nil, nil, self);
					end;
				end;
			end;
		else
			if self.requestTimer == 0 then
				self.requestTimer = -1;
				g_client:getServerConnection():sendEvent(massSyncRequest:new(self, self.saveId, g_currentMission.playerUserId));
			elseif self.requestTimer > 0 then
				self.requestTimer = self.requestTimer -1;
			end;
		end;

		if self.vehiclesInTriggerCount <= 0 then
			self.showHud = false;
			self.timerSet = 0;
			self.timerCnt = 0;
			self.showWarn = false;
			self.sumMass = 0;
			self.sumMassLoad = 0;
			self.zwMass = 0;
			self.overweight = false;
			if self.workLights.on ~= nil then setVisibility(self.workLights.on,false) end;
			if self.workLights.off ~= nil then setVisibility(self.workLights.off,true) end;
		else
			if self.workLights.on ~= nil then setVisibility(self.workLights.on,true) end;
			if self.workLights.off ~= nil then setVisibility(self.workLights.off,false) end;
		end;

		if self.plate.index ~= nil then
			if self.plate.mass ~= self.plate.massOld then
				local posy = self.plate.max - (((self.plate.max - self.plate.min) / 120000) * self.plate.mass);
				local yChanged = (self.plate.max - self.plate.min) / 300;
				local mChanged = self.plate.mass / 300;
				local x, y, z = getTranslation(self.plate.index);
				local y2 = y;
				if self.plate.mass > self.plate.massOld then
					y2 = y2 - yChanged;
					self.plate.massOld = self.plate.massOld + mChanged;
					if posy < y2 then posy = y2 end;
				elseif self.plate.mass < self.plate.massOld then
					y2 = y2 + yChanged;
					self.plate.massOld = self.plate.massOld - mChanged;
					if posy > y2 then posy = y2 end;
				end;
				if posy < self.plate.min then
					posy = self.plate.min;
					self.plate.massOld = self.plate.mass;
				elseif posy > self.plate.max then
					posy = self.plate.max;
					self.plate.massOld = self.plate.mass;
				end;
				if y2 ~= y then
					setTranslation(self.plate.index, x, posy, z);
				end;
			end;
		end;

		local schowMe = false;
		-- Timer Sets
		-- 0 = no vehicle on scale
		-- 1 = vehicle drive on scale
		-- 2 = vehicle overall weight is measured
		-- 3 = vehicle drive away allowed
		-- 4 = vehicle fill weight is measured
		if self.timerSet == 0 then
			if self.timerSet ~= self.timerSetLast then self:setLightState(1,100) end;
		elseif self.timerSet == 1 then
			if self.timerSet ~= self.timerSetLast then self:setLightState(10,100) end;
		elseif self.timerSet == 2 then
			if self.timerSet ~= self.timerSetLast then self:setLightState(100,100) end;
			self.showWarn = true;
			self.warnMessage = self.i18n:getText("ScaleWarn1");
		elseif self.timerSet == 4 then
			if self.timerSet ~= self.timerSetLast then self:setLightState(100,110) self:setScaleDisplay(self.display2,self.sumMass) end;
			self.showWarn = true;
			self.warnMessage = self.i18n:getText("scaleWarn2");
		elseif self.timerSet == 3 then
			if self.timerSet ~= self.timerSetLast then self:setLightState(100,1) end;
			self.showWarn = true;
			self.warnMessage = self.i18n:getText("scaleReady");
		end;
		if self.timerSet ~= self.timerSetLast then
			if self.timerSet >= 1 then
				self.playerName, self.sumMass, self.sumMassLoad, self.fillTypes = self:getScaleMass();
				if self.sumMass > 80000 and not self.overweight then self.overweight = true end;
			else
				self.playerName = "Unknown";
				self.sumMass = 0;
				self.sumMassLoad = 0;
				self:setScaleDisplay(self.display1,0);
				self:setScaleDisplay(self.display2,0);
				self.overweight = false;
			end;
			self.timerSetLast = self.timerSet;
		end;
		if self.timerSet > 1 then
			self.showHud = true;
			if self.timerCnt >= timerDef then
				if self.timerSet == 2 then
					self.zwMass = self.sumMass;
					self.timerSet = 4;
				elseif self.timerSet == 4 then
					self.zwMass = self.sumMassLoad;
					self.sumMass = self.sumMassLoad;
					self.timerSet = 3;
					self.warnMessage = self.i18n:getText("scaleReady");
				end;
				self.timerCnt = 0;
				self.showWarn = true;
			else
				self.timerCnt = self.timerCnt + 1;
			end;
			if self.timerSet == 2 then
				self.zwMass = self.sumMass;
				if self.timerCnt < (timerDef * 0.9) then self.zwMass = math.random(self.sumMass - (self.sumMass / self.timerCnt), self.sumMass + (self.sumMass / self.timerCnt)) end;
				self.showWarn = true;
				self.warnMessage = self.i18n:getText("scaleWarn1");
				if math.random(1,10) > 5 then self:setScaleDisplay(self.display1, self.zwMass) end;
				if schowMe == true then  end;
			elseif self.timerSet == 4 then
				if self.timerCnt < (timerDef * 0.9) then
					local diff = self.zwMass - self.sumMassLoad;
					local fac = (timerDef * 0.91) - self.timerCnt;
					self.zwMass = self.zwMass - ((diff) / (fac));
				else
					self.zwMass = self.sumMassLoad;
				end;
				self.showWarn = true;
				self.warnMessage = self.i18n:getText("scaleWarn2");
				if math.random(1,10) > 6 then self:setScaleDisplay(self.display1, self.zwMass) end;
			elseif self.timerSet == 3 then
				if self.zwMass > 0 then
					self:setScaleDisplay(self.display1, self.zwMass);
					mustAdded = true;
					if self.playerName ~= nil then
						if table.maxn(self.fillTypes) > 0 then
							for p=1, FillUtil.NUM_FILLTYPES do
								if self.fillTypes[p] ~= nil and self.fillTypes[p] > 0 then
									if g_server ~= nil then
										g_server:broadcastEvent(syncRequestSend:new(self, self.saveId, self.playerName, p, self.fillTypes[p], 0), nil, nil, self);
										self.dataSend.sync = 1;
										self.dataSend.saveId = self.saveId;
										self.dataSend.player = self.playerName;
										self.dataSend.fillType = p;
										self.dataSend.mass = self.fillTypes[p];
										self:addPlayerOrFruit(self.saveId,self.playerName,p,self.fillTypes[p],0)
									end;
								end;
							end;
						end;
					end;
					self.zwMass = 0;
				end;
			end;
		else
			if self.dataSend.sync == 2 then
				self.dataSend.sync = 0;
				self.dataSend.fillType = 0;
				self.dataSend.mass = 0;
				self.dataSend.saveId = nil;
				self.dataSend.player = nil;
			end;
		end;
	end;
end;

function scaleStation:resetSelf(player, noEventSend)
	if player == nil then player = "NONE" end;
	if noEventSend == nil or noEventSend == false then
		self.isSender = true;
		g_client:getServerConnection():sendEvent(massResetEvent:new(self, player));
	end;
	if (noEventSend and not self.isSender) or (self.isSender and (noEventSend == nil or noEventSend == false)) then

		-- "NONE"			komplette Waage wird resettet inklusive Spieler darin und Daten der Spieler global
		-- "ALL"			alle Spieler einer Waage werden gelöscht, global bei Spielern die Daten dieser Waage, die Daten der Waage an sich bleiben jedoch erhalten
		-- playerName		einzelner Spieler wird aus der Waage gelöscht

		if player == "NONE" or player == "ALL" then
			for a,b in pairs(self.player) do
				if a ~= nil and b.name == a then
					local ply = g_currentMission.scaleStation.players[a];
					if ply ~= nil and ply.scales[self.saveId] ~= nil and ply.scales[self.saveId] == self then
						ply.scales[self.saveId] = nil;
						ply.numScales = math.max(0,ply.numScales - 1);
						if ply.numFillTypes > 0 then
							for c,d in pairs(self.player[a].fillTypes) do
								if c ~= nil and d > 0 then
									ply.overallMass = math.max(0,ply.overallMass - d);
									ply.fillTypes[c] = math.max(0,ply.fillTypes[c] - d);
									if ply.fillTypes[c] == 0 then
										ply.fillTypes[c] = nil;
										ply.numFillTypes = math.max(0,ply.numFillTypes - 1);
									end;
								end;
							end;
						end;
					end;
				end;
			end;
			if player == "NONE" then
				for a,b in pairs(self.playerFruits) do
					if g_currentMission.scaleStation.fruits[a] ~= nil then
						if g_currentMission.scaleStation.fruits[a].scale ~= nil and g_currentMission.scaleStation.fruits[a].scale[self.saveId] ~= nil then
							g_currentMission.scaleStation.fruits[a].scale[self.saveId] = nil;
							g_currentMission.scaleStation.fruits[a].numScales = g_currentMission.scaleStation.fruits[a].numScales - 1;
							g_currentMission.scaleStation.fruits[a].mass = g_currentMission.scaleStation.fruits[a].mass - b;
							if g_currentMission.scaleStation.fruits[a].mass <= 0 or g_currentMission.scaleStation.fruits[a].numScale <= 0 then
								g_currentMission.scaleStation.fruits[a] = nil;
							end;
						end;
					end;
				end;
				self.dataSend = {};
				self.dataSend.sync = 0;
				self.dataSend.player = nil;
				self.dataSend.saveId = nil;
				self.dataSend.mass = 0;
				self.dataSend.fillType = 0;
				self.overallMass = 0;
				self.playerFruits = {};
			end;
			self.playerCount = 0;
			self.player = {};
		else
			if self.player[player] ~= nil then
				local ply = g_currentMission.scaleStation.players[player];
				if ply ~= nil and ply.scales[self.saveId] ~= nil and ply.scales[self.saveId] == self then
					ply.scales[self.saveId] = nil;
					ply.numScales = math.max(0,ply.numScales - 1);
					if ply.numFillTypes > 0 then
						for c,d in pairs(self.player[a].fillTypes) do
							if c ~= nil and d > 0 then
								ply.overallMass = math.max(0,ply.overallMass - d);
								ply.fillTypes[c] = math.max(0,ply.fillTypes[c] - d);
								if ply.fillTypes[c] == 0 then
									ply.fillTypes[c] = nil;
									ply.numFillTypes = math.max(0,ply.numFillTypes - 1);
								end;
							end;
						end;
					end;
				end;
				self.player[player] = nil;
				self.playerCount = math.max(0,self.playerCount - 1);
			end;
		end;
	end;
end;

function scaleStation:getScaleMass()
	local pName, mass, massLoad = nil, 0, 0;
	local fillTypes = {};
	for vId,vIn in pairs(self.vehiclesInTrigger) do
		if vIn and vId ~= nil then
			local vehicle = g_currentMission.nodeToVehicle[vId];
			if vehicle ~= nil then
				if SpecializationUtil.hasSpecialization(Steerable, vehicle.specializations) then
					pName = vehicle.controllerName;
				end;
				mass = mass + Utils.getNoNil(vehicle:getTotalMass(),0) * 1000;
				if vehicle.fillUnits ~= nil then
					for _,fillUnit in pairs(vehicle.fillUnits) do
						if fillUnit.currentFillType ~= FillUtil.FILLTYPE_UNKNOWN then
							local fruitMass = (Utils.getNoNil(fillUnit.fillLevel,0) * Utils.getNoNil(FillUtil.fillTypeIndexToDesc[fillUnit.currentFillType].massPerLiter,0.0004) * 1000);
							fillTypes[fillUnit.currentFillType] = Utils.getNoNil(fillTypes[fillUnit.currentFillType],0) + fruitMass;
							massLoad = massLoad + fruitMass;
							local correcter = (fruitMass * g_currentMission.scaleWeightFactor) - fruitMass;
							fillTypes[fillUnit.currentFillType] = fillTypes[fillUnit.currentFillType] + correcter;
							massLoad = massLoad + correcter;
							mass = mass + correcter;
						end;
					end;
				end;
			end;
		end;
	end;
	return pName, mass, massLoad, fillTypes;
end;

function scaleStation:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if self.isEnabled  then
		local vehicle = g_currentMission.nodeToVehicle[otherId];
		if vehicle ~= nil then
			if onEnter then
				local doInsert = true;
				if self.vehiclesInTrigger[otherId] then doInsert = false end;
				if vehicle.massTrigger ~= nil and vehicle.massTrigger == self then doInsert = false end;
				if doInsert == true then
					self.vehiclesInTriggerCount = self.vehiclesInTriggerCount + 1;
					self.vehiclesInTrigger[otherId] = true;
					vehicle.massTrigger = self;
					self.plate.mass = self.plate.mass + (vehicle:getTotalMass() * 1000);
				end;
				if self.timerSet == 0 then
					self.timerSet = 1;
					self.timerSetLast = 0;
				end;
			elseif onLeave then
				if self.vehiclesInTrigger[otherId] or (vehicle.massTrigger ~= nil and vehicle.massTrigger == self) then
					self.vehiclesInTrigger[otherId] = nil;
					vehicle.massTrigger = nil;
					self.vehiclesInTriggerCount = self.vehiclesInTriggerCount - 1;
					if self.vehiclesInTriggerCount <= 0 then
						self.vehiclesInTriggerCount = 0;
						self.timerSet = 0;
						self.timerSetLast = 1;
					end;
					self.plate.mass = self.plate.mass - (vehicle:getTotalMass() * 1000);
					if self.plate.mass <= 0 then
						self.plate.mass = 0;
						self.timerSet = 0;
						self.timerSetLast = 1;
					end;
				end;
			end;
		end;
	end;
end;

function scaleStation:setScaleDisplay(display,mass)
	if display == nil then return end
	if display.digits == nil or (display.digits ~= nil and table.getn(display.digits) == 0) then return end
	local overweight = self.overweight;
	if mass > 0 then
		if display.workLights.ok ~= nil then setVisibility(display.workLights.ok,(not overweight)) end;
		if display.workLights.fault ~= nil then setVisibility(display.workLights.fault,overweight) end;
		if display.digits[0].digiK ~= nil then setShaderParameter(display.digits[0].digiK, "number", tonumber(display.defaultK), 0, 0, 0, false) end;
		if display.digits[0].digiG ~= nil then setShaderParameter(display.digits[0].digiG, "number", tonumber(display.defaultG), 0, 0, 0, false) end;
		if display.digits[0].digiE ~= nil then setShaderParameter(display.digits[0].digiE, "number", tonumber(display.defaultOff), 0, 0, 0, false) end;
		if display.digits[0].digiOff ~= nil then setShaderParameter(display.digits[0].digiOff, "number", tonumber(display.defaultOff), 0, 0, 0, false) end;
		for i=1, #display.digits do
			local number = math.floor(mass - (math.floor(mass / 10) * 10));
			mass = math.floor(mass / 10);
			if overweight == true then
				setShaderParameter(display.digits[i].id, "number", tonumber(display.defaultMinus), 0, 0, 0, false);
				if display.digits[i].dot ~= nil then
					setVisibility(display.digits[i].dot,false);
				end;
				if display.digiE ~= nil then setShaderParameter(display.digiE, "number", tonumber(display.defaultE), 0, 0, 0, false) end;
			elseif number <= 0 and mass <= 0 then
				setShaderParameter(display.digits[i].id, "number", tonumber(display.defaultOff), 0, 0, 0, false);
				if display.digits[i].dot ~= nil then
					setVisibility(display.digits[i].dot,false);
				end;
			else
				setShaderParameter(display.digits[i].id, "number", number, 0, 0, 0, false);
				if display.digits[i].dot ~= nil then
					setVisibility(display.digits[i].dot,true);
				end;
			end;
		end;
	else
		if display.workLights.ok ~= nil then setVisibility(display.workLights.ok,false) end;
		if display.workLights.fault ~= nil then setVisibility(display.workLights.fault,false) end;
		if display.digits[0].digiK ~= nil then setShaderParameter(display.digits[0].digiK, "number", tonumber(display.defaultOff), 0, 0, 0, false) end;
		if display.digits[0].digiG ~= nil then setShaderParameter(display.digits[0].digiG, "number", tonumber(display.defaultOff), 0, 0, 0, false) end;
		if display.digits[0].digiE ~= nil then setShaderParameter(display.digits[0].digiE, "number", tonumber(display.defaultOff), 0, 0, 0, false) end;
		if display.digits[0].digiOff ~= nil then setShaderParameter(display.digits[0].digiOff, "number", tonumber(display.defaultOff), 0, 0, 0, false) end;
		for i=1, #display.digits do
			setShaderParameter(display.digits[i].id, "number", tonumber(display.defaultOff), 0, 0, 0, false);
			if display.digits[i].dot ~= nil then
				setVisibility(display.digits[i].dot,false);
			end;
		end;
	end;
end;

function scaleStation:loadFromAttributesAndNodes(xmlFile, key)
	local saveId = Utils.getNoNil(getXMLString(xmlFile,key.."#saveId"),nil);
	local playersKey = string.format(key..".players");
	if hasXMLProperty(xmlFile, playersKey) then
		local i = 0;
		while true do
			local player = string.format(playersKey..".player(%d)",i);
			if not hasXMLProperty(xmlFile, player) then
				break;
			end;
			local playerName = getXMLString(xmlFile,player.."#playerName");
			local playerMass = getXMLFloat(xmlFile,player.."#mass");
			local playerFruitCount = getXMLInt(xmlFile,player.."#numFruits");
			if playerFruitCount > 0 then
				for x=0, playerFruitCount - 1 do
					local playerFruit = string.format(player..".fruits(%d)",x);
					if hasXMLProperty(xmlFile, playerFruit) then
						local fillType = getXMLString(xmlFile,playerFruit.."#fillType");
						local fillMass = getXMLFloat(xmlFile,playerFruit.."#fillMass");
						local fillType = FillUtil.fillTypeNameToInt[fillType];
						if fillType ~= nil and fillType ~= FillUtil.FILLTYPE_UNKNOWN then
							scaleStation:addPlayerOrFruit(self.saveId,playerName,fillType,fillMass,0);
						end;
					end;
				end;
			end;
			i = i + 1;
		end;
	end;
	local fruitsKey = string.format(key..".scaleFruits");
	if hasXMLProperty(xmlFile, fruitsKey) then
		local scaleFruitCount = getXMLInt(xmlFile,fruitsKey.."#numFruits");
		for i=0, scaleFruitCount-1 do
			local fruit = string.format(fruitsKey..".fruits(%d)",i);
			if not hasXMLProperty(xmlFile, fruit) then
				break;
			end;
			local fillType = getXMLString(xmlFile,fruit.."#fillType");
			local fillMass = getXMLFloat(xmlFile,fruit.."#fillMass");
			if fillType ~= nil then
				local fillType = FillUtil.fillTypeNameToInt[fillType];
				if fillType ~= nil and fillType ~= FillUtil.FILLTYPE_UNKNOWN then
					scaleStation:addPlayerOrFruit(self.saveId,"FRUIT",fillType,fillMass,0);
				end;
			end;
		end;
	end;
	self.overallMass = Utils.getNoNil(getXMLFloat(xmlFile,key.."#mass"),0);
	return true;
end;

function scaleStation:getSaveAttributesAndNodes(nodeIdent)
	local attributes = 'mass="' .. tostring(self.overallMass) .. '"';
	local nodes = "";
	local ident = '    ';
	if self.player ~= nil then
		local playersStart = nodeIdent..'<players>';
		local playersEnd = nodeIdent..'</players>';
		local player = "";
		for k,v in pairs(self.player) do
			player = player..'\n'..nodeIdent..ident..'<player playerName="'..tostring(k)..'" mass="'..tostring(v.mass)..'"';
			local numFillTypes = 0;
			local fillTypes = "";
			if v.fillTypes ~= nil then
				for g=1, FillUtil.NUM_FILLTYPES do
					if v.fillTypes[g] ~= nil and v.fillTypes[g] > 0 then
						fillTypes = fillTypes..'\n'..nodeIdent..ident..ident..'<fruits fillType="'..tostring(FillUtil.fillTypeIntToName[g])..'" fillMass="'..tostring(v.fillTypes[g])..'" />';
						numFillTypes = numFillTypes + 1;
					end;
				end;
			end;
			player = player..' numFruits="'..tostring(numFillTypes)..'"';
			if numFillTypes > 0 then
				player = player..'>'..fillTypes..'\n'..nodeIdent..ident..'</player>';
			else
				player = player..'/>';
			end;
		end;
		nodes = nodes..playersStart..player..'\n'..playersEnd;
	end;
	if self.playerFruits ~= nil then
		local fruitsStart = nodeIdent..'<scaleFruits';
		local fruitsEnd = nodeIdent..'</scaleFruits>';
		local fruit = "";
		local numFillTypes = 0;
		local fillTypes = "";
		for g=1, FillUtil.NUM_FILLTYPES do
			if self.playerFruits[g] ~= nil and self.playerFruits[g] > 0 then
				fruit = fruit..'\n'..nodeIdent..ident..'<fruits fillType="'..tostring(FillUtil.fillTypeIntToName[g])..'" fillMass="'..tostring(self.playerFruits[g])..'" />';
				numFillTypes = numFillTypes + 1;
			end;
		end;
		if numFillTypes > 0 then
			if string.len(nodes) > 0 then nodes = nodes..'\n' end;
			nodes = nodes..fruitsStart..' numFruits="'..tostring(numFillTypes)..'">'..fruit..'\n'..fruitsEnd;
		end;
	end;
	return attributes, nodes;
end;

g_onCreateUtil.addOnCreateFunction("scaleStationOnCreate", scaleStation.onCreate);


----------------  EVENTS  ------------------
--------------------------------------------

massSyncRequest = {}
massSyncRequest_mt = Class(massSyncRequest, Event)
InitEventClass(massSyncRequest, "massSyncRequest")
function massSyncRequest:emptyNew()
	local self = Event:new(massSyncRequest_mt);
	return self;
end;
function massSyncRequest:new(rStation, saveId, pId)
	local self = massSyncRequest:emptyNew()
	self.rStation = rStation;
	self.saveId = saveId;
	self.pId = pId;
	return self;
end;
function massSyncRequest:readStream(streamId, connection)
	self.rStation = readNetworkNodeObject(streamId);
	self.saveId = streamReadString(streamId);
	self.pId = streamReadInt8(streamId);
	self:run(connection);
end;
function massSyncRequest:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.rStation);
	streamWriteString(streamId, self.saveId);
	streamWriteInt8(streamId, self.pId);
end;
function massSyncRequest:run(connection)
	if not connection:getIsServer() then
		if g_currentMission.scaleStation ~= nil then
			for a,b in pairs(g_currentMission.scaleStation) do
				if a == self.saveId and type(b) == "table" and b.saveId == self.saveId then
					b.requestSend = 1;
					b.playerUserId = self.pId;
				end;
			end;
		end;
	end;
end;


massResetEvent = {}
massResetEvent_mt = Class(massResetEvent, Event)
InitEventClass(massResetEvent, "massResetEvent")
function massResetEvent:emptyNew()
    local self = Event:new(massResetEvent_mt);
    return self;
end;
function massResetEvent:new(rStation,player)
    local self = massResetEvent:emptyNew()
    self.rStation = rStation;
    self.player = player;
    return self;
end;
function massResetEvent:readStream(streamId, connection)
    self.rStation = readNetworkNodeObject(streamId);
    self.player = streamReadString(streamId);
    self:run(connection);
end;
function massResetEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.rStation);
    streamWriteString(streamId, self.player);
end;
function massResetEvent:run(connection)
	if g_currentMission.scaleStation ~= nil then
		for a,b in pairs(g_currentMission.scaleStation) do
			if b ~= nil and b == self.rStation and b.saveId == a then
				b:resetSelf(self.player, true);
			end;
		end;
	end;
end;


syncRequestSend = {}
syncRequestSend_mt = Class(syncRequestSend, Event)
InitEventClass(syncRequestSend, "syncRequestSend")
function syncRequestSend:emptyNew()
	local self = Event:new(syncRequestSend_mt);
	return self;
end;
function syncRequestSend:new(station,saveId,pName,fType,fTypeMass,pId)
	local self = syncRequestSend:emptyNew()
	self.station = station;
	self.saveId = saveId;
	self.pName = pName;
	self.fType = fType;
	self.fTypeMass = fTypeMass;
	self.pId = pId;
	return self;
end;
function syncRequestSend:readStream(streamId, connection)
	if connection:getIsServer() then
		self.station = readNetworkNodeObject(streamId);
		self.saveId = streamReadString(streamId)			-- scale saveId
		self.pName = streamReadString(streamId)				-- player name
		self.fType = streamReadInt32(streamId)				-- fillType
		self.fTypeMass = streamReadFloat32(streamId)			-- fillType mass
		self.pId = streamReadInt8(streamId)				-- player id of player who request it, is 0 on normal gameplay, only for start sync needed 
	end
	self:run(connection);
end;
function syncRequestSend:writeStream(streamId, connection)
	if not connection:getIsServer() then
		writeNetworkNodeObject(streamId, self.station);
		streamWriteString(streamId, self.saveId);
		streamWriteString(streamId, self.pName);
		streamWriteInt32(streamId, self.fType);
		streamWriteFloat32(streamId, self.fTypeMass);
		streamWriteInt8(streamId, self.pId);
	end
end;
function syncRequestSend:run(connection)
	-- run only on clients
	if connection:getIsServer() then
		scaleStation:addPlayerOrFruit(self.saveId,self.pName,self.fType,self.fTypeMass,self.pId)
	end;
end;


-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------

scaleStationOverview = {}
scaleStationOverview.modDir = g_currentModDirectory

function scaleStationOverview:loadMap(name)
	if g_currentMission.scaleStation == nil then g_currentMission.scaleStation = {} end;
	if g_currentMission.scaleStation.hudPath == nil then
		g_currentMission.scaleStation.hudPath = scaleStationOverview.modDir.."huds/";
	end;
	self.ssov = {};
	self.ssov.hud = createImageOverlay(Utils.getFilename("handheld.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.up_hover = createImageOverlay(Utils.getFilename("handheld_up_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.up_press = createImageOverlay(Utils.getFilename("handheld_up_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.down_hover = createImageOverlay(Utils.getFilename("handheld_down_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.down_press = createImageOverlay(Utils.getFilename("handheld_down_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.left_hover = createImageOverlay(Utils.getFilename("handheld_left_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.left_press = createImageOverlay(Utils.getFilename("handheld_left_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.right_hover = createImageOverlay(Utils.getFilename("handheld_right_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.right_press = createImageOverlay(Utils.getFilename("handheld_right_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.ok_hover = createImageOverlay(Utils.getFilename("handheld_ok_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.ok_press = createImageOverlay(Utils.getFilename("handheld_ok_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.menu_hover = createImageOverlay(Utils.getFilename("handheld_menu_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.menu_press = createImageOverlay(Utils.getFilename("handheld_menu_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.off_hover = createImageOverlay(Utils.getFilename("handheld_off_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.off_press = createImageOverlay(Utils.getFilename("handheld_off_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.extra_hover = createImageOverlay(Utils.getFilename("handheld_extra_hover.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.extra_press = createImageOverlay(Utils.getFilename("handheld_extra_press.dds", g_currentMission.scaleStation.hudPath));
	self.ssov.W = 0.86;
	self.ssov.H = 0.8;
	self.ssov.X = 0.07;
	self.ssov.Y = 0.08;
	self.ssov.user = {};
	self.ssov.tmr = 0;
	self.ssov.lastUser = 0;
	self.ssov.page = 0;
	self.ssov.subPage = 0;
	self.ssov.subSubPage = 0;
	self.ssov.pageMax = 0;
	self.ssov.subPageMax = 0;
	self.ssov.subSubPageMax = 0;
	self.ssov.active = 0;
	self.ssov.mode = 0;
	self.ssov.reset = -1;
	self.ssov.button = 0;
	self.ssov.pressTimer = 0;
	self.ssov.entrys = {};
	self.ssov.players = {};
	self.ssov.fillTypes = {};
	self.buttonLock = 0;
	
	self.mpx = 0;
	self.mpy = 0;
	self.showMC = false;
	self.camFix = false;
end;

function scaleStationOverview:deleteMap()
end;

function scaleStationOverview:readStream(streamId, connection)
	self.ssov.reset = streamReadBool(streamId);
end;

function scaleStationOverview:writeStream(streamId, connection)
	streamWriteBool(streamId, self.ssov.reset);
end;

function scaleStationOverview:mouseEvent(posX, posY, isDown, isUp, button)
	self.mpx = posX;
	self.mpy = posY;
	local overButton = 0;

	if self.showMC then
		-- OFF Button
		if posX > 0.841 and posX < 0.863 and posY > 0.653 and posY < 0.685 then
			overButton = 1;
		end;
		-- MENU Button
		if posX > 0.841 and posX < 0.863 and posY > 0.587 and posY < 0.619 then
			overButton = 2;
		end;
		-- OK Button
		if posX > 0.851 and posX < 0.872 and posY > 0.459 and posY < 0.492 then
			overButton = 3;
		end;
		-- LEFT Button
		if posX > 0.82 and posX < 0.843 and posY > 0.459 and posY < 0.492 then
			overButton = 4;
		end;
		-- RIGHT Button
		if posX > 0.881 and posX < 0.903 and posY > 0.459 and posY < 0.492 then
			overButton = 5;
		end;
		-- UP Button
		if posX > 0.851 and posX < 0.872 and posY > 0.513 and posY < 0.547 then
			overButton = 6;
		end;
		-- DOWN Button
		if posX > 0.851 and posX < 0.872 and posY > 0.402 and posY < 0.438 then
			overButton = 7;
		end;
		-- EXTRA 1 Button
		if posX > 0.823 and posX < 0.876 and posY > 0.34 and posY < 0.381 then
			overButton = 8;
		end;
		-- EXTRA 2 Button
		if posX > 0.823 and posX < 0.876 and posY > 0.28 and posY < 0.321 then
			overButton = 9;
		end;
		-- EXTRA 3 Button
		if posX > 0.823 and posX < 0.876 and posY > 0.22 and posY < 0.261 then
			overButton = 10;
		end;

		if isDown then
			self.ssov.pressTimer = 35;
			if self.ssov.mode >= 1 and self.ssov.mode <= 3 then
				if self.ssov.entrys ~= nil and self.ssov.entrys.mode ~= nil and self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
					local marker = 0;
					for i=1, self.ssov.entrys.entrys do
						if self.ssov.entrys[i] ~= nil and self.ssov.entrys[i].x1 ~= nil then
							if posX >= self.ssov.entrys[i].x1 and posX <= self.ssov.entrys[i].x2 and posY >= self.ssov.entrys[i].y1 and posY < self.ssov.entrys[i].y2 then
								self.ssov.entrys[i].active = true;
								self.ssov.players = {};
								self.ssov.fillTypes = {};
								marker = i;
							end;
						end;
					end;
					if marker > 0 then
						for i=1, self.ssov.entrys.entrys do
							if self.ssov.entrys[i] ~= nil then
								if i ~= marker then
									self.ssov.entrys[i].active = false;
								end;
							end;
						end;
					end;
				end;
			end;
			if self.ssov.mode >= 10 and self.ssov.mode <= 35 then
				if self.ssov.players ~= nil and self.ssov.players.mode ~= nil and self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
					local marker = 0;
					for i=1, self.ssov.players.entrys do
						if self.ssov.players[i] ~= nil and self.ssov.players[i].x1 ~= nil then
							if posX >= self.ssov.players[i].x1 and posX <= self.ssov.players[i].x2 and posY >= self.ssov.players[i].y1 and posY < self.ssov.players[i].y2 then
								self.ssov.players[i].active = true;
								self.ssov.fillTypes = {};
								marker = i;
							end;
						end;
					end;
					if marker > 0 then
						for i=1, self.ssov.players.entrys do
							if self.ssov.players[i] ~= nil then
								if i ~= marker then
									self.ssov.players[i].active = false;
								end;
							end;
						end;
					end;
				end;
			end;
		end;
		if isUp and button == 1 then
			self:setMenuState(false, overButton);
		end;
		
		self.ssov.button = overButton;
	else
		self.ssov.button = 0;
	end;
end;

function scaleStationOverview:keyEvent(unicode, sym, modifier, isDown)
end;

function scaleStationOverview:setMenuState(valBool, valInt1, valInt2)

	-- Menu-Übersicht:
	--
	-- 0			==	Hauptmenü
	-- 1			==	Waagenübersicht - Waagen-Anzeige
	-- + 10		==	Waagenübersicht - Waagen-Anzeige - Einzelwaage - Anzeige Spieler
	-- + + 100	==	Waagenübersicht - Waagen-Anzeige - Einzelwaage - Anzeige Spieler - einzelner Spieler mit FillTypes
	-- + 15		==	Waagenübersicht - Waagen-Anzeige - Einzelwaage - Anzeige FillTypes
	-- + + 150	==	Waagenübersicht - Waagen-Anzeige - Einzelwaage - Anzeige FillTypes - einzelner FillType mit Spielern
	-- 2			==	Spielerübersicht - Spieler-Anzeige
	-- + 20		==	Spielerübersicht - Spieler-Anzeige - Einzelspieler - Anzeige FillTypes
	-- + + 200	==	Spielerübersicht - Spieler-Anzeige - Einzelspieler - Anzeige FillTypes - einzelner Filltype bei welcher Waage
	-- + 25		==	Spielerübersicht - Spieler-Anzeige - Einzelspieler - Anzeige Waagen
	-- + + 250	==	Spielerübersicht - Spieler-Anzeige - Einzelspieler - Anzeige Waagen - einzelne Waage mit FillTypes
	-- 3			==	Ladungsübersicht - Ladung-Anzeige

	valBool = Utils.getNoNil(valBool, true);
	if valInt1 == 1 then -- OFF BUTTON
		self.showMC = valBool;
		InputBinding.setShowMouseCursor(valBool);
		if valBool then
			g_gui.currentGui = self;
		else
			g_gui.currentGui = nil;
		end;
	elseif valInt1 == 2 then -- MENU BUTTON
		self.ssov.mode = 0;
		self.ssov.entrys = {};
		self.ssov.active = nil;
		self.ssov.players.active = nil;
		self.ssov.fillTypes.active = nil;
	elseif valInt1 == 3 then -- OK BUTTON
		if self.ssov.mode == 10 then
			if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
				for i=1, self.ssov.players.entrys do
					if self.ssov.players[i].active and self.ssov.players[i].player ~= nil then
						self.ssov.players.active = self.ssov.active.player[self.ssov.players[i].name];
						self.ssov.mode = 100;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 25 then
			if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
				for i=1, self.ssov.players.entrys do
					if self.ssov.players[i].active and self.ssov.players[i].scale ~= nil then
						self.ssov.players.active = self.ssov.players[i].scale;
						self.ssov.mode = 250;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 20 then
			if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
				for i=1, self.ssov.players.entrys do
					if self.ssov.players[i].active and self.ssov.players[i].fruit ~= nil and self.ssov.players[i].numFruitScales > 0 then
						self.ssov.players.active = self.ssov.players[i].fruit;
						self.ssov.mode = 200;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 15 then
			if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
				for i=1, self.ssov.players.entrys do
					if self.ssov.players[i].active and self.ssov.players[i].fruit ~= nil then
						self.ssov.players.active = self.ssov.players[i].fruit;
						self.ssov.mode = 150;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 1 then
			if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
				for i=1, self.ssov.entrys.entrys do
					if self.ssov.entrys[i].active and self.ssov.entrys[i].scale ~= nil then
						self.ssov.active = self.ssov.entrys[i].scale;
						self.ssov.mode = 10;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 2 then
			if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
				for i=1, self.ssov.entrys.entrys do
					if self.ssov.entrys[i].active and self.ssov.entrys[i].player ~= nil then
						self.ssov.active = self.ssov.entrys[i].player;
						self.ssov.mode = 20;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 3 then
			if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
				for i=1, self.ssov.entrys.entrys do
					if self.ssov.entrys[i].active and self.ssov.entrys[i].fruit ~= nil then
						self.ssov.active = self.ssov.entrys[i].fruit;
						self.ssov.mode = 30;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 30 then
			if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
				for i=1, self.ssov.players.entrys do
					if self.ssov.players[i].active and self.ssov.players[i].scale ~= nil then
						self.ssov.players.active = self.ssov.players[i].scale;
						self.ssov.mode = 300;
						break;
					end;
				end;
			end;
		elseif self.ssov.mode == 35 then
			if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
				for i=1, self.ssov.players.entrys do
					if self.ssov.players[i].active and self.ssov.players[i].player ~= nil then
						self.ssov.players.active = self.ssov.players[i].player;
						self.ssov.mode = 350;
						break;
					end;
				end;
			end;
		end;
	elseif valInt1 == 4 then -- LEFT BUTTON
		if self.ssov.mode >= 1 and self.ssov.mode <= 3 then
			self:setMenuState(true,2);
		elseif self.ssov.mode == 10 then
			self.ssov.mode = 1;
		elseif self.ssov.mode == 15 then
			self.ssov.mode = 10;
		elseif self.ssov.mode == 20 then
			self.ssov.mode = 2;
		elseif self.ssov.mode == 25 then
			self.ssov.mode = 20;
		elseif self.ssov.mode == 30 then
			self.ssov.mode = 3;
		elseif self.ssov.mode == 35 then
			self.ssov.mode = 30;
		elseif self.ssov.mode == 100 then
			self.ssov.mode = 10;
		elseif self.ssov.mode == 150 then
			self.ssov.mode = 15;
		elseif self.ssov.mode == 200 then
			self.ssov.mode = 20;
		elseif self.ssov.mode == 250 then
			self.ssov.mode = 25;
		elseif self.ssov.mode == 300 then
			self.ssov.mode = 30;
		elseif self.ssov.mode == 350 then
			self.ssov.mode = 35;
		end;
	elseif valInt1 == 5 then -- RIGHT BUTTON
		if self.ssov.mode == 10 then
			self.ssov.mode = 15;
		elseif self.ssov.mode == 20 then
			self.ssov.mode = 25;
		elseif self.ssov.mode == 30 then
			self.ssov.mode = 35;
		end;
	elseif valInt1 == 6 then -- UP BUTTON
		if self.ssov.mode >= 1 and self.ssov.mode <= 3 then
			self.ssov.page = self.ssov.page - 1;
			if self.ssov.page < 0 then
				self.ssov.page = 0;
			end;
		elseif self.ssov.mode >= 10 and self.ssov.mode <= 35 then
			self.ssov.subPage = self.ssov.subPage - 1;
			if self.ssov.subPage < 0 then
				self.ssov.subPage = 0;
			end;
		elseif self.ssov.mode >= 100 and self.ssov.mode <= 350 then
			self.ssov.subSubPage = self.ssov.subSubPage - 1;
			if self.ssov.subSubPage < 0 then
				self.ssov.subSubPage = 0;
			end;
		end;
	elseif valInt1 == 7 then -- DOWN BUTTON
		if self.ssov.mode >= 1 and self.ssov.mode <= 3 then
			self.ssov.page = self.ssov.page + 1;
		elseif self.ssov.mode >= 10 and self.ssov.mode <= 35 then
			self.ssov.subPage = self.ssov.subPage + 1;
		elseif self.ssov.mode >= 100 and self.ssov.mode <= 350 then
			self.ssov.subSubPage = self.ssov.subSubPage + 1;
		end;
	elseif valInt1 == 8 then -- EXTRA 1 BUTTON
		if self.ssov.mode == 0 then
			self.ssov.mode = 1;
		elseif self.ssov.mode == 1 or self.ssov.mode == 15 then
			-- Einzelne Waage zurücksetzen
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
					for i=1, self.ssov.entrys.entrys do
						if self.ssov.entrys[i].active and self.ssov.entrys[i].scale ~= nil then
							self.ssov.entrys[i].scale:resetSelf("NONE");
							self.ssov.entrys = nil;
							self.ssov.entrys = {};
							break;
						end;
					end;
				end;
			end;
		elseif self.ssov.mode == 25 then
			-- Einzelnen Spieler von einer Waage zurücksetzen
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				if self.ssov.active ~= nil and self.ssov.active.numScales > 0 then
					if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
						for x=1,self.ssov.players.entrys do
							if self.ssov.players[x].active then
								self.ssov.entrys[i].scale:resetSelf(self.ssov.active.name);
								self.ssov.players = nil;
								self.ssov.players = {};
								break;
							end;
						end;
					end;
				end;
			end;
		elseif self.ssov.mode == 10 then
			-- Einzelnen Spieler einer Waage zurücksetzen
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
					for i=1, self.ssov.entrys.entrys do
						if self.ssov.entrys[i].active and self.ssov.entrys[i].scale ~= nil then
							if self.ssov.players.entrys ~= nil and self.ssov.players.entrys > 0 then
								for x=1,self.ssov.players.entrys do
									if self.ssov.players[x].active then
										self.ssov.entrys[i].scale:resetSelf(self.ssov.players[x].name);
										self.ssov.players = nil;
										self.ssov.players = {};
										break;
									end;
								end;
							end;
						end;
					end;
				end;
			end;
		elseif self.ssov.mode == 2 or self.ssov.mode == 20 then
			-- Einzelnen Spieler von allen Waage zurücksetzen
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
					for i=1, self.ssov.entrys.entrys do
						if self.ssov.entrys[i].active and self.ssov.entrys[i].player ~= nil and self.ssov.entrys[i].player.name ~= nil then
							if self.ssov.entrys[i].player.numScales ~= nil and self.ssov.entrys[i].player.numScales > 0 then
								for x,y in pairs(self.ssov.entrys[i].player.scales) do
									if type(y) == "table" and y.saveId ~= nil then
										y:resetSelf(self.ssov.entrys[i].player.name);
									end;
								end;
							end;
							g_currentMission.scaleStation.players[self.ssov.entrys[i].player.name] = nil;
						end;
					end;
				end;
			end;
		end;
	elseif valInt1 == 9 then -- EXTRA 2 BUTTON
		if self.ssov.mode == 0 then
			self.ssov.mode = 2;
		elseif self.ssov.mode == 1 then
			-- alle Waagen resetten
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				for a, b in pairs(g_currentMission.scaleStation) do
					if b~= nil and type(b) == "table" and b.saveId == a then
						b:resetSelf("NONE");
						self.ssov.players = nil;
						self.ssov.players = {};
					end;
				end;
			end;
		elseif self.ssov.mode == 2 then
			-- alle Fahrer von allen Waage resetten
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
					for i=1, self.ssov.entrys.entrys do
						if self.ssov.entrys[i].scale ~= nil then
							self.ssov.entrys[i].scale:resetSelf("ALL");
							self.ssov.players = nil;
							self.ssov.players = {};
						end;
					end;
				end;
			end;
		elseif self.ssov.mode == 10 then
			-- alle Fahrer einer Waage resetten
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				if self.ssov.entrys.entrys ~= nil and self.ssov.entrys.entrys > 0 then
					for i=1, self.ssov.entrys.entrys do
						if self.ssov.entrys[i].active and self.ssov.entrys[i].scale ~= nil then
							self.ssov.entrys[i].scale:resetSelf("ALL");
							self.ssov.players = nil;
							self.ssov.players = {};
							break;
						end;
					end;
				end;
			end;
		elseif self.ssov.mode == 25 then
			-- Einzelnen Spieler von allen Waage zurücksetzen
			if (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false then
				if self.ssov.active ~= nil and self.ssov.active.numScales > 0 then
					for x,y in pairs(self.ssov.active.scales) do
						if type(y) == "table" and y.saveId ~= nil and y.saveId == x then
							y:resetSelf(self.ssov.active.name);
						end;
					end;
					g_currentMission.scaleStation.players[self.ssov.active.name] = nil;
				end;
			end;
		end;
	elseif valInt1 == 10 then -- EXTRA 3 BUTTON
		if self.ssov.mode == 0 then
			self.ssov.mode = 3;
		end;
	end;
end;

function scaleStationOverview:update(dt)
	if InputBinding.hasEvent(InputBinding.SCALESTATION_SHOW) then
		if self.buttonLock <= 0 then
			self.buttonLock = 10;
			self:setMenuState(not self.showMC,1);
		end;
	end;
	if self.buttonLock > 0 then
		self.buttonLock = self.buttonLock - 1;
	end;

	if self.showMC then
		if self.ssov.pressTimer > 0 then
			self.ssov.pressTimer = self.ssov.pressTimer - 1;
		end;

		-- Page Checker
		if self.ssov.mode == 1 then
			local maxPages = math.max(math.ceil(g_currentMission.scaleStation.scaleCount / 20) - 1,0);
			self.ssov.pageMax = maxPages;
			if self.ssov.page > maxPages then
				self.ssov.page = maxPages;
			end;
		end;
		if self.ssov.mode == 2 then
			local maxPages = math.max(math.ceil(g_currentMission.scaleStation.playerCount / 20) - 1,0);
			self.ssov.pageMax = maxPages;
			if self.ssov.page > maxPages then
				self.ssov.page = maxPages;
			end;
		end;
		if self.ssov.mode == 3 then
			local maxPages = math.max(math.ceil(g_currentMission.scaleStation.numFruits / 20) - 1,0);
			self.ssov.pageMax = maxPages;
			if self.ssov.page > maxPages then
				self.ssov.page = maxPages;
			end;
		end;
		if self.ssov.mode == 10 then
			if self.ssov.active.playerCount > 0 then
				local maxPages = math.max(math.ceil(self.ssov.active.playerCount / 20) - 1,0);
				self.ssov.subPageMax = maxPages;
				if self.ssov.subPage > maxPages then
					self.ssov.subPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 15 then
			if type(self.ssov.active.playerFruits) and  #self.ssov.active.playerFruits > 0 then
				local maxPages = math.max(math.ceil(#self.ssov.active.playerFruits / 20) - 1,0);
				self.ssov.subPageMax = maxPages;
				if self.ssov.subPage > maxPages then
					self.ssov.subPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 20 then
			if self.ssov.active.numFillTypes > 0 then
				local maxPages = math.max(math.ceil(self.ssov.active.numFillTypes / 20) - 1,0);
				self.ssov.subPageMax = maxPages;
				if self.ssov.subPage > maxPages then
					self.ssov.subPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 25 then
			if self.ssov.active.numScales > 0 then
				local maxPages = math.max(math.ceil(self.ssov.active.numScales / 20) - 1,0);
				self.ssov.subPageMax = maxPages;
				if self.ssov.subPage > maxPages then
					self.ssov.subPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 30 then
			if self.ssov.active.numScales > 0 then
				local maxPages = math.max(math.ceil(self.ssov.active.numScales / 20) - 1,0);
				self.ssov.subPageMax = maxPages;
				if self.ssov.subPage > maxPages then
					self.ssov.subPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 35 then
			if self.ssov.active.numPlayer > 0 then
				local maxPages = math.max(math.ceil(self.ssov.active.numPlayer / 20) - 1,0);
				self.ssov.subPageMax = maxPages;
				if self.ssov.subPage > maxPages then
					self.ssov.subPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 100 then
			if self.ssov.players.active ~= nil and self.ssov.players.active.fillTypes ~= nil and table.maxn(self.ssov.players.active.fillTypes) > 0 then
				local tmp = 0;
				for i=1, table.maxn(self.ssov.players.active.fillTypes) do
					if self.ssov.players.active.fillTypes[i] ~= nil and self.ssov.players.active.fillTypes[i] > 0 then
						tmp = tmp + 1;
					end;
				end;
				local maxPages = math.max(math.ceil(tmp / 20) - 1,0);
				self.ssov.subSubPageMax = maxPages;
				if self.ssov.subSubPage > maxPages then
					self.ssov.subSubPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 150 then
			if type(self.ssov.active.playerFruits) == "table" and #self.ssov.active.playerFruits > 0 and type(self.ssov.active.player) == "table" then
				local tmp = 0;
				for x,y in pairs(self.ssov.active.player) do
					if y ~= nil and type(y.fillTypes) == "table" and y.fillTypes[self.ssov.players.active] ~= nil and y.fillTypes[self.ssov.players.active] > 0 then
						tmp = tmp + 1;
					end;
				end;
				local maxPages = math.max(math.ceil(tmp / 20) - 1,0);
				self.ssov.subSubPageMax = maxPages;
				if self.ssov.subSubPage > maxPages then
					self.ssov.subSubPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 200 then
			if self.ssov.active.numFillTypes > 0 and self.ssov.active.fillTypes[self.ssov.players.active] > 0 then
				local tmp = 0;
				for x,y in pairs(self.ssov.active.scales) do
					if x ~= nil and y ~= nil and type(y) == "table" and y.player[self.ssov.active.name] ~= nil and y.player[self.ssov.active.name].fillTypes ~= nil and y.player[self.ssov.active.name].fillTypes[self.ssov.players.active] ~= nil then
						tmp = tmp + 1;
					end;
				end;
				local maxPages = math.max(math.ceil(tmp / 20) - 1,0);
				self.ssov.subSubPageMax = maxPages;
				if self.ssov.subSubPage > maxPages then
					self.ssov.subSubPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 250 then
			if self.ssov.players.active ~= nil and self.ssov.players.active.saveId ~= nil and self.ssov.players.active.player ~= nil and self.ssov.players.active.player[self.ssov.active.name] ~= nil then
				local tmp = 0;
				local ft = self.ssov.players.active.player[self.ssov.active.name];
				if ft.numFillTypes ~= nil and ft.numFillTypes > 0 then
					for x,y in pairs(ft.fillTypes) do
						if x ~= nil and y ~= nil and y > 0 then
							tmp = tmp + 1;
						end;
					end;
				end;
				local maxPages = math.max(math.ceil(tmp / 20) - 1,0);
				self.ssov.subSubPageMax = maxPages;
				if self.ssov.subSubPage > maxPages then
					self.ssov.subSubPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 300 then
			if self.ssov.players.active ~= nil and self.ssov.players.active.saveId ~= nil and self.ssov.players.active.player ~= nil then
				local tmp = 0;
				for c,d in pairs(self.ssov.players.active.player) do
					if c ~= nil and type(d) == "table" and d.name == c then
						if d.fillTypes ~= nil and d.fillTypes[self.ssov.active.fillType] ~= nil and d.fillTypes[self.ssov.active.fillType] > 0 then
							tmp = tmp + 1;
						end;
					end;
				end;
				local maxPages = math.max(math.ceil(tmp / 20) - 1,0);
				self.ssov.subSubPageMax = maxPages;
				if self.ssov.subSubPage > maxPages then
					self.ssov.subSubPage = maxPages;
				end;
			end;
		end;
		if self.ssov.mode == 350 then
			if self.ssov.players.active ~= nil and self.ssov.players.active.name ~= nil and self.ssov.players.active.scales ~= nil and self.ssov.players.active.numScales > 0 then
				local tmp = 0;
				for c,d in pairs(self.ssov.players.active.scales) do
					if c ~= nil and d ~= nil and d.saveId == c then
						if d.player[self.ssov.players.active.name] ~= nil and d.player[self.ssov.players.active.name].fillTypes ~= nil and d.player[self.ssov.players.active.name].fillTypes[self.ssov.active.fillType] ~= nil and d.player[self.ssov.players.active.name].fillTypes[self.ssov.active.fillType] > 0 then
							tmp = tmp + 1;
						end;
					end;
				end;
				local maxPages = math.max(math.ceil(tmp / 20) - 1,0);
				self.ssov.subSubPageMax = maxPages;
				if self.ssov.subSubPage > maxPages then
					self.ssov.subSubPage = maxPages;
				end;
			end;
		end;
	end;
end;

function scaleStationOverview:draw()
	if self.showMC then
		renderOverlay(self.ssov.hud, self.ssov.X, self.ssov.Y, self.ssov.W, self.ssov.H);
		local bt = self.ssov.button;
		local tmr = self.ssov.pressTimer;
		local isMaster = (g_currentMission.missionDynamicInfo.isMultiplayer and g_currentMission.isMasterUser) or g_currentMission.missionDynamicInfo.isMultiplayer == false;
		if bt > 0 then
			if bt == 1 then
				if tmr > 0 then
					renderOverlay(self.ssov.off_press, 0.8363, 0.640, 0.033, 0.0535);
				else
					renderOverlay(self.ssov.off_hover, 0.8363, 0.640, 0.033, 0.0535);
				end;
			elseif bt == 2 then
				if tmr > 0 then
					renderOverlay(self.ssov.menu_press, 0.8363, 0.575, 0.033, 0.0535);
				else
					renderOverlay(self.ssov.menu_hover, 0.8363, 0.575, 0.033, 0.0535);
				end;
			elseif bt == 3 then
				if tmr > 0 then
					renderOverlay(self.ssov.ok_press, 0.8475, 0.453, 0.030, 0.045);
				else
					renderOverlay(self.ssov.ok_hover, 0.8475, 0.453, 0.030, 0.045);
				end;
			elseif bt == 4 then
				if tmr > 0 then
					renderOverlay(self.ssov.left_press, 0.8175, 0.453, 0.030, 0.045);
				else
					renderOverlay(self.ssov.left_hover, 0.8175, 0.453, 0.030, 0.045);
				end;
			elseif bt == 5 then
				if tmr > 0 then
					renderOverlay(self.ssov.right_press, 0.8783, 0.453, 0.030, 0.045);
				else
					renderOverlay(self.ssov.right_hover, 0.8783, 0.453, 0.030, 0.045);
				end;
			elseif bt == 6 then
				if tmr > 0 then
					renderOverlay(self.ssov.up_press, 0.8475, 0.5075, 0.030, 0.045);
				else
					renderOverlay(self.ssov.up_hover, 0.8475, 0.5075, 0.030, 0.045);
				end;
			elseif bt == 7 then
				if tmr > 0 then
					renderOverlay(self.ssov.down_press, 0.848, 0.3975, 0.030, 0.045);
				else
					renderOverlay(self.ssov.down_hover, 0.848, 0.3975, 0.030, 0.045);
				end;
			elseif bt == 8 then
				if tmr > 0 then
					renderOverlay(self.ssov.extra_press, 0.8185, 0.335, 0.0645, 0.0505);
				else
					renderOverlay(self.ssov.extra_hover, 0.8185, 0.335, 0.0645, 0.0505);
				end;
			elseif bt == 9 then
				if tmr > 0 then
					renderOverlay(self.ssov.extra_press, 0.8185, 0.275, 0.0645, 0.0505);
				else
					renderOverlay(self.ssov.extra_hover, 0.8185, 0.275, 0.0645, 0.0505);
				end;
			elseif bt == 10 then
				if tmr > 0 then
					renderOverlay(self.ssov.extra_press, 0.8185, 0.216, 0.0645, 0.0505);
				else
					renderOverlay(self.ssov.extra_hover, 0.8185, 0.216, 0.0645, 0.0505);
				end;
			end;
		end;

		-- TextArea
		-- Start:   X: 0.121  Y: 0.737  bis X: 0.802  Y: 0.737
		-- Ende:    x: 0.121  Y: 0.194  bis X: 0.802  Y: 0.194
		
		setTextBold(true);
		setTextAlignment(RenderText.ALIGN_LEFT);
		setTextColor(1,1,0.8314,1);
		renderText(0.118, 0.733, 0.017, "_________________________________________________________________________________________________________________________________________________________________________________");
		renderText(0.120, 0.733, 0.017, "_________________________________________________________________________________________________________________________________________________________________________________");
		renderText(0.122, 0.733, 0.017, "_________________________________________________________________________________________________________________________________________________________________________________");

		if self.ssov.mode > 0 then
			renderText(0.118, 0.25, 0.017, "_________________________________________________________________________________________________________________________________________________________________________________");
			renderText(0.120, 0.25, 0.017, "_________________________________________________________________________________________________________________________________________________________________________________");
			renderText(0.122, 0.25, 0.017, "_________________________________________________________________________________________________________________________________________________________________________________");
		end;

		renderText(0.121, 0.737, 0.017, g_i18n:getText("scaleString1"));

		local modeButton1 = g_i18n:getText("scaleString4");
		local modeButton2 = g_i18n:getText("scaleString5");
		local modeButton3 = g_i18n:getText("scaleString11");
		if self.ssov.mode == 0 then  -- Hauptmenü
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2")); -- Hauptmenü Menütext

			renderText(0.125, 0.691, 0.016, g_i18n:getText("scaleText1").." "..scaleStation.version);
			setTextBold(false);
			setTextWrapWidth(0.655);
			renderText(0.125, 0.660, 0.016, g_i18n:getText("scaleText2")); -- Hauptmenü Menütext
			setTextWrapWidth(1);
		elseif self.ssov.mode == 150 then
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString4").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString11").." -> "..tostring(FillUtil.fillTypeIndexToDesc[Utils.getNoNil(self.ssov.players.active,0)].nameI18N)); -- Waagendetails Menütext

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString17").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.playerFruits[self.ssov.players.active]).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subSubPage * 20) + 1;
			local offset = (self.ssov.subSubPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subSubPage+1,self.ssov.subSubPageMax+1));
			setTextBold(true);
			renderText(posX+0.33, 0.691, 0.016, g_i18n:getText("scaleString12"));
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.016, g_i18n:getText("scaleString5"));
			setTextBold(false);
			if self.ssov.active.playerFruits[self.ssov.players.active] > 0 and self.ssov.players.active > 0 then
				local i = start;
				local q = 0;
				for x,y in pairs(self.ssov.active.player) do
					if y ~= nil and type(y.fillTypes) == "table" and y.fillTypes[self.ssov.players.active] ~= nil and y.fillTypes[self.ssov.players.active] > 0 then
						q = q + 1;
						if q >= i and q < (start + 20) then
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, posY, 0.016, tostring(y.name));
							setTextAlignment(RenderText.ALIGN_RIGHT);
							renderText(posX+0.33, posY, 0.016, tostring(g_i18n:formatReadableNumber(y.fillTypes[self.ssov.players.active]).." kg"));
							posY = posY - 0.02;
							setTextAlignment(RenderText.ALIGN_LEFT);
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText23"));
		elseif self.ssov.mode == 100 then
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString4").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString5").." -> "..tostring(self.ssov.players.active.name)); -- Waagendetails Menütext

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString10").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.players.active.mass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subSubPage * 20) + 1;
			local offset = (self.ssov.subSubPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subSubPage+1,self.ssov.subSubPageMax+1));
			setTextBold(true);
			renderText(posX+0.33, 0.691, 0.016, g_i18n:getText("scaleString12"));
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.016, g_i18n:getText("scaleString11"));
			setTextBold(false);
			if table.maxn(self.ssov.players.active.fillTypes) > 0 then
				i = start;
				x = 1;
				while x < (start + 20) do
					if self.ssov.players.active.fillTypes[i] ~= nil and self.ssov.players.active.fillTypes[i] > 0 then
						setTextAlignment(RenderText.ALIGN_LEFT);
						renderText(posX, posY, 0.016, tostring(FillUtil.fillTypeIndexToDesc[i].nameI18N));
						setTextAlignment(RenderText.ALIGN_RIGHT);
						renderText(posX+0.33, posY, 0.016, tostring(g_i18n:formatReadableNumber(self.ssov.players.active.fillTypes[i]).." kg"));
						posY = posY - 0.02;
						x = x + 1;
						setTextAlignment(RenderText.ALIGN_LEFT);
					end;
					i = i + 1;
					if i > table.maxn(self.ssov.players.active.fillTypes) then
						x = start + 20;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText23"));
		elseif self.ssov.mode == 15 then			-- Übersicht einer Waage mit Fruchtauflistung
			if (self.ssov.players.mode ~= nil and (self.ssov.players.mode ~= 15 or self.ssov.players.page ~= self.ssov.subPage)) or self.ssov.players.mode == nil then
				self.ssov.players = nil;
				self.ssov.players = {};
				self.ssov.players.mode = 15;
				self.ssov.players.page = self.ssov.subPage;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString4").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString11")); -- Waagendetails Menütext

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString9").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.overallMass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local gcm = g_currentMission.scaleStation;
			local start = (self.ssov.subPage * 20) + 1;
			local offset = (self.ssov.subPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			if isMaster then modeButton1 = g_i18n:getText("scaleString14") end;
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subPage+1,self.ssov.subPageMax+1));
			setTextBold(true);
			renderText(posX+0.33, 0.691, 0.016, g_i18n:getText("scaleString8"));
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.016, g_i18n:getText("scaleString11"));
			setTextBold(false);
			if isMaster then renderText(posX, 0.195, 0.015, g_i18n:getText("scaleText8")) end;
			local i = 0;
			local isOk = false;
			if type(self.ssov.active.playerFruits) == "table" then
				for c,d in pairs(self.ssov.active.playerFruits) do
					if FillUtil.fillTypeIndexToDesc[c] ~= nil and d > 0 then
						i = i + 1;
						if i >= start and i <= math.min(#self.ssov.active.playerFruits,start+19) then
							entrys = entrys + 1;
							if self.ssov.players[i-offset] == nil then
								self.ssov.players[i-offset] = {};
								self.ssov.players[i-offset].x1 = posX;
								self.ssov.players[i-offset].y1 = posY - 0.004;
								self.ssov.players[i-offset].x2 = posX + 0.5;
								self.ssov.players[i-offset].y2 = self.ssov.players[i-offset].y1 + 0.015;
								self.ssov.players[i-offset].active = false;
								self.ssov.players[i-offset].fruit = c;
								self.ssov.players[i-offset].fruitDesc = FillUtil.fillTypeIndexToDesc[c];
								self.ssov.players[i-offset].fruitMass = d;
							end;
							if self.ssov.players[i-offset].active then
								setTextColor(0.3,1,0.3,1);
								isOk = true;
							else
								setTextColor(1,1,0.8314,1);
							end;
							self.ssov.players.entrys = entrys;
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, posY, 0.016, tostring(self.ssov.players[i-offset].fruitDesc.nameI18N));
							setTextAlignment(RenderText.ALIGN_RIGHT);
							renderText(posX+0.33, posY, 0.016, tostring(g_i18n:formatReadableNumber(d).." kg"));
							posY = posY - 0.02;
							setTextAlignment(RenderText.ALIGN_LEFT);
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			if isOk then
				renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText16").." "..g_i18n:getText("scaleText15"));
			else
				renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText15"));
			end;
		elseif self.ssov.mode == 10 then			-- Übersicht einer Waage mit Spielerauflistung
			if (self.ssov.players.mode ~= nil and (self.ssov.players.mode ~= 10 or self.ssov.players.page ~= self.ssov.subPage)) or self.ssov.players.mode == nil then
				self.ssov.players = nil;
				self.ssov.players = {};
				self.ssov.players.mode = 10;
				self.ssov.players.page = self.ssov.subPage;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString4").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString5")); -- Waagendetails Menütext

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString9").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.overallMass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subPage * 20) + 1;
			local offset = (self.ssov.subPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			if isMaster then modeButton2 = g_i18n:getText("scaleString15") end;
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subPage+1,self.ssov.subPageMax+1));
			setTextBold(true);
			renderText(posX+0.33, 0.691, 0.016, g_i18n:getText("scaleString8"));
			renderText(posX+0.48, 0.691, 0.016, g_i18n:getText("scaleString11"));
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.016, g_i18n:getText("scaleString5"));
			setTextBold(false);
			if isMaster then renderText(posX, 0.195, 0.015, g_i18n:getText("scaleText9")) end;
			local i = 0;
			if self.ssov.active.playerCount > 0 then
				for c,d in pairs(self.ssov.active.player) do
					if type(d) == "table" and d.name ~= nil then
						i = i + 1;
						if i >= start and i <= math.min(self.ssov.active.playerCount,start+19) then
							entrys = entrys + 1;
							if self.ssov.players[i-offset] == nil then
								self.ssov.players[i-offset] = {};
								self.ssov.players[i-offset].x1 = posX;
								self.ssov.players[i-offset].y1 = posY - 0.004;
								self.ssov.players[i-offset].x2 = posX + 0.5;
								self.ssov.players[i-offset].y2 = self.ssov.players[i-offset].y1 + 0.015;
								self.ssov.players[i-offset].active = false;
								self.ssov.players[i-offset].player = i;
								self.ssov.players[i-offset].name = d.name;
							end;
							if self.ssov.players[i-offset].active then
								modeButton1 = g_i18n:getText("scaleString14");
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, 0.213, 0.015, g_i18n:getText("scaleText10"));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								setTextColor(0.3,1,0.3,1);
							else
								setTextColor(1,1,0.8314,1);
							end;
							self.ssov.players.entrys = entrys;
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, posY, 0.016, tostring(d.name));
							setTextAlignment(RenderText.ALIGN_RIGHT);
							renderText(posX+0.33, posY, 0.016, tostring(g_i18n:formatReadableNumber(d.mass).." kg"));
							local tmp = 0
							for x=1, FillUtil.NUM_FILLTYPES do
								if d.fillTypes[x] ~= nil and d.fillTypes[x] > 0 then
									tmp = tmp + 1;
								end;
							end;
							renderText(posX+0.48, posY, 0.016, tostring(tmp));
							posY = posY - 0.02;
							setTextAlignment(RenderText.ALIGN_LEFT);
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			if modeButton1 == g_i18n:getText("scaleString14") then
				renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText11").." "..g_i18n:getText("scaleText14"));
			else
				renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText14"));
			end;
		elseif self.ssov.mode == 1 then			-- Übersicht der Waagen
			if (self.ssov.entrys.mode ~= nil and (self.ssov.entrys.mode ~= 1 or self.ssov.entrys.page ~= self.ssov.page)) or self.ssov.entrys.mode == nil then
				self.ssov.entrys = nil;
				self.ssov.entrys = {};
				self.ssov.entrys.mode = 1;
				self.ssov.entrys.page = self.ssov.page;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString4")); -- Waagen Menütext

			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleText3"));

			local posX = 0.150;
			local posY = 0.670;
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.692, 0.0155, g_i18n:getText("scaleString4"));
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(posX+0.25, 0.692, 0.0155, g_i18n:getText("scaleString12"));
			renderText(posX+0.35, 0.692, 0.0155, g_i18n:getText("scaleString5"));
			renderText(posX+0.45, 0.692, 0.0155, g_i18n:getText("scaleString11"));
			setTextBold(false);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.page+1,self.ssov.pageMax+1));
			local gcm = g_currentMission.scaleStation;
			local start = (self.ssov.page * 20) + 1;
			local offset = (self.ssov.page * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			if isMaster then modeButton2 = g_i18n:getText("scaleString15") end;
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_LEFT);
			if isMaster then renderText(posX, 0.195, 0.015, g_i18n:getText("scaleText7")) end;
			setTextAlignment(RenderText.ALIGN_RIGHT);
			local i = 0;
			for a,b in pairs(gcm) do
				if type(b) == "table" and b ~= nil and b.saveId ~= nil then
					i = i + 1;
					if i >= start and i <= (start + 19) then
						entrys = entrys + 1;
						if self.ssov.entrys[i-offset] == nil then
							self.ssov.entrys[i-offset] = {};
							self.ssov.entrys[i-offset].x1 = posX;
							self.ssov.entrys[i-offset].y1 = posY - 0.004;
							self.ssov.entrys[i-offset].x2 = posX + 0.5;
							self.ssov.entrys[i-offset].y2 = self.ssov.entrys[i-offset].y1 + 0.015;
							self.ssov.entrys[i-offset].active = false;
							self.ssov.entrys[i-offset].scale = b;
						end;
						if self.ssov.entrys[i-offset].active then
							modeButton1 = g_i18n:getText("scaleString14");
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, 0.213, 0.015, g_i18n:getText("scaleText8"));
							renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText6"));
							setTextAlignment(RenderText.ALIGN_RIGHT);
							setTextColor(0.3,1,0.3,1);
						else
							setTextColor(1,1,0.8314,1);
						end;
						self.ssov.entrys.entrys = entrys;
						setTextAlignment(RenderText.ALIGN_LEFT);
						renderText(posX, posY, 0.016, b.name);
						setTextAlignment(RenderText.ALIGN_RIGHT);
						renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(b.overallMass).." kg"));
						renderText(posX+0.35, posY, 0.016, tostring(b.playerCount));
						local tmp = 0
						for x=1, FillUtil.NUM_FILLTYPES do
							if b.playerFruits[x] ~= nil and b.playerFruits[x] > 0 then
								tmp = tmp + 1;
							end;
						end;
						renderText(posX+0.45, posY, 0.016, tostring(tmp));
						posY = posY - 0.02;
					end;
				end;
			end;
		elseif self.ssov.mode == 250 then
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString5").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString4").." -> "..tostring(self.ssov.players.active.name));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString21").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.players.active.player[self.ssov.active.name].mass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subSubPage * 20) + 1;
			local offset = (self.ssov.subSubPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subSubPage+1,self.ssov.subSubPageMax+1));
			setTextBold(true);
			renderText(posX+0.35, 0.691, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.0155, g_i18n:getText("scaleString11"));		-- Filltypes
			setTextBold(false);
			if self.ssov.players.active.player[self.ssov.active.name].numFillTypes > 0 then
				local i = start;
				local x = 1;
				for c,d in pairs(self.ssov.players.active.player[self.ssov.active.name].fillTypes) do
					if c ~= nil and c > 0 and d ~= nil and d > 0 then
						if FillUtil.fillTypeIndexToDesc[c] ~= nil then
							x = x + 1;
							if x >= i and x < (start + 20) then
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, posY, 0.016, tostring(FillUtil.fillTypeIndexToDesc[c].nameI18N));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								renderText(posX+0.33, posY, 0.016, tostring(g_i18n:formatReadableNumber(d).." kg"));
								posY = posY - 0.02;
								setTextAlignment(RenderText.ALIGN_LEFT);
							end;
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText23"));
		elseif self.ssov.mode == 200 then
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString5").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString11").." -> "..tostring(FillUtil.fillTypeIndexToDesc[Utils.getNoNil(self.ssov.players.active,0)].nameI18N));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString20").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.fillTypes[self.ssov.players.active]).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subSubPage * 20) + 1;
			local offset = (self.ssov.subSubPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subSubPage+1,self.ssov.subSubPageMax+1));
			setTextBold(true);
			renderText(posX+0.35, 0.691, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.0155, g_i18n:getText("scaleString4"));		-- Waagen
			setTextBold(false);
			if self.ssov.active.numScales > 0 then
				local i = start;
				local x = 1;
				for c,d in pairs(self.ssov.active.scales) do
					if c ~= nil and type(d) == "table" and d.saveId == c then
						if d.player[self.ssov.active.name] ~= nil and d.player[self.ssov.active.name].fillTypes ~= nil and d.player[self.ssov.active.name].fillTypes[self.ssov.players.active] ~= nil then
							x = x + 1;
							if x >= i and x < (start + 20) then
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, posY, 0.016, tostring(d.name));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								renderText(posX+0.33, posY, 0.016, tostring(g_i18n:formatReadableNumber(d.player[self.ssov.active.name].fillTypes[self.ssov.players.active]).." kg"));
								posY = posY - 0.02;
								setTextAlignment(RenderText.ALIGN_LEFT);
							end;
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText23"));
		elseif self.ssov.mode == 25 then
			if (self.ssov.players.mode ~= nil and (self.ssov.players.mode ~= 25 or self.ssov.players.page ~= self.ssov.subPage)) or self.ssov.players.mode == nil then
				self.ssov.players = nil;
				self.ssov.players = {};
				self.ssov.players.mode = 25;
				self.ssov.players.page = self.ssov.subPage;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString5").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString4"));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString19").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.overallMass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subPage * 20) + 1;
			local offset = (self.ssov.subPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			if isMaster then modeButton2 = g_i18n:getText("scaleString15") end;
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subPage+1,self.ssov.subPageMax+1));
			setTextBold(true);
			renderText(posX+0.25, 0.691, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			renderText(posX+0.35, 0.691, 0.0155, g_i18n:getText("scaleString11"));		-- Filltypes
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.0155, g_i18n:getText("scaleString4"));		-- Waagen
			setTextBold(false);
			if isMaster then renderText(posX, 0.195, 0.015, g_i18n:getText("scaleText12")) end;
			local i = 0;
			local isOk = false;
			if self.ssov.active.numScales > 0 then
				for c,d in pairs(self.ssov.active.scales) do
					if c ~= nil and d ~= nil and d.saveId ~= nil and d.player[self.ssov.active.name] ~= nil then
						i = i + 1;
						if i >= start and i <= math.min(self.ssov.active.numScales,start+19) then
							entrys = entrys + 1;
							if self.ssov.players[i-offset] == nil then
								self.ssov.players[i-offset] = {};
								self.ssov.players[i-offset].x1 = posX;
								self.ssov.players[i-offset].y1 = posY - 0.004;
								self.ssov.players[i-offset].x2 = posX + 0.5;
								self.ssov.players[i-offset].y2 = self.ssov.players[i-offset].y1 + 0.015;
								self.ssov.players[i-offset].active = false;
								self.ssov.players[i-offset].player = d.player[self.ssov.active.name];
								self.ssov.players[i-offset].scale = d;
								self.ssov.players[i-offset].numPlayerFillTypes = d.player[self.ssov.active.name].numFillTypes;
							end;
							if self.ssov.players[i-offset].active then
								modeButton1 = g_i18n:getText("scaleString14");
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, 0.213, 0.015, g_i18n:getText("scaleText18"));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								setTextColor(0.3,1,0.3,1);
								isOk = true;
							else
								setTextColor(1,1,0.8314,1);
							end;
							self.ssov.players.entrys = entrys;
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, posY, 0.016, tostring(d.name));
							setTextAlignment(RenderText.ALIGN_RIGHT);
							renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(d.player[self.ssov.active.name].mass).." kg"));
							renderText(posX+0.35, posY, 0.016, tostring(d.player[self.ssov.active.name].numFillTypes));
							posY = posY - 0.02;
							setTextAlignment(RenderText.ALIGN_LEFT);
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			if osOk == true then
				renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText6").." "..g_i18n:getText("scaleText22"));
			else
				renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText22"));
			end;
		elseif self.ssov.mode == 20 then
			if (self.ssov.players.mode ~= nil and (self.ssov.players.mode ~= 20 or self.ssov.players.page ~= self.ssov.subPage)) or self.ssov.players.mode == nil then
				self.ssov.players = nil;
				self.ssov.players = {};
				self.ssov.players.mode = 20;
				self.ssov.players.page = self.ssov.subPage;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString5").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString11"));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString19").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.overallMass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subPage * 20) + 1;
			local offset = (self.ssov.subPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			if isMaster then modeButton2 = g_i18n:getText("scaleString15") end;
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subPage+1,self.ssov.subPageMax+1));
			setTextBold(true);
			renderText(posX+0.25, 0.691, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			renderText(posX+0.35, 0.691, 0.0155, g_i18n:getText("scaleString4"));		-- Waagen
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.0155, g_i18n:getText("scaleString11"));		-- Filltype
			setTextBold(false);
			if isMaster then renderText(posX, 0.195, 0.015, g_i18n:getText("scaleText12")) end;
			local i = 0;
			if self.ssov.active.numFillTypes > 0 then
				for c,d in pairs(self.ssov.active.fillTypes) do
					if c ~= nil and d > 0 then
						i = i + 1;
						if i >= start and i <= math.min(self.ssov.active.numFillTypes,start+19) then
							entrys = entrys + 1;
							if self.ssov.players[i-offset] == nil then
								self.ssov.players[i-offset] = {};
								self.ssov.players[i-offset].x1 = posX;
								self.ssov.players[i-offset].y1 = posY - 0.004;
								self.ssov.players[i-offset].x2 = posX + 0.5;
								self.ssov.players[i-offset].y2 = self.ssov.players[i-offset].y1 + 0.015;
								self.ssov.players[i-offset].active = false;
								self.ssov.players[i-offset].fruit = c;
								self.ssov.players[i-offset].fruitDesc = FillUtil.fillTypeIndexToDesc[c];
								self.ssov.players[i-offset].fruitMass = d;
								self.ssov.players[i-offset].numFruitScales = 0;
								for q,r in pairs(self.ssov.active.scales) do
									if q ~= nil and type(r) == "table" and r.player ~= nil and r.player[self.ssov.active.name] ~= nil and r.player[self.ssov.active.name].fillTypes ~= nil then
										if r.player[self.ssov.active.name].fillTypes[c] ~= nil and r.player[self.ssov.active.name].fillTypes[c] > 0 then
											self.ssov.players[i-offset].numFruitScales = self.ssov.players[i-offset].numFruitScales + 1;
										end;
									end;
								end;
							end;
							if self.ssov.players[i-offset].active then
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, 0.213, 0.015, g_i18n:getText("scaleText16"));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								setTextColor(0.3,1,0.3,1);
							else
								setTextColor(1,1,0.8314,1);
							end;
							self.ssov.players.entrys = entrys;
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, posY, 0.016, tostring(FillUtil.fillTypeIndexToDesc[c].nameI18N));
							setTextAlignment(RenderText.ALIGN_RIGHT);
							renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(d).." kg"));
							renderText(posX+0.35, posY, 0.016, tostring(self.ssov.players[i-offset].numFruitScales));
							posY = posY - 0.02;
							setTextAlignment(RenderText.ALIGN_LEFT);
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText20"));
		elseif self.ssov.mode == 2 then			-- Übersicht der Spieler aller Waagen
			if (self.ssov.entrys.mode ~= nil and (self.ssov.entrys.mode ~= 2 or self.ssov.entrys.page ~= self.ssov.page)) or self.ssov.entrys.mode == nil then
				self.ssov.entrys = nil;
				self.ssov.entrys = {};
				self.ssov.entrys.mode = 2;
				self.ssov.entrys.page = self.ssov.page;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString5")); -- Waagen Menütext

			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleText4"));

			local posX = 0.150;
			local posY = 0.670;
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.692, 0.0155, g_i18n:getText("scaleString5"));
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(posX+0.25, 0.692, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			renderText(posX+0.35, 0.692, 0.0155, g_i18n:getText("scaleString4"));		-- Waagen
			renderText(posX+0.45, 0.692, 0.0155, g_i18n:getText("scaleString11"));	-- Ladungen
			setTextBold(false);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.page+1,self.ssov.pageMax+1));
			local gcm = g_currentMission.scaleStation.players;
			local start = (self.ssov.page * 20) + 1;
			local offset = (self.ssov.page * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			if isMaster then modeButton2 = g_i18n:getText("scaleString15") end;
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_LEFT);
			if isMaster then renderText(posX, 0.195, 0.015, g_i18n:getText("scaleText13")) end;
			setTextAlignment(RenderText.ALIGN_RIGHT);
			local i = 0;
			for a,b in pairs(gcm) do
				if type(b) == "table" then
					i = i + 1;
					if i >= start and i <= (start + 19) then
						if b ~= nil and b.name ~= nil then
							entrys = entrys + 1;
							if self.ssov.entrys[i-offset] == nil then
								self.ssov.entrys[i-offset] = {};
								self.ssov.entrys[i-offset].x1 = posX;
								self.ssov.entrys[i-offset].y1 = posY - 0.004;
								self.ssov.entrys[i-offset].x2 = posX + 0.5;
								self.ssov.entrys[i-offset].y2 = self.ssov.entrys[i-offset].y1 + 0.015;
								self.ssov.entrys[i-offset].active = false;
								self.ssov.entrys[i-offset].player = b;
							end;
							if self.ssov.entrys[i-offset].active then
								modeButton1 = g_i18n:getText("scaleString14");
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, 0.213, 0.015, g_i18n:getText("scaleText17"));
								renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText11"));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								setTextColor(0.3,1,0.3,1);
							else
								setTextColor(1,1,0.8314,1);
							end;
							self.ssov.entrys.entrys = entrys;
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, posY, 0.016, b.name);
							setTextAlignment(RenderText.ALIGN_RIGHT);
							renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(b.overallMass).." kg"));
							renderText(posX+0.35, posY, 0.016, tostring(b.numScales));
							renderText(posX+0.45, posY, 0.016, tostring(b.numFillTypes));
							posY = posY - 0.02;
						end;
					end;
				end;
			end;
		elseif self.ssov.mode == 350 then
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString11").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString5").." -> "..tostring(self.ssov.players.active.name));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString24").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.players.active.fillTypes[self.ssov.active.fillType]).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subSubPage * 20) + 1;
			local offset = (self.ssov.subSubPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subSubPage+1,self.ssov.subSubPageMax+1));
			setTextBold(true);
			renderText(posX+0.25, 0.691, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.0155, g_i18n:getText("scaleString4"));		-- Waage
			setTextBold(false);
			if self.ssov.players.active.numScales > 0 then
				local i = start;
				local x = 1;
				for c,d in pairs(self.ssov.players.active.scales) do
					if c ~= nil and d ~= nil and d.saveId == c then
						if d.player[self.ssov.players.active.name] ~= nil and d.player[self.ssov.players.active.name].fillTypes ~= nil and d.player[self.ssov.players.active.name].fillTypes[self.ssov.active.fillType] ~= nil and d.player[self.ssov.players.active.name].fillTypes[self.ssov.active.fillType] > 0 then
							x = x + 1;
							if x >= i and x < (start + 20) then
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, posY, 0.016, tostring(d.name));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(d.player[self.ssov.players.active.name].fillTypes[self.ssov.active.fillType]).." kg"));
								posY = posY - 0.02;
								setTextAlignment(RenderText.ALIGN_LEFT);
							end;
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText23"));
		elseif self.ssov.mode == 300 then
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString11").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString4").." -> "..tostring(self.ssov.players.active.name));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString23").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.players.active.playerFruits[self.ssov.active.fillType]).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subSubPage * 20) + 1;
			local offset = (self.ssov.subSubPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subSubPage+1,self.ssov.subSubPageMax+1));
			setTextBold(true);
			renderText(posX+0.25, 0.691, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.0155, g_i18n:getText("scaleString5"));		-- Fahrer
			setTextBold(false);
			if self.ssov.players.active.player ~= nil then
				local i = start;
				local x = 1;
				for c,d in pairs(self.ssov.players.active.player) do
					if c ~= nil and type(d) == "table" and d.name == c then
						if d.fillTypes ~= nil and d.fillTypes[self.ssov.active.fillType] ~= nil and d.fillTypes[self.ssov.active.fillType] > 0 then
							x = x + 1;
							if x >= i and x < (start + 20) then
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, posY, 0.016, tostring(d.name));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(d.fillTypes[self.ssov.active.fillType]).." kg"));
								posY = posY - 0.02;
								setTextAlignment(RenderText.ALIGN_LEFT);
							end;
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText23"));
		elseif self.ssov.mode == 35 then
			if (self.ssov.players.mode ~= nil and (self.ssov.players.mode ~= 35 or self.ssov.players.page ~= self.ssov.subPage)) or self.ssov.players.mode == nil then
				self.ssov.players = nil;
				self.ssov.players = {};
				self.ssov.players.mode = 35;
				self.ssov.players.page = self.ssov.subPage;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString11").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString5"));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString22").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.mass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			local start = (self.ssov.subPage * 20) + 1;
			local offset = (self.ssov.subPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subPage+1,self.ssov.subPageMax+1));
			setTextBold(true);
			renderText(posX+0.25, 0.691, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			renderText(posX+0.35, 0.691, 0.0155, g_i18n:getText("scaleString4"));		-- Waagen
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.691, 0.0155, g_i18n:getText("scaleString5"));		-- Fahrer
			setTextBold(false);
			local i = 0;
			if self.ssov.active.numPlayer > 0 then
				for c,d in pairs(self.ssov.active.player) do
					if c ~= nil and d ~= nil and d.name ~= nil and d.fillTypes ~= nil and d.fillTypes[self.ssov.active.fillType] ~= nil then
						i = i + 1;
						if i >= start and i <= math.min(self.ssov.active.numPlayer,start+19) then
							entrys = entrys + 1;
							if self.ssov.players[i-offset] == nil then
								self.ssov.players[i-offset] = {};
								self.ssov.players[i-offset].x1 = posX;
								self.ssov.players[i-offset].y1 = posY - 0.004;
								self.ssov.players[i-offset].x2 = posX + 0.5;
								self.ssov.players[i-offset].y2 = self.ssov.players[i-offset].y1 + 0.015;
								self.ssov.players[i-offset].active = false;
								self.ssov.players[i-offset].player = d;
							end;
							if self.ssov.players[i-offset].active then
								setTextAlignment(RenderText.ALIGN_LEFT);
								renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText11"));
								setTextAlignment(RenderText.ALIGN_RIGHT);
								setTextColor(0.3,1,0.3,1);
							else
								setTextColor(1,1,0.8314,1);
							end;
							local tmpS = 0;
							for k,l in pairs(self.ssov.active.scales) do
								if l ~= nil and l.saveId ~= nil then
									if l.player ~= nil and l.player[d.name] ~= nil then
										if l.player[d.name].fillTypes ~= nil and l.player[d.name].fillTypes[self.ssov.active.fillType] ~= nil and l.player[d.name].fillTypes[self.ssov.active.fillType] > 0 then
											tmpS = tmpS + 1;
										end;
									end;
								end;
							end;
							self.ssov.players.entrys = entrys;
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, posY, 0.016, tostring(c));
							setTextAlignment(RenderText.ALIGN_RIGHT);
							renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(d.fillTypes[self.ssov.active.fillType]).." kg"));
							renderText(posX+0.35, posY, 0.016, tostring(tmpS));
							posY = posY - 0.02;
							setTextAlignment(RenderText.ALIGN_LEFT);
						end;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.213, 0.015, g_i18n:getText("scaleText21"));
		elseif self.ssov.mode == 30 then
			if (self.ssov.players.mode ~= nil and (self.ssov.players.mode ~= 30 or self.ssov.players.page ~= self.ssov.page)) or self.ssov.players.mode == nil then
				self.ssov.players = nil;
				self.ssov.players = {};
				self.ssov.players.mode = 30;
				self.ssov.players.page = self.ssov.subPage;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString11").." -> "..tostring(self.ssov.active.name).." | "..g_i18n:getText("scaleString4"));

			setTextBold(false);
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleString22").." : "..tostring(g_i18n:formatReadableNumber(self.ssov.active.mass).." kg"));
			local posX = 0.150;
			local posY = 0.668;
			setTextBold(true);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.692, 0.0155, g_i18n:getText("scaleString4"));
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(posX+0.25, 0.692, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			renderText(posX+0.35, 0.692, 0.0155, g_i18n:getText("scaleString5"));		-- Spieler
			setTextBold(false);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.subPage+1,self.ssov.subPageMax+1));
			local gcm = self.ssov.active.scales;
			local start = (self.ssov.subPage * 20) + 1;
			local offset = (self.ssov.subPage * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			local i = 0;
			for a,b in pairs(gcm) do
				if b ~= nil and b.name ~= nil and a == b.saveId and b.overallMass ~= nil and b.overallMass > 0 then
					i = i + 1;
					if i >= start and i <= (start + 19) then
						entrys = entrys + 1;
						if self.ssov.players[i-offset] == nil then
							self.ssov.players[i-offset] = {};
							self.ssov.players[i-offset].x1 = posX;
							self.ssov.players[i-offset].y1 = posY - 0.004;
							self.ssov.players[i-offset].x2 = posX + 0.5;
							self.ssov.players[i-offset].y2 = self.ssov.players[i-offset].y1 + 0.015;
							self.ssov.players[i-offset].active = false;
							self.ssov.players[i-offset].scale = b;
						end;
						local tmpP = 0;
						if b.player ~= nil and type(b.player) == "table" then
							for g,h in pairs(b.player) do
								if h ~= nil and h.name ~= nil then
									tmpP = tmpP + 1;
								end;
							end;
						end;
						if self.ssov.players[i-offset].active then
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText6"));
							setTextColor(0.3,1,0.3,1);
						else
							setTextColor(1,1,0.8314,1);
						end;
						self.ssov.players.entrys = entrys;
						setTextAlignment(RenderText.ALIGN_LEFT);
						renderText(posX, posY, 0.016, b.name);
						setTextAlignment(RenderText.ALIGN_RIGHT);
						renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(b.overallMass).." kg"));
						renderText(posX+0.45, posY, 0.016, tostring(tmpP));
						posY = posY - 0.02;
					end;
				end;
			end;
			setTextColor(1,1,0.8314,1);
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.213, 0.015, g_i18n:getText("scaleText19"));
		elseif self.ssov.mode == 3 then			-- Übersicht der Ladungen aller Waagen
			if (self.ssov.entrys.mode ~= nil and (self.ssov.entrys.mode ~= 3 or self.ssov.entrys.page ~= self.ssov.page)) or self.ssov.entrys.mode == nil then
				self.ssov.entrys = nil;
				self.ssov.entrys = {};
				self.ssov.entrys.mode = 3;
				self.ssov.entrys.page = self.ssov.page;
			end;
			renderText(0.320, 0.737, 0.017, g_i18n:getText("scaleString2").." -> "..g_i18n:getText("scaleString11")); -- Ladung Menütext

			renderText(0.125, 0.711, 0.016, g_i18n:getText("scaleText4"));

			local posX = 0.150;
			local posY = 0.670;
			setTextAlignment(RenderText.ALIGN_LEFT);
			renderText(posX, 0.692, 0.0155, g_i18n:getText("scaleString11"));
			setTextAlignment(RenderText.ALIGN_RIGHT);
			renderText(posX+0.25, 0.692, 0.0155, g_i18n:getText("scaleString12"));	-- Gewicht
			renderText(posX+0.35, 0.692, 0.0155, g_i18n:getText("scaleString4"));		-- Waagen
			renderText(posX+0.45, 0.692, 0.0155, g_i18n:getText("scaleString5"));		-- Spieler
			setTextBold(false);
			renderText(0.8, 0.195, 0.015, string.format(g_i18n:getText("scaleString16"),self.ssov.page+1,self.ssov.pageMax+1));
			local start = (self.ssov.page * 20) + 1;
			local offset = (self.ssov.page * 20);
			local entrys = 0;
			modeButton1 = g_i18n:getText("scaleString0");
			modeButton2 = g_i18n:getText("scaleString0");
			modeButton3 = g_i18n:getText("scaleString0");
			local i = 0;
			for a,b in pairs(g_currentMission.scaleStation.fruits) do
				if b ~= nil and b.name ~= nil and b.mass ~= nil and b.mass > 0 then
					i = i + 1;
					if i >= start and i <= (start + 19) then
						entrys = entrys + 1;
						if self.ssov.entrys[i-offset] == nil then
							self.ssov.entrys[i-offset] = {};
							self.ssov.entrys[i-offset].x1 = posX;
							self.ssov.entrys[i-offset].y1 = posY - 0.004;
							self.ssov.entrys[i-offset].x2 = posX + 0.5;
							self.ssov.entrys[i-offset].y2 = self.ssov.entrys[i-offset].y1 + 0.015;
							self.ssov.entrys[i-offset].active = false;
							self.ssov.entrys[i-offset].fruit = b;
						end;
						if self.ssov.entrys[i-offset].active then
							setTextAlignment(RenderText.ALIGN_LEFT);
							renderText(posX, 0.231, 0.015, g_i18n:getText("scaleText16"));
							setTextColor(0.3,1,0.3,1);
						else
							setTextColor(1,1,0.8314,1);
						end;
						self.ssov.entrys.entrys = entrys;
						setTextAlignment(RenderText.ALIGN_LEFT);
						renderText(posX, posY, 0.016, b.name);
						setTextAlignment(RenderText.ALIGN_RIGHT);
						renderText(posX+0.25, posY, 0.016, tostring(g_i18n:formatReadableNumber(b.mass).." kg"));
						renderText(posX+0.35, posY, 0.016, tostring(b.numScales));
						renderText(posX+0.45, posY, 0.016, tostring(b.numPlayer));
						posY = posY - 0.02;
					end;
				end;
			end;
		end;

		-- Extra Buttons
		setTextBold(false);
		setTextAlignment(RenderText.ALIGN_CENTER);
		setTextColor(1,1,0.8314,1);
		renderText(0.85, 0.3535, 0.0135, modeButton1);
		renderText(0.85, 0.2935, 0.0135, modeButton2);
		renderText(0.85, 0.2340, 0.0135, modeButton3);


		setTextAlignment(RenderText.ALIGN_LEFT);
		setTextColor(0,0,0,1);
--		renderText(0.22, 0.12, 0.015, "X: "..tostring(self.mpx));
--		renderText(0.22, 0.139, 0.015, "Y: "..tostring(self.mpy));

		setTextBold(false);
		setTextColor(1,1,1,1);
	end;
end;

addModEventListener(scaleStationOverview);

I18N.formatReadableNumber = function(self, number, precision)
	local numberString = "";
	local separatorK separatorD = ",",".";
	if g_languageShort == "de" then
		separatorK = ".";
		separatorD = ",";
	end;
	if precision == nil then
		precision = 3;
	end;
	local baseString = string.format("%1." .. precision .. "f", number);
	local prefix, num, decimal = string.match(baseString, "^([^%d]*%d)(%d*)[.]?(%d*)");
	numberString = prefix .. num:reverse():gsub("(%d%d%d)", "%1" .. separatorK):reverse();
	local prec = decimal:len();
	if prec > 0 then
		numberString = numberString .. separatorD .. decimal:sub(1, precision);
	end;
	return numberString;
end


print(" ++ loading Scale Station with statistics V "..scaleStation.version.." (by Blacky_BPG)")
