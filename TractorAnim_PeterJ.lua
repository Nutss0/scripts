--
-- TractorAnim_PeterJ
-- Class for toggle animations - i.e. doors, levers...
--
-- @author  PeterJ 
-- @date  28/12/2015 - FS15 implementation
-- @date  12/01/2017 - FS17 conversion
--
-- https://www.facebook.com/peterjMods/
--
-- Copyright (C) PeterJ, Confidential, All Rights Reserved.


TractorAnim_PeterJ = {};

TractorAnim_PeterJ.modDirectory 		= g_currentModDirectory;

function TractorAnim_PeterJ.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations);
end;

function TractorAnim_PeterJ:load(saveGame)

	self.toggleAnimState = SpecializationUtil.callSpecializationsFunction("toggleAnimState");
	self.getNextValidAnimPart = TractorAnim_PeterJ.getNextValidAnimPart;
	self.getIsControlAnimChangeAllowed = TractorAnim_PeterJ.getIsControlAnimChangeAllowed;
	
	--! toggle animations entries !--
	self.toggleAnimationParts = {};
	local i = 0;
	while true do
		local key = string.format("vehicle.toggleAnimationParts.animatedPart(%d)", i);
		if not hasXMLProperty(self.xmlFile, key) then
			break;
		end;
		local animatedPart = {};
		local animationName = getXMLString(self.xmlFile, key.."#animationName");
		if animationName ~= nil then
			animatedPart.animationName = animationName;
		else
			break;
		end;
		animatedPart.isOn = false;
		animatedPart.isAvailable = true;
		animatedPart.posDirectionText = Utils.getNoNil(getXMLString(self.xmlFile, key.."#posDirectionText"), "action_unfoldOBJECT");
		animatedPart.negDirectionText = Utils.getNoNil(getXMLString(self.xmlFile, key.."#negDirectionText"), "action_foldOBJECT");
		animatedPart.visibilityRefRestriction = Utils.indexToObject(self.components, getXMLString(self.xmlFile, key.."#visibilityRestrictionNode"));
		animatedPart.attacherJointRestriction = getXMLFloat(self.xmlFile, key.."#attacherJointRestriction");
		
		table.insert(self.toggleAnimationParts, animatedPart);
		i = i + 1;
	end;
	self.numToggleAnimationsParts = table.getn(self.toggleAnimationParts);
	self.numAvailableAnimations = self.numToggleAnimationsParts;
	self.selectedAnimationPart = 1;

	local operateInputButtonStr = getXMLString(self.xmlFile, "vehicle.toggleAnimationParts#operateInputButton");
    if operateInputButtonStr ~= nil then
        self.operateInputButton = InputBinding[operateInputButtonStr];
    end
    self.operateInputButton = Utils.getNoNil(self.operateInputButton, InputBinding.IMPLEMENT_EXTRA2);

	local toggleAnimInputButtonStr = getXMLString(self.xmlFile, "vehicle.toggleAnimationParts#toggleAnimInputButton");
    if toggleAnimInputButtonStr ~= nil then
        self.toggleAnimInputButton = InputBinding[toggleAnimInputButtonStr];
    end
    self.toggleAnimInputButton = Utils.getNoNil(self.toggleAnimInputButton, InputBinding.IMPLEMENT_EXTRA4);

	local toggleAnimBackInputButtonStr = getXMLString(self.xmlFile, "vehicle.toggleAnimationParts#toggleAnimBackInputButton");
    if toggleAnimBackInputButtonStr ~= nil then
        self.toggleAnimBackInputButton = InputBinding[toggleAnimBackInputButtonStr];
    end
    self.toggleAnimBackInputButton = Utils.getNoNil(self.toggleAnimBackInputButton, InputBinding.TOGGLE_CONTROLGROUP);

	--! attacher animations entries !--
	local i=0;
	while true do
		local key = string.format("vehicle.attacherJoints.attacherJoint(%d)", i);
		local index = getXMLString(self.xmlFile, key.."#index");
		if index == nil then
			break;
		end;		
		local joint = self.attacherJoints[i+1];
		
		local ptoLeverAnim = getXMLString(self.xmlFile, key.."#ptoLeverAnim");
		if ptoLeverAnim ~= nil then
			joint.ptoLeverAnim = ptoLeverAnim;
			joint.ptoLeverState = -1;
			joint.ptoLeverPreviousState = -1;
		end;
		local liftArmsLeverAnim = getXMLString(self.xmlFile, key..".bottomArm#liftArmsLeverAnim");
		if liftArmsLeverAnim ~= nil then
			joint.liftArmsLeverAnim = liftArmsLeverAnim;
			joint.liftArmsLeverState = 0;
			joint.liftArmsPreviousState = 0;
			joint.defaultLiftArmsLeverPos = Utils.getNoNil(getXMLFloat(self.xmlFile, key..".bottomArm#defaultAnimPos"), 0);
		end;
		i = i + 1;
	end;

	--! light animations entries !--
	self.setLightAnimations = TractorAnim_PeterJ.setLightAnimations;

	self.lightAnimationParts = {};
	local i = 0;
	while true do
		local key = string.format("vehicle.lightAnimationParts.animatedPart(%d)", i);
		if not hasXMLProperty(self.xmlFile, key) then
			break;
		end;
		local animatedPart = {};
		local animationName = getXMLString(self.xmlFile, key.."#animationName");
		if animationName ~= nil then
			animatedPart.animationName = animationName;
		else
			break;
		end;
		local lightIndex = Utils.indexToObject(self.components, getXMLString(self.xmlFile, key.."#lightIndex"));
		if lightIndex ~= nil then
			animatedPart.lightIndex = lightIndex;
		else
			animatedPart.isReverse = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#isReverse"), false);
			animatedPart.isBeacon = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#isBeacon"), false);
			animatedPart.isHazard = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#isHazard"), false);
			animatedPart.isLeftIndicator = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#isLeftIndicator"), false);
			animatedPart.isRightIndicator = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#isRightIndicator"), false);
		end;
		animatedPart.secondaryAnimName = getXMLString(self.xmlFile, key.."#secondaryAnimName");
		animatedPart.isOn = false;
		
		table.insert(self.lightAnimationParts, animatedPart);
		i = i + 1;
	end;
	
	--! extra indoor hud entry !--
	self.ignitionAnim		= getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.ignition#animName");
	self.ignitionAnimOn		= false;
	if self.ignitionAnim ~= nil then
		self:playAnimation(self.ignitionAnim, -1, nil, true);
	end;
	self.lowFuelHUD			= Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.fuel#lowWarningIndex"));
	self.handBrakeAnim		= getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.handBrake#animName");
	
	self.fourWDAnim			= getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.fourWD#animName");
	self.diffLockAnim		= getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.diffLock#animName");
	
	self.fourWheelDrive = true;
	self.differentialLockBack = true;
	self.handBrakeState = false;
	
	--! wiper animations entries !--
	self.setTurnOnWiper		= TractorAnim_PeterJ.setTurnOnWiper;
	self.wipersAnim			= getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.wipers#animationName");
	self.wipersButtonAnim	= getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.wipers#buttonAnim");
	self.isWiperOn			= false;

	--self.enableSteerEngineOff = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.driveableExtraAnimations.steering#enableSteerEngineOff"), true);
	
	--! adjust front axle eposition depending on part visibility !-- 
	self.frontAxleJoint = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.frontAxleComponentJoint#jointNode"));
	self.AWDfrontAxle = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.frontAxleComponentJoint#refNode"));
	self.adjustPosition = Utils.getVectorNFromString(getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.frontAxleComponentJoint#adjustPosition"), 3);
	
	--! loader controls animations entries !--
	self.setLightAnimations = TractorAnim_PeterJ.setLightAnimations;

	self.loaderControls = {};
	local i = 0;
	while true do
		local key = string.format("vehicle.loaderControls.loaderControl(%d)", i);
		if not hasXMLProperty(self.xmlFile, key) then
			break;
		end;
		local loaderControl = {};
		local refIndex = Utils.indexToObject(self.components, getXMLString(self.xmlFile, key.."#refIndex"));
		if refIndex ~= nil then
			loaderControl.refIndex = refIndex;
		else
			break;
		end;
		loaderControl.posAnim = getXMLString(self.xmlFile, key.."#posAnim");
		loaderControl.negAnim = getXMLString(self.xmlFile, key.."#negAnim");
		loaderControl.previousPos = 0;		
		loaderControl.rotMovement = Utils.getNoNil(getXMLBool(self.xmlFile, key.."#rotMovement"), true);		
		loaderControl.isPos = false;
		loaderControl.isNeg = false;
		
		table.insert(self.loaderControls, loaderControl);
		i = i + 1;
	end;
	
	self.isSelectable = true;
end;

function TractorAnim_PeterJ:postLoad(savegame)
	if self:getIsControlAnimChangeAllowed() then
		local selectedIdx = self:getNextValidAnimPart(1);
		self:toggleAnimState(selectedIdx, nil);
	end;
	
	--! change fuel capacity depending on part visibility !-- 
	local capacityConfigPart = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.driveableExtraAnimations.fuel#extraCapacityIndex"));
	local newFuelCapacity = getXMLFloat(self.xmlFile, "vehicle.driveableExtraAnimations.fuel#newTankCapacity");
	if capacityConfigPart ~= nil and newFuelCapacity ~= nil and newFuelCapacity ~= self.fuelCapacity then
		local configPartVis = getVisibility(capacityConfigPart);
		if configPartVis then
			self.fuelCapacity = newFuelCapacity;
			self:setFuelFillLevel(self.fuelCapacity);
		end;
	end;

	if self.frontAxleJoint ~= nil and self.AWDfrontAxle ~= nil and self.adjustPosition ~= nil then
		local configPartVis = getVisibility(self.AWDfrontAxle);
		if configPartVis then
			setTranslation(self.frontAxleJoint, self.adjustPosition[1], self.adjustPosition[2], self.adjustPosition[3]);
			for _, tool in ipairs(self.movingTools) do
				if self.isServer then
					Cylindered.updateComponentJoints(self, tool, true);
				end;
			end;
		end;
	end;		
end;

function TractorAnim_PeterJ:delete()
end;

function TractorAnim_PeterJ:readStream(streamId, connection)
	for animatedPart,part in ipairs(self.toggleAnimationParts) do
		local state = streamReadBool(streamId);
		self:toggleAnimState(animatedPart, state, true);
	end;
end;

function TractorAnim_PeterJ:writeStream(streamId, connection)
	for animatedPart,part in ipairs(self.toggleAnimationParts) do
		streamWriteBool(streamId, part.isOn);
	end;
end;

function TractorAnim_PeterJ:mouseEvent(posX, posY, isDown, isUp, button)
end;

function TractorAnim_PeterJ:keyEvent(unicode, sym, modifier, isDown)
end;
--[[
function TractorAnim_PeterJ:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	if not resetVehicles then
		for i, part in ipairs(self.toggleAnimationParts) do
			if part.animationName ~= nil then
				local partKey = key..string.format(".animatedPart%d",i);
				local animTime = getXMLFloat(xmlFile, partKey.."#animTime");
				if animTime ~= nil then
					self:setAnimationTime(part.animationName, animTime, true);
					if animTime > 0.5 then
						part.isOn = true;
					end;
				end;
			end;
		end;
	end;
	return BaseMission.VEHICLE_LOAD_OK;
end;

function TractorAnim_PeterJ:getSaveAttributesAndNodes(nodeIdent)
	local attributes = "";
	local nodes = "";
	local numNodes = 0;
	for i, part in ipairs(self.toggleAnimationParts) do
		if part.animationName ~= nil then
			if numNodes > 0 then
				nodes = nodes.."\n";
			end
			numNodes = numNodes + 1;
			nodes = nodes.. nodeIdent..string.format('<animatedPart%d', i);
			if part.isOn ~= nil then
				local animTime = self:getAnimationTime(part.animationName);
				nodes = nodes.. ' animTime="'..animTime..'"';
			end;
			nodes = nodes..'/>';
		end;
	end;
	return attributes, nodes;
end;]]

function TractorAnim_PeterJ:update(dt)
	if self:getIsActive() and self:getIsActiveForInput(false) then
		if self.numToggleAnimationsParts > 0 and self:getIsActiveForInput(true) and not self:hasInputConflictWithSelection() then
			if self.selectedAnimationPart ~= nil and self.selectedAnimationPart > 0 then
				if self.numAvailableAnimations > 1 then
					if InputBinding.hasEvent(self.toggleAnimInputButton) then
						if self:getIsControlAnimChangeAllowed() then
							local direction = 1;
							local index = self:getNextValidAnimPart(direction);
							if index ~= nil then
								self:toggleAnimState(index, nil);
							end;
						end;
					end;
					if InputBinding.hasEvent(self.toggleAnimBackInputButton) then
						if self:getIsControlAnimChangeAllowed() then
							local direction = -1;
							local index = self:getNextValidAnimPart(direction);
							if index ~= nil then
								self:toggleAnimState(index, nil);
							end;
						end;
					end;
				end;
				if InputBinding.hasEvent(self.operateInputButton) then
					if self.toggleAnimationParts[self.selectedAnimationPart].isAvailable then
						self:toggleAnimState(self.selectedAnimationPart, not self.toggleAnimationParts[self.selectedAnimationPart].isOn);
					end;
				end;
			end;
		end;
		if self.wipersAnim ~= nil then
			if InputBinding.hasEvent(InputBinding.TOGGLE_WIPERS) then
				self:setTurnOnWiper(not self.isWiperOn);
			end;
		end;
	end;
	
	if self:getIsActive() then
		for i, part in ipairs(self.loaderControls) do
			if part.refIndex ~= nil then
				local partCurrentPos = nil;
				if part.rotMovement then
					local xRot,_,_ = getRotation(part.refIndex);
					partCurrentPos = xRot;			
				else
					local _,yTrans,_ = getTranslation(part.refIndex);
					partCurrentPos = yTrans;			
				end;
				if partCurrentPos ~= nil then
					if part.previousPos ~= partCurrentPos then
						if partCurrentPos > part.previousPos then
							if not part.isPos then
								self:playAnimation(part.posAnim, 1, nil, true);
								part.isPos = true;
								part.isNeg = false;
							end;
							self.vehicleCharacter:setDirty();
						elseif partCurrentPos < part.previousPos then
							if not part.isNeg then
								self:playAnimation(part.negAnim, 1, nil, true);
								part.isNeg = true;
								part.isPos = false;
							end;
							self.vehicleCharacter:setDirty();
						end;
					else
						if part.isPos then
							self:playAnimation(part.posAnim, -1, nil, true);
							part.isPos = false;
							self.vehicleCharacter:setDirty();
						else
							if self:getIsAnimationPlaying(part.posAnim) then
								self.vehicleCharacter:setDirty();
							end;
						end;
						if part.isNeg then
							self:playAnimation(part.negAnim, -1, nil, true);
							part.isNeg = false;
							self.vehicleCharacter:setDirty();
						else
							if self:getIsAnimationPlaying(part.negAnim) then
								self.vehicleCharacter:setDirty();
							end;
						end;
					end;
					part.previousPos = partCurrentPos;
				end;
			end;
		end;
	end;
end;

function TractorAnim_PeterJ:updateTick(dt)
	if self:getIsActive() then
		self:setLightAnimations();

		if self.ignitionAnim ~= nil then
			local dir = 1;
			local playIgnitionAnim = true;
			if not self.isMotorStarted then
				dir = -1;
				playIgnitionAnim = false;
			end;
			if self.ignitionAnimOn ~= playIgnitionAnim then
				self:playAnimation(self.ignitionAnim, dir, nil, true);
				self.ignitionAnimOn = playIgnitionAnim;
			end;
		end;
		if self.lowFuelHUD ~= nil and self.fuelCapacity ~= 0 then
			setVisibility(self.lowFuelHUD, self.fuelFillLevel < (self.fuelCapacity*0.2));
		end;

		if table.getn(self.attachedImplements) > 0 then
			for k,implement in pairs(self.attachedImplements) do
				local jointIndex = implement.jointDescIndex;
				local currentJoint = self.attacherJoints[jointIndex];
				local attachedTool = implement.object;
				if currentJoint.liftArmsLeverAnim ~= nil then
					if currentJoint.allowsLowering then
						if attachedTool:isLowered(false) then
							currentJoint.liftArmsLeverState = -1;
						else
							currentJoint.liftArmsLeverState = 1;
						end;
						if currentJoint.liftArmsLeverState ~= currentJoint.liftArmsPreviousState then
							self:playAnimation(currentJoint.liftArmsLeverAnim, currentJoint.liftArmsLeverState, nil, true);
						end;
						currentJoint.liftArmsPreviousState = currentJoint.liftArmsLeverState;
					end;
				end;
				if currentJoint.ptoLeverAnim ~= nil then
					if attachedTool.ptoInput ~= nil and attachedTool.ptoInput.node ~= nil then
						if attachedTool.turnOnVehicle ~= nil and attachedTool.turnOnVehicle.isTurnedOn ~= nil then
							if attachedTool.turnOnVehicle.isTurnedOn then
								currentJoint.ptoLeverState = 1;
							else
								currentJoint.ptoLeverState = -1;
							end;
							if currentJoint.ptoLeverState ~= currentJoint.ptoLeverPreviousState then
								self:playAnimation(currentJoint.ptoLeverAnim, currentJoint.ptoLeverState, nil, true);
								currentJoint.ptoLeverPreviousState = currentJoint.ptoLeverState;
							end;
						end;
					end;
				end;
			end;
		end;
		if self.handBrakeAnim ~= nil then
			local isHandBrakeOn = false;
			local dir = -1;
			if self.isMotorStarted then
				if self.movingDirection == 0 and not self.brakeLightsVisibility then
					dir = 1;
					isHandBrakeOn = true;
				end;
			else
				dir = 1;
				isHandBrakeOn = true;
			end;
			if isHandBrakeOn ~= self.handBrakeState then
				self:playAnimation(self.handBrakeAnim, dir, nil, true);
				self.handBrakeState = isHandBrakeOn;
			end;
		end;
		--! driveControl animations !--
		--[[if self.driveControl ~= nil then
			if self.fourWDAnim ~= nil then
				if self.driveControl.fourWDandDifferentials.fourWheel ~= nil and self.fourWheelDrive ~= self.driveControl.fourWDandDifferentials.fourWheel then
					self.fourWheelDrive = self.driveControl.fourWDandDifferentials.fourWheel;
					--self.driveControl.fourWDandDifferentials.diffLockFront = self.fourWheelDrive;
					local dir = 1;
					if not self.fourWheelDrive then
						dir = -1;
					end;
					self:playAnimation(self.fourWDAnim, dir, nil, true);
				end;
			end;
			if self.diffLockAnim ~= nil then
				if self.driveControl.fourWDandDifferentials.diffLockBack ~= nil and self.differentialLockBack ~= self.driveControl.fourWDandDifferentials.diffLockBack then
					self.differentialLockBack = self.driveControl.fourWDandDifferentials.diffLockBack;
					local dir = 1;
					if not self.differentialLockBack then
						dir = -1;
					end;
					self:playAnimation(self.diffLockAnim, dir, nil, true);
				end;
			end;
		end;]]
		--[[if not self.enableSteerEngineOff and not self.isHired then
			self.steeringEnabled = self.isMotorStarted;
		end;]]

	end;
end;

function TractorAnim_PeterJ:draw()
	if self:getIsActive() then
		if self.numToggleAnimationsParts > 0 and self:getIsActiveForInput(true) and not self:hasInputConflictWithSelection() then
			if self.selectedAnimationPart ~= nil and self.selectedAnimationPart > 0 and self.numAvailableAnimations > 0 then
				if self.numAvailableAnimations > 1 then
					g_currentMission:addHelpButtonText(g_i18n:getText("SWITCH_ANIMATION"), self.toggleAnimInputButton);
				end;
				if not self.toggleAnimationParts[self.selectedAnimationPart].isOn then
					g_currentMission:addHelpButtonText(g_i18n:getText(self.toggleAnimationParts[self.selectedAnimationPart].posDirectionText), self.operateInputButton);
				else
					g_currentMission:addHelpButtonText(g_i18n:getText(self.toggleAnimationParts[self.selectedAnimationPart].negDirectionText), self.operateInputButton);
				end;
			end;
		end;
		if self.wipersAnim ~= nil then --and not self.isAttachable
			if g_currentMission.environment.lastRainScale > 0.1 and g_currentMission.environment.timeSinceLastRain < 30 then
				g_currentMission:addHelpButtonText(g_i18n:getText("TOGGLE_WIPERS"), InputBinding.TOGGLE_WIPERS);	
			end;
		end;
	end;
end;

function TractorAnim_PeterJ:onAttachImplement(implement)
	
	local jointIndex = implement.jointDescIndex;
	for i, part in ipairs(self.toggleAnimationParts) do
		if part.attacherJointRestriction ~= nil then
			if part.attacherJointRestriction == jointIndex then
				if part.isAvailable then
					part.isAvailable = false;
					part.isOn = false;
					local newAvailableAnims = self.numAvailableAnimations - 1;
					self.numAvailableAnimations =  math.max(newAvailableAnims, 0);
					if self.numAvailableAnimations > 0 and self.selectedAnimationPart == i then
						if self:getIsControlAnimChangeAllowed() then
							local selectedIdx = self:getNextValidAnimPart(1);
							self:toggleAnimState(selectedIdx, nil);
						end;
					end;
				end;
			end;
		end;
	end;	
end;

function TractorAnim_PeterJ:onDetachImplement(implementIndex)
	
	local implement = self.attachedImplements[implementIndex];
	local jointIndex = implement.jointDescIndex;
	local attacherJoint = self.attacherJoints[jointIndex];
	
	for i, part in ipairs(self.toggleAnimationParts) do
		if part.attacherJointRestriction ~= nil then
			if part.attacherJointRestriction == jointIndex then
				if not part.isAvailable then
					part.isAvailable = true;
					local newAvailableAnims = self.numAvailableAnimations + 1;
					self.numAvailableAnimations =  math.min(newAvailableAnims, self.numToggleAnimationsParts);
				end;
			end;
		end;
	end;
	if attacherJoint.liftArmsLeverAnim ~= nil then
		self:setAnimationTime(attacherJoint.liftArmsLeverAnim, attacherJoint.defaultLiftArmsLeverPos, true);
		attacherJoint.liftArmsPreviousState = 0;
	end;
	if attacherJoint.ptoLeverAnim ~= nil then
		local animTime = self:getAnimationTime(attacherJoint.ptoLeverAnim);
		if animTime > 0 then
			self:playAnimation(attacherJoint.ptoLeverAnim, -1, nil, true);
			attacherJoint.ptoLeverPreviousState = -1;
		end;
	end;
end;

function TractorAnim_PeterJ:getNextValidAnimPart(direction)

    local index = self.selectedAnimationPart;
	if direction > 0 then
		if index == self.numToggleAnimationsParts then
			index = 0;
		end;
	else
		if index == 1 then
			index = self.numToggleAnimationsParts + 1;
		end;
	end;
	self.toggleDir = direction;

	local returnValue = 1;
	for i, part in ipairs(self.toggleAnimationParts) do
		if part.isAvailable ~= nil then
			if part.isAvailable then
				if self.toggleDir > 0 then
					if i > index then
						return i;
					end;
				else -- set loop back
					if index > i then
						returnValue = i;
					end;
				end;
			end;
		end;
	end;
	
	return returnValue;

end;

function TractorAnim_PeterJ:getIsControlAnimChangeAllowed()
    if self.numToggleAnimationsParts > 1 then
		for i, part in ipairs(self.toggleAnimationParts) do
			if part.visibilityRefRestriction ~= nil then
				local visibilityRestrictionPart = getVisibility(part.visibilityRefRestriction);
				if visibilityRestrictionPart == false then
					if part.isAvailable then
						part.isAvailable = false;
						local newAvailableAnims = self.numAvailableAnimations - 1;
						self.numAvailableAnimations = math.max(newAvailableAnims, 0);
					end;
				else
					--[[if not part.isAvailable then
						part.isAvailable = true;
						local newAvailableAnims = self.numAvailableAnimations + 1;
						self.numAvailableAnimations = newAvailableAnims;
					end;]]
				end;
			end;
		end;
		if self.numAvailableAnimations > 1 then
			return true;
		else
			local index = self:getNextValidAnimPart(1)
			self.selectedAnimationPart = index;
		end;
    else
        return false;
    end;
end;

function TractorAnim_PeterJ:toggleAnimState(id, state, noEventSend)
	self.selectedAnimationPart = id;
	if state ~= nil then
		if noEventSend == nil or noEventSend == false then
			SetToggleAnimEvent.sendEvent(self,id,state,noEventSend);
		end;
		if self.toggleAnimationParts[id].isOn ~= state then
			for i=1, table.getn(self.toggleAnimationParts) do
				if i == id then
					if self.toggleAnimationParts[id].animationName ~= nil then
						local direction = 1;
						if not state then
							direction = -direction;
						end;
						self:playAnimation(self.toggleAnimationParts[id].animationName, direction, nil, true);
						self.toggleAnimationParts[id].isOn = state;
					end;
				end;
			end;
		end;
	end;
end;

function TractorAnim_PeterJ:setLightAnimations()

		for i, part in ipairs(self.lightAnimationParts) do
			if part.lightIndex ~= nil then
				local lightVisility = getVisibility(part.lightIndex);
				if lightVisility then
					if not part.isOn then
						self:playAnimation(part.animationName, 1, nil, true);
						if part.secondaryAnimName then
							self:playAnimation(part.animationName, 1, nil, true);
						end;
						part.isOn = true;
					end;
				else
					if part.isOn then
						self:playAnimation(part.animationName, -1, nil, true);
						if part.secondaryAnimName then
							self:playAnimation(part.animationName, -1, nil, true);
						end;
						part.isOn = false;
					end;
				end;
			else
				if part.isReverse then
					if self.reverseLightsVisibility then
						if not part.isOn then
							self:playAnimation(part.animationName, 1, nil, true);
							part.isOn = true;
						end;
					else
						if part.isOn then
							self:playAnimation(part.animationName, -1, nil, true);
							part.isOn = false;
						end;
					end;
				end;
				if part.isBeacon then
					if self.beaconLightsActive  then
						if not part.isOn then
							self:playAnimation(part.animationName, 1, nil, true);
							part.isOn = true;
						end;
					else
						if part.isOn then
							self:playAnimation(part.animationName, -1, nil, true);
							part.isOn = false;
						end;
					end;
				end;
				if self.turnLightState == Lights.TURNLIGHT_OFF then
					if part.isLeftIndicator or part.isRightIndicator or part.isHazard then
						if part.isOn then
							self:playAnimation(part.animationName, -1, nil, true);
							part.isOn = false;
						end;			
					end;			
				elseif self.turnLightState == Lights.TURNLIGHT_LEFT then
					if part.isLeftIndicator then
						if not part.isOn then
							self:playAnimation(part.animationName, 1, nil, true);
							part.isOn = true;
						end;
					else
						if part.isRightIndicator or part.isHazard then
							if part.isOn then
								--self:playAnimation(part.animationName, -1, nil, true);
								self:setAnimationTime(part.animationName, 0, true);
								self:stopAnimation(part.animationName, nil);
								part.isOn = false;
							end;
						end;
					end;
				elseif self.turnLightState == Lights.TURNLIGHT_RIGHT then
					if part.isRightIndicator then
						if not part.isOn then
							self:playAnimation(part.animationName, 1, nil, true);
							part.isOn = true;
						end;
					else
						if part.isLeftIndicator or part.isHazard then
							if part.isOn then
								--self:playAnimation(part.animationName, -1, nil, true);
								self:setAnimationTime(part.animationName, 0, true);
								self:stopAnimation(part.animationName, nil);
								part.isOn = false;
							end;
						end;
					end;
				elseif self.turnLightState == Lights.TURNLIGHT_HAZARD then
					if part.isHazard then
						if not part.isOn then
							self:playAnimation(part.animationName, 1, 0, true);
							part.isOn = true;
						end;
					else
						if part.isLeftIndicator or part.isRightIndicator then
							if part.isOn then
								self:playAnimation(part.animationName, -1, nil, true);
								part.isOn = false;
							end;
						end;
					end;
				end;
			end;
		end;
end;
	
function TractorAnim_PeterJ:setTurnOnWiper(isWiperOn, noEventSend)
    if isWiperOn ~= self.isWiperOn then
		local direction = 1;
		if not isWiperOn then
			direction = -1;
		end;
		if self.wipersAnim ~= nil then
			self:playAnimation(self.wipersAnim, direction, nil, false);
		end;
		if self.wipersButtonAnim ~= nil then
			self:playAnimation(self.wipersButtonAnim, direction, nil, false);
			--playSample(g_currentMission.toggleLightsSound, 1, 1.0, 0);
		end;
		self.isWiperOn = isWiperOn;
	end;
end;



SetToggleAnimEvent = {};
SetToggleAnimEvent_mt = Class(SetToggleAnimEvent, Event);
InitEventClass(SetToggleAnimEvent, "SetToggleAnimEvent");

function SetToggleAnimEvent:emptyNew()
    local self = Event:new(SetToggleAnimEvent_mt);
    self.className="SetToggleAnimEvent";
    return self;
end;

function SetToggleAnimEvent:new(vehicle, id, state)
	local self = SetToggleAnimEvent:emptyNew()
	self.vehicle = vehicle;
	self.id = id;
	self.state = state;
	return self;
end;

function SetToggleAnimEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
	self.vehicle = networkGetObject(id);
	self.id  = streamReadInt8(streamId);
    self.state = streamReadBool(streamId);
    self:run(connection);
end;

function SetToggleAnimEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
	streamWriteInt8(streamId, self.id);
	streamWriteBool(streamId, self.state);
end;

function SetToggleAnimEvent:run(connection)
	self.vehicle:toggleAnimState(self.id,self.state, true);
	if not connection:getIsServer() then
		g_server:broadcastEvent(SetToggleAnimEvent:new(self.vehicle, self.id, self.state), nil, connection, self.vehicle);
	end;	
end;

function SetToggleAnimEvent.sendEvent(vehicle, id, state, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(SetToggleAnimEvent:new(vehicle, id, state), nil, nil, vehicle);
		else
			g_client:getServerConnection():sendEvent(SetToggleAnimEvent:new(vehicle, id, state));
		end;
	end;
end;
