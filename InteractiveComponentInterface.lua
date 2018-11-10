--
-- InteractiveComponent Interface
-- Specifies an interactive component
--
-- SFM-Modding
-- @author:      Manuel Leithner
-- @date:        15/05/2013
-- @version:     v2.0
-- @history:     v1.0 - initial implementation
--               v2.0 - convert to LS2011 and some bugfixes
--               v3.0 - covnert to LS2013 and bugfixes
--
-- free for noncommerical-usage
--

InteractiveComponentInterface = {};

function InteractiveComponentInterface:new(node, highlight, name, mark, size, onMessage, offMessage, mt)

    local mTable = mt;
    if mTable == nil then
        mTable = Class(InteractiveComponentInterface);
    end;
    local instance = {};
    setmetatable(instance, mTable);

    instance.node = node;
    instance.highlight = highlight;
    instance.scaleX, instance.scaleY, instance.scaleZ = getScale(instance.highlight);
    instance.name = name;
    instance.mark = mark;
    setVisibility(mark,false);
    instance.scale = 0.01;
    instance.size = size;
    instance.xPos = 0;
    instance.yPos = 0;
    instance.zPos = 0;
    instance.isActive = true;
    instance.isMouseOver = false;
    instance.isOpen = false;
    instance.onMessage = Utils.getNoNil(onMessage, g_i18n:getText("ic_component_open"));
    instance.offMessage = Utils.getNoNil(offMessage, g_i18n:getText("ic_component_close"));
    instance.synch = true;

    return instance;
end;


function InteractiveComponentInterface:delete()
end;

function InteractiveComponentInterface:mouseEvent(posX, posY, isDown, isUp, button)
end;

function InteractiveComponentInterface:keyEvent(unicode, sym, modifier, isDown)
end;

function InteractiveComponentInterface:update(dt)
    if self.isActive then
        if self.highlight ~= nil then
            if self.isMouseOver then
				self.scale = self.scale - 0.0003 * dt;
				setScale(self.highlight, self.scaleX + self.scale, self.scaleY + self.scale, self.scaleZ);
				if self.scaleX + self.scale <= 0.95 then
					self.scale = 0.05;
                end;
            end;
        end;
    end;
end;

function InteractiveComponentInterface:draw()
    --if self.isActive then
		if self.isMouseOver then
            if self.isOpen then
				g_currentMission:addExtraPrintText(string.format(self.offMessage, self.name));
			else
				g_currentMission:addExtraPrintText(string.format(self.onMessage, self.name));
            end;
        end;
    --end;
end;

function InteractiveComponentInterface:doAction(forceValue)
    if forceValue ~= nil then
        self.isOpen = forceValue;
    else
        self.isOpen = not self.isOpen;
    end;
end;

function InteractiveComponentInterface:onEnter()
    self.isMouseOver = true;
end;

function InteractiveComponentInterface:onExit()
    self.isMouseOver = false;
end;

function InteractiveComponentInterface:setActive(isActive)
    self.isActive = isActive;
end;

function InteractiveComponentInterface:setVisible(isVisible)
    if self.mark ~= nil then
        setVisibility(self.mark, isVisible);
    end;
end;