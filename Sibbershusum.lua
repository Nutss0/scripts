-- Sibbershusum
--
-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.
--
-- Sibbershusum Copyright (C) Fendtfan79
-- 04/01/17

Sibbershusum = {}
local ModMap_mt = Class(Sibbershusum, Mission00)

function Sibbershusum:new(baseDirectory, customMt)
    local mt = customMt
    if mt == nil then
        mt = ModMap_mt
    end
    local self = Sibbershusum:superClass():new(baseDirectory, mt)
    -- Number of additional channels that are used compared to the original setting (2)
    local numAdditionalAngleChannels = 4;

    self.terrainDetailAngleNumChannels = self.terrainDetailAngleNumChannels + numAdditionalAngleChannels;
    self.terrainDetailAngleMaxValue = (2^self.terrainDetailAngleNumChannels) - 1;
	
    self.sprayLevelFirstChannel = self.sprayLevelFirstChannel + numAdditionalAngleChannels;

    self.ploughCounterFirstChannel = self.ploughCounterFirstChannel + numAdditionalAngleChannels;
    return self
end

function Sibbershusum:onStartMission()
    Sibbershusum:superClass().onStartMission(self);
	if g_currentMission:getIsServer() and not g_currentMission.missionInfo.isValid then		
		g_currentMission.missionStats.money = 0;		
		if self.missionInfo.difficulty == 1 then
			self:addSharedMoney(150000);
			g_currentMission.missionStats.loan = 1000;        
		elseif self.missionInfo.difficulty == 2 then
			self:addSharedMoney(100000);
			g_currentMission.missionStats.loan = 3000;        
		elseif self.missionInfo.difficulty == 3 then
			self:addSharedMoney(50000); 
			g_currentMission.missionStats.loan = 9000; 
        end;
    end;
end;