--[[
ChangeAnimalsData

  @author: 	Ifko[nator]
  @date: 	26.03.2018
  @version: 2.5
  
  @usage:

	<extraSourceFiles>
        <sourceFile filename="ChangeAnimalsData.lua"/>
    </extraSourceFiles>
	
	<changeAnimalsData>
		<changeAnimalData animal="cow" manurePerDay="200" liqudManurePerDay="250" milkPerDay="714" dirtFillLevelPerDay="30" birthRatePerDay="0.02" strawPerDay="70" waterPerDay="35" foodPerDay="350">
			<virtualToVisibleAnimal virtual1="100" visible1="100" virtual2="180" visible2="90"/> <!-- standard for all animals = virtual1="12" visible1="12" virtual2="50" visible2="25" -->
		</changeAnimalData>
		
		<changeAnimalData animal="pig" manurePerDay="50" liqudManurePerDay="65" dirtFillLevelPerDay="16" birthRatePerDay="2" strawPerDay="20" waterPerDay="10" foodPerDay="90" animalChildBirthrate="4">
			<virtualToVisibleAnimal virtual1="40" visible1="40" virtual2="140" visible2="70"/>
		</changeAnimalData>
		
		<changeAnimalData animal="sheep" palletFillLevelPerDay="24" dirtFillLevelPerDay="6" birthRatePerDay="0.025" waterPerDay="15" foodPerDay="20">
			<virtualToVisibleAnimal virtual1="50" visible1="50" virtual2="60" visible2="30"/>
		</changeAnimalData>
		
		
		<changeAnimalData animal="chicken" pickUpObjectsPerDay="1">
			<virtualToVisibleAnimal virtual1="80" visible1="80" virtual2="100" visible2="50"/>
		</changeAnimalData>
	</changeAnimalsData>
]]

local count = 0;
local modDesc = loadXMLFile("modDesc", g_currentModDirectory .. "modDesc.xml");

while true do
	local baseText = string.format("modDesc.changeAnimalsData.changeAnimalData(%d)", count);
	
	if not hasXMLProperty(modDesc, baseText) then
		break;
	end;

	local animal = getXMLString(modDesc, baseText .. "#animal");
	local manurePerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#manurePerDay"), 0);
	local liqudManurePerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#liqudManurePerDay"), 0);
	local milkPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#milkPerDay"), 0);
	local palletFillLevelPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#palletFillLevelPerDay"), 0);
	local dirtFillLevelPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#dirtFillLevelPerDay"), 0);
	local pickUpObjectsPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#pickUpObjectsPerDay"), 0);
	local birthRatePerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#birthRatePerDay"), 0);
	local strawPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#strawPerDay"), 0);
	local waterPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#waterPerDay"), 0);
	local foodPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#foodPerDay"), 0);
	
	if animal ~= nil and AnimalUtil["ANIMAL_" .. string.upper(animal)] ~= nil then
		AnimalUtil.setAnimalData(AnimalUtil["ANIMAL_" .. string.upper(animal)], milkPerDay, manurePerDay, liqudManurePerDay, palletFillLevelPerDay, pickUpObjectsPerDay, dirtFillLevelPerDay, birthRatePerDay, strawPerDay, waterPerDay, foodPerDay);
		
		print("[Info from ChangeAnimalsData.lua]: Change Animal Data for: " .. animal .. " successfully.");
	end;
	
	count = count + 1;
end;

ChangeAnimalsData = {};
addModEventListener(ChangeAnimalsData);

function ChangeAnimalsData:loadMap(name)
	local count = 0;
	
	while true do
		local baseText = string.format("modDesc.changeAnimalsData.changeAnimalData(%d)", count);
		
		if not hasXMLProperty(modDesc, baseText) then
			break;
		end;
	
		local animal = getXMLString(modDesc, baseText .. "#animal");
		local palletFillLevelPerDay = Utils.getNoNil(getXMLFloat(modDesc, baseText .. "#palletFillLevelPerDay"), 0);
		
		if animal ~= nil and AnimalUtil["ANIMAL_" .. string.upper(animal)] ~= nil then
			--[[print("--------------------------------[Info from ChangeAnimalsData.lua] for animal " .. animal .. " ----------------------------------------------");
			
			print("old virtual 1 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[1].virtual);
			print("old visible 1 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[1].visible);
			
			print("old virtual 2 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[2].virtual);
			print("old visible 2 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[2].visible);
			
			print("-----------------------------------------------------------------------");]]
			
			local virtualAnimals1 = Utils.getNoNil(getXMLFloat(modDesc, baseText .. ".virtualToVisibleAnimal#virtual1"), g_currentMission.husbandries[animal].virtualToVisibleAnimals[1].virtual);
			local visibleAnimals1 = Utils.getNoNil(getXMLFloat(modDesc, baseText .. ".virtualToVisibleAnimal#visible1"), g_currentMission.husbandries[animal].virtualToVisibleAnimals[1].visible);
			
			local virtualAnimals2 = Utils.getNoNil(getXMLFloat(modDesc, baseText .. ".virtualToVisibleAnimal#virtual2"), g_currentMission.husbandries[animal].virtualToVisibleAnimals[2].virtual);
			local visibleAnimals2 = Utils.getNoNil(getXMLFloat(modDesc, baseText .. ".virtualToVisibleAnimal#visible2"), g_currentMission.husbandries[animal].virtualToVisibleAnimals[2].visible);
			
			g_currentMission.husbandries[animal].virtualToVisibleAnimals = {{virtual = virtualAnimals1, visible = visibleAnimals1}, {virtual = virtualAnimals2, visible = visibleAnimals2}};
			
			--[[print("new virtual 1 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[1].virtual);
			print("new visible 1 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[1].visible);
			
			print("new virtual 2 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[2].virtual);
			print("new visible 2 from animal: " .. animal .. " = " .. g_currentMission.husbandries[animal].virtualToVisibleAnimals[2].visible);]]
			
			if animal == "pig" then	
				self.startPalletFillLevelPerDayPigs = palletFillLevelPerDay;
			elseif animal == "cow" then
				self.startPalletFillLevelPerDayCows = palletFillLevelPerDay;
			end;
		end;
		
		count = count + 1;
	end;
	
	count = 0;
	
	self.youngAnimals = {};
	
	while true do
		local baseText = string.format("modDesc.youngAnimalsData.youngAnimalData(%d)", count);
		
		if not hasXMLProperty(modDesc, baseText) then
			break;
		end;
	
		local animal = getXMLString(modDesc, baseText .. "#animal");
		
		if animal ~= nil and AnimalUtil["ANIMAL_" .. string.upper(animal)] ~= nil then
			local youngAnimal = {};
			
			youngAnimal.animal = animal;
			youngAnimal.birthrate = Utils.getNoNil(getXMLInt(modDesc, baseText .. "#animalChildBirthrate"), 10);
			youngAnimal.animalsPerBirthrate = Utils.getNoNil(getXMLInt(modDesc, baseText .. "#animalsPerBirthrate"), 5);
			youngAnimal.allowAddAnimals = true;
			
			table.insert(self.youngAnimals, youngAnimal);
		end;
		
		count = count + 1;
	end;
	
	self.num = {};
	self.num.pig = 0;
	self.num.cow = 0;
	--self.num.sheep = 0;
end;

function ChangeAnimalsData:update(dt)
	local seasonLengthfactor = 1;
	
	if g_seasons ~= nil then
		--## seasons mod found, little adjusment at the 'palletFillLevelPerDay' value required
	
		seasonLengthfactor = 6 / g_seasons.environment.daysInSeason;
	end;
	
	if g_currentMission.husbandries ~= nil then
		for _, youngAnimal in pairs(self.youngAnimals) do
			if g_currentMission.husbandries[youngAnimal.animal] ~= nil then
				if g_currentMission.husbandries[youngAnimal.animal].numAnimals[0] > 0 then
					if g_currentMission.husbandries[youngAnimal.animal].numAnimals[0] >= youngAnimal.birthrate and youngAnimal.allowAddAnimals then 
						g_currentMission.husbandries[youngAnimal.animal]:addAnimals(youngAnimal.animalsPerBirthrate, 1);
						
						g_currentMission.husbandries[youngAnimal.animal].totalNumAnimals = g_currentMission.husbandries[youngAnimal.animal].numAnimals[0];
						
						youngAnimal.allowAddAnimals = false;
					end;
				else
					if g_currentMission.husbandries[youngAnimal.animal].numAnimals[1] > 0 then	
						g_currentMission.husbandries[youngAnimal.animal]:removeAnimals(g_currentMission.husbandries[youngAnimal.animal].numAnimals[1], 1);
						
						youngAnimal.allowAddAnimals = true;
					end;
					
					if g_currentMission.husbandries[youngAnimal.animal].totalNumAnimals < 0 then
						g_currentMission.husbandries[youngAnimal.animal].totalNumAnimals = 0;
					end;
				end;
			end;
		end;
		
		for _, animal in pairs({"pig", "cow"}) do
			if  g_currentMission.husbandries[animal] ~= nil and g_currentMission.husbandries[animal].numAnimals[0] > 0 and self.num[animal] ~= g_currentMission.husbandries[animal].numAnimals[0] then
				--print("huhu animal " .. animal);
				
				self.num[animal] = g_currentMission.husbandries[animal].numAnimals[0];
				
				if AnimalUtil.animals[animal].palletFillLevelPerDay ~= nil then
					local palletFillLevelPerDay = self.startPalletFillLevelPerDayPigs;
					
					if animal == "cow" then
						palletFillLevelPerDay = self.startPalletFillLevelPerDayCows;
					end;
					
					AnimalUtil.animals[animal].palletFillLevelPerDay = (palletFillLevelPerDay / self.num[animal]) / seasonLengthfactor;
					
					--[[
					print("startPalletFillLevelPerDay " .. animal .. "s = " .. palletFillLevelPerDay);
					print("num ".. animal .. "s = " .. self.num[animal]);
					
					print("seasonLengthfactor = " .. seasonLengthfactor);
					
					print("palletFillLevelPerDay without Fix = " .. palletFillLevelPerDay / self.num[animal]);
					print("palletFillLevelPerDay with Fix = " .. (palletFillLevelPerDay / self.num[animal]) / seasonLengthfactor);
					]]
				end;
			end;
		end;
	end;
end;

function ChangeAnimalsData:deleteMap()end;
function ChangeAnimalsData:mouseEvent(posX, posY, isDown, isUp, button)end;
function ChangeAnimalsData:keyEvent(unicode, sym, modifier, isDown)end;
function ChangeAnimalsData:draw()end;