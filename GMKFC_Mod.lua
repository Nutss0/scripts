-- GMKFC Mod
-- Author:	Ifko[nator]
-- Datum:	18.06.2017
-- Version: 2.9

-- Version 1.0 @ 08.02.2015 - intial release for FS 15
-- Version 2.0 @ 26.12.2016 - intial release for FS 17
--							  add support for kalk, compost and digestate
-- Version 2.5 @ 24.03.2017 - add support for create layer when trailer is empty and helper is active
--							  create or destroy layer is now only possible if the field is owned by the player
--							  deactivated for field jobs
-- Version 2.6 @ 22.04.2017 - fix issue with liquid fertilizier
-- Version 2.7 @ 06.06.2017 - fix the issue with which the helper make layer at using the Holmer Terra Variant + Zunhammer Fass + Zunhammer Vibro
-- Version 2.8 @ 11.06.2017 - fix the issue with which the helper make layer at using the an sprayer witch supports liqud fertilizer
-- Version 2.9 @ 18.06.2017 - fix for mower, they will now also remove the layer


local manure_haulm = 0;
local manureLiquid_haulm = 0;
local fertilizer_haulm = 0;
local kalk_haulm = 0
local compost_haulm = 0;

local function getHaulmID(name)
	if name ~= nil then
        local haulmId = g_currentMission:loadFoliageLayer(name, -5, -1, true, "alphaBlendStartEnd");
        
		return haulmId;
    end;
	
    return 0;
end;

local orgi_sprayerUpdateTick = Sprayer.updateTick;

function Sprayer.updateTick(self, dt)
	orgi_sprayerUpdateTick(self, dt);
	
	if not g_hasSetIds then
		manure_haulm = getHaulmID("manure_haulm");
		manureLiquid_haulm = getHaulmID("manureLiquid_haulm");
		fertilizer_haulm = getHaulmID("fertilizer_haulm");
		kalk_haulm = getHaulmID("kalk_haulm");
		compost_haulm = getHaulmID("compost_haulm");
		
		g_hasSetIds = true;
	end;
	
	local isFieldJobVehicle = false;
	
	if g_currentMission.fieldJobManager ~= nil then
		if g_currentMission.fieldJobManager.currentFieldJob ~= nil then
			if g_currentMission.fieldJobManager.currentFieldJob.fieldJobVehicles ~= nil then
				for _, vehicle in pairs(g_currentMission.fieldJobManager.currentFieldJob.fieldJobVehicles) do
					if vehicle == self then
						isFieldJobVehicle = true;
						
						break;
					end;
				end;
			end;
		end;
	end;
	
	if self:getIsTurnedOn() 
		and not SpecializationUtil.hasSpecialization(SowingMachine, self.specializations)
		and not SpecializationUtil.hasSpecialization(Cultivator, self.specializations)		
		and not isFieldJobVehicle 
	then                                                                                                 
		local haulmId = 0;
		
		if self.attacherVehicle and self.attacherVehicle.isHired and self:getFillLevel() == 0 then
			--## support to create layer when trailer is empty and helper is active
			
			if SpecializationUtil.hasSpecialization(ManureSpreader, self.specializations) then
				haulmId = manure_haulm;
			elseif SpecializationUtil.hasSpecialization(ManureBarrel, self.specializations) then
				haulmId = manureLiquid_haulm;
			elseif SpecializationUtil.hasSpecialization(Sprayer, self.specializations) then
				if not self:allowFillType(FillUtil.FILLTYPE_LIQUIDFERTILIZER) then	
					haulmId = fertilizer_haulm;
				end;
			end;
		else	
			if self:getFillLevel() > 0 then
				for _, fillUnit in pairs(self.fillUnits) do
					if fillUnit.currentFillType == FillUtil.FILLTYPE_MANURE then
						haulmId = manure_haulm;
					elseif fillUnit.currentFillType == FillUtil.FILLTYPE_LIQUIDMANURE or fillUnit.currentFillType == FillUtil.FILLTYPE_DIGESTATE then
						haulmId = manureLiquid_haulm;
					elseif fillUnit.currentFillType == FillUtil.FILLTYPE_FERTILIZER then
						haulmId = fertilizer_haulm;
					elseif fillUnit.currentFillType == FillUtil.FILLTYPE_KALK then
						haulmId = kalk_haulm;
					elseif fillUnit.currentFillType == FillUtil.FILLTYPE_COMPOST then
						haulmId = compost_haulm;
					end;
				end;
			end;
		end;
		
		--print("haulmId = " .. tostring(haulmId));
	
		if haulmId ~= 0 then
			for _, workArea in pairs(self.workAreas) do
				if self:getIsWorkAreaActive(workArea) then
					local startWorldX, _, startWorldZ = getWorldTranslation(workArea.start);
					local widthWorldX, _, widthWorldZ = getWorldTranslation(workArea.width);
					local heightWorldX, _, heightWorldZ = getWorldTranslation(workArea.height);
					
					if not self.showFieldNotOwnedWarning then
						Utils.createHaulmArea(haulmId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
					end;
				end;
			end;
		end;
	end;
end;

local orgi_cutterUpdateTick = Cutter.updateTick;

function Cutter.updateTick(self, dt)
	orgi_cutterUpdateTick(self, dt);
	
	if self.attacherVehicle and self.attacherVehicle.turnOnVehicle and self.attacherVehicle:getIsTurnedOn() then
		for _, workArea in pairs(self.workAreas) do
			if self:getIsWorkAreaActive(workArea) then
				local startWorldX, _, startWorldZ = getWorldTranslation(workArea.start);
				local widthWorldX, _, widthWorldZ = getWorldTranslation(workArea.width);
				local heightWorldX, _, heightWorldZ = getWorldTranslation(workArea.height);
				
				if not self.showFieldNotOwnedWarning then
					Utils.destroyHaulmArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
				end;
			end;
		end;
	end;
end;

local orgi_mowerUpdateTick = Mower.updateTick;

function Mower.updateTick(self, dt)
	orgi_mowerUpdateTick(self, dt);
	
	if self.turnOnVehicle and self:getIsTurnedOn() then
		for _, workArea in pairs(self.workAreas) do
			if self:getIsWorkAreaActive(workArea) then
				local startWorldX, _, startWorldZ = getWorldTranslation(workArea.start);
				local widthWorldX, _, widthWorldZ = getWorldTranslation(workArea.width);
				local heightWorldX, _, heightWorldZ = getWorldTranslation(workArea.height);
				
				if not self.showFieldNotOwnedWarning then
					Utils.destroyHaulmArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
				end;
			end;
		end;
	end;
end;

local orgi_sowingMachineUpdateTick = SowingMachine.updateTick;

function SowingMachine.updateTick(self, dt)
	orgi_sowingMachineUpdateTick(self, dt);
	
	local doGroundManipulation = self.movingDirection > 0 and self.sowingMachineHasGroundContact and not self.needsActivation or self:getIsTurnedOn();
	
	if doGroundManipulation then
		for _, workArea in pairs(self.workAreas) do
			if self:getIsWorkAreaActive(workArea) then
				local startWorldX, _, startWorldZ = getWorldTranslation(workArea.start);
				local widthWorldX, _, widthWorldZ = getWorldTranslation(workArea.width);
				local heightWorldX, _, heightWorldZ = getWorldTranslation(workArea.height);
				
				if not self.showFieldNotOwnedWarning then
					Utils.destroyHaulmArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
				end;
			end;
		end;
	end;
end;

local orgi_cultivatorUpdateTick = Cultivator.updateTick;

function Cultivator.updateTick(self, dt)
	orgi_cultivatorUpdateTick(self, dt);
	
	if self.doGroundManipulation then
		for _, workArea in pairs(self.workAreas) do
			if self:getIsWorkAreaActive(workArea) then
				local startWorldX, _, startWorldZ = getWorldTranslation(workArea.start);
				local widthWorldX, _, widthWorldZ = getWorldTranslation(workArea.width);
				local heightWorldX, _, heightWorldZ = getWorldTranslation(workArea.height);
				
				if not self.showFieldNotOwnedWarning then
					Utils.destroyHaulmArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
				end;
			end;
		end;
	end;
end;

local orgi_ploughUpdateTick = Plough.updateTick;

function Plough.updateTick(self, dt)
	orgi_ploughUpdateTick(self, dt);
	
	if self.ploughHasGroundContact then
		for _, workArea in pairs(self.workAreas) do
			if self:getIsWorkAreaActive(workArea) then
				local startWorldX, _, startWorldZ = getWorldTranslation(workArea.start);
				local widthWorldX, _, widthWorldZ = getWorldTranslation(workArea.width);
				local heightWorldX, _, heightWorldZ = getWorldTranslation(workArea.height);
				
				if not self.showFieldNotOwnedWarning then
					Utils.destroyHaulmArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
				end;
			end;
		end;
	end;
end;                                                                                                                                                                    

function Utils.createHaulmArea(haulmId, x, z, x1, z1, x2, z2)
	local IDs, detailId = {}, g_currentMission.terrainDetailId;
	local dx, dz, dwidthX, dwidthZ, dheightX, dheightZ = Utils.getXZWidthAndHeight(detailId, x, z, x1, z1, x2, z2);

	table.insert(IDs, g_currentMission.cultivatorChannel);
	table.insert(IDs, g_currentMission.sowingChannel);
	table.insert(IDs, g_currentMission.ploughChannel);
	table.insert(IDs, g_currentMission.terrainDetailTypeFirstChannel);
	
	for id = 1, #IDs do
		setDensityMaskedParallelogram(haulmId, dx, dz, dwidthX, dwidthZ, dheightX, dheightZ, 0, 1, detailId, IDs[id], g_currentMission.terrainDetailTypeNumChannels, 1);
	end;
end;                                                                                                                                                                                     

function Utils.destroyHaulmArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
	local value = 0;
	
	local haulms = {};

	table.insert(haulms, manure_haulm);
	table.insert(haulms, manureLiquid_haulm);
	table.insert(haulms, fertilizer_haulm);
	table.insert(haulms, kalk_haulm);
	table.insert(haulms, compost_haulm);
	
	for _, haulm in pairs(haulms) do
		if haulm ~= 0 then
			value = value + Utils.updateDensity(haulm, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, 0, 0);
		end;
	end;
	
	return math.min(1, value);
end;                                                                                                                                                                     