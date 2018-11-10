--[[
AddConfig

Specialization for extended design configurations and register new configurations.

Author:		Ifko[nator]
Datum:		21.07.2017

Version:	v3.0

History:	v1.0 @ 28.02.2017 - initial implementation - added possibility to change capacity via desingConfiguration
			------------------------------------------------------------------------------------------------------------------
			v2.0 @ 25.03.2017 - added possibility to change rim and axis color via desingConfiguration
			------------------------------------------------------------------------------------------------------------------
			v3.0 @ 21.07.2017 - added possibility to change fillable fill types and cutable fruit types via desingConfiguration
			------------------------------------------------------------------------------------------------------------------
]]

AddConfig = {};

local currentModDirectory = g_currentModDirectory;

function AddConfig.prerequisitesPresent(specializations)
    return true;
end

function AddConfig:load(savegame)
	self.applyCustomDesing = Utils.overwrittenFunction(self.applyDesign, AddConfig.applyCustomDesing);
	
	local modDesc = loadXMLFile("modDesc", currentModDirectory .. "modDesc.xml");
	local configNumber = 0;
	
	while true do
		local configKey = "modDesc.newConfigurations.newConfiguration(" .. tostring(configNumber) .. ")";
		
		if not hasXMLProperty(modDesc, configKey) then
			break;
		end;
		
		local isColorConfig = Utils.getNoNil(getXMLBool(modDesc, configKey .. "#isColorConfig"), false);
		local configName = getXMLString(modDesc, configKey .. "#configName");
		local configXMLTag = getXMLString(modDesc, configKey .. "#configXMLTag");
		
		if configName ~= (nil and "") then
			if self.configurations[configName] ~= nil then	
				if isColorConfig then
					self:setColor(self.xmlFile, configName, self.configurations[configName]); --## config to change color on vehicle
				else
					if configXMLTag ~= (nil and "") then
						self:applyCustomDesing(self.xmlFile, self.configurations[configName], configXMLTag); --## config to change texture on vehicle
					else
						print("ERROR AddConfig.lua: Missing the xml tag for the new Config '" .. configName .. "'! Stopping adding this config now!");
					end;
				end;
			end;
		else
			print("ERROR AddConfig.lua: Missing the name for the new Config in '" .. configKey .. "'! Stopping adding this config now!");
		end;
	
		configNumber = configNumber + 1;
	end;
	
	delete(modDesc);
end;

function AddConfig:applyCustomDesing(oldFunc, xmlFile, configDesignId, configXMLTag)
    local designKey = string.format("vehicle." .. configXMLTag .. "s." .. configXMLTag .. "(%d)", configDesignId - 1);
    
    if not hasXMLProperty(xmlFile, designKey) then
        print("Warning: Invalid " .. configXMLTag .. " configuration " .. configDesignId);
        
	    return;
    end;
	
    --## change cutable fruit types
	
    local fruitTypes = {};
    local newFruitTypeCategories = getXMLString(self.xmlFile, designKey .. "#fruitTypeCategories");
    local newFruitTypeNames = getXMLString(self.xmlFile, designKey .. "#fruitTypes");
    local hasDeletedFruitTypes = false;
	
    if newFruitTypeCategories ~= nil and newFruitTypeNames == nil then
        fruitTypes = FruitUtil.getFruitTypeByCategoryName(newFruitTypeCategories);
    elseif newFruitTypeCategories == nil and newFruitTypeNames ~= nil then
        fruitTypes = FruitUtil.getFruitTypesByNames(newFruitTypeNames);
    end;

    if fruitTypes ~= nil then
	    for _, fruitType in pairs(fruitTypes) do
		    if not hasDeletedFruitTypes then
			    --## delete current cutable fruit types
				
				self.fruitTypes = {};
				
			    hasDeletedFruitTypes = true;
			end;

			local fillTypeCeck = FillUtil.fillTypeIntToName[fruitType];

			if fillTypeCeck ~= nil then	
				--## insert new cutable fruit types
				
				self.fruitTypes[fruitType] = true;
			end;
        end;
    end;
	
	--## change fillable fill types
	
	local fillTypes = {};
	local newFillTypeCategories = getXMLString(xmlFile, designKey .. "#fillTypeCategories");
	local newFillTypeNames = getXMLString(xmlFile, designKey .. "#fillTypes");
	local hasDeletedFillTypes = false;
	
	if newFillTypeCategories ~= nil and newFillTypeNames == nil then
		fillTypes = FillUtil.getFillTypeByCategoryName(newFillTypeCategories);
	elseif newFillTypeCategories == nil and newFillTypeNames ~= nil then
		fillTypes = FillUtil.getFillTypesByNames(newFillTypeNames);
	end;
	
	if fillTypes ~= nil then
		for _, fillType in pairs(fillTypes) do
			for _, fillUnit in pairs(self.fillUnits) do
				if not hasDeletedFillTypes then
					--## delete current fillable fill types
					
					fillUnit.fillTypes = {};
					
					hasDeletedFillTypes = true;
				end;
				
				local fillTypeCeck = FillUtil.fillTypeIntToName[fillType];
				
				if fillTypeCeck ~= nil then
					--## insert new fillable fill types
					
					fillUnit.fillTypes[fillType] = true;
				end;
			end;
		end;
	end;
	
	--## change capacity
    
	local newCapacity = getXMLFloat(xmlFile, designKey .. "#capacity");
	
	if newCapacity ~= nil then
		for _, fillUnit in pairs(self.fillUnits) do
			fillUnit.capacity = newCapacity;
			
			--print("Change capacity to: " .. fillUnit.capacity);
		end;
	end;
	
	--## change rim and axis color
	
	local axisColor = getXMLString(xmlFile, designKey .. "#axisColor");
	local rimColor = getXMLString(xmlFile, designKey .. "#rimColor");
    
	for _, wheel in pairs(self.wheels) do
		if axisColor ~= nil then
			self.axisColor = Vehicle.getColorFromString(axisColor);
			
			if wheel.wheelHub ~= nil then
				local r, g, b, a = unpack(self.axisColor);
            
				setShaderParameter(wheel.wheelHub, "colorScale", r, g, b, a, false);
			
				--print("Change axis color to: " .. axisColor);
			end;
		end;
		
		if rimColor ~= nil then
			self.rimColor = Vehicle.getColorFromString(rimColor);
			
			local r, g, b, a = unpack(self.rimColor);
        
			if wheel.wheelOuterRim ~= nil then
				setShaderParameter(wheel.wheelOuterRim, "colorScale", r, g, b, a, false);
			
				--print("Change outer rim color to: " .. rimColor);
			end;
			
			if wheel.wheelInnerRim ~= nil then
				setShaderParameter(wheel.wheelInnerRim, "colorScale", r, g, b, a, false);
			
				--print("Change inner rim color to: " .. rimColor);
			end;
		end;
	end;
	
	--## change material
    
	local i = 0;
    
	while true do
        local materialKey = string.format(designKey .. ".material(%d)", i);
        
		if not hasXMLProperty(xmlFile, materialKey) then
            break;
        end;
        
		local baseMaterialNode = Utils.indexToObject(self.components, getXMLString(xmlFile, materialKey.."#node"));
        local refMaterialNode = Utils.indexToObject(self.components, getXMLString(xmlFile, materialKey.."#refNode"));
        
		if baseMaterialNode ~= nil and refMaterialNode ~= nil then
            local oldMaterial = getMaterial(baseMaterialNode, 0);
            local newMaterial = getMaterial(refMaterialNode, 0);
            
			for _, component in pairs(self.components) do
                self:replaceMaterialRec(component.node, oldMaterial, newMaterial);
            end;
        end;
        
		i = i + 1;
    end;
    
	ObjectChangeUtil.updateObjectChanges(self.xmlFile, "vehicle." .. configXMLTag .. "s." .. configXMLTag, configDesignId, self.components, self);
end;

function AddConfig:delete()end;
function AddConfig:mouseEvent(posX, posY, isDown, isUp, button)end;
function AddConfig:keyEvent(unicode, sym, modifier, isDown)end;
function AddConfig:update(dt)end;
function AddConfig:draw()end;

local modDesc = loadXMLFile("modDesc", currentModDirectory .. "modDesc.xml");
local configNumber = 0;
	
while true do
	local configKey = "modDesc.newConfigurations.newConfiguration(" .. tostring(configNumber) .. ")";
	
	if not hasXMLProperty(modDesc, configKey) then
		break;
	end;
	
	local isColorConfig = Utils.getNoNil(getXMLBool(modDesc, configKey .. "#isColorConfig"), false);
	local configName = getXMLString(modDesc, configKey .. "#configName");
	
	if configName ~= nil and configName ~= "" then
		if ConfigurationUtil.configurations[configName] == nil then
			if isColorConfig then
				ConfigurationUtil.registerConfigurationType(configName, g_i18n:getText("configuration_" .. configName), nil, Vehicle.getConfigColorSingleItemLoad, Vehicle.getConfigColorPostLoad, ConfigurationUtil.SELECTOR_COLOR); --## config to change color on vehicle
			else
				ConfigurationUtil.registerConfigurationType(configName, g_i18n:getText("configuration_" .. configName), nil, nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION); --## config to change parts on vehicle
			end;
		end;
	else
		print("ERROR AddConfig.lua: Missing the name for the new Config in '" .. configKey .. "'! Stopping register this config now!");
	end;

	configNumber = configNumber + 1;
end;