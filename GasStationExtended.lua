-- 
-- Gas Station Extended
-- by Blacky_BPG
-- 
-- Version 1.4.0.0      10.02.2017    fixed error on vehicle sale and on game cancel fixed
-- Version 1.3.1.0 A    23.01.2017    fixed end game bug with trailer in trigger, fixed start game bug with trailer in trigger, fixed FuelTrailer trigger check on ending game
-- Version 1.3.1.0      03.01.2017    corrected money calculation while fueling and wrong variable on savegame loading (thanks Bauerpower939)
-- Version 1.3.0.1      14.12.2016    fix name that show in PDA
-- Version 1.3.0.0	    22.11.2016    Version for FS17
--

GasStationExtended = {};
GasStationExtended.version = "1.4.0.0  -  10.02.2017";
GasStationExtended_mt = Class(GasStationExtended, Object);
InitObjectClass(GasStationExtended, "GasStationExtended");

function GasStationExtended.onCreate(id)
	local trigger = GasStationExtended:new(g_server ~= nil, g_client ~= nil);
	trigger:load(id)
	g_currentMission:addOnCreateLoadedObject(trigger);
	-- g_currentMission:addOnCreateLoadedObjectToSave(trigger);
	trigger:register(true);
end;

function GasStationExtended:new(isServer, isClient, customMt)
	if customMt == nil then
		customMt = GasStationExtended_mt;
	end;
	local self = Object:new(isServer, isClient, customMt);
	self.triggerId = 0;
	self.rootNode = 0;
	self.tipTriggers = {};
	self.fillLevel = 0;
	self.maxFuel = -1;
	if g_currentMission.gasStations == nil then
		g_currentMission.gasStations = {};
	end;
	table.insert(g_currentMission.gasStations, self);
	self.gasTriggerDirtyFlag = self:getNextDirtyFlag();
	return self;
end;

function GasStationExtended:load(id)
	self.rootNode = id;
	self.triggerId = id;
	addTrigger(id, "triggerCallback", self);

	self.vehiclesTriggerCount = {};

	self.showOnMap = Utils.getNoNil(getUserAttribute(id, "showOnMap"),true);
	local fuelStationName = getUserAttribute(id, "saveId");
	if g_i18n:hasText(fuelStationName) then
		self.fuelStationName = g_i18n:getText(fuelStationName);
	else
		self.fuelStationName = g_i18n:getText("gasStation");
	end;
	self.MHSx, y, self.MHSz = getWorldTranslation(id);
	if self.showOnMap then
		self.MHSiconSize = g_currentMission.ingameMap.mapWidth / 15;
		self.mapHotspot = g_currentMission.ingameMap:createMapHotspot("fuelStation", self.fuelStationName, nil, getNormalizedUVs({264, 520, 240, 240}), nil, self.MHSx, self.MHSz, nil, nil, false, false, false, self.triggerId, nil, MapHotspot.CATEGORY_DEFAULT);
	end;

	self.priceMultiplier = Utils.getNoNil(getUserAttribute(id, "priceMultiplier"),1);
	self.maxFuel = Utils.getNoNil(getUserAttribute(id, "maxFuelBunker"),-1);
	self.capacity = self.maxFuel;
	self.fillLitersPerSecond = Utils.getNoNil(getUserAttribute(id, "fillLitersPerSecond"),5);
	self.fillSpeed = 0;
	self.isFirstStart = true;
	self.cntTimer = 0;
	self.isTrailer = 0;
	self.showDelta = 0;
	self.showDeltaPrice = 0;
	self.displayRefresher = 5;
	self.fuelTrailerInTrigger = nil;

	self.trailerCan = Utils.getNoNil(getUserAttribute(id, "trailerCan"),true);
	self.trailerOnly = Utils.getNoNil(getUserAttribute(id, "trailerOnly"),false);
	self.showFill = Utils.getNoNil(getUserAttribute(id, "fuelDigits"),false);
	self.showLevel = Utils.getNoNil(getUserAttribute(id, "levelDigits"),false);
	self.showPrice = Utils.getNoNil(getUserAttribute(id, "priceDigits"),false);
	self.defaultOff = Utils.getNoNil(tonumber(getUserAttribute(id, "defaultOff")),11);
	if self.showFill then
		local digitGroup = Utils.indexToObject(id, getUserAttribute(id, "digitFill"));
		local num = getNumOfChildren(digitGroup);
		self.digitFill = {};
		for i=1, num do
			local child = getChildAt(digitGroup, i-1);
			if child ~= nil and child ~= 0 then
				self.digitFill[i] = {};
				self.digitFill[i].id = child;
				local numDot = getNumOfChildren(child);
				if numDot ~= 0 then
					self.digitFill[i].dot = getChildAt(child, 0);
				end;
			end;
		end;
	end;
	if self.showPrice then
		local digitGroup = Utils.indexToObject(id, getUserAttribute(id, "digitPrice"));
		local num = getNumOfChildren(digitGroup);
		self.digitPrice = {};
		for i=1, num do
			local child = getChildAt(digitGroup, i-1);
			if child ~= nil and child ~= 0 then
				self.digitPrice[i] = {};
				self.digitPrice[i].id = child;
				local numDot = getNumOfChildren(child);
				if numDot ~= 0 then
					self.digitPrice[i].dot = getChildAt(child, 0);
				end;
			end;
		end;
	end;
	if self.showLevel then
		local digitGroup = Utils.indexToObject(id, getUserAttribute(id, "digitLevel"));
		local num = getNumOfChildren(digitGroup);
		self.digitLevel = {};
		for i=1, num do
			local child = getChildAt(digitGroup, i-1);
			if child ~= nil and child ~= 0 then
				self.digitLevel[i] = {};
				self.digitLevel[i].id = child;
				local numDot = getNumOfChildren(child);
				if numDot ~= 0 then
					self.digitLevel[i].dot = getChildAt(child, 0);
				end;
			end;
		end;
	end;

	self.isEnabled = true;
	self.isFuelTrailerActivated = false;

	if g_currentMission.gasStationDisplays == nil then
		g_currentMission.gasStationDisplays = {};
	end;
	self.lastDelta = 0;
	table.insert(g_currentMission.gasStationDisplays,self);
	self.valuePos = table.getn(g_currentMission.gasStationDisplays);

	local tipTriggerIndex = getUserAttribute(self.rootNode, "tipTriggerIndex");
	if tipTriggerIndex ~= nil then
		local tipTriggersId = Utils.indexToObject(self.rootNode, tipTriggerIndex);
		if tipTriggersId ~= nil then
			local tipTrigger = GasolineTipTrigger:new(self.isServer, self.isClient);
			tipTrigger:load(tipTriggersId, self);
			g_currentMission:addOnCreateLoadedObject(tipTrigger);
			tipTrigger:register(true);
			table.insert(self.tipTriggers, tipTrigger);
			tipTrigger:addTipTriggerTarget(self,false);
		end;
	end;

	if Utils.getNoNil(getUserAttribute(self.rootNode, "hasGauges"),false) == true then
		local gaugeGroup = getUserAttribute(self.rootNode, "gaugeGroupIndex");
		if gaugeGroup ~= nil then
			gauges = Utils.indexToObject(self.rootNode,gaugeGroup);
			if gauges ~= nil and gauges ~= 0 then
				local numGauges = getNumOfChildren(gauges);
				if numGauges > 0 then
					self.gauges = {};
					self.gauges.main = {};
					self.gauges.tanks = {};
					local x = 0;
					for i=1, numGauges do
						local gauge = getChildAt(gauges,i-1);
						if gauge ~= nil and gauge ~= 0 then
							if Utils.getNoNil(getUserAttribute(gauge, "isMain"),false) == true then
								local low = getUserAttribute(gauge, "lowPointer");
								local high = getUserAttribute(gauge, "highPointer");
								if low ~= nil then
									self.gauges.main.lowPointer = Utils.indexToObject(gauge,low);
									self.gauges.main.lowValueMax = Utils.getNoNil(getUserAttribute(gauge, "lowValueMax"),100);
								end;
								if high ~= nil then
									self.gauges.main.highPointer = Utils.indexToObject(gauge,high);
									self.gauges.main.highValueMax = Utils.getNoNil(getUserAttribute(gauge, "highValueMax"),2500);
								end;
							end;
							if Utils.getNoNil(getUserAttribute(gauge, "isTank"),false) == true then
								x = x + 1;
								self.gauges.tanks[x] = {}
								local tankP = getUserAttribute(gauge, "tankPointer");
								if tankP ~= nil then
									self.gauges.tanks[x].pointer = Utils.indexToObject(gauge, tankP);
									self.gauges.tanks[x].maxRot = Utils.getNoNil(getUserAttribute(gauge, "maxRot"),270);
									self.gauges.tanks[x].minRot = Utils.getNoNil(getUserAttribute(gauge, "minRot"),0);
									self.gauges.tanks[x].lastRot = 90;
								end;
							end;
						end;
					end;
				end;
			end;
		end;
	end;
	local mainTankIndex = getUserAttribute(self.rootNode, "tanksIndex");
	if mainTankIndex ~= nil then
		self.tankStorage = {};
		local main = Utils.indexToObject(self.rootNode, mainTankIndex);
		local num = getNumOfChildren(main);
		for i=1, num do
			local childTank = getChildAt(main,i-1);
			local warnLights = {};
			if childTank ~= nil and childTank ~= 0 then
				local numLamps = getNumOfChildren(childTank);
				if numLamps > 0 then
					if numLamps > 2 then numLamps = 2 end;
					for x=1, numLamps do
						local childLamp = getChildAt(childTank,x-1);
						if childLamp ~= nil and childLamp ~= 0 then
							table.insert(warnLights,childLamp);
						end;
					end;
				end;
			end;
			if #warnLights > 0 then
				table.insert(self.tankStorage,warnLights);
			end;
		end;
	end;
	self.blinkingObject = nil;
	self.blinkingTimer = 0;
	self.blinkSpeed = 1;

	self.isEnabled = true;
	local saveString = "X"..math.floor(math.max(self.MHSx,-self.MHSx) * 100).."_Y"..math.floor(math.max(y,-y) * 100).."_Z"..math.floor(math.max(self.MHSz,-self.MHSz) * 100);
	self.saveId = "fuelStation_"..Utils.getNoNil(getUserAttribute(id, "saveId"),saveString)
	g_currentMission:addNodeObject(self.rootNode, self);
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		g_currentMission:addOnCreateLoadedObjectToSave(self);
	else
		self.moneyChangeId = getMoneyTypeId();
	end;
	self.oldTruckState = 3;
	self.oldTime = 0;
	self:setDisplay(self.showFill, self.showLevel, self.showPrice);
	return true;
end;

function GasStationExtended:delete()
	for vehicle,count in pairs(self.vehiclesTriggerCount) do
		if count > 0 then
			if vehicle.removeFuelFillTrigger ~= nil then
				vehicle:removeFuelFillTrigger(self);
			end;
		end;
	end;
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		g_currentMission:removeOnCreateLoadedObjectToSave(self);
	end;
	if self.isServer then
		if table.getn(self.tipTriggers) > 0 then
			for _,trigger in pairs(self.tipTriggers) do
				if trigger.isRegistered then
					trigger:unregister();
					trigger:delete();
				end;
			end;
		end;
	end;
	if self.mapHotspot ~= nil then
		g_currentMission.ingameMap:deleteMapHotspot(self.mapHotspot);
	end
	if self.rootNode ~= nil then
		g_currentMission:removeNodeObject(self.rootNode);
	end;
	removeTrigger(self.triggerId);
end;

function GasStationExtended:readStream(streamId, connection)
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		local fillLevel = streamReadFloat32(streamId);
		if fillLevel ~= self.fillLevel then
			self:setDisplay(true, false, true);
		end;
		self.fillLevel = fillLevel;
	end;
end;

function GasStationExtended:writeStream(streamId, timestamp, connection)
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		streamWriteFloat32(streamId, self.fillLevel);
	end;
end;

function GasStationExtended:readUpdateStream(streamId, timestamp, connection)
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		if connection ~= nil and connection:getIsServer() then
			local fillLevel = streamReadFloat32(streamId);
			if fillLevel ~= self.fillLevel then
				self:setDisplay(true, false, true);
			end;
			self.fillLevel = fillLevel;
		end;
	end;
end;

function GasStationExtended:writeUpdateStream(streamId, connection, dirtyMask)
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		if connection ~= nil and not connection:getIsServer() then
			streamWriteFloat32(streamId, self.fillLevel);
		end;
	end;
end;

function GasStationExtended:loadFromAttributesAndNodes(xmlFile, key)
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		local fillLevel = getXMLFloat(xmlFile, key.."#fillLevel");
		if fillLevel ~= nil then
			if self.maxFuel > -1 and fillLevel > self.maxFuel then
				fillLevel = self.maxFuel;
			end;
		else
			fillLevel = 0;
		end;
		self.fillLevel = fillLevel;
	end;
	return true;
end;

function GasStationExtended:getSaveAttributesAndNodes(nodeIdent)
	local attributes = "";
	local nodes = "";
	if self.maxFuel > -1 and table.getn(self.tipTriggers) > 0 then
		attributes = 'fillLevel="'..self.fillLevel..'"';
	end;
	return attributes, nodes;
end;

function GasStationExtended:update(dt)
	if self.fillLevel == nil then
		self.fillLevel = 0;
	end;
	if self.fuelTrailerInTrigger ~= nil then
		if self.fuelTrailerInTrigger:getFillLevel(FillUtil.FILLTYPE_FUEL) > 0 then
			if self.fuelTrailerInTrigger.setUnloadingToTank ~= nil then
				self.fuelTrailerInTrigger:setUnloadingToTank(self.fuelTrailerInTrigger);
			end;
		end;
	end;
	local fuelFillLevel = self.fillLevel;
	self.fillSpeed = self.fillLitersPerSecond * 0.001 * dt;
	local fPrice = Utils.getNoNil(g_currentMission.gasStationFuelPrice,1.1);
	if self.maxFuel > -1 then
		if self.tankStorage ~= nil and #self.tankStorage > 0 then
			local cap = math.floor(self.maxFuel / #self.tankStorage);
			local maxOn = math.floor(self.fillLevel / cap);
			local showOn = false;
			local x = 0;
			for i=1,#self.tankStorage do
				if i > maxOn then
					showOn = true;
					if x == 0 then x = i end;
				end;
				if self.tankStorage[i][1] ~= nil and getVisibility(self.tankStorage[i][1]) ~= showOn then
					setVisibility(self.tankStorage[i][1],showOn);
				end;
				if self.tankStorage[i][2] ~= nil and getVisibility(self.tankStorage[i][2]) == showOn and x ~= i then
					setVisibility(self.tankStorage[i][2],not showOn);
				end;
			end;
			if x <= #self.tankStorage then
				local calc = cap * maxOn;
				if self.fillLevel > calc then
					self.blinkSpeed = ((calc + cap) - self.fillLevel) / cap
					if self.tankStorage[x][2] ~= nil then
						self.blinkingObject = self.tankStorage[x][2];
					end;
				else
					self.blinkingObject = nil;
				end;
			else
				self.blinkingObject = nil;
			end;
			self.blinkingTimer = self.blinkingTimer + 1;
			local showBlink = false;
			if self.blinkingObject ~= nil then
				if self.blinkingTimer > math.max((300 * self.blinkSpeed),15) then
					self.blinkingTimer = 0;
				elseif self.blinkingTimer > math.max((120 * self.blinkSpeed),6) then
					showBlink = true;
				end;
				if showBlink ~= getVisibility(self.blinkingObject) then
					setVisibility(self.blinkingObject,showBlink);
				end;
			else
			end;
		end;
		if self.showOnMap then
			if fuelFillLevel > 0 and self.mapHotspot == nil then
				self.mapHotspot = g_currentMission.ingameMap:createMapHotspot("fuelStation", self.fuelStationName, nil, getNormalizedUVs({264, 520, 240, 240}), nil, self.MHSx, self.MHSz, nil, nil, false, false, false, self.triggerId, nil, MapHotspot.CATEGORY_DEFAULT);
			elseif fuelFillLevel <= 0 and self.mapHotspot ~= nil then
				g_currentMission.ingameMap:deleteMapHotspot(self.mapHotspot);
				self.mapHotspot = nil;
			end;
		end;
	else
		self.fillLevel = 9999999;
	end;
	if self.displayRefresher <= 0 then
		self:setDisplay(true, false, true);
		for a,b in pairs(self.vehiclesTriggerCount) do
			if b ~= nil and b == 1 and a ~= nil then
				if a.engineMustRun and ((not a.isFuelFilling) or (a.isFuelTrailerActivated)) then
					self:manageMotorized(a,false);
				end;
			end;
		end;
	else
		self.displayRefresher = self.displayRefresher - 1;
	end;
end;
function GasStationExtended:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if self.isEnabled then
		local vehicle = g_currentMission.nodeToVehicle[otherId];
		if vehicle ~= nil and vehicle.addFuelFillTrigger ~= nil and vehicle.removeFuelFillTrigger ~= nil and vehicle ~= self then
			local count = Utils.getNoNil(self.vehiclesTriggerCount[vehicle], 0);
			if onEnter then
				if (self.fillLevel > 0 and self.maxFuel > -1) or self.maxFuel == -1 then
					local allowed = false;
					if vehicle.fuelTrailerFillActivatable ~= nil then
						self.isTrailer = true;
						if self.trailerCan or self.trailerOnly then
							allowed = true;
						end;
					else
						if not self.trailerOnly then
							allowed = true;
						end;
					end;
					if allowed then
						self.vehiclesTriggerCount[vehicle] = 1;
						if count == 0 then
							vehicle:addFuelFillTrigger(self);
							if self.maxFuel > -1 then
								self:setDisplay(true, false, true);
							else
								self:setDisplay(true, true, true);
							end;
							if vehicle.fuelTrailerFillActivatable ~= nil then
								self.isTrailer = true;
							end;
						end;
					end;
				end;
			elseif onLeave then
				self.vehiclesTriggerCount[vehicle] = 0;
				if count == 1 then
					self.vehiclesTriggerCount[vehicle] = nil;
					vehicle:removeFuelFillTrigger(self);
					if table.getn(self.vehiclesTriggerCount) < 1 then
						self.showDelta = 0;
						self.showDeltaPrice = 0;
					end;
					if self.maxFuel > -1 then
						self:setDisplay(true, false, true);
					else
						self:setDisplay(true, true, true);
					end;
					if vehicle.fuelTrailerFillActivatable ~= nil then
						self.isTrailer = false;
					end;
				end;
			end;
		end;
	end;
end;
function GasStationExtended:onVehicleDeleted(vehicle)
    self.vehiclesTriggerCount[vehicle] = nil;
    if self.moneyChangeId ~= nil then
		g_currentMission:showMoneyChange(self.moneyChangeId, g_i18n:getText("finance_purchaseFuel"));
    end;
end;
function GasStationExtended:setDisplay(fuel, price, leftFuel)
	self.displayRefresher = math.random(10,20);
	if self.lastDelta ~= self.showDelta then
		if self.isServer then
			self:raiseDirtyFlags(self.gasTriggerDirtyFlag);
			g_server:broadcastEvent(GasStationDisplayEvent:new(self.valuePos, self.showDelta, self.showDeltaPrice, fuel, price, leftFuel));
			self.lastDelta = self.showDelta;
		end;

		if fuel and self.gauges ~= nil and self.gauges.main ~= nil then
			if self.gauges.main.lowValueMax ~= nil and self.gauges.main.lowValueMax > 0 then
				local lRot = -math.max(360 / self.gauges.main.lowValueMax * self.showDelta,0);
				setRotation(self.gauges.main.lowPointer,0,0,Utils.degToRad(lRot));
			end;
			if self.gauges.main.highValueMax ~= nil and self.gauges.main.highValueMax > 0 then
				local hRot = -math.max(360 / self.gauges.main.highValueMax * self.showDelta,0);
				setRotation(self.gauges.main.highPointer,0,0,Utils.degToRad(hRot));
			end;
		end;
	end;
	if leftFuel and self.maxFuel > -1 and self.gauges ~= nil and self.gauges.tanks ~= nil and table.getn(self.gauges.tanks) > 0 then
		local valuePerGauge = self.maxFuel / table.getn(self.gauges.tanks);
		local maxFuel = self.fillLevel;
		for i=1, table.getn(self.gauges.tanks) do
			if self.gauges.tanks[i].pointer ~= nil and self.gauges.tanks[i].pointer ~= 0 then
				local maxRot = self.gauges.tanks[i].maxRot;
				local minRot = self.gauges.tanks[i].minRot;
				local cRot = maxRot - minRot;
				local nRot = minRot;
				if maxRot > minRot then
					nRot = math.max(math.min((cRot / valuePerGauge * maxFuel) + minRot,maxRot),minRot);
				else
					nRot = math.min(math.max((cRot / valuePerGauge * maxFuel) + minRot,maxRot),minRot);
				end;
				if self.gauges.tanks[i].lastRot ~= nRot then
					setRotation(self.gauges.tanks[i].pointer,0,0,Utils.degToRad(nRot));
					self.gauges.tanks[i].lastRot = nRot;
				end;
				maxFuel = math.max(maxFuel - valuePerGauge,0);
			end;
		end;
	end;

	if leftFuel and self.showLevel then
	  if self.maxFuel > -1 then
		local fL = math.floor(self.fillLevel * 100);
		for i=1, table.getn(self.digitLevel) do
			local number = math.floor(fL - (math.floor(fL / 10) * 10));
			fL = math.floor(fL / 10);
			if number <= 0 and fL <= 0 then
				setShaderParameter(self.digitLevel[i].id, "number", self.defaultOff, 0, 0, 0, false);
				if self.digitLevel[i].dot ~= nil then
					setVisibility(self.digitLevel[i].dot,false);
				end;
			else
				setShaderParameter(self.digitLevel[i].id, "number", number, 0, 0, 0, false);
				if self.digitLevel[i].dot ~= nil then
					setVisibility(self.digitLevel[i].dot,true);
				end;
			end;
		end;
	  else
		local fL = (math.floor(Utils.getNoNil(g_currentMission.gasStationFuelPrice,1.1) * self.priceMultiplier * 100) * 10) + 9;
		for i=1, table.getn(self.digitLevel) do
			local number = math.floor(fL - (math.floor(fL / 10) * 10));
			fL = math.floor(fL / 10);
			if number <= 0 and fL <= 0 then
				setShaderParameter(self.digitLevel[i].id, "number", self.defaultOff, 0, 0, 0, false);
				if self.digitLevel[i].dot ~= nil then
					setVisibility(self.digitLevel[i].dot,false);
				end;
			else
				setShaderParameter(self.digitLevel[i].id, "number", number, 0, 0, 0, false);
				if self.digitLevel[i].dot ~= nil then
					setVisibility(self.digitLevel[i].dot,true);
				end;
			end;
		end;
	  end;
	end;
	if fuel and self.showFill then
		local fD = math.floor(self.showDelta * 100);
		for i=1, table.getn(self.digitFill) do
			local number = math.floor(fD - (math.floor(fD / 10) * 10));
			fD = math.floor(fD / 10);
			if number <= 0 and fD <= 0 then
				setShaderParameter(self.digitFill[i].id, "number", self.defaultOff, 0, 0, 0, false);
				if self.digitFill[i].dot ~= nil then
					setVisibility(self.digitFill[i].dot,false);
				end;
			else
				setShaderParameter(self.digitFill[i].id, "number", number, 0, 0, 0, false);
				if self.digitFill[i].dot ~= nil then
					setVisibility(self.digitFill[i].dot,true);
				end;
			end;
		end;
	end;
	if price and self.showPrice then
		local pD = math.floor(self.showDeltaPrice * 100);
		for i=1, table.getn(self.digitPrice) do
			local number = math.floor(pD - (math.floor(pD / 10) * 10));
			pD = math.floor(pD / 10);
			if number <= 0 and pD <= 0 then
				setShaderParameter(self.digitPrice[i].id, "number", self.defaultOff, 0, 0, 0, false);
				if self.digitPrice[i].dot ~= nil then
					setVisibility(self.digitPrice[i].dot,false);
				end;
			else
				setShaderParameter(self.digitPrice[i].id, "number", number, 0, 0, 0, false);
				if self.digitPrice[i].dot ~= nil then
					setVisibility(self.digitPrice[i].dot,true);
				end;
			end;
		end;
	end;
end;
function GasStationExtended:checkMotorized()
	for a,b in pairs(self.vehiclesTriggerCount) do
		if b ~= nil and b == 1 and a ~= nil then
			if a.engineMustRun and not a.isFuelFilling then
				self:manageMotorized(a,false);
			end;
		end;
	end;
end;
function GasStationExtended:manageMotorized(vehicle, motorOff)
	if motorOff == nil then
		motorOff = false;
	end;
	local shutUp = false;
	local suObject = nil;
	if SpecializationUtil.hasSpecialization(Motorized, vehicle.specializations) then
		suObject = vehicle;
		if vehicle.isMotorStarted then
			suObject.engineMustRun = true;
			shutUp = true;
		end;
	else
		if vehicle.attacherVehicle ~= nil then
			if SpecializationUtil.hasSpecialization(Motorized, vehicle.attacherVehicle.specializations) then
				suObject = vehicle.attacherVehicle;
				if vehicle.attacherVehicle.isMotorStarted then
					if vehicle.isFuelTrailerActivated ~= nil then
						vehicle.isFuelTrailerActivated = vehicle.attacherVehicle.isFuelTrailerActivated;
					end;
					suObject.engineMustRun = true;
					shutUp = true;
				end;
			else
				if vehicle.attacherVehicle.attacherVehicle ~= nil then
					if SpecializationUtil.hasSpecialization(Motorized, vehicle.attacherVehicle.attacherVehicle.specializations) then
						suObject = vehicle.attacherVehicle.attacherVehicle;
						if vehicle.attacherVehicle.attacherVehicle.isMotorStarted then
							if vehicle.isFuelTrailerActivated ~= nil then
								vehicle.isFuelTrailerActivated = vehicle.attacherVehicle.attacherVehicle.isFuelTrailerActivated;
							end;
							suObject.engineMustRun = true
							shutUp = true;
						end;
					end;
				end;
			end;
		end;
	end;
	if suObject ~= nil then
		if motorOff and shutUp then
			if suObject.stopMotor ~= nil then
				suObject:stopMotor();
			end;
		elseif motorOff == false and shutUp == false then
			if suObject.startMotor ~= nil and suObject.engineMustRun then
				suObject.engineMustRun = false;
				suObject:startMotor();
			end;
		end;
	end;
end;
function GasStationExtended:fillFuel(vehicle, delta)
	local fuelFillLevel = self.fillLevel;
	if (not self.isTrailer) and delta > self.fillSpeed then
		delta = self.fillSpeed;
	end;
	if self.maxFuel > -1 and fuelFillLevel > 0 then
		delta = math.min(delta, fuelFillLevel);
		if delta <= 0 then
			delta = 0;
		end;
	elseif self.maxFuel > -1 and fuelFillLevel <= 0 then
		self.fillLevel = 0;
		self:setDisplay(true, false, true);
		delta = 0;
	end;
	if vehicle.setFuelFillLevel ~= nil then
		local oldFillLevel = vehicle.fuelFillLevel
		vehicle:setFuelFillLevel(vehicle.fuelFillLevel + delta);
		delta = vehicle.fuelFillLevel - oldFillLevel;
	else
		if not vehicle:allowFillType(FillUtil.FILLTYPE_FUEL, false) then
			delta = 0;
		else
			local oldFillLevel = vehicle:getFillLevel(FillUtil.FILLTYPE_FUEL);
			vehicle:setFillLevel(oldFillLevel + delta, FillUtil.FILLTYPE_FUEL);
			delta = vehicle:getFillLevel(FillUtil.FILLTYPE_FUEL) - oldFillLevel;
		end;
	end;
	if delta > 0 then
		self.showDelta = self.showDelta + delta;
		self:manageMotorized(vehicle,true);
		if self.maxFuel > -1 then
			self.fillLevel = math.max(self.fillLevel - delta,0);
			self:setDisplay(true, false, true);
		else
			local price = delta * (((math.floor(Utils.getNoNil(g_currentMission.gasStationFuelPrice,1.1) * self.priceMultiplier * 100) * 10) + 9) / 1000);
			self.showDeltaPrice = self.showDeltaPrice + price;
			self:setDisplay(true, true, true);
			g_currentMission.missionStats:updateStats("expenses", price);
			g_currentMission:addMoneyChange(-price, self.moneyChangeId);
			if self.isServer or g_server ~= nil then
				g_currentMission:addSharedMoney(-price, "purchaseFuel");
			end;
		end;
		self:raiseDirtyFlags(self.gasTriggerDirtyFlag);
	else
		self:setDisplay(true, true, true);
		self:manageMotorized(vehicle,false);
	end;
	return delta;
end;
function GasStationExtended:getIsActivatable(vehicle)
	if self.trailer ~= nil then
		if self.trailer:getFillLevel(FillUtil.FILLTYPE_FUEL) <= 0 then
			return false;
		end;
	end;
	if vehicle.setFuelFillLevel == nil and not vehicle:allowFillType(FillUtil.FILLTYPE_FUEL, false) then
		return false;
	end;
	if self.maxFuel > -1 and self.fillLevel <= 0 then
		return false;
	end;
	return true;
end;

function GasStationExtended:setTrailerFillDelta(trailer, fillDelta, fillType)
	local fillDeltaOld = fillDelta;
	if trailer.getUnitCapacity ~= nil and trailer:getUnitCapacity(FillUtil.FILLTYPE_FUEL) ~= nil and trailer:getUnitCapacity(FillUtil.FILLTYPE_FUEL) > 0 then
		local tmp = trailer:getUnitCapacity(FillUtil.FILLTYPE_FUEL) / 100;
		if fillDelta < tmp then
			fillDelta = tmp;
		end;
	end;
	if trailer.fillLitersPerSecond ~= nil and trailer.fillLitersPerSecond > 0 then
		if fillDelta > trailer.fillLitersPerSecond then
			fillDelta = trailer.fillLitersPerSecond;
		end;
	end;
	if trailer.fuelFillLitersPerSecond ~= nil and trailer.fuelFillLitersPerSecond > 0 then
		if fillDelta > trailer.fuelFillLitersPerSecond then
			fillDelta = trailer.fuelFillLitersPerSecond;
		end;
	end;
	if fillDelta > 120 then
		fillDelta = 120;
	end;
	if self.maxFuel > -1 and (self.fillLevel + fillDelta) > self.maxFuel then
		fillDelta = self.maxFuel - self.fillLevel;
	end;
	if fillDeltaOld > fillDelta then
		local tAdd = fillDeltaOld - fillDelta;
		trailer:setFillLevel(trailer:getFillLevel(fillType) + tAdd,fillType,true);
	end;
	if fillDelta > 0 then
		self.fillLevel = self.fillLevel + fillDelta;
		self:raiseDirtyFlags(self.gasTriggerDirtyFlag);
		self:setDisplay(true, true, true);
		self:manageMotorized(trailer,true);
	else
		if trailer.onEndTip ~= nil then
			trailer:onEndTip();
		end;
		if trailer.isFuelFilling ~= nil and trailer.setIsFuelFilling ~= nil then
			trailer:setIsFuelFilling(self.isFuelTrailerActivated);
		end;
		self:manageMotorized(trailer,false);
	end;
end;

----------------------------------------------------------------------------------------------------------------

GasolineTipTrigger = {};
local GasolineTipTrigger_mt = Class(GasolineTipTrigger, TipTrigger);
InitObjectClass(GasolineTipTrigger, "GasolineTipTrigger");
function GasolineTipTrigger:new(isServer, isClient, customMt)
	local mt = customMt;
	if mt == nil then
		mt = GasolineTipTrigger_mt;
	end;
	local self = TipTrigger:new(isServer, isClient, mt);
	return self;
end;
function GasolineTipTrigger:load(id, tippingSilo)
	self.defaultPriceMultiplier = 0;
	GasolineTipTrigger:superClass().load(self, id);
	self.appearsOnPDA = false;
	self.isFarmTrigger = false;
	self.stationName = "GasolineSilo"
	self.tippingSilo = tippingSilo;
	self.rootNode = id;
	self.triggerId = id;
	self.isFuelFilling = false;
	self.lastFillDelta = 0;
	addTrigger(self.triggerId, "triggerCallback", self)
	return true;
end;
function GasolineTipTrigger:delete()
	if self.fuelTrailer ~= nil then
		self.fuelTrailer:removeFuelFillTrigger(self);
	end;
	if self.tippingSilo.fuelTrailerInTrigger ~= nil then
		self.tippingSilo.fuelTrailerInTrigger:removeFuelFillTrigger(self);
	end;
	GasolineTipTrigger:superClass().delete(self);
end;
function GasolineTipTrigger:update(dt)
	if self.fuelTrailer ~= nil and self.fuelTrailer.UpdateOverloadPipe then
		self.fuelTrailer.isFillingOverloadPipe = self.isFuelFilling;
	end;
	if self.lastFillDelta > 0 then
		self.lastFillDelta = 0;
	else
		self.isFuelFilling = false;
	end;
	GasolineTipTrigger:superClass().update(self,dt);
end;
function GasolineTipTrigger:addFillLevelFromTool(trailer, fillDelta, fillType)
	if fillDelta > 0 then
		self.tippingSilo:setTrailerFillDelta(trailer, fillDelta, fillType);
	end;
end;
function GasolineTipTrigger:getTipDistanceFromTrailer(trailer, tipReferencePointIndex)
	if self.tippingSilo.fillLevel >= self.tippingSilo.capacity then
		return math.huge;
	end;
	return GasolineTipTrigger:superClass().getTipDistanceFromTrailer(self, trailer, tipReferencePointIndex);
end;
function GasolineTipTrigger:getTipInfoForTrailer(trailer, tipReferencePointIndex)
	local minDistance, bestPoint = self:getTipDistanceFromTrailer(trailer, tipReferencePointIndex)
	local isAllowed = false
	local fillTypes = trailer:getCurrentFillTypes()
	if fillTypes ~= nil then
		for _,fillType in pairs(fillTypes) do
			if self:getAllowFillTypeFromTool(fillType, TipTrigger.TOOL_TYPE_TRAILER) then
				isAllowed = true;
				break;
			end
		end
	end
	return GasolineTipTrigger:superClass().getTipInfoForTrailer(self, trailer, tipReferencePointIndex);
end;
function GasolineTipTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if self.isEnabled then
		local trailer = g_currentMission.objectToTrailer[otherId]
		if trailer ~= nil and trailer.fuelTrailerFillActivatable then
			if onEnter then
				self.tippingSilo.fuelTrailerInTrigger = trailer;
				self.fuelTrailer = trailer;
				trailer:addFuelFillTrigger(self);
			elseif onLeave then
				self.tippingSilo.fuelTrailerInTrigger = nil;
				self.fuelTrailer = nil;
				trailer:removeFuelFillTrigger(self)
			end
		end
	end
end
function GasolineTipTrigger:getIsActivatable(vehicle)
	if self.tippingSilo.fuelTrailerInTrigger ~= nil then
		if self.tippingSilo.fuelTrailerInTrigger:getFillLevel(FillUtil.FILLTYPE_FUEL) <= 0 then
			return false;
		end;
	end
	if vehicle.setFuelFillLevel == nil and not vehicle:allowFillType(FillUtil.FILLTYPE_FUEL, false) then
		return false;
	end
	return true;
end
function GasolineTipTrigger:fillFuel(vehicle, delta)
	if self.tippingSilo.fuelTrailerInTrigger ~= nil then
		local trailerFuelFillLevel = self.tippingSilo.fuelTrailerInTrigger:getFillLevel(FillUtil.FILLTYPE_FUEL);
		if trailerFuelFillLevel > 0 then
			delta = math.min(delta, trailerFuelFillLevel);
			if delta <= 0 then
				return 0;
			end
		else
			return 0;
		end
	end
	if vehicle.setFuelFillLevel ~= nil then
		local oldFillLevel = vehicle.fuelFillLevel
		vehicle:setFuelFillLevel(vehicle.fuelFillLevel + delta);
		delta = vehicle.fuelFillLevel - oldFillLevel;
	else
		if not vehicle:allowFillType(FillUtil.FILLTYPE_FUEL, false) then
			return 0;
		end
		local oldFillLevel = vehicle:getFillLevel(FillUtil.FILLTYPE_FUEL);
		vehicle:setFillLevel(oldFillLevel - delta, FillUtil.FILLTYPE_FUEL);
		delta = oldFillLevel - vehicle:getFillLevel(FillUtil.FILLTYPE_FUEL);
	end
	if delta > 0 then
		if self.tippingSilo.fuelTrailerInTrigger ~= nil then
			self.tippingSilo:setTrailerFillDelta(vehicle,delta,FillUtil.FILLTYPE_FUEL);
		end
		self.isFuelFilling = true;
		self.lastFillDelta = delta;
		if self.isClient and self.fuelTrailer ~= nil and self.fuelTrailer.setOverloadPipe ~= nil and self.fuelTrailer.setTrigger ~= nil then
			self.fuelTrailer:setTrigger(self.tippingSilo.triggerId);
			self.fuelTrailer:setOverloadPipe(self.tippingSilo.triggerId);
		end;
	end
	return delta;
end;
local oldFTU = FuelTrailer.update
FuelTrailer.update = function (self, dt)
	if self.isFuelTrailerActivated == nil then
		self.isFuelTrailerActivated = false;
		self.setUnloadingToTank = SpecializationUtil.callSpecializationsFunction("setUnloadingToTank");
	end;
	oldFTU(self, dt);
end;
function FuelTrailer:delete()
	for _, trigger in pairs(self.fuelFillTriggers) do
		-- check if trigger exists befor execute, fix for giants NOT checking this
		if trigger ~= nil and trigger.vehiclesTriggerCount ~= nil and trigger.vehiclesTriggerCount[vehicle] ~= nil then
			trigger:onVehicleDeleted(self);
		end;
	end;
	g_currentMission:removeActivatableObject(self.fuelTrailerFillActivatable);
	if self.gasStationTrigger ~= nil then
		self.gasStationTrigger:delete();
		self.gasStationTrigger = nil;
	end;
	if self.isClient then
		SoundUtil.deleteSample(self.sampleRefuel);
	end;
end;

function FuelTrailer:setUnloadingToTank(self)
	if g_currentMission:getIsClient() and self:getIsActiveForInput() then
		if not self.isFuelTrailerActivated then
			if self:getFreeCapacity(FillUtil.FILLTYPE_FUEL) <= 0 then
				g_currentMission:addHelpButtonText(g_i18n:getText("activateFuelUnload"), InputBinding.ACTIVATE_OBJECT, nil, GS_PRIO_VERY_HIGH);
			end;
		end;
		if InputBinding.hasEvent(InputBinding.ACTIVATE_OBJECT) then
			self.isFuelTrailerActivated = not self.isFuelTrailerActivated;
			self:setIsFuelFilling(self.isFuelTrailerActivated);
		end;
	end;
end;
local oldFAUAT = FuelTrailerFillActivatable.updateActivateText
FuelTrailerFillActivatable.updateActivateText = function(self)
	if self.trailer.isFuelTrailerActivated ~= nil then
		if self.trailer.isFuelTrailerActivated then
			self.activateText = g_i18n:getText("activateFuelUnload");
			return;
		else
			if self.trailer.fuelFillTriggers ~= nil then
				for i=1, table.getn(self.trailer.fuelFillTriggers) do
					if self.trailer.fuelFillTriggers[i] ~= nil and self.trailer.fuelFillTriggers[i].tippingSilo ~= nil then
						self.activateText = g_i18n:getText("deactivateFuelUnload");
						return;
					end;
				end;
			end;
		end;
	end;
	if self.trailer.isFuelFilling then
		self.activateText = string.format(g_i18n:getText("action_stopRefillingOBJECT"), g_i18n:getText("fuelTankTrailer"));
	else
		self.activateText = string.format(g_i18n:getText("action_refillOBJECT"), g_i18n:getText("fuelTankTrailer"));
	end;
end;
----------------------------------------------------------------------------------------------------------------

GasStationDisplayEvent = {};
GasStationDisplayEvent_mt = Class(GasStationDisplayEvent, Event);
InitEventClass(GasStationDisplayEvent, "GasStationDisplayEvent");

function GasStationDisplayEvent:emptyNew()
    local self = Event:new(GasStationDisplayEvent_mt);
    return self;
end;
function GasStationDisplayEvent:new(gsPos, value1, value2, bool1, bool2, bool3)
    local self = GasStationDisplayEvent:emptyNew()
    self.gsPos = gsPos;
    self.value1 = value1;
    self.value2 = value2;
    self.bool1 = bool1;
    self.bool2 = bool2;
    self.bool3 = bool3;
    return self;
end;
function GasStationDisplayEvent:readStream(streamId, connection)
	self.gsPos = streamReadInt32(streamId);
	self.value1 = streamReadFloat32(streamId);
	self.value2 = streamReadFloat32(streamId);
	self.bool1 = streamReadBool(streamId);
	self.bool2 = streamReadBool(streamId);
	self.bool3 = streamReadBool(streamId);
	self:run(connection);
end;
function GasStationDisplayEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId,self.gsPos);
	streamWriteFloat32(streamId,self.value1);
	streamWriteFloat32(streamId,self.value2);
	streamWriteBool(streamId,self.bool1);
	streamWriteBool(streamId,self.bool2);
	streamWriteBool(streamId,self.bool3);
end;
function GasStationDisplayEvent:run(connection)
	if connection:getIsServer() then
		local gS = g_currentMission.gasStationDisplays;
		if gS ~= nil and type(gS) == "table" and table.getn(gS) > 0 and gS[self.gsPos] ~= nil then
			g_currentMission.gasStationDisplays[self.gsPos].showDelta = self.value1;
			g_currentMission.gasStationDisplays[self.gsPos].showDeltaPrice = self.value2;
			g_currentMission.gasStationDisplays[self.gsPos]:setDisplay(self.bool1, self.bool2, self.bool3)
		end;
	end;
end;

g_onCreateUtil.addOnCreateFunction("GasStationExtended", GasStationExtended.onCreate);

print(" ++ loading GasStation Extended V "..tostring(GasStationExtended.version).." (by Blacky_BPG)");
