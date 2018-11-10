-- Filename: LowerAnimalPrices.lua
-- Autore: vortex1988
-- Data: 13/11/2016
-- Script per aggiornare i prezzi degil animali in modo da renderli più realistici
-- Update 1.1.0: modificato il prezzo dei suini per rendere la vendita realistica e l'acquisto di scrofe realistico.

LowerAnimalPrices = {};
LowerAnimalPrices.modDirectory = g_currentModDirectory;

addModEventListener(LowerAnimalPrices);

function LowerAnimalPrices:draw()
end;

function LowerAnimalPrices:keyEvent(unicode, sym, modifier, isDown)
end;

function LowerAnimalPrices:mouseEvent(posX, posY, isDown, isUp, button)
end;

function LowerAnimalPrices:update(dt)

	if  g_currentMission.husbandries.cow.animalDesc.canBeBought then
		g_currentMission.husbandries.cow.animalDesc.price = 1800;
		g_currentMission.husbandries.cow.animalDesc.dailyUpkeep = 0;
		g_currentMission.husbandries.cow.animalDesc.canBeBought = true;
		g_currentMission.husbandries.cow.animalDesc.hasStatistics = true;
		--g_currentMission.husbandries.cow.animalDesc.imageFilename = self.modDirectory .. "store/store_cow.png";
	end;
	
	
	if  g_currentMission.husbandries.pig.animalDesc.canBeBought then
		g_currentMission.husbandries.pig.animalDesc.price = 700;
		g_currentMission.husbandries.pig.animalDesc.dailyUpkeep = 0;
		g_currentMission.husbandries.pig.animalDesc.canBeBought = true;
		g_currentMission.husbandries.pig.animalDesc.hasStatistics = true;
	--	g_currentMission.husbandries.pig.animalDesc.imageFilename = self.modDirectory .. "store/store_pig.png";
	end;
	
	if  g_currentMission.husbandries.sheep.animalDesc.canBeBought then
		g_currentMission.husbandries.sheep.animalDesc.price = 400;
		g_currentMission.husbandries.sheep.animalDesc.dailyUpkeep = 0;
		g_currentMission.husbandries.sheep.animalDesc.canBeBought = true;
		g_currentMission.husbandries.sheep.animalDesc.hasStatistics = true;
	--	g_currentMission.husbandries.sheep.animalDesc.imageFilename = self.modDirectory .. "store/store_sheep.png";
	end;
	
	-- if  g_currentMission.husbandries.chicken.animalDesc.canBeBought then
		-- g_currentMission.husbandries.chicken.animalDesc.price = 200;
		-- g_currentMission.husbandries.chicken.animalDesc.dailyUpkeep = 10;
		-- g_currentMission.husbandries.chicken.animalDesc.canBeBought = true;
		-- g_currentMission.husbandries.chicken.animalDesc.hasStatistics = true;
	-- --	g_currentMission.husbandries.sheep.animalDesc.imageFilename = self.modDirectory .. "store/store_sheep.png";
	-- end;
	
end;

function LowerAnimalPrices:deleteMap()end;