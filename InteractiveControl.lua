--
-- InteractiveControl v3.0
-- Specialization for an interactive control
--
-- SFM-Modding
-- @author:      Manuel Leithner
-- @date:        15/05/2013
-- @version:     v2.0
-- @history:     v1.0 - initial implementation
--               v2.0 - convert to LS2011 and some bugfixes
--               v3.0 - convert to LS2013 and bugfixes
--
--
-- free for noncommerical-usage
--

originalInputBindingUpdate = InputBinding.update;
InputBinding.update = function(dt)
    InputBinding.accumMouseMovementXBackUp = InputBinding.accumMouseMovementX;
    InputBinding.accumMouseMovementYBackUp = InputBinding.accumMouseMovementY;
    originalInputBindingUpdate(dt);
end;

InteractiveControl = {};

function InteractiveControl.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Steerable, specializations);
end;

function InteractiveControl:load(xmlFile)

	source(Utils.getFilename("scripts/InteractiveComponentInterface.lua", self.baseDirectory));

    self.doActionOnObject = SpecializationUtil.callSpecializationsFunction("doActionOnObject");
    self.setPanelOverlay = SpecializationUtil.callSpecializationsFunction("setPanelOverlay");

    self.interactiveObjects = {};

    self.indoorCamIndex = 2;
    self.outdoorCamIndex = 1;

    self.lastMouseXPos = 0;
    self.lastMouseYPos = 0;

    self.panelOverlay = nil;
    self.foundInteractiveObject = nil;
    self.isMouseActive = false;
	
	self.ICrefNode = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.interactiveComponents#refNode"));
end;

function InteractiveControl:postLoad(savegame)
    if savegame ~= nil then
		local i=0;
		while true do
			local objKey = savegame.key .. string.format(".interactiveObject(%d)", i);
			if not hasXMLProperty(savegame.xmlFile, objKey) then
				break;
			end;
			local id = getXMLInt(savegame.xmlFile, objKey.."#id");
			if id ~= nil then
				local state = Utils.getNoNil(getXMLBool(savegame.xmlFile, objKey.."#state"), false);
				local iObj = self.interactiveObjects[id];
				if iObj ~= nil then
					iObj:doAction(true, state);
				end;
			end;
			i = i +1;
		end;
    end;
	if self.ICrefNode ~= nil then
		self.useIC = getVisibility(self.ICrefNode);
	else
		self.useIC = true;
	end;
end

function InteractiveControl:delete()
    for _,v in pairs(self.interactiveObjects) do
        v:delete();
    end;
end;

function InteractiveControl:readStream(streamId, connection)
    local icCount = streamReadInt8(streamId);
    for i=1, icCount do
        local isOpen = streamReadBool(streamId);
        if self.interactiveObjects[i].synch then
            self.interactiveObjects[i]:doAction(true, isOpen);
        end;
    end;
end;

function InteractiveControl:writeStream(streamId, connection)
    streamWriteInt8(streamId, table.getn(self.interactiveObjects));
    for k,v in pairs(self.interactiveObjects) do
        streamWriteBool(streamId, v.isOpen);
    end;
end;

function InteractiveControl:mouseEvent(posX, posY, isDown, isUp, button)
	if self.useIC then
    self.lastMouseXPos = posX;
    self.lastMouseYPos = posY;

    if isDown then
        if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_LEFT) and self.foundInteractiveObject ~= nil then
            self:doActionOnObject(self.foundInteractiveObject);
        end;
        local currentCam = self.cameras[self.camIndex];
        if currentCam.allowTranslation then
            if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                currentCam:zoomSmoothly(-0.75);
            elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                currentCam:zoomSmoothly(0.75);
            end;
        end;
    end;

    for _,v in pairs(self.interactiveObjects) do
        v:mouseEvent(posX, posY, isDown, isUp, button);
    end;
    end;
end;

function InteractiveControl:keyEvent(unicode, sym, modifier, isDown)
	if self.useIC then
    for _,v in pairs(self.interactiveObjects) do
        v:keyEvent(unicode, sym, modifier, isDown);
    end;
    end;
end;

function InteractiveControl:update(dt)
	if self.useIC then
	if self:getIsActive() then
        self.foundInteractiveObject = nil;
        local icObject = nil;
        for k,v in pairs(self.interactiveObjects) do
            v:update(dt);
        end;

        if self.isClient and self:getIsActiveForInput(false) and not self:hasInputConflictWithSelection() then
			if self.activeCamera.isInside then
				if InputBinding.hasEvent(InputBinding.INTERACTIVE_CONTROL_SWITCH) then
					self.isMouseActive = not self.isMouseActive;

					if not self.isMouseActive then
						InputBinding.setShowMouseCursor(false);
						self.cameras[self.camIndex].isActivated = true;
						for _,v in pairs(self.interactiveObjects) do
							v:onExit(dt);
						end;
					end;

					for _,v in pairs(self.interactiveObjects) do
						v:setVisible(self.isMouseActive);
					end;
				end;
			else
				if self.isMouseActive then
					self.isMouseActive = false;
					if not self.isMouseActive then
						InputBinding.setShowMouseCursor(false);
						self.cameras[self.camIndex].isActivated = true;
						for _,v in pairs(self.interactiveObjects) do
							v:onExit(dt);
						end;
					end;

					for _,v in pairs(self.interactiveObjects) do
						v:setVisible(self.isMouseActive);
					end;
				end;
			end;
			if self.isMouseActive then
				local currentCam = self.cameras[self.camIndex];

				if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_RIGHT) then
					InputBinding.wrapMousePositionEnabled = true;
					currentCam.rotX = currentCam.rotX + InputBinding.accumMouseMovementYBackUp;
					currentCam.rotY = currentCam.rotY - InputBinding.accumMouseMovementXBackUp;

					self.cameras[self.indoorCamIndex].isActivated = self.camIndex == self.indoorCamIndex;
					self.cameras[self.outdoorCamIndex].isActivated = self.camIndex == self.outdoorCamIndex;
					--setShowMouseCursor(false);
					InputBinding.setShowMouseCursor(false);
				else
					self.cameras[self.indoorCamIndex].isActivated = self.camIndex ~= self.indoorCamIndex;
					self.cameras[self.outdoorCamIndex].isActivated = self.camIndex ~= self.outdoorCamIndex;
					InputBinding.setShowMouseCursor(true);
				end;
			else
				self.foundInteractiveObject = nil;
			end;
        else
            self.foundInteractiveObject = nil;
        end;

        InputBinding.accumMouseMovementXBackUp = 0;
        InputBinding.accumMouseMovementYBackUp = 0;

    end;
    end;
end;

function InteractiveControl:updateTick(dt)
end;

function InteractiveControl:doActionOnObject(id, noEventSend)
	if self.useIC then
    if self.interactiveObjects[id].isLocalOnly == nil or not self.interactiveObjects[id].isLocalOnly then
        InteractiveControlEvent.sendEvent(self, id, noEventSend);
    end;
    self.interactiveObjects[id]:doAction(noEventSend);
    end;
end;

function InteractiveControl:draw()
	if self.useIC then
    if self:getIsActive() and self.activeCamera.isInside then
        self.foundInteractiveObject = nil;
        local icObject = nil;
        for k,v in pairs(self.interactiveObjects) do
            if self.isMouseActive then
                v:onExit();
                if icObject == nil and self.camIndex == self.indoorCamIndex then
                    local worldX,worldY,worldZ = getWorldTranslation(v.mark);
                    local x,y,z = project(worldX,worldY,worldZ);
                    if z <= 1 then
                        if self.lastMouseXPos > (x-v.size/2) and self.lastMouseXPos < (x+v.size/2) then
                            if self.lastMouseYPos > (y-v.size/2) and self.lastMouseYPos < (y+v.size/2) then
                                local isOverlapped = false;

                                if self.panelOverlay ~= nil then
                                    local overlay = self.panelOverlay.mainBackground;
                                    isOverlapped = self.lastMouseXPos >= overlay.x and self.lastMouseXPos <= overlay.x+overlay.width and self.lastMouseYPos >= overlay.y and self.lastMouseYPos <= overlay.y+overlay.height;
                                end;

                                if not isOverlapped then
                                    icObject = v;
                                    self.foundInteractiveObject = k;
                                    break;
                                end;
                            end;
                        end;
                    end;
                end;
            end;
        end;

        if icObject ~= nil then
            icObject:onEnter();
        end;
		
		if self.isMouseActive then
			g_currentMission:addHelpButtonText(g_i18n:getText("InteractiveControl_Off"), InputBinding.INTERACTIVE_CONTROL_SWITCH);
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("InteractiveControl_On"), InputBinding.INTERACTIVE_CONTROL_SWITCH);
		end;
    end;

    for _,v in pairs(self.interactiveObjects) do
        v:draw();
    end;
    end;
end;

function InteractiveControl:onLeave()
	if self.useIC then
    self.cameras[self.indoorCamIndex].isActivated = true;
    --g_mouseControlsHelp.active = true;
    if g_gui.currentGui == nil then
        InputBinding.setShowMouseCursor(false);
    end;
    end;
end;

function InteractiveControl:setPanelOverlay(panel)
	if self.useIC then
    if self.panelOverlay ~= nil then
        if self.panelOverlay.setActive ~= nil then
            self.panelOverlay:setActive(false);
        end;
    end;
    self.panelOverlay = panel;

    if panel ~= nil then
        if panel.setActive ~= nil then
            panel:setActive(true);
        end;
    end;
    end;
end;

function InteractiveControl:getSaveAttributesAndNodes(nodeIdent)
	if self.useIC then
    local attributes = "";
    local nodes = "";

    for id, iObj in pairs(self.interactiveObjects) do
        if id > 1 then
            nodes = nodes.."\n";
        end;
        nodes = nodes..nodeIdent..'<interactiveObject id="'..id..'" state="'..tostring(iObj.isOpen)..'"/>';
    end;

    return attributes, nodes;
    end;
end;



--
-- InteractiveControlEvent
-- Specialization for an interactive control
--
-- SFM-Modding
-- @author:      Manuel Leithner
-- @date:        14/12/11
-- @version:    v2.0
-- @history:    v1.0 - initial implementation
--                v2.0 - convert to LS2011 and some bugfixes
--
InteractiveControlEvent = {};
InteractiveControlEvent_mt = Class(InteractiveControlEvent, Event);

InitEventClass(InteractiveControlEvent, "InteractiveControlEvent");

function InteractiveControlEvent:emptyNew()
    local self = Event:new(InteractiveControlEvent_mt);
    return self;
end;

function InteractiveControlEvent:new(vehicle, interactiveControlID)
    local self = InteractiveControlEvent:emptyNew()
    self.vehicle = vehicle;
    self.interactiveControlID = interactiveControlID;
    return self;
end;

function InteractiveControlEvent:readStream(streamId, connection)
    local id = streamReadInt32(streamId);
    self.interactiveControlID = streamReadInt8(streamId);
    self.vehicle = networkGetObject(id);
    self:run(connection);
end;

function InteractiveControlEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
    streamWriteInt8(streamId, self.interactiveControlID);
end;

function InteractiveControlEvent:run(connection)
    self.vehicle:doActionOnObject(self.interactiveControlID, true);
    if not connection:getIsServer() then
        g_server:broadcastEvent(InteractiveControlEvent:new(self.vehicle, self.interactiveControlID), nil, connection, self.vehicle);
    end;
end;

function InteractiveControlEvent.sendEvent(vehicle, icObject, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(InteractiveControlEvent:new(vehicle, icObject), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(InteractiveControlEvent:new(vehicle, icObject));
        end;
    end;
end;