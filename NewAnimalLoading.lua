--
-- New AnimalLoading Trigger and HUD
-- Animal Loading only as dealer with seperate buy and sell trigger functionality
--
-- Edited Script Blacky_BPG
--
-- Version:		1.4.4.0 A  -    23.03.2017    fixed animal sell function
-- Version:		1.4.4.0    -    19.03.2017    initial release for FS17
--

addNewAnimalScreens = {};
addNewAnimalScreens.version = "1.4.4.0 A  -   23.03.2017";
addNewAnimalScreens.modDirectory = g_currentModDirectory;
function addNewAnimalScreens:loadMap(name)
	local count = 0;
	local modDesc = loadXMLFile("modDesc", addNewAnimalScreens.modDirectory .. "modDesc.xml");
	while true do
		local baseText = string.format("modDesc.l10n.text(%d)", count);
		if not hasXMLProperty(modDesc, baseText) then
			break;
		end;
		local name = getXMLString(modDesc, baseText .. "#name");
		local entry = getXMLString(modDesc, baseText .. "."..g_languageShort);
		g_i18n.globalI18N.texts[name] = Utils.getNoNil(entry,g_i18n:getText(name));
		count = count + 1;
	end;
	g_currentMission.AnimalScreenBuy = AnimalScreenBuy:new();
	g_currentMission.AnimalScreenSell = AnimalScreenSell:new();
	g_gui:loadGui(Utils.getFilename("maps/xmls/NewAnimalScreen.xml",addNewAnimalScreens.modDirectory), "AnimalScreenBuy", g_currentMission.AnimalScreenBuy);
	g_gui:loadGui(Utils.getFilename("maps/xmls/NewAnimalScreen.xml",addNewAnimalScreens.modDirectory), "AnimalScreenSell", g_currentMission.AnimalScreenSell);
	print(" ++ register NewAnimalLoading GUI V "..tostring(addNewAnimalScreens.version).." (by Blacky_BPG)");
end;
function addNewAnimalScreens:deleteMap() end;
function addNewAnimalScreens:keyEvent(unicode, sym, modifier, isDown) end;
function addNewAnimalScreens:mouseEvent(posX, posY, isDown, isUp, button) end;
function addNewAnimalScreens:update(dt) end;
function addNewAnimalScreens:draw() end; 
addModEventListener(addNewAnimalScreens);


----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------


NewAnimalLoadingTrigger = {};
local NewAnimalLoadingTrigger_mt = Class(NewAnimalLoadingTrigger, Object);
InitObjectClass(NewAnimalLoadingTrigger, "NewAnimalLoadingTrigger");

function NewAnimalLoadingTrigger.onCreate(id)
    local trigger = NewAnimalLoadingTrigger:new(g_server ~= nil, g_client ~= nil)
    if trigger ~= nil then
        g_currentMission:addOnCreateLoadedObject(trigger);
        trigger:load(id);
        trigger:register(true);
    end
end

function NewAnimalLoadingTrigger:new(isServer, isClient)
    local self = Object:new(isServer, isClient, NewAnimalLoadingTrigger_mt);
    return self;
end

function NewAnimalLoadingTrigger:load(id)
    self.isDealer = true;
    self.animalTypes = {};
    self.buyDealer = Utils.getNoNil(getUserAttribute(id, "buyDealer"),false);
    self.sellDealer = Utils.getNoNil(getUserAttribute(id, "sellDealer"),false);
    local animalTypesString = getUserAttribute(id, "animalTypes");
    if animalTypesString == nil then
        print("Error: NewAnimalLoadingTrigger (Dealer) has missing attribute 'animalTypes'!");
        return nil;
    end
    if self.buyDealer == false and self.sellDealer == false then
        print("Error: NewAnimalLoadingTrigger (Dealer) does not know whether to sell or buy (buyDealer and sellDealer not set)");
        return nil;
    end
    local animalTypes = Utils.splitString(" ", animalTypesString);
    for _, animalType in pairs(animalTypes) do
        local desc = AnimalUtil.animals[animalType];
        if desc ~= nil then
            table.insert(self.animalTypes, desc.index);
        else
            print("Error: NewAnimalLoadingTrigger (Dealer) has invalid animalType ("..tostring(animalType)..")");
        end
    end

    self.triggerId = id;
    addTrigger(id, "triggerCallback", self);

    self.appearsOnPDA = Utils.getNoNil(getUserAttribute(id, "appearsOnPDA"), true);
    self.title = g_i18n:getText(Utils.getNoNil(getUserAttribute(id, "title"), "ui_farm"))

    self.isEnabled = true

    if self.appearsOnPDA then
        local mapPosition = id;
        local mapPositionIndex = getUserAttribute(id, "mapPositionIndex");
        if mapPositionIndex ~= nil then
            mapPosition = Utils.indexToObject(id, mapPositionIndex);
            if mapPosition == nil then
                mapPosition = id;
            end
        end

        local x, _, z = getWorldTranslation(mapPosition);

        local hotspotObjectId = 0;
        local fullViewName = Utils.getNoNil(getUserAttribute(id, "stationName"), "animals_dealer")
        if g_i18n:hasText(fullViewName) then
            fullViewName = g_i18n:getText(fullViewName)
        end
        self.mapHotspot = g_currentMission.ingameMap:createMapHotspot("livestockDealer", fullViewName, nil, getNormalizedUVs({264, 776, 240, 240}), nil, x, z, nil, nil, false, false, false, hotspotObjectId, nil, MapHotspot.CATEGORY_DEFAULT);
    end

    self.loadingVehicle = nil;

    self.activateText = g_i18n:getText("animals_openAnimalScreen")
    self.isActivatableAdded = false

    self.moneyChangeId = getMoneyTypeId();

    return self;
end

function NewAnimalLoadingTrigger:delete()
    if self.mapHotspot ~= nil then
        g_currentMission.ingameMap:deleteMapHotspot(self.mapHotspot);
    end
    removeTrigger(self.triggerId);
end

function NewAnimalLoadingTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if self.isEnabled and (onEnter or onLeave) then
        local vehicle = g_currentMission.nodeToVehicle[otherId];
        if vehicle ~= nil and vehicle.allowFillType ~= nil then
            local validFillType = false;
            for _, animalType in pairs(self.animalTypes) do
                local animalDesc = AnimalUtil.animalIndexToDesc[animalType]
                if vehicle:allowFillType(animalDesc.fillType) then
                    validFillType = true;
                    break;
                end
            end
            if validFillType then
                if onEnter then
                    local isValid = true;
                    local fillType = vehicle:getUnitFillType(vehicle.livestockTrailer.fillUnitIndex);
                    if fillType ~= nil and fillType ~= FillUtil.FILLTYPE_UNKNOWN then
                        isValid = false;
                        for _, animalType in pairs(self.animalTypes) do
                            local animalDesc = AnimalUtil.animalIndexToDesc[animalType];
                            if animalDesc.fillType == fillType then
                                isValid = true;
                                break;
                            end
                        end
                    end
                    if isValid then
                        self:setLoadingTrailer(vehicle)
                    end

                elseif onLeave then
                    if vehicle == self.loadingVehicle then
                        self:setLoadingTrailer(nil)
                    end
                    if vehicle == self.activatedTarget then
						if self.buyDealer and self.sellDealer then
							g_animalScreen:onVehicleLeftTrigger()
						elseif self.buyDealer then
							g_currentMission.AnimalScreenBuy:onVehicleLeftTrigger()
						elseif self.sellDealer then
							g_currentMission.AnimalScreenSell:onVehicleLeftTrigger()
						end;
                        self.objectActivated = false
                    end
                end
            end
        elseif g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
            if onEnter then
                self.isPlayerInRange = true
            else
                self.isPlayerInRange = false
            end
            self:updateActivatableObject()
        end


    end
end

function NewAnimalLoadingTrigger:updateActivatableObject()
    if self.loadingVehicle ~= nil or self.isPlayerInRange then
        if not self.isActivatableAdded then
            self.isActivatableAdded = true
            g_currentMission:addActivatableObject(self);
        end
    else
        if self.isActivatableAdded and self.loadingVehicle == nil and not self.isPlayerInRange then
            g_currentMission:removeActivatableObject(self);
            self.isActivatableAdded = false
            self.objectActivated = false;
        end
    end
end

function NewAnimalLoadingTrigger:setLoadingTrailer(loadingVehicle)
    if self.loadingVehicle ~= nil then
        self.loadingVehicle.animalTrigger = nil
    end
    self.loadingVehicle = loadingVehicle
    if self.loadingVehicle ~= nil then
        self.loadingVehicle.animalTrigger = self
    end
    self:updateActivatableObject()
end

function NewAnimalLoadingTrigger:getIsActivatable(vehicle)
    if g_gui.currentGui == nil and self.isEnabled and g_currentMission:getHasPermission("tradeAnimals") then
        local rootAttacherVehicle = nil
        if self.loadingVehicle ~= nil then
            rootAttacherVehicle = self.loadingVehicle:getRootAttacherVehicle();
        end
        return self.isPlayerInRange or rootAttacherVehicle == g_currentMission.controlledVehicle
    end
    return false;
end

function NewAnimalLoadingTrigger:drawActivate()
end

function NewAnimalLoadingTrigger:onActivateObject()
    g_currentMission:addActivatableObject(self);
    self.objectActivated = true;
    self.activatedTarget = self.loadingVehicle
    if self.buyDealer and self.sellDealer then
        g_animalScreen:setData(true, self.title, self.animalTypes, self.loadingVehicle)
        g_animalScreen:setCallback(self.loadAnimals, self);
        g_gui:showGui("AnimalScreen");
    elseif self.buyDealer then
        g_currentMission.AnimalScreenBuy:setData(true, self.title, self.animalTypes, self.loadingVehicle)
        g_currentMission.AnimalScreenBuy:setCallback(self.loadAnimals, self);
        g_gui:showGui("AnimalScreenBuy");
    elseif self.sellDealer then
        g_currentMission.AnimalScreenSell:setData(true, self.title, self.animalTypes, self.loadingVehicle)
        g_currentMission.AnimalScreenSell:setCallback(self.loadAnimals, self);
        g_gui:showGui("AnimalScreenSell");
    end;
end

function NewAnimalLoadingTrigger:loadAnimals(target, animalType, numAnimalsDiff, price)
    self.activatedTarget = nil
    self.objectActivated = false
    if not self.isServer then
        g_client:getServerConnection():sendEvent( AnimalLoadingTriggerEvent:new(self, target, animalType, numAnimalsDiff, price) );
    else
        self:doAnimalLoading(target, animalType, numAnimalsDiff, price);
    end
end

function NewAnimalLoadingTrigger:doAnimalLoading(target, animalType, numAnimalsDiff, price, userId)
    if not self.isServer then
        return;
    end
    if self.buyDealer and numAnimalsDiff > 0 and not self.sellDealer then
        return;
    end;
    if self.sellDealer and numAnimalsDiff < 0 and not self.buyDealer then
        return;
    end;
    local animalDesc = AnimalUtil.animalIndexToDesc[animalType]
    local husbandry = g_currentMission.husbandries[animalDesc.name]
    if numAnimalsDiff < 0 then
        if target == nil then
            husbandry:addAnimals(math.abs(numAnimalsDiff), animalDesc.subType);
        end
    else
        if target == nil then
            husbandry:removeAnimals(math.abs(numAnimalsDiff), animalDesc.subType);
        end
    end
    if target ~= nil then
        numAnimalsDiff = numAnimalsDiff * -1
        target:setUnitFillLevel(target.livestockTrailer.fillUnitIndex, target:getUnitFillLevel(target.livestockTrailer.fillUnitIndex) + numAnimalsDiff, animalDesc.fillType)
    end

    userId = Utils.getNoNil(userId, g_currentMission:getServerUserId())

    if price ~= 0 then
        if price > 0 then
            g_currentMission:addMoney(price, userId, "soldAnimals");
            if userId == g_currentMission:getServerUserId() then
                g_currentMission:addMoneyChange(price, FSBaseMission.MONEY_TYPE_ANIMALS, true, g_i18n:getText("finance_soldAnimals"));
            end
        else
            g_currentMission:addMoney(price, userId, "newAnimalsCost");
            if userId == g_currentMission:getServerUserId() then
                g_currentMission:addMoneyChange(price, FSBaseMission.MONEY_TYPE_ANIMALS, true, g_i18n:getText("finance_newAnimalsCost"));
            end
        end
    end

end

print(" ++ register NewAnimalLoading Trigger V "..tostring(addNewAnimalScreens.version).." (by Blacky_BPG)");

g_onCreateUtil.addOnCreateFunction("NewAnimalLoadingTrigger", NewAnimalLoadingTrigger.onCreate);


----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------

AnimalScreenBuy = {};
AnimalScreenBuy.modDirectory = g_currentModDirectory;

local AnimalScreenBuy_mt = Class(AnimalScreenBuy, ScreenElement);

function AnimalScreenBuy:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = AnimalScreenBuy_mt;
    end;
    local self = ScreenElement:new(target, custom_mt);
    self.isOpen = false

    self.selectedAnimalIndex = 0
    self.isDealer = true

    self.returnScreenName = ""
    self.currentNumAnimals = 0

    self.transferData = {}

    return self;
end;

function AnimalScreenBuy:onCreate()
    self.listSliderElement:setController(self.animalItemList)
end;

function AnimalScreenBuy:onClose(element)
    AnimalScreenBuy:superClass().onClose(self);
    self.transferData = {}
    self.isOpen = false;
end

function AnimalScreenBuy:onOpen()
    AnimalScreenBuy:superClass().onOpen(self);

    self:updateBalanceText();

    self.isOpen = true;

    self.animalItemList.ignoreUpdate = true;
    self.animalItemList:deleteListItems();

    self.currentItemList = {};
    self.currentAnimalList = {};
    self.animalIconMapping = {}
    for _, animalType in pairs(self.animalTypes) do
        local animalDesc = AnimalUtil.animalIndexToDesc[animalType]
        if g_currentMission.husbandries[animalDesc.name] ~= nil and (self.animalTarget == nil or self.animalTarget:allowFillType(animalDesc.fillType)) then
            if animalDesc.canBeBought then
                self.currentAnimal = animalDesc;
                local newListItem = self.animalItemTemplate:clone(self.animalItemList);
                newListItem:updateAbsolutePosition();
                table.insert(self.currentItemList, self.currentAnimal);
                table.insert(self.currentAnimalList, animalDesc);
                self.currentAnimal = nil;
            end
        end
    end;
    self.animalItemList.ignoreUpdate = false;
    self.animalItemList:updateItemPositions();

    local numAnimals = #self.currentItemList;

    self.shopListSeparator1:setVisible(numAnimals > 0)
    self.shopListSeparator2:setVisible(numAnimals > 1)

    if numAnimals > 0 then
        self.animalItemList:scrollTo(1, false);
        self.animalItemList:setSelectedRow(1, true);
    end

    self:updateData()

    if GS_IS_CONSOLE_VERSION then
        FocusManager:setFocus(self.animalItemList)
    end
end

function AnimalScreenBuy:onClickBack()
    AnimalScreenBuy:superClass().onClickBack(self);
end;

function AnimalScreenBuy:onClickActivate()
    AnimalScreenBuy:superClass().onClickActivate(self);

    if self.transferData.left.baseNumOfAnimals == self.transferData.left.numOfAnimals and self.transferData.right.baseNumOfAnimals == self.transferData.right.numOfAnimals then
        return
    end

    local enoughMoney = true
    if g_currentMission ~= nil then
        enoughMoney = g_currentMission.missionStats.money >= -self.totalPrice
    end
    if not enoughMoney then
        g_gui:showInfoDialog({text=g_i18n:getText("shop_messageNotEnoughMoneyToBuy")})
        return
    end

    self.animalType = self.currentAnimalList[self.selectedAnimalIndex].index
    local animalDesc = AnimalUtil.animalIndexToDesc[self.animalType]
    local text = ""
    local numAnimalsDif = self.transferData.right.numOfAnimals - self.transferData.right.baseNumOfAnimals

    if numAnimalsDif < 0 then
        text = string.format(g_i18n:getText("animals_buy"), math.abs(numAnimalsDif), animalDesc.title, g_i18n:formatMoney(math.abs(self.totalPrice), 0, true, false))
    else
        g_gui:showInfoDialog({text=g_i18n:getText("shop_messageOnlyBuyAnimals")})
        return
    end

    g_gui:showYesNoDialog({text=text, callback=self.onClickYesNo, target=self})
end

function AnimalScreenBuy:onVehicleLeftTrigger()
    if self.isOpen then
        g_gui:showInfoDialog({text=g_i18n:getText("animals_transportTargetLeftTrigger"), callback=self.onClickInfoOk, target=self})
    end
end

function AnimalScreenBuy:onClickInfoOk()
    self:onClickBack()
end

function AnimalScreenBuy:onClickYesNo(yes)
    if yes then
        if self.callbackFunc ~= nil then
            local dif = self.transferData.right.numOfAnimals - self.transferData.right.baseNumOfAnimals
            if self.callbackTarget ~= nil then
                self.callbackFunc(self.callbackTarget, self.animalTarget, self.animalType, dif, self.totalPrice);
            else
                self.callbackFunc(self.animalTarget, self.animalType, dif, self.totalPrice);
            end;
        end;
        self:onClickBack()
    end
end

function AnimalScreenBuy:onClickAddOne()
    self:changeNumAnimals(1)
end

function AnimalScreenBuy:onClickRemoveOne()
    self:changeNumAnimals(-1)
end

function AnimalScreenBuy:changeNumAnimals(dif)
    if dif > 0 then
        dif = math.min(dif, self.transferData.right.numOfAnimals, self.transferData.left.capacity-self.transferData.left.numOfAnimals)
    else
        dif = math.max(-self.transferData.left.numOfAnimals, dif, -(self.transferData.right.capacity-self.transferData.right.numOfAnimals))
    end

    self.transferData.left.numOfAnimals = math.max(self.currentNumAnimals,self.transferData.left.numOfAnimals + dif)
    self.transferData.right.numOfAnimals = math.min(AnimalScreen.MAX_ITEMS,self.transferData.right.numOfAnimals - dif)
    self:updateData()
end

function AnimalScreenBuy:updateData()
    local animalDesc = self.currentAnimalList[self.selectedAnimalIndex]

    local lockedAnimal = nil
    if self.animalTarget ~= nil and self.animalTarget:getUnitFillLevel(self.animalTarget.livestockTrailer.fillUnitIndex) > 0 then
        lockedAnimal = self.animalTarget:getUnitFillType(self.animalTarget.livestockTrailer.fillUnitIndex)
    elseif self.transferData.left.baseNumOfAnimals ~= self.transferData.left.numOfAnimals or self.transferData.right.baseNumOfAnimals ~= self.transferData.right.numOfAnimals then
        lockedAnimal = animalDesc.fillType
    end
    self:lockAnimal(lockedAnimal)

    self.totalPrice = 0
    local sellPrice = 0
    local buyPrice = 0
    local fee = 0
    local dif = self.transferData.right.numOfAnimals - self.transferData.right.baseNumOfAnimals

    if self.transferData.right.numOfAnimals < self.transferData.right.baseNumOfAnimals then
        buyPrice = dif * self.currentAnimalList[self.selectedAnimalIndex].price
    else
        dif = 0
    end

    if self.animalTarget == nil and dif ~= 0 then
        fee = -AnimalScreen.TRANSPORTATION_FEE * g_currentMission.missionInfo.buyPriceMultiplier * math.abs(dif);
    end

    self.totalPrice = sellPrice + buyPrice + fee
    self.feeText:setText(g_i18n:formatMoney(fee, 0, true, false), true)

    self.sellTextBox:setVisible(false)
    self.sellTextElement:setVisible(false)

    local buyText1 = g_i18n:formatMoney(buyPrice, 0, true, false)
    local buyText2 = ""
    local buyText3 = ""
    if buyPrice ~= 0 then
        buyText1 = buyText1 .. " ( "
        buyText2 = math.abs(dif)
        buyText3 = " )"
    end
    self.buyText[1]:setText(buyText1, true)
    self.buyText[2]:setText(buyText2, true)
    self.buyText[3]:setText(buyText3, true)
    self.buyTextBox:invalidateLayout()

    self.buttonBottom:setText(g_i18n:getText("shop_giveAnimals"), false)

    if self.totalPrice < 0 then
        self.totalText:applyProfile("animalAttributeValueNeg")
    elseif self.totalPrice > 0 then
        self.totalText:applyProfile("animalAttributeValuePos")
    else
        self.totalText:applyProfile("animalAttributeValue")
    end
    self.totalText:setText(g_i18n:formatMoney(self.totalPrice, 0, true, false), true)

    self.feeTextBox:invalidateLayout()
    self.totalTextBox:invalidateLayout()

    local icon = ""
    if self.lockedAnimal ~= nil then
        icon = FillUtil.fillTypeIndexToDesc[self.lockedAnimal].hudOverlayFilenameSmall
    else
        if self.currentAnimalList ~= nil then
            animalDesc = self.currentAnimalList[self.selectedAnimalIndex]
            icon = FillUtil.fillTypeIndexToDesc[animalDesc.fillType].hudOverlayFilenameSmall
        end
    end

    local numOfAnimals = self.transferData.left.numOfAnimals
    if self.transferData.left.target ~= nil then
        numOfAnimals = numOfAnimals .. " / " .. self.transferData.left.capacity
    end
    self.fillIconText:setText(numOfAnimals)
    self.fillIcon:setVisible(icon ~= "")
    if icon ~= "" then
        self.fillIcon:setImageFilename(icon)
    end

    numOfAnimals = self.transferData.right.numOfAnimals
    if self.transferData.right.target ~= nil then
        numOfAnimals = numOfAnimals .. " / " .. self.transferData.right.capacity
    end
    self.fillIconTextRight:setText(numOfAnimals)
    self.fillIconRight:setVisible(icon ~= "")
    if icon ~= "" then
        self.fillIconRight:setImageFilename(icon)
    end

    self:updateButtons(self.transferData.left.baseNumOfAnimals == self.transferData.left.numOfAnimals and self.transferData.right.baseNumOfAnimals == self.transferData.right.numOfAnimals , self.transferData.left.numOfAnimals ~= self.currentNumAnimals)
end

function AnimalScreenBuy:setData(isDealer, title, animalTypes, target)
    isDealer = true;
    self.boxRight:setVisible(target ~= nil and not isDealer)
    self.boxPriceRight:setVisible(not self.boxRight.visible)

    local targetIcon = Utils.getFilename("$dataS2/menu/hud/ui_animalDealer.dds", AnimalScreenBuy.modDirectory);
    local targetName = title
    if target ~= nil then
        local storeItem = StoreItemsUtil.storeItemsByXMLFilename[target.configFileName:lower()];
        targetIcon = storeItem.imageActive
        targetName = storeItem.name
    end

    self.buttonTop:setText(g_i18n:getText("button_buy"))

    if target == nil then
        targetName = g_i18n:getText("ui_farm")
    end
    self.boxTargetIcon:setImageFilename(targetIcon)
    self.boxHeaderText:setText(targetName)
    self.title:setText(title)

    self.animalTypes = animalTypes
    self.animalTarget = target

    self.isDealer = isDealer

    self:updateButtons(false,true)
end

function AnimalScreenBuy:lockAnimal(animalFillType)
    self.animalItemList:setDisabled(animalFillType ~= nil)

    local selectedIndex = 1
    for k, desc in pairs(self.currentItemList) do
        local elem = self.animalIconMapping[desc]
        if animalFillType == nil or desc.fillType == animalFillType then
            elem:applyProfile("animalIcon")
            selectedIndex = k
        else
            elem:applyProfile("animalIconDisabled")
        end
        self.animalIconMapping[desc]:setImageFilename(desc.imageFilename);
    end

    if animalFillType == nil then
        selectedIndex = self.selectedAnimalIndex
    end

    if selectedIndex > 0 then
        self.animalItemList:setSelectedRow(selectedIndex);
        self.animalItemList.listItems[selectedIndex]:setSelected(true)
    end
end

function AnimalScreenBuy:onCreateAnimalIcon(element)
    if self.currentAnimal ~= nil then
        self.animalIconMapping[self.currentAnimal] = element
        element:setImageFilename(self.currentAnimal.imageFilename);
    end;
end;

function AnimalScreenBuy:onCreateAnimalName(element)
    if self.currentAnimal ~= nil then
        element:setText(self.currentAnimal.title);
    end;
end;

function AnimalScreenBuy:onCreateAnimalPrice(element)
    if self.currentAnimal ~= nil then
        element:setText(g_i18n:formatMoney(self.currentAnimal.price, 0, true, true), true)
    end;
end;

function AnimalScreenBuy:onCreatePriceBox(element)
    element:invalidateLayout(true)
end

function AnimalScreenBuy:updateBalanceText()
    local money = 10000;
    if g_currentMission ~= nil then
        money = g_currentMission.missionStats.money;
    end;

    self.shopMoney:setText(g_i18n:formatMoney(money, 0, true, true), true);
    if money > 0 then
        self.shopMoney:applyProfile("shopMoney")
    else
        self.shopMoney:applyProfile("shopMoneyNeg")
    end
    self.shopMoneyBox:invalidateLayout()
end;

function AnimalScreenBuy:onMoneyChanged()
    if self.isOpen then
        self:updateBalanceText();
        if g_currentMission ~= nil then
            self.lastMoney = g_currentMission.missionStats.money;
        end
    end;
end;

function AnimalScreenBuy:update(dt)
    AnimalScreenBuy:superClass().update(self, dt);

    if g_currentMission ~= nil and self.lastMoney ~= g_currentMission.missionStats.money then
        self:onMoneyChanged();
    end;

    if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
        self:changeNumAnimals(1)
    elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
        self:changeNumAnimals(-1)
    end;
end

function AnimalScreenBuy:onListSelectionChanged(rowIndex)
    if not self.animalItemList.ignoreUpdate then
        self.selectedAnimalIndex = rowIndex;
        if self.animalItemList.listItems[rowIndex] ~= nil then
            local pos = self.animalItemList.elements[rowIndex].absPosition[1] - self.shopListItemMarker.size[1]*0.5 + self.animalItemList.listItemWidth*0.5
            self.shopListItemMarker:setAbsolutePosition(pos, self.shopListItemMarker.absPosition[2])
        end
        self.shopListItemMarker:setVisible(self.animalItemList.listItems[rowIndex] ~= nil)


        self.transferData.right = {target=nil, baseNumOfAnimals=AnimalScreen.MAX_ITEMS, numOfAnimals=AnimalScreen.MAX_ITEMS, capacity=math.huge}
        local animalDesc = self.currentAnimalList[rowIndex]
        local numAnimals = g_currentMission.husbandries[animalDesc.name].totalNumAnimals
        self.currentNumAnimals = numAnimals
        self.transferData.left = {target=nil, baseNumOfAnimals=numAnimals, numOfAnimals=numAnimals, capacity=math.huge}

        if self.animalTarget ~= nil then
            self.transferData.left = {target=self.animalTarget, baseNumOfAnimals=self.animalTarget:getUnitFillLevel(1), numOfAnimals=self.animalTarget:getUnitFillLevel(1), capacity=self.animalTarget:getCapacity(animalDesc.fillType)}
            self.currentNumAnimals = self.animalTarget:getUnitFillLevel(1)
        end

        self:updateData()
    end
end;

function AnimalScreenBuy:setCallback(callbackFunc, target)
    self.callbackFunc = callbackFunc;
    self.callbackTarget = target;
end

function AnimalScreenBuy:updateButtons(isDisabled,canSell)
    if self.buyButton ~= nil then
        self.buyButton:setDisabled(isDisabled)
    end
    if self.buyButtonConsole ~= nil then
        self.buyButtonConsole:setVisible(not isDisabled)
    end
    if self.buttonBottom ~= nil then
        self.buttonBottom:setDisabled(not canSell)
    end
end

----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------

AnimalScreenSell = {};

local AnimalScreenSell_mt = Class(AnimalScreenSell, ScreenElement);

function AnimalScreenSell:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = AnimalScreenSell_mt;
    end;
    local self = ScreenElement:new(target, custom_mt);
    self.isOpen = false

    self.selectedAnimalIndex = 0
    self.isDealer = true

    self.returnScreenName = ""
    self.currentNumAnimals = 0

    self.transferData = {}

    return self;
end;

function AnimalScreenSell:onCreate()
    self.listSliderElement:setController(self.animalItemList)
end;

function AnimalScreenSell:onClose(element)
    AnimalScreenSell:superClass().onClose(self);
    self.transferData = {}
    self.isOpen = false;
end

function AnimalScreenSell:onOpen()
    AnimalScreenSell:superClass().onOpen(self);

    self:updateBalanceText();

    self.isOpen = true;

    self.animalItemList.ignoreUpdate = true;
    self.animalItemList:deleteListItems();

    self.currentItemList = {};
    self.currentAnimalList = {};
    self.animalIconMapping = {}
    for _, animalType in pairs(self.animalTypes) do
        local animalDesc = AnimalUtil.animalIndexToDesc[animalType]
        if g_currentMission.husbandries[animalDesc.name] ~= nil and (self.animalTarget == nil or self.animalTarget:allowFillType(animalDesc.fillType)) then
            if animalDesc.canBeBought then
                self.currentAnimal = animalDesc;
                local newListItem = self.animalItemTemplate:clone(self.animalItemList);
                newListItem:updateAbsolutePosition();
                table.insert(self.currentItemList, self.currentAnimal);
                table.insert(self.currentAnimalList, animalDesc);
                self.currentAnimal = nil;
            end
        end
    end;
    self.animalItemList.ignoreUpdate = false;
    self.animalItemList:updateItemPositions();

    local numAnimals = #self.currentItemList;

    self.shopListSeparator1:setVisible(numAnimals > 0)
    self.shopListSeparator2:setVisible(numAnimals > 1)

    if numAnimals > 0 then
        self.animalItemList:scrollTo(1, false);
        self.animalItemList:setSelectedRow(1, true);
    end

    self:updateData()

    if GS_IS_CONSOLE_VERSION then
        FocusManager:setFocus(self.animalItemList)
    end
end

function AnimalScreenSell:onClickBack()
    AnimalScreenSell:superClass().onClickBack(self);
end;

function AnimalScreenSell:onClickActivate()
    AnimalScreenSell:superClass().onClickActivate(self);

    if self.transferData.left.baseNumOfAnimals == self.transferData.left.numOfAnimals and self.transferData.right.baseNumOfAnimals == self.transferData.right.numOfAnimals then
        return
    end

    local enoughMoney = true

    self.animalType = self.currentAnimalList[self.selectedAnimalIndex].index
    local animalDesc = AnimalUtil.animalIndexToDesc[self.animalType]
    local text = ""
    local numAnimalsDif = self.transferData.right.numOfAnimals - self.transferData.right.baseNumOfAnimals

    if numAnimalsDif < 0 then
        g_gui:showInfoDialog({text=g_i18n:getText("shop_messageOnlySellAnimals")})
        return
    else
        text = string.format(g_i18n:getText("animals_sell"), math.abs(numAnimalsDif), animalDesc.title, g_i18n:formatMoney(math.abs(self.totalPrice), 0, true, false))
    end

    g_gui:showYesNoDialog({text=text, callback=self.onClickYesNo, target=self})
end

function AnimalScreenSell:onVehicleLeftTrigger()
    if self.isOpen then
        g_gui:showInfoDialog({text=g_i18n:getText("animals_transportTargetLeftTrigger"), callback=self.onClickInfoOk, target=self})
    end
end

function AnimalScreenSell:onClickInfoOk()
    self:onClickBack()
end

function AnimalScreenSell:onClickYesNo(yes)
    if yes then
        if self.callbackFunc ~= nil then
            local dif = self.transferData.right.numOfAnimals - self.transferData.right.baseNumOfAnimals
            if self.callbackTarget ~= nil then
                self.callbackFunc(self.callbackTarget, self.animalTarget, self.animalType, dif, self.totalPrice);
            else
                self.callbackFunc(self.animalTarget, self.animalType, dif, self.totalPrice);
            end;
        end;
        self:onClickBack()
    end
end

function AnimalScreenSell:onClickAddOne()
    self:changeNumAnimals(1)
end

function AnimalScreenSell:onClickRemoveOne()
    self:changeNumAnimals(-1)
end

function AnimalScreenSell:changeNumAnimals(dif)
    if dif > 0 then
        dif = math.min(dif, self.transferData.right.numOfAnimals, self.transferData.left.capacity-self.transferData.left.numOfAnimals)
    else
        dif = math.max(-self.transferData.left.numOfAnimals, dif, -(self.transferData.right.capacity-self.transferData.right.numOfAnimals))
    end

    self.transferData.left.numOfAnimals = math.min(self.currentNumAnimals,self.transferData.left.numOfAnimals + dif)
    self.transferData.right.numOfAnimals = math.max(AnimalScreen.MAX_ITEMS,self.transferData.right.numOfAnimals - dif)
    self:updateData()
end

function AnimalScreenSell:updateData()
    local animalDesc = self.currentAnimalList[self.selectedAnimalIndex]

    local lockedAnimal = nil
    if self.animalTarget ~= nil and self.animalTarget:getUnitFillLevel(self.animalTarget.livestockTrailer.fillUnitIndex) > 0 then
        lockedAnimal = self.animalTarget:getUnitFillType(self.animalTarget.livestockTrailer.fillUnitIndex)
    elseif self.transferData.left.baseNumOfAnimals ~= self.transferData.left.numOfAnimals or self.transferData.right.baseNumOfAnimals ~= self.transferData.right.numOfAnimals then
        lockedAnimal = animalDesc.fillType
    end
    self:lockAnimal(lockedAnimal)

    self.totalPrice = 0
    local sellPrice = 0
    local buyPrice = 0
    local fee = 0
    local dif = self.transferData.right.numOfAnimals - self.transferData.right.baseNumOfAnimals

    if self.transferData.right.numOfAnimals < self.transferData.right.baseNumOfAnimals then
        dif = 0
    else
        sellPrice = dif * self.currentAnimalList[self.selectedAnimalIndex].price * (0.4 * g_currentMission.missionInfo.sellPriceMultiplier);
    end

    if self.animalTarget == nil and dif ~= 0 then
        fee = -AnimalScreen.TRANSPORTATION_FEE * g_currentMission.missionInfo.buyPriceMultiplier * math.abs(dif);
    end

    self.totalPrice = sellPrice + buyPrice + fee
    self.feeText:setText(g_i18n:formatMoney(fee, 0, true, false), true)

    self.buyTextBox:setVisible(false)
    self.buyTextElement:setVisible(false)

    local sellText1 = g_i18n:formatMoney(sellPrice, 0, true, false)
    local sellText2 = ""
    local sellText3 = ""
    if sellPrice ~= 0 then
        sellText1 = sellText1 .. " ( "
        sellText2 = math.abs(dif)
        sellText3 = " )"
    end
    self.sellText[1]:setText(sellText1, true)
    self.sellText[2]:setText(sellText2, true)
    self.sellText[3]:setText(sellText3, true)
    self.sellTextBox:invalidateLayout()

    self.buttonTop:setText(g_i18n:getText("shop_holdAnimals"), false)

    if self.totalPrice < 0 then
        self.totalText:applyProfile("animalAttributeValueNeg")
    elseif self.totalPrice > 0 then
        self.totalText:applyProfile("animalAttributeValuePos")
    else
        self.totalText:applyProfile("animalAttributeValue")
    end
    self.totalText:setText(g_i18n:formatMoney(self.totalPrice, 0, true, false), true)

    self.feeTextBox:invalidateLayout()
    self.totalTextBox:invalidateLayout()

    local icon = ""
    if self.lockedAnimal ~= nil then
        icon = FillUtil.fillTypeIndexToDesc[self.lockedAnimal].hudOverlayFilenameSmall
    else
        if self.currentAnimalList ~= nil then
            animalDesc = self.currentAnimalList[self.selectedAnimalIndex]
            icon = FillUtil.fillTypeIndexToDesc[animalDesc.fillType].hudOverlayFilenameSmall
        end
    end

    local numOfAnimals = self.transferData.left.numOfAnimals
    if self.transferData.left.target ~= nil then
        numOfAnimals = numOfAnimals .. " / " .. self.transferData.left.capacity
    end
    self.fillIconText:setText(numOfAnimals)
    self.fillIcon:setVisible(icon ~= "")
    if icon ~= "" then
        self.fillIcon:setImageFilename(icon)
    end

    numOfAnimals = self.transferData.right.numOfAnimals
    if self.transferData.right.target ~= nil then
        numOfAnimals = numOfAnimals .. " / " .. self.transferData.right.capacity
    end
    self.fillIconTextRight:setText(numOfAnimals)
    self.fillIconRight:setVisible(icon ~= "")
    if icon ~= "" then
        self.fillIconRight:setImageFilename(icon)
    end

    self:updateButtons(self.transferData.left.baseNumOfAnimals == self.transferData.left.numOfAnimals and self.transferData.right.baseNumOfAnimals == self.transferData.right.numOfAnimals , self.transferData.left.numOfAnimals ~= self.currentNumAnimals)
end

function AnimalScreenSell:setData(isDealer, title, animalTypes, target)
    isDealer = true;
    self.boxRight:setVisible(target ~= nil and not isDealer)
    self.boxPriceRight:setVisible(not self.boxRight.visible)

    local targetIcon = Utils.getFilename("$dataS2/menu/hud/ui_animalDealer.dds", AnimalScreenBuy.modDirectory);
    local targetName = title
    if target ~= nil then
        local storeItem = StoreItemsUtil.storeItemsByXMLFilename[target.configFileName:lower()];
        targetIcon = storeItem.imageActive
        targetName = storeItem.name
    end

    self.buttonBottom:setText(g_i18n:getText("button_sell"))

    if target == nil then
        targetName = g_i18n:getText("ui_farm")
    end
    self.boxTargetIcon:setImageFilename(targetIcon)
    self.boxHeaderText:setText(targetName)
    self.title:setText(title)

    self.animalTypes = animalTypes
    self.animalTarget = target

    self.isDealer = isDealer

    self:updateButtons(false,true)
end

function AnimalScreenSell:lockAnimal(animalFillType)
    self.animalItemList:setDisabled(animalFillType ~= nil)

    local selectedIndex = 1
    for k, desc in pairs(self.currentItemList) do
        local elem = self.animalIconMapping[desc]
        if animalFillType == nil or desc.fillType == animalFillType then
            elem:applyProfile("animalIcon")
            selectedIndex = k
        else
            elem:applyProfile("animalIconDisabled")
        end
        self.animalIconMapping[desc]:setImageFilename(desc.imageFilename);
    end

    if animalFillType == nil then
        selectedIndex = self.selectedAnimalIndex
    end

    if selectedIndex > 0 then
        self.animalItemList:setSelectedRow(selectedIndex);
        self.animalItemList.listItems[selectedIndex]:setSelected(true)
    end
end

function AnimalScreenSell:onCreateAnimalIcon(element)
    if self.currentAnimal ~= nil then
        self.animalIconMapping[self.currentAnimal] = element
        element:setImageFilename(self.currentAnimal.imageFilename);
    end;
end;

function AnimalScreenSell:onCreateAnimalName(element)
    if self.currentAnimal ~= nil then
        element:setText(self.currentAnimal.title);
    end;
end;

function AnimalScreenSell:onCreateAnimalPrice(element)
    if self.currentAnimal ~= nil then
        element:setText(g_i18n:formatMoney(self.currentAnimal.price, 0, true, true), true)
    end;
end;

function AnimalScreenSell:onCreatePriceBox(element)
    element:invalidateLayout(true)
end

function AnimalScreenSell:updateBalanceText()
    local money = 10000;
    if g_currentMission ~= nil then
        money = g_currentMission.missionStats.money;
    end;

    self.shopMoney:setText(g_i18n:formatMoney(money, 0, true, true), true);
    if money > 0 then
        self.shopMoney:applyProfile("shopMoney")
    else
        self.shopMoney:applyProfile("shopMoneyNeg")
    end
    self.shopMoneyBox:invalidateLayout()
end;

function AnimalScreenSell:onMoneyChanged()
    if self.isOpen then
        self:updateBalanceText();
        if g_currentMission ~= nil then
            self.lastMoney = g_currentMission.missionStats.money;
        end
    end;
end;

function AnimalScreenSell:update(dt)
    AnimalScreenSell:superClass().update(self, dt);

    if g_currentMission ~= nil and self.lastMoney ~= g_currentMission.missionStats.money then
        self:onMoneyChanged();
    end;

    if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
        self:changeNumAnimals(1)
    elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
        self:changeNumAnimals(-1)
    end;
end

function AnimalScreenSell:onListSelectionChanged(rowIndex)
    if not self.animalItemList.ignoreUpdate then
        self.selectedAnimalIndex = rowIndex;
        if self.animalItemList.listItems[rowIndex] ~= nil then
            local pos = self.animalItemList.elements[rowIndex].absPosition[1] - self.shopListItemMarker.size[1]*0.5 + self.animalItemList.listItemWidth*0.5
            self.shopListItemMarker:setAbsolutePosition(pos, self.shopListItemMarker.absPosition[2])
        end
        self.shopListItemMarker:setVisible(self.animalItemList.listItems[rowIndex] ~= nil)


        self.transferData.right = {target=nil, baseNumOfAnimals=AnimalScreen.MAX_ITEMS, numOfAnimals=AnimalScreen.MAX_ITEMS, capacity=math.huge}
        local animalDesc = self.currentAnimalList[rowIndex]
        local numAnimals = g_currentMission.husbandries[animalDesc.name].totalNumAnimals
        self.currentNumAnimals = numAnimals
        self.transferData.left = {target=nil, baseNumOfAnimals=numAnimals, numOfAnimals=numAnimals, capacity=math.huge}

        if self.animalTarget ~= nil then
            self.transferData.left = {target=self.animalTarget, baseNumOfAnimals=self.animalTarget:getUnitFillLevel(1), numOfAnimals=self.animalTarget:getUnitFillLevel(1), capacity=self.animalTarget:getCapacity(animalDesc.fillType)}
            self.currentNumAnimals = self.animalTarget:getUnitFillLevel(1)
        end

        self:updateData()
    end
end;

function AnimalScreenSell:setCallback(callbackFunc, target)
    self.callbackFunc = callbackFunc;
    self.callbackTarget = target;
end

function AnimalScreenSell:updateButtons(isDisabled,canBuy)
    if self.buyButton ~= nil then
        self.buyButton:setDisabled(isDisabled)
    end
    if self.buyButtonConsole ~= nil then
        self.buyButtonConsole:setVisible(not isDisabled)
    end
    if self.buttonTop ~= nil then
        self.buttonTop:setDisabled(not canBuy)
    end
end
