--
-- InteractiveWindows
-- Specialization for InteractiveWindows
--
-- @author      Manuel Leithner (SFM-Modding)
-- @version     v3.0
-- @date        24/10/12
-- @history:    v1.0 - Initial version
--              v2.0 - converted to ls2011
--              v3.0 - converted to ls2013
--
-- free for noncommerical-usage
--

InteractiveWindows = {};

function InteractiveWindows.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(InteractiveControl, specializations) and SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations);
end;

function InteractiveWindows:load(savegame)

    local i=0;
    while true do
        local windowName = string.format("vehicle.interactiveComponents.windows.window(%d)", i);
        if not hasXMLProperty(self.xmlFile, windowName) then
            break;
        end;
        local animation = getXMLString(self.xmlFile, windowName .. "#animName");
        local name = Utils.getNoNil(g_i18n:getText(getXMLString(self.xmlFile, windowName .. "#name")), "ERROR");
        local mark = Utils.indexToObject(self.components, getXMLString(self.xmlFile, windowName .. "#mark"));
        local highlight = getChildAt(mark, 0);
        local size = Utils.getNoNil(getXMLFloat(self.xmlFile, windowName .. "#size"), 0.1);
        local onMessage = g_i18n:getText(Utils.getNoNil(getXMLString(self.xmlFile, windowName .. "#onMessage"), "ic_button_on"));
        local offMessage =  g_i18n:getText(Utils.getNoNil(getXMLString(self.xmlFile, windowName .. "#offMessage") , "ic_button_off"));
        local window = Window:new(highlight, name, animation, mark, size, self, onMessage, offMessage);
        window.synch = Utils.getNoNil(getXMLBool(self.xmlFile, windowName .. "#synch"), true);
        table.insert(self.interactiveObjects, window);
        i = i + 1;
    end;
end;

function InteractiveWindows:delete()
end;

function InteractiveWindows:mouseEvent(posX, posY, isDown, isUp, button)
end;

function InteractiveWindows:keyEvent(unicode, sym, modifier, isDown)
end;

function InteractiveWindows:update(dt)
end;

function InteractiveWindows:draw()
end;



--
-- Window Class
-- Specifies an interactive window
--
-- SFM-Modding
-- @author  Manuel Leithner
-- @date  26/12/09
--

Window = {};

function Window:new(highlight, name, animation, mark, size, vehicle, onMessage, offMessage)

    local Window_mt = Class(Window, InteractiveComponentInterface);
    local instance = InteractiveComponentInterface:new(nil, highlight, name, mark, size, onMessage, offMessage, Window_mt);
    instance.vehicle = vehicle;
    instance.animation = animation;

    return instance;
end;

function Window:delete()
    InteractiveComponentInterface.delete(self);
end;

function Window:mouseEvent(posX, posY, isDown, isUp, button)
    InteractiveComponentInterface.mouseEvent(self, posX, posY, isDown, isUp, button);
end;

function Window:keyEvent(unicode, sym, modifier, isDown)
    InteractiveComponentInterface.keyEvent(self, unicode, sym, modifier, isDown);
end;

function Window:update(dt)
    InteractiveComponentInterface.update(self, dt);
end;

function Window:draw()
    InteractiveComponentInterface.draw(self);
end;

function Window:doAction(noEventSend, forceAction)
    InteractiveComponentInterface.doAction(self, forceAction);
    local dir = 1;
    if not self.isOpen  then
        dir = -1;
    end;
    self.vehicle:playAnimation(self.animation, dir, Utils.clamp(self.vehicle:getAnimationTime(self.animation), 0, 1), true);
end;

function Window:onEnter()
    InteractiveComponentInterface.onEnter(self);
end;

function Window:onExit()
    InteractiveComponentInterface.onExit(self);
end;

function Window:setActive()
    InteractiveComponentInterface.setActive(self, isActive);
end;

function Window:setVisible(isVisible)
    InteractiveComponentInterface.setVisible(self, isVisible);
end;