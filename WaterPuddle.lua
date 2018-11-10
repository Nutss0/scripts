-- Name: WaterPuddle
-- Version: 1.0.0
-- Date: 22.01.2017
-- Author: kevink98
-- Web & Support: http://ls-modcompany.de/

local version = "1.0";

-- V 1.0.0 (22.01.2017):
		-- Release

WaterPuddle = {}
local WaterPuddle_mt = Class(WaterPuddle,Object);
InitObjectClass(WaterPuddle, "WaterPuddle");

function WaterPuddle.onCreate(id)
    local object = WaterPuddle:new(g_server ~= nil, g_client ~= nil);
	g_currentMission:addOnCreateLoadedObject(object);
	if object:load(id) then
		g_currentMission:addOnCreateLoadedObjectToSave(object);
        object:register(true);
	else
		object:delete();
	end;
end;

function WaterPuddle:new(isServer, isClient)
    local self = {};
    self = Object:new(isServer,isClient,WaterPuddle_mt);
	return self;
end;

function WaterPuddle:load(id)	
	
	self.saveId = "WaterPuddle_"..getName(id)
	self.updateM = 60000;
    self.nodeId = id;
	self.scaleBack = Utils.getNoNil(getUserAttribute(id,"scale_back"),0.002);
	self.scaleRain = Utils.getNoNil(getUserAttribute(id,"scale_ifRain"),0.002);
	self.updateTime = Utils.getNoNil(getUserAttribute(id,"updateTime"),5);	
	self.updateMinute = self.updateTime;
	
	self.numPlanes = getNumOfChildren(id);
	self.planes = {};
	self.moving = true;
	
	for i=1,self.numPlanes do
		self.planes[i] = {};
		self.planes[i].node = getChildAt(id,i-1);
		self.planes[i].state_Min = Utils.getNoNil(getUserAttribute(self.planes[i].node,"min"),0);
		self.planes[i].state_Max= Utils.getNoNil(getUserAttribute(self.planes[i].node,"max"),2);
		local x,_,z = getTranslation(self.planes[i].node);
		setTranslation(self.planes[i].node,x,self.planes[i].state_Min,z);
		local x,y,z = getTranslation(self.planes[i].node)
	end;
	
	g_currentMission:addNodeObject(self.nodeId, self)
    return true;
end;

function WaterPuddle:getSaveAttributesAndNodes(nodeIdent)
	local attributes, nodes = "","";
	for id,_ in pairs (self.planes) do
		if 0 < nodes.len(nodes) then
			nodes = nodes .. "\n"
		end
		local x,y,z = getTranslation(self.planes[id].node)
		nodes = nodes..nodeIdent..'<Plane xPos="'..x..'" yPos="'..y..'" zPos="'..z..'" nodeId="'..id..'"/>';
	end
    return attributes,nodes;
end

function WaterPuddle:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	local i = 0
	while true do
		local planeKey = key .. string.format(".Plane(%d)", i)
		if not hasXMLProperty(xmlFile, planeKey) then
			break
		end
		local x = getXMLFloat(xmlFile, planeKey .. "#xPos")
		local y = getXMLFloat(xmlFile, planeKey .. "#yPos")
		local z = getXMLFloat(xmlFile, planeKey .. "#zPos")
		local id = getXMLInt(xmlFile, planeKey .. "#nodeId")
		setTranslation(self.planes[id].node,x,y,z);		
		i = i + 1
	end;
	return true;
end

function WaterPuddle:deleteMap()
	self:delete();
end;
function WaterPuddle:delete()
	unregisterObjectClassName(self)
	g_currentMission:removeOnCreateLoadedObjectToSave(self)
end;

function WaterPuddle:update()
	--if g_currentMission.environment.currentRain == Environment.RAINTYPE_RAIN then
	--	self.moving = true;
	--end;
	local rainType = g_currentMission.environment:getRainType()
	if rainType and (rainType.typeId == Environment.RAINTYPE_RAIN or rainType.typeId == Environment.RAINTYPE_HAIL) then
		self.moving = true;	
		self.rain = true;
	else
		self.rain = false;
	end;	
	
end;

function WaterPuddle:updateTick(dt)
	if self.moving then
		self.updateM = self.updateM + (dt * g_currentMission.loadingScreen.missionInfo.timeScale);
		if self.updateM >= 60000 and self.isClient then
			self.updateM = self.updateM - 60000;
			self.updateMinute = self.updateMinute + 1;
			if self.updateMinute >= self.updateTime then
				self.updateMinute = self.updateMinute - self.updateTime;
				if self.rain then
					for id,_ in pairs(self.planes) do
						local plane = self.planes[id]
						local x,y,z = getTranslation(plane.node)
						y = math.min(y+self.scaleRain,plane.state_Max);	
						setTranslation(plane.node,x,y,z);
					end;
				else
					local i = 0;
					for id,_ in pairs(self.planes) do
						local plane = self.planes[id]
						local x,y,z = getTranslation(plane.node)
						y = y - self.scaleBack;
						if y <= plane.state_Min then
							setTranslation(plane.node,x,plane.state_Min,z);
							i = i + 1;
						else
							setTranslation(plane.node,x,y,z);
						end;	
					end;
					if i == self.numPlanes then
						self.moving = false;
					end;	
				end;
			end;
		end;
	end;
end;

g_onCreateUtil.addOnCreateFunction("WaterPuddle", WaterPuddle.onCreate);