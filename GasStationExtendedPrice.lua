-- 
-- Dynamic fuel prices
-- Script: Blacky_BPG
-- 
-- 1.3.1.0   12.01.2017   price calculation correction
-- 1.3.0.0   22.11.2016   initial Version for FS17
-- 


GasStationExtendedPrice = {}
GasStationExtendedPrice.version = "1.3.1.0  -  12.01.2017"
GasStationExtendedPrice_mt = Class(GasStationExtendedPrice, Object)
InitObjectClass(GasStationExtendedPrice, "GasStationExtendedPrice")

function GasStationExtendedPrice.onCreate(id)
	local object = GasStationExtendedPrice:new(g_server ~= nil, g_client ~= nil);
	if object:load(id) then
		g_currentMission:addOnCreateLoadedObject(object);
		g_currentMission:addOnCreateLoadedObjectToSave(object);
		object:register(true);
		g_currentMission.gasStationPriceRegistered = true;
	else
		object:delete();
	end;
end;

function GasStationExtendedPrice:new(isServer, isClient, mt)
	local mt = customMt;
	if mt == nil then
		mt = GasStationExtendedPrice_mt;
	end;
	local self = Object:new(isServer, isClient, mt);
	self.GasStationExtendedPriceDirtyFlag = self:getNextDirtyFlag();
	return self;
end;

function GasStationExtendedPrice:load(id)
	self.nodeId = id;
	if g_currentMission.gasStationPriceRegistered ~= nil and g_currentMission.gasStationPriceRegistered then
		return false;
	end;
	if self.isServer or g_server ~= nil then
		g_currentMission.environment:addHourChangeListener(self);
	end;
	self.fuelPrice = 1.1;
	self.fuelPriceBase = self.fuelPrice;
	self.maxFuelPrice = Utils.getNoNil(getUserAttribute(id, "maxFuelPrice"),1.5);
	self.minFuelPrice = Utils.getNoNil(getUserAttribute(id, "minFuelPrice"),1.0);
	self.maxChangeMultiplier = math.floor((self.maxFuelPrice - self.minFuelPrice) * 1000);
	self.isEnabled = true;
	self.saveId = "GasStation_fuelPrice";
	self.firstStart = true;
	return true;
end;

function GasStationExtendedPrice:delete()
	g_currentMission:removeOnCreateLoadedObjectToSave(self);
	g_currentMission.environment:removeHourChangeListener(self);
	GasStationExtendedPrice:superClass().delete(self);
end;

function GasStationExtendedPrice:readStream(streamId, connection)
	GasStationExtendedPrice:superClass().readStream(self, streamId, connection);
	if connection:getIsServer() then
		self:setFuelPrice(Utils.getNoNil(streamReadFloat32(streamId), self.fuelPrice));
	end;
end;

function GasStationExtendedPrice:readUpdateStream(streamId, timestamp, connection)
	GasStationExtendedPrice:superClass().readUpdateStream(self, streamId, timestamp, connection);
	if connection:getIsServer() then
		if streamReadBool(streamId) then
			GasStationExtendedPrice.readStream(self, streamId, connection);
		end;
	end;
end;

function GasStationExtendedPrice:writeUpdateStream(streamId, connection, dirtyMask)
	GasStationExtendedPrice:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	if not connection:getIsServer() then
		 if streamWriteBool(streamId, bitAND(dirtyMask, self.GasStationExtendedPriceDirtyFlag) ~= 0) then
			GasStationExtendedPrice.writeStream(self, streamId, connection);
		 end;
	end;
end;

function GasStationExtendedPrice:writeStream(streamId, connection)
	GasStationExtendedPrice:superClass().writeStream(self, streamId, connection);
	if not connection:getIsServer() then
		streamWriteFloat32(streamId, self.fuelPrice);
	end;
end;

function GasStationExtendedPrice:update(dt)
	if self.firstStart then
		self.firstStart = false;
		if self.isServer or g_server~= nil then
			if g_currentMission.gasStationFuelPrice == nil then
				self:hourChanged();
			end;
		end;
	end;
end;

function GasStationExtendedPrice:hourChanged()
	if self.isServer or g_server ~= nil then
		local fuelPrice = self.fuelPrice;
		local base = self.fuelPriceBase;
		local rPrice = math.random(-self.maxChangeMultiplier,self.maxChangeMultiplier)/1.5;
		local rPriceMultiAdd = 1 + (rPrice / 1000);
		local rPriceMultiSub = 1 - (rPrice / 1000);
		local fuelPriceNew = fuelPrice * rPriceMultiAdd;
		while fuelPriceNew > self.maxFuelPrice do
			fuelPriceNew = fuelPriceNew * math.min(rPriceMultiSub,rPriceMultiAdd);
		end;
		while fuelPriceNew < self.minFuelPrice do
			fuelPriceNew = fuelPriceNew * math.max(rPriceMultiSub,rPriceMultiAdd);
		end;
		self:setFuelPrice(fuelPriceNew);
	end;
end;

function GasStationExtendedPrice:setFuelPrice(price, noEventSend)
	price = Utils.getNoNil(price,self.fuelPrice);
	self.fuelPrice = price;
	g_currentMission.gasStationFuelPrice = price;
	if self.isServer or g_server ~= nil then
		self:raiseDirtyFlags(self.GasStationExtendedPriceDirtyFlag);
	end;
	GasStationExtendedPriceEvent.sendEvent(self, price, noEventSend)
end;

function GasStationExtendedPrice:loadFromAttributesAndNodes(xmlFile, key)
	local fuelPrice = Utils.getNoNil(getXMLFloat(xmlFile, key .."#fuelPrice"), self.fuelPrice);
	self:setFuelPrice(fuelPrice);
	return true;
end;

function GasStationExtendedPrice:getSaveAttributesAndNodes(nodeIdent)
	local attributes = 'fuelPrice="'..tostring(self.fuelPrice)..'"';
	return attributes, "";
end;

g_onCreateUtil.addOnCreateFunction("GasStationExtendedPrice", GasStationExtendedPrice.onCreate);

-----------------------------------------------------------------------

GasStationExtendedPriceEvent = {}
GasStationExtendedPriceEvent_mt = Class(GasStationExtendedPriceEvent, Event)
InitEventClass(GasStationExtendedPriceEvent, "GasStationExtendedPriceEvent")
function GasStationExtendedPriceEvent:emptyNew()
	local self = Event:new(GasStationExtendedPriceEvent_mt);
	return self;
end;
function GasStationExtendedPriceEvent:new(object, price)
	local self = GasStationExtendedPriceEvent:emptyNew()
	self.object = object;
	self.price = price;
	return self;
end;
function GasStationExtendedPriceEvent:readStream(streamId, connection)
	local id = streamReadInt32(streamId);
	self.object = networkGetObject(id);
	self.price = streamReadFloat32(streamId);
	self:run(connection);
end;
function GasStationExtendedPriceEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, networkGetObjectId(self.object));
	streamWriteFloat32(streamId, self.price);
end;
function GasStationExtendedPriceEvent:run(connection)
	if self.object ~= nil then
		self.object:setFuelPrice(self.price, true);
	end;
	if not connection:getIsServer() then
		g_server:broadcastEvent(GasStationExtendedPriceEvent:new(self.object, self.price), nil, connection, self.object);
	end;
end;
function GasStationExtendedPriceEvent.sendEvent(object, price, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(GasStationExtendedPriceEvent:new(object, price), nil, nil, object);
		else
			-- event can only be called by server
		end;
	end;
end;

print(" ++ loading GasStation Extended - variable fuel price V "..tostring(GasStationExtendedPrice.version).." (by Blacky_BPG)");
