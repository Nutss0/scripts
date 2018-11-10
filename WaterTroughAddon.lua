--[[
Copyright (C) GtX (Andy), 2018

Interface: 1.5.1.0 b1580

Author: GtX (LS-Modcompany)
Date: 21.01.2018

Support only at: http://ls-modcompany.com

Official Prefab available at: https://www.farming-simulator.com/mods.php

History:
Version: 1.0.0.0 - @ 21.01.2018
Version: 1.1.0.0 - @ 05.03.2018 (Prefab release, added optional status rendering for users with the `Controls Help Menu [F1]` closed.)
Version: 1.1.1.0 - @ 23.04.2018 (Adjusted fill start levels, filling is now possible if the trough level is less than 98%. This is to adjust for maps using 'seasons mod'.
								 Status Rendering is now colour coded based on fill level of the trough and will also display the number of days the trough fill level will last.
								 You can now set a water price scale in GE by adding by adding 'float - attribute [waterPriceScale]' if you wish to charge for water use. Default is `0`)

About:
This script allows you to add a fill point directly at your animal water troughs. You can set the option to allow the players to purchase this option or you can set it already built.
The script will collect water in your troughs when it is raining even if the addon is not purchased. To use this feature make sure to tick the 'allowRainWater' attribute.

Thankyou:
Johnny Vee @ PC-SG for the idea.

Important:
This script may be included in any maps.
No changes are to be made to this script without permission from GtX @ http://ls-modcompany.com
--]]

WaterTroughAddon = {}
WaterTroughAddon_mt = Class(WaterTroughAddon, Object)
InitObjectClass(WaterTroughAddon, "WaterTroughAddon")

local wtaModDir = g_currentModDirectory

function WaterTroughAddon.onCreate(id)

	local object = WaterTroughAddon:new(g_server ~= nil, g_client ~= nil)

	g_currentMission:addOnCreateLoadedObject(object)
	if object:load(id) then
		g_currentMission:addOnCreateLoadedObjectToSave(object)
        object:register(true)
    else
        object:delete()
    end

end

function WaterTroughAddon:new(isServer, isClient)
    local self = {}
    self = Object:new(isServer, isClient, WaterTroughAddon_mt)

	local i = 0
	local modDescXML = loadXMLFile("modDesc", wtaModDir.."modDesc.xml")
	while true do
	   local text = string.format("modDesc.l10n.text(%d)", i)
	   if not hasXMLProperty(modDescXML, text) then
		  break
	   end
	   local name = getXMLString(modDescXML, text.."#name")
	   g_i18n.globalI18N.texts[name] = g_i18n:getText(name)
	   i = i + 1
	end

	return self
end

function WaterTroughAddon:load(id)

	self.nodeId = id
	self.husbandryType = nil
	self.startFilling = false
	self.fillEffectActive = false
	self.rainWater = 0
	self.wtaBought = false

	self.husbandryAnimal = Utils.getNoNil(getUserAttribute(id, "husbandryType"), "cow")
	if self.husbandryAnimal ~= nil then
		local animalDesc = AnimalUtil.animals[self.husbandryAnimal]
		self.husbandryName = animalDesc.title
		if self.husbandryAnimal == "chicken" then
			if g_currentMission.enhancedChickens ~= nil then
				self.husbandryType = g_currentMission.enhancedChickens
				self.isModChickens = true
			else
				print("ERROR: [ WaterTroughAddon.lua ] Animal Type 'chickens' require the 'EnhancedChickens.lua by GtX. Please visit www.ls-modcompany.com")
			end			
		else
			self.husbandryType = g_currentMission.husbandries[self.husbandryAnimal]
			self.isModChickens = false
		end
		self.saveId = "WaterTroughAddon_"..self.husbandryAnimal
	else
		print("WARNING: [ WaterTroughAddon.lua ] Attribute 'husbandryType' is missing at " ..getName(id).. ". Please set an animal type.")
		print("ERROR: [ WaterTroughAddon.lua ] No animal type has been set. 'SaveID ERROR' ")
	end

	self.ownedOnStart = Utils.getNoNil(getUserAttribute(id, "isOwnedOnStart"), false)
	self.isOwned = self.ownedOnStart

	self.maintCost = Utils.getNoNil(getUserAttribute(id, "maintenancePerDay"), 20)

	self.allowRainWater = Utils.getNoNil(getUserAttribute(id, "allowRainWater"), false)

	self.waterPriceScale = Utils.getNoNil(getUserAttribute(id, "waterPriceScale"), 0)

	self.renderScreenHelp = Utils.getNoNil(getUserAttribute(id, "renderScreenHelp"), true)
	if self.renderScreenHelp then
		local uiScale = g_gameSettings:getValue("uiScale")

		self.helpWidth, self.helpHeight = getNormalizedScreenValues(500*uiScale, 60*uiScale)
		self.helpBacking = Overlay:new("helpBacking", g_baseUIFilename, 0.5, 0.1, self.helpWidth, self.helpHeight)
		self.helpBacking:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
		self.helpBacking:setUVs(g_colorBgUVs)
		self.helpBacking:setColor(unpack(g_colorBg))

		self.help2Width, self.help2Height = getNormalizedScreenValues(500*uiScale, 80*uiScale)
		self.help2Backing = Overlay:new("help2Backing", g_baseUIFilename, 0.5, 0.08, self.help2Width, self.help2Height)
		self.help2Backing:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
		self.help2Backing:setUVs(g_colorBgUVs)
		self.help2Backing:setColor(unpack(g_colorBg))

		self.helpHead = Overlay:new("helpHead", g_baseUIFilename, 0.5, 0.1+self.helpHeight/2, self.helpWidth, self.helpHeight/2.5)
		self.helpHead:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_CENTER)
		self.helpHead:setUVs(g_colorBgUVs)
		self.helpHead:setColor(0.0075, 0.0075, 0.0075, 1)

		_, self.headerTextSizeY = getNormalizedScreenValues(0, 13*uiScale)
		_, self.offsetHeadY = getNormalizedScreenValues(0, 18*uiScale)
		_, self.mainTextSizeY = getNormalizedScreenValues(0, 15*uiScale)
	end

	if self.ownedOnStart then
		self.buildTime = 8
		self.buildStage = 8
	else
		self.startTime = Utils.getNoNil(getUserAttribute(id, "buildStartHour"), 6)
		self.buildTime = Utils.getNoNil(getUserAttribute(id, "buildTotalHours"), 8)
		self.buildCost = Utils.getNoNil(getUserAttribute(id, "buildCost"), 5000)

		-- These Attributes can be added in `GE` at the each water fill point if you want different text for each animal area.
		self.buyText = Utils.getNoNil(getUserAttribute(id, "buyText"), g_i18n:getText("wta_BuyText"))
		self.boughtText = Utils.getNoNil(getUserAttribute(id, "boughtText"), g_i18n:getText("wta_BoughtText"))
		self.startedText = Utils.getNoNil(getUserAttribute(id, "startedText"), g_i18n:getText("wta_StartedBuildText"))
		self.buildStage = -1
		self.stageCounter = -1

		local markerNode = getUserAttribute(id, "purchaseMarker")
		if markerNode ~= nil then
			local markerNodeId = Utils.indexToObject(id, markerNode)
			self.purchaseMarker = {}
			setVisibility(markerNodeId, true)
			self.purchaseMarker.node = markerNodeId
			self.purchaseMarker.active = true
		end

		local boughtNodes = getUserAttribute(id, "builtVisNodes")
		if boughtNodes ~= nil then
			local boughtNodesId = Utils.indexToObject(id, boughtNodes)
			self.boughtParts = {}
			local numberNodes = getNumOfChildren(boughtNodesId)
			if numberNodes > 0 then
				for i=1, numberNodes do
					local visNode = getChildAt(boughtNodesId, i-1)
					local rigidBody = getRigidBodyType(visNode)
					setVisibility(visNode, false)
					setRigidBodyType(visNode,"NoRigidBody")
					local node = {}
					node.index = visNode
					node.rigidBody = rigidBody
					table.insert(self.boughtParts, node)
				end
			end
		end

		local buildDecoIndex = getUserAttribute(id, "buildDecoIndex")
		if buildDecoIndex and buildDecoIndex ~= 0 then
			buildDecoNode = Utils.indexToObject(id, buildDecoIndex)
			self.buildDeco = {}
			self.buildDecoSet = false
			self.decoOnStart = Utils.getNoNil(getUserAttribute(buildDecoNode, "showOnBuildStart"), false)
			local numberNodes = getNumOfChildren(buildDecoNode)
			if numberNodes > 0 then
				for i=1, numberNodes do
					local visNode = getChildAt(buildDecoNode, i-1)
					local rigidBody = getRigidBodyType(visNode)
					setVisibility(visNode, false)
					setRigidBodyType(visNode,"NoRigidBody")
					local node = {}
					node.index = visNode
					node.rigidBody = rigidBody
					table.insert(self.buildDeco, node)
				end
			end
		end
	end

	local animationNode = getUserAttribute(id, "animationNode")
	if animationNode ~= nil then
		local animationNodeId = Utils.indexToObject(id, animationNode)
		self.minRotate = Utils.getNoNil(getUserAttribute(animationNodeId, "minRotateZ"), 0)
		self.maxRotate = Utils.getNoNil(getUserAttribute(animationNodeId, "maxRotateZ"), 170)
		self.rotate = self.maxRotate
		self.animationNode = animationNodeId
	end

	local particlesIndex = getUserAttribute(id, "fillEffectsIndex")
	if particlesIndex and particlesIndex ~= 0 then
		local particleEffectNode = Utils.indexToObject(id, particlesIndex)
		self.fillEffect = EffectManager:loadFromNode(particleEffectNode, self)
	end

	local fillSoundIndex = getUserAttribute(id, "fillSoundsIndex")
	if fillSoundIndex and fillSoundIndex ~= 0 then
		local soundNode = Utils.indexToObject(id, fillSoundIndex)
		self.fillSound = soundNode
		setVisibility(soundNode, false)
	end

	local PlayerIndex = getUserAttribute(id, "playerTriggerIndex")
	if PlayerIndex ~= nil then
		local playerTriggerId = Utils.indexToObject(id, PlayerIndex)
		if playerTriggerId and playerTriggerId ~= 0 then
			self.playerTrigger = playerTriggerId
			addTrigger(self.playerTrigger, "playerTriggerCallback", self)
		end
	end

	if self.isServer then
        g_currentMission.environment:addHourChangeListener(self)
		g_currentMission.environment:addDayChangeListener(self)
    end

	return true

end

function WaterTroughAddon:loadFromAttributesAndNodes(xmlFile, key)

	if not self.ownedOnStart then
		self.isOwned = Utils.getNoNil(getXMLBool(xmlFile, key .."#isOwned"), false)
		self.buildStage = Utils.getNoNil(getXMLFloat(xmlFile, key .."#buildStage"), -1)
	end

    return true
end

function WaterTroughAddon:getSaveAttributesAndNodes(nodeIdent)
	local attributes = nil
    local nodes = ""

	if not self.ownedOnStart then
		attributes = 'isOwned="'..tostring(self.isOwned)..'" buildStage="'..tostring(self.buildStage)..'"'
	end

	return attributes, nodes
end

function WaterTroughAddon:deleteMap()
	self:delete()
end

function WaterTroughAddon:delete()
	unregisterObjectClassName(self)
	g_currentMission:removeOnCreateLoadedObjectToSave(self)

	if self.playerTrigger then
		removeTrigger(self.playerTrigger)
	end

	if self.renderScreenHelp then
		self.helpBacking:delete()
		self.helpHead:delete()
	end

	if self.isClient then
		EffectManager:deleteEffects(self.fillEffect)
	end

	if self.isServer then
		g_currentMission.environment:removeHourChangeListener(self)
		g_currentMission.environment:removeDayChangeListener(self)
	end
end

function WaterTroughAddon:readStream(streamId, connection)
	if connection:getIsServer() then
		self.isOwned = streamReadBool(streamId)
		self.buildStage = streamReadInt16(streamId)
	end
end

function WaterTroughAddon:writeStream(streamId, connection)
	if not connection:getIsServer() then
		streamWriteBool(streamId, self.isOwned)
		streamWriteInt16(streamId, self.buildStage)
	end
end

function WaterTroughAddon:update(dt)

	if self.playerInTrigger then
		local fillLevel, percent = self:getTroughData()
		local timeLeft = self:getTroughDays(percent)
		g_currentMission:addExtraPrintText(g_i18n:getText("info_waterFillLevel")..":  "..math.floor(fillLevel).." ("..math.floor(percent).."%)".."      -      ("..timeLeft..")")

		if self.waterPriceScale > 0 then
			local pricePerLitre = g_currentMission.economyManager:getPricePerLiter(FillUtil.FILLTYPE_WATER) * self.waterPriceScale
			g_currentMission:addExtraPrintText(g_i18n:getText("finance_purchaseWater")..": "..g_i18n:formatMoney(pricePerLitre, 2).."      -      ( "..g_i18n:getText("unit_literShort").." )")
		end

		if self.isOwned then
			if self.buildStage == self.buildTime then
				local canFillTrough = percent < 98 and not self.startFilling

				if self.renderScreenHelp then
					local text = g_i18n:getText("info_waterFillLevel")..":    "..math.floor(fillLevel).."   ("..math.floor(percent).."%)".."      -      ("..timeLeft..")"
					local text2 = string.format("%s      -      ( %s ) ", g_i18n:getText("input_WaterTroughAddon"), g_i18n:getText("wta_InputName"))
					if canFillTrough then
						self:renderHelp(text, percent, text2)
					else
						self:renderHelp(text, percent)
					end
				end

				if canFillTrough then
					g_currentMission:addHelpButtonText(g_i18n:getText("input_WaterTroughAddon"), InputBinding.WaterTroughAddon)
					if InputBinding.hasEvent(InputBinding.WaterTroughAddon) then
						self:fillingState(true)
					end
				end
			else
				g_currentMission:addHelpButtonText(g_i18n:getText("input_MENU"), InputBinding.WaterTroughAddon)
				if self.renderScreenHelp then
					local text = string.format("%s      -      ( %s ) ", g_i18n:getText("input_MENU"), g_i18n:getText("wta_InputName"))
					self:renderHelp(text)
				end
				if InputBinding.hasEvent(InputBinding.WaterTroughAddon) then
					self:showBuyInfo()
				end
			end
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("wta_Purchase"), InputBinding.WaterTroughAddon)
			if self.renderScreenHelp then
				local text = string.format("%s      -      ( %s ) ", g_i18n:getText("wta_Purchase"), g_i18n:getText("wta_InputName"))
				self:renderHelp(text)
			end
			if InputBinding.hasEvent(InputBinding.WaterTroughAddon) then
				if g_currentMission.missionDynamicInfo.isMultiplayer then
					self:preBuyText(g_currentMission.isMasterUser)
				else
					self:preBuyText(true)
				end
			end
		end

		if g_currentMission.controlledVehicle ~= nil then
			self.playerInTrigger = false
		end
	end

	if self.startFilling then
		if self.isServer then
			local amountToAdd = self:getTroughSpace()
			local fillDelta = math.min(amountToAdd, 0.45 * dt)
			self:updateTrough(fillDelta, true)
		end

		self:fillEffectState(true)
	else
		self:fillEffectState(false)
	end

	if self.isServer and self.allowRainWater then
		if g_currentMission.environment.lastRainScale > 0.1 and g_currentMission.environment.timeSinceLastRain < 30 then
			self.updateMinute = self.updateMinute + (dt * g_currentMission.loadingScreen.missionInfo.timeScale)
			if self.updateMinute >= 60000 then
				self.updateMinute = 0
				self.rainWater = self.rainWater + 1
				if self.rainWater >= 15 then
					self:updateTrough(self.rainWater, false)
					self.rainWater = 0
				end
			end
		else
			if self.updateMinute ~= 0 then
				self.updateMinute = 0
			end
			if self.rainWater ~= 0 then
				self.rainWater = 0
			end
		end
	end

	if self.animationNode ~= nil then
		local old = self.rotate

		if self.startFilling then
			if self.rotate < self.maxRotate then
				self.rotate = self.rotate + dt*0.003*60
			end

			if self.rotate > self.maxRotate then
				self.rotate = self.maxRotate
			end
		else
			if self.rotate > self.minRotate then
				self.rotate = self.rotate - dt*0.003*60
			end

			if self.rotate < self.minRotate then
				self.rotate = self.minRotate
			end
		end

		if old ~= self.rotate then
			setRotation(self.animationNode, 0, 0, Utils.degToRad(self.rotate))
		end
	end

	if self.isClient and not self.ownedOnStart then
		if self.purchaseMarker ~= nil then
			if self.isOwned and self.buildStage == self.buildTime then
				if self.purchaseMarker.active then
					setVisibility(self.purchaseMarker.node, false)
					self.purchaseMarker.active = false
				end
			else
				if not self.purchaseMarker.active then
					setVisibility(self.purchaseMarker.node, true)
					self.purchaseMarker.active = true
				end
			end
		end

		if self.isOwned and self.buildStage >= 0 then
			if self.stageCounter ~= nil then
				if self.buildStage > self.stageCounter then
					local count = table.getn(self.boughtParts)
					local visNode = math.ceil((count * self.buildStage) / self.buildTime)
					for i = 1, count, 1 do
						setVisibility(self.boughtParts[i].index, i <= visNode)
						setRigidBodyType(self.boughtParts[i].index, i <= visNode and self.boughtParts[i].rigidBody or "NoRigidBody")
					end
					self.stageCounter = self.buildStage

					if self.buildDeco ~= nil then
						if self.buildStage > self.buildTime-1 then
							self:updateDecoNodes(false)
						end
					end
				end
			end
		end

		if self.buildDeco ~= nil and not self.buildDecoSet then
			if self.buildStage < self.buildTime-1 then
				if self.decoOnStart then
					if self.buildStage >= 0 then
						self:updateDecoNodes(true)
						self.buildDecoSet = true
					end
				else
					self:updateDecoNodes(true)
					self.buildDecoSet = true
				end
			end
		end
	end
end

function WaterTroughAddon:updateDecoNodes(setOn)
	local count = table.getn(self.buildDeco)
	for i = 1, count do
		setVisibility(self.buildDeco[i].index, setOn)
		setRigidBodyType(self.buildDeco[i].index, setOn and self.buildDeco[i].rigidBody or "NoRigidBody")
	end
end

function WaterTroughAddon:preBuyText(master)
	if master then
		local title = "TECH FARM"
		local text = string.format(self.buyText, self.buildCost, self.husbandryName, self.maintCost)
		g_gui:showYesNoDialog({text=text, title=title, callback=self.onClickYes, target=self})
	else
		local defualtText = string.format(self.buyText, self.buildCost, self.husbandryName, self.maintCost)
		local text = string.format("( %s ) - %s", g_i18n:getText("button_adminLogin"), defualtText)
		g_gui:showInfoDialog({text=text, okText=g_i18n:getText("button_back")})
	end
end

function WaterTroughAddon:onClickYes(yes)
    if yes then
		if g_currentMission:getIsServer() then
			self.isOwned = true
			self:moneyChange(true, false)
			self:showBuyInfo()
		else
			g_client:getServerConnection():sendEvent(WaterTroughAddonBuyEvent:new(self, true))
			self:showBuyInfo()
		end
    end
end

function WaterTroughAddon:showBuyInfo()
	local text = ""
	if self.buildStage < 0 then
		local completedTime = self.startTime+self.buildTime
		text = string.format(self.boughtText, self.startTime..":00", completedTime..":00")
	else
		local completedTime = self.buildTime-self.buildStage
		text = string.format(self.startedText, completedTime)
	end
	g_gui:showInfoDialog({text=text, dialogType=DialogElement.TYPE_LOADING})
end

function WaterTroughAddon:renderHelp(text, percent, text2)
	if text ~= nil then
		if (g_gui:getIsGuiVisible() or g_currentMission.inGameMessage:getIsVisible()) then
			return
		end

		local headerPosY = g_safeFrameOffsetY + self.helpHeight - self.offsetHeadY - self.headerTextSizeY
		setTextAlignment(RenderText.ALIGN_CENTER)
		setTextColor(1.0, 1.0, 1.0, 1.0)
		setTextBold(true)
		renderText(self.helpHead.x, self.helpHead.y-self.offsetHeadY, self.headerTextSizeY, "TECH FARM")
		setTextBold(false)
		local pulse = 0

		if percent ~= nil then
			if percent <= 20 then
				setTextColor(0.8069, 0.0097, 0.0097, 1)
				pulse = Utils.clamp(math.cos( 9.0 * (g_currentMission.time/2000) ), 0, 1)
			elseif percent <= 60 then
				setTextColor(0.9301, 0.2874, 0.0130, 1)
			else
				setTextColor(0.2122, 0.5271, 0.0307, 1)
			end

			if text2 ~= nil then
				self.help2Backing:render()
				self.helpHead:render()
				renderText(self.helpBacking.x, self.helpBacking.y-self.mainTextSizeY, self.mainTextSizeY, text)
				setTextColor(1.0, 1.0, 1.0, 1.0)
				if pulse == 0 then
					renderText(self.helpBacking.x, self.helpBacking.y-(self.mainTextSizeY*3), self.mainTextSizeY, text2)
				end
			else
				self.helpBacking:render()
				self.helpHead:render()
				renderText(self.helpBacking.x, self.helpBacking.y-self.mainTextSizeY, self.mainTextSizeY, text)
			end
		else
			self.helpBacking:render()
			self.helpHead:render()
			renderText(self.helpBacking.x, self.helpBacking.y-self.mainTextSizeY, self.mainTextSizeY, text)
		end
	else
		return
	end
end

function WaterTroughAddon:updateTrough(fillDelta, townWater)

	local space = self:getTroughSpace()

	if fillDelta > 0 and fillDelta <= space then
		if self.isModChickens then
			local totalDelta = self.husbandryType:getFillLevel("Water") + fillDelta
			self.husbandryType:updateLevel("Water", totalDelta, true)
		else
			for id, types in pairs (g_currentMission.husbandries[self.husbandryAnimal].tipTriggers) do
				for k,v in pairs(g_currentMission.husbandries[self.husbandryAnimal].tipTriggers[id].acceptedFillTypes) do
					if k == FillUtil.FILLTYPE_WATER then
						g_currentMission.husbandries[self.husbandryAnimal].tipTriggers[id]:addFillLevelFromTool(nil, fillDelta, FillUtil.FILLTYPE_WATER)
					end
				end
			end
		end
		if townWater then
			if self.waterPriceScale > 0 then
				local price = fillDelta * g_currentMission.economyManager:getPricePerLiter(FillUtil.FILLTYPE_WATER) * self.waterPriceScale
				g_currentMission.missionStats:updateStats("expenses", price)
				g_currentMission:addSharedMoney(-price, "purchaseWater")
			end
		end
	else
		if self.startFilling then
			self:fillingState(false)
		end
	end
end

function WaterTroughAddon:fillingState(state, noEventSend)
	WaterTroughAddonFillEvent.sendEvent(self, state, noEventSend)
	self.startFilling = state
end

function WaterTroughAddon:fillEffectState(isActive)
	if self.effectsActive ~= isActive then
		if self.fillEffect ~= nil then
			if isActive then
				EffectManager:setFillType(self.fillEffect, FillUtil.FILLTYPE_WATER)
				EffectManager:startEffects(self.fillEffect)
			else
				EffectManager:stopEffects(self.fillEffect)
			end
		end

		if self.fillSound ~= nil then
			setVisibility(self.fillSound, isActive)
		end
	end
	self.effectsActive = isActive
end

function WaterTroughAddon:hourChanged()
	if self.isServer and not self.ownedOnStart then
		if self.buildStage >= 0 then
			if self.buildStage < self.buildTime then
				self.buildStage = self.buildStage + 1
				g_server:broadcastEvent(WaterTroughAddonStageEvent:new(self, self.buildStage))
			end
		end

		if self.startBuild ~= nil and self.startBuild then
			local currentHour = g_currentMission.environment.currentHour
			if currentHour >= self.startTime then
				self.startBuild = false
				self.buildStage = 0
				g_server:broadcastEvent(WaterTroughAddonStageEvent:new(self, self.buildStage))
			end
		end
	end
end

function WaterTroughAddon:dayChanged()
	if self.isServer and not self.ownedOnStart then
		if self.isOwned then
			if self.buildStage < 0 then
				self.startBuild = true
			end
			if self.buildStage == self.buildTime then
				self:moneyChange(false, true)
			end
		end
	end
end

function WaterTroughAddon:getTroughSpace()
	local space = 0

	if self.isModChickens then
		space = self.husbandryType:getTroughCapacity("Water", true)
	else
		local waterLevels = self.husbandryType:getFillLevel(FillUtil.FILLTYPE_WATER)
		local waterCapacity = self.husbandryType:getCapacity(FillUtil.FILLTYPE_WATER)
		space = waterCapacity - waterLevels
	end

	return space
end

function WaterTroughAddon:getTroughData()
	local fillLevel = 0
	local percent = 0

	if self.isModChickens then
		fillLevel = self.husbandryType:getFillLevel("Water")
		capacity = self.husbandryType:getTroughCapacity("Water", false)
		percent = math.min(100, fillLevel/capacity*100)
	else
		fillLevel = self.husbandryType:getFillLevel(FillUtil.FILLTYPE_WATER)
		capacity = self.husbandryType:getCapacity(FillUtil.FILLTYPE_WATER)
		percent = math.min(100, fillLevel/capacity*100)
	end

	return fillLevel, percent
end

function WaterTroughAddon:getTroughDays(percent)
	local timeLeft = ""
	local troughDays = 6

	if g_seasons ~= nil then
		troughDays = 3
	end

	local days = (percent/100) * troughDays
	local totalHours = math.floor(days * 24)
	local floorDays = math.floor(days)
	local hours = totalHours - (floorDays * 24)
	if hours > 0 then
		timeLeft = floorDays.."d "..hours.."h"
	else
		timeLeft = floorDays.."d"
	end

	return timeLeft
end

function WaterTroughAddon:playerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (g_currentMission.controlPlayer and g_currentMission.player and otherId == g_currentMission.player.rootNode) then
		if (onEnter) then
            self.playerInTrigger = true
        elseif (onLeave) then
            self.playerInTrigger = false
        end
	end
end

function WaterTroughAddon:moneyChange(firstBuy, daily)
	if self.isServer then
		if firstBuy then
			g_currentMission:addMoney(-self.buildCost, g_currentMission:getServerUserId(), "constructionCost")
			g_currentMission:addMoneyChange(-self.buildCost, FSBaseMission.MONEY_TYPE_SHOP_PROPERTY_BUY, true, g_i18n:getText("finance_constructionCost"))
		end

		if daily then
			g_currentMission:addMoney(-self.maintCost, g_currentMission:getServerUserId(), "propertyMaintenance")
            g_currentMission:addMoneyChange(-self.maintCost, EconomyManager.MONEY_TYPE_PROPERTY_MAINTENANCE)
		end
	end
end

g_onCreateUtil.addOnCreateFunction("WaterTroughAddon", WaterTroughAddon.onCreate)

WaterTroughAddonBuyEvent = {}
WaterTroughAddonBuyEvent_mt = Class(WaterTroughAddonBuyEvent, Event)
InitEventClass(WaterTroughAddonBuyEvent, "WaterTroughAddonBuyEvent")

function WaterTroughAddonBuyEvent:emptyNew()
	local self = Event:new(WaterTroughAddonBuyEvent_mt)
    return self
end

function WaterTroughAddonBuyEvent:new(object, isOwned)
	local self = WaterTroughAddonBuyEvent:emptyNew()
	self.object = object
	self.isOwned = isOwned
	return self
end

function WaterTroughAddonBuyEvent:readStream(streamId, connection)
	local object = readNetworkNodeObject(streamId)
	local isOwned = streamReadBool(streamId)
	if object ~= nil then
		if g_server then
			object.isOwned = isOwned
			object:moneyChange(true, false)
			g_server:broadcastEvent(WaterTroughAddonBuyEvent:new(object, isOwned))
		else
			object.isOwned = isOwned
		end
	end
end

function WaterTroughAddonBuyEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.isOwned)
end

WaterTroughAddonStageEvent = {}
WaterTroughAddonStageEvent_mt = Class(WaterTroughAddonStageEvent, Event)
InitEventClass(WaterTroughAddonStageEvent, "WaterTroughAddonStageEvent")

function WaterTroughAddonStageEvent:emptyNew()
	local self = Event:new(WaterTroughAddonStageEvent_mt)
    return self
end

function WaterTroughAddonStageEvent:new(object, buildStage)
	local self = WaterTroughAddonStageEvent:emptyNew()
	self.object = object
	self.buildStage = buildStage
	return self
end

function WaterTroughAddonStageEvent:readStream(streamId, connection)
	local object = readNetworkNodeObject(streamId)
	local buildStage = streamReadInt16(streamId)
	if object ~= nil then
		object.buildStage = buildStage
	end
end

function WaterTroughAddonStageEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.object)
	streamWriteInt16(streamId, self.buildStage)
end

WaterTroughAddonFillEvent = {}
WaterTroughAddonFillEvent_mt = Class(WaterTroughAddonFillEvent, Event)
InitEventClass(WaterTroughAddonFillEvent, "WaterTroughAddonFillEvent")

function WaterTroughAddonFillEvent:emptyNew()
	local self = Event:new(WaterTroughAddonFillEvent_mt)
    return self
end

function WaterTroughAddonFillEvent:new(trough, startFilling)
	local self = WaterTroughAddonFillEvent:emptyNew()
	self.trough = trough
	self.startFilling = startFilling
	return self
end

function WaterTroughAddonFillEvent:readStream(streamId, connection)
	self.trough = readNetworkNodeObject(streamId)
	self.startFilling = streamReadBool(streamId)
	self:run(connection)
end

function WaterTroughAddonFillEvent:writeStream(streamId, connection)
	writeNetworkNodeObject(streamId, self.trough)
	streamWriteBool(streamId, self.startFilling)
end

function WaterTroughAddonFillEvent:run(connection)
	if self.trough ~= nil then
		self.trough:fillingState(self.startFilling, true)
	end

	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.trough)
	end
end

function WaterTroughAddonFillEvent.sendEvent(trough, startFilling, noEventSend)
	if startFilling ~= trough.startFilling then
		if noEventSend == nil or noEventSend == false then
			if g_server ~= nil then
				g_server:broadcastEvent(WaterTroughAddonFillEvent:new(trough, startFilling), nil, nil, trough)
			else
				g_client:getServerConnection():sendEvent(WaterTroughAddonFillEvent:new(trough, startFilling))
			end
		end
	end
end