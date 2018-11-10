--
-- InteractiveButtons
-- Specialization for an interactive control button
--
-- @author  	Manuel Leithner (SFM-Modding)
-- @version 	v2.1
-- @date  		29/08/11
-- @history:	v1.0 - Initial version
--				v2.0 - converted to ls2011
--				v2.1 - improvements
--
-- free for noncommerical-usage
--

InteractiveButtons = {};

function InteractiveButtons.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(InteractiveControl, specializations);
end;

function InteractiveButtons:load(savegame)

	local i=0;
	while true do
		local buttonName = string.format("vehicle.interactiveComponents.buttons.button(%d)", i);	
		if not hasXMLProperty(self.xmlFile, buttonName) then
			break;
		end;
		local name = Utils.getNoNil(g_i18n:getText(getXMLString(self.xmlFile, buttonName .. "#name")), "ERROR");
		local mark = Utils.indexToObject(self.components, getXMLString(self.xmlFile, buttonName .. "#mark"));
		local highlight = getChildAt(mark, 0);
		local size = Utils.getNoNil(getXMLFloat(self.xmlFile, buttonName .. "#size"), 0.1);
		local event = getXMLString(self.xmlFile, buttonName .. "#event");
		local onMessage = g_i18n:getText(Utils.getNoNil(getXMLString(self.xmlFile, buttonName .. "#onMessage"), "ic_button_on"));
		local offMessage =  g_i18n:getText(Utils.getNoNil(getXMLString(self.xmlFile, buttonName .. "#offMessage") , "ic_button_off"));
	
		local button = Button:new(nil, highlight, name, mark, size, event, self, onMessage, offMessage, self.infoBar);
		
		button.synch = Utils.getNoNil(getXMLBool(self.xmlFile, buttonName .. "#synch"), true);

		table.insert(self.interactiveObjects, button);
		i = i + 1;
	end;
end;

function InteractiveButtons:delete()
end;

function InteractiveButtons:mouseEvent(posX, posY, isDown, isUp, button)
end;

function InteractiveButtons:keyEvent(unicode, sym, modifier, isDown)
end;

function InteractiveButtons:update(dt)	
end;

function InteractiveButtons:draw()
end;



--
-- Button Class
-- Specifies an interactive Button
--
-- SFM-Modding
-- @author  Manuel Leithner
-- @date  29/08/11
--

Button = {};

function Button:new(node, highlight, name, mark, size, event, vehicle, onMessage, offMessage, infobar)

	local Button_mt = Class(Button, InteractiveComponentInterface);	
    local instance = InteractiveComponentInterface:new(node, highlight, name, mark, size, onMessage, offMessage, infobar, Button_mt);

	instance.vehicle = vehicle;
	instance.event = event;
	
	return instance;	
end;

function Button:delete()
	InteractiveComponentInterface.delete(self);
end;

function Button:mouseEvent(posX, posY, isDown, isUp, button)
	InteractiveComponentInterface.mouseEvent(self, posX, posY, isDown, isUp, button);
end;

function Button:keyEvent(unicode, sym, modifier, isDown)
	InteractiveComponentInterface.keyEvent(self, unicode, sym, modifier, isDown);
end;

function Button:update(dt)
	if self.vehicle ~= nil then
		if self.event == "cablight" then
			self.isOpen = self.vehicle.cl.turnOn;
		--elseif self.event == " " then
		end;
	end;
	InteractiveComponentInterface.update(self, dt);
end;

function Button:draw()
	InteractiveComponentInterface.draw(self);
end;

function Button:doAction(noEventSend, forceAction)
	if self.vehicle ~= nil then
		if self.event == "cablight" then
			if forceAction == nil then
				local state = not self.vehicle.cl.turnOn;
				self.vehicle:setCablight(state, true);
			end;
--		elseif self.event == "" then

		end;	
	end;
end;

function Button:onEnter(dt)
	InteractiveComponentInterface.onEnter(self, dt);
end;

function Button:onExit(dt)
	InteractiveComponentInterface.onExit(self, dt);
end;

function Button:setActive()
	InteractiveComponentInterface.setActive(self, isActive);
end;

function Button:setVisible(isVisible)
	InteractiveComponentInterface.setVisible(self, isVisible);
end;