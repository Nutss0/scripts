--
-- Register of Animals
--
-- @author: kevink98
-- @version: 1.1.0.0
-- @date: 13.11.2017
-- @Map: Sibbershusum
--
-- Erlaubnis zum einbau in die Sibbershusum Map liegt von kevink98/ LS ModCompany vor!
-- Permission to install in the Sibbershusum Map is available from kevink98/ LS ModCompany!
-- 

local dir = g_currentModDirectory;

AnimalUtil.registerAnimal("cowcalf", g_i18n:getText("shopItem_cowcalf"), dir .. "scripts/hud/cowcalf.png", dir .. "scripts/hud/hud_fill_cowcalf.png", dir .. "scripts/hud/hud_fill_cowcalf_sml.png", 200, 180 * 0.000001* 0.5, 5, true,  false);
AnimalUtil.registerAnimal("piglet", g_i18n:getText("shopItem_piglet"), dir .. "scripts/hud/piglet.png", dir .. "scripts/hud/hud_fill_piglet.png", dir .. "scripts/hud/hud_fill_piglet_sml.png", 200, 150 * 0.000001* 0.5, 5, true,  false);
AnimalUtil.registerAnimal("beef", g_i18n:getText("shopItem_beef"), dir .. "scripts/hud/beef.png", dir .. "scripts/hud/hud_fill_beef.png", dir .. "scripts/hud/hud_fill_beef_sml.png", 300, 250 * 0.000001* 0.5, 10, true,  false);

AnimalUtil.sendNumBits = AnimalUtil.sendNumBits + 3;

registerAnimal = {};
registerAnimal.newAnimals = {["cowcalf"]=true, ["piglet"]=true, ["beef"]=true};
addModEventListener(registerAnimal);
function registerAnimal:loadMap() 
	self:setAnimals();
end;
function registerAnimal:getNumAnimals()
	return 0;
end;

function registerAnimal:setAnimals()
	if self.isSet == nil then
		self:setTablet("cowcalf");
		self:setTablet("piglet");
		self:setTablet("beef");
		self.isSet = true;
	end;
end;

function registerAnimal:setTablet(name)
	if g_currentMission.husbandries[name] == nil then
		g_currentMission.husbandries[name] = {};
		g_currentMission.husbandries[name].typeName = name;
		g_currentMission.husbandries[name].animalDesc = AnimalUtil.animals[name];
		g_currentMission.husbandries[name].totalNumAnimals = 0;
		g_currentMission.husbandries[name].numAnimals = 0;
		g_currentMission.husbandries[name].numVisibleAnimals = 0;
		g_currentMission.husbandries[name].tipTriggers = {};
		g_currentMission.husbandries[name].tipTriggersFillLevels = {};
		g_currentMission.husbandries[name].modfactoryFakeHusbandry = true;
		g_currentMission.husbandries[name].dailyUpkeep = 0;
		g_currentMission.husbandries[name].productivity = 0;
		g_currentMission.husbandries[name].dirtificationFillType = FillUtil.FILLTYPE_GRASS_WINDROW;
		g_currentMission.husbandries[name].averageProduction = 0;
		g_currentMission.husbandries[name].getNumAnimals = function(...) return self:getNumAnimals(...) end;
		g_currentMission.husbandries[name].addAnimals = function(...) return self:addAnimals(...) end;		
	end;
end;

function registerAnimal:update() end;
function registerAnimal:draw() end;
function registerAnimal:mouseEvent() end;
function registerAnimal:keyEvent() end;
function registerAnimal:delete() end;
function registerAnimal:deleteMap() end;

function registerAnimal.doAnimalLoading(old)
	return function(e,target, animalType, numAnimalsDiff, price, userId)
		if registerAnimal.newAnimals[AnimalUtil.animalIndexToDesc[animalType].name] == nil or target ~= nil then
			old(e,target, animalType, numAnimalsDiff, price, userId);
		end;
	end;
end;

function registerAnimal.setLoadSeason(old)
	return function(...)
		registerAnimal:setAnimals()
		old(...);
	end;
end;

AnimalLoadingTrigger.doAnimalLoading = registerAnimal.doAnimalLoading(AnimalLoadingTrigger.doAnimalLoading)
if g_seasons ~= nil and g_seasons.animals ~= nil and g_seasons.animals.load ~= nil then
	g_seasons.animals.load = registerAnimal.setLoadSeason(g_seasons.animals.load)
end;
   