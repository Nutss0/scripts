--[[
Script to add new store category(s) in the mod view

Author:		Ifko[nator]
Date:		06.05.2017
Version:	1.8

History:	V 1.0 @ 16.11.2015 - intial release
			V 1.1 @ 09.12.2015 - bug fix for wrong placement of the new category in the mod view
			V 1.5 @ 25.10.2016 - add support for the new categories from FS 17
			V 1.8 @ 06.05.2017 - some improvements in the script, now it is smaller
]]

local count = 0;
local modDesc = loadXMLFile("modDesc", g_currentModDirectory .. "modDesc.xml");

while true do
	local baseString = string.format("modDesc.storeItems.newCategories.newCategory(%d)", count);
	
	if not hasXMLProperty(modDesc, baseString) then
		break;
	end;
	
	local name = getXMLString(modDesc, baseString .. "#name");
	local previousCategory = getXMLString(modDesc, baseString .. "#previousCategory");
	local imageFilename = getXMLString(modDesc, baseString .. "#imageFilename");
	local image = Utils.getFilename(imageFilename, g_currentModDirectory);
	
	local modFilename, isMod, ModDirectoryIndex = Utils.removeModDirectory(g_currentModDirectory);
	
	if (name and image) ~= (nil and "") then
		if isMod then 
			local storeUtil = StoreItemsUtil.storeCategories;
			local storeItem = storeUtil.placeables.orderId;
			
			if previousCategory ~= (nil and "") then
				if storeUtil[previousCategory].orderId ~= nil then
					storeItem = storeUtil[previousCategory].orderId;
				else
					print("[INFO (addStoreCategory.lua)]: The previous category '" .. previousCategory .. "' is not an standard category! Adding the category '" .. name .. "' from the Mod '" .. g_currentModName .. "' as last!");
				end;
			else
				print("[INFO (addStoreCategory.lua)]: Missing the previous category name! Adding the category '" .. name .. "' from the Mod '" .. g_currentModName .. "' as last!");
			end;
		
			if storeUtil[name] == nil then
				if g_i18n:hasText(name) then	
					storeUtil[name] = {
						orderId = storeItem - 0.1,
						name = name,
						title = g_i18n:getText(name),
						image = image
					};
				else
					print("[Error (addStoreCategory.lua)]: Missing the l10n entry for '" .. name .. "'! Stop adding the category(" .. count .. ") from the Mod '" .. g_currentModName .. "' now!");
				end;
			end;
		end;
	else
		if name == (nil or "") then
			print("[Error (addStoreCategory.lua)]: Missing the category name! Stop adding the category(" .. count .. ") from the Mod '" .. g_currentModName .. "' now!");
		else
			print("[Error (addStoreCategory.lua)]: Missing the image  for the category '" .. name .. "'! Stop adding the category(" .. count .. ") from the Mod '" .. g_currentModName .. "' now!");
		end;
	end;

	count = count - 1;
end;