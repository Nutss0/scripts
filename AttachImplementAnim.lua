--
-- AttachImplementAnim
-- Class for animations when attaching implements
--
-- @author  PeterJ 
-- @date  26/09/2018
--
-- https://www.facebook.com/peterjMods/
--
-- Copyright (C) PeterJ, Confidential, All Rights Reserved.


AttachImplementAnim = {};

function AttachImplementAnim.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AttacherJoints, specializations) and SpecializationUtil.hasSpecialization(AnimatedVehicle, specializations);
end;

function AttachImplementAnim:load(saveGame)

end;

function AttachImplementAnim:postLoad(savegame)


	self.attachAnimations = {};
	local i = 0;
	while true do
		local key = string.format("vehicle.attacherJoints.attacherJoint(%d)", i);
		if not hasXMLProperty(self.xmlFile, key) then
			break;
		end;
		local attachAnims = {};
		local attachIndex = Utils.indexToObject(self.components, getXMLString(self.xmlFile, key.."#index"));
		if attachIndex == nil then
			break;
		end;
		attachAnims.animation = getXMLString(self.xmlFile, key.."#animName");
		
		table.insert(self.attachAnimations, attachAnims);
		i = i + 1;
	end;	
end;

function AttachImplementAnim:delete()
end;

function AttachImplementAnim:readStream(streamId, connection)
end;

function AttachImplementAnim:writeStream(streamId, connection)
end;

function AttachImplementAnim:mouseEvent(posX, posY, isDown, isUp, button)
end;

function AttachImplementAnim:keyEvent(unicode, sym, modifier, isDown)
end;

function AttachImplementAnim:update(dt)
end;

function AttachImplementAnim:updateTick(dt)
end;

function AttachImplementAnim:draw()
end;

function AttachImplementAnim:onAttachImplement(implement)
	
	local jointIndex = implement.jointDescIndex;
	for i, part in ipairs(self.attachAnimations) do
		if part.animation ~= nil then
			if jointIndex == i then
				self:playAnimation(part.animation, 1, nil, true);
			end;
		end;
	end;	
end;

function AttachImplementAnim:onDetachImplement(implementIndex)

	local implement = self.attachedImplements[implementIndex];
	local jointIndex = implement.jointDescIndex;
	for i, part in ipairs(self.attachAnimations) do
		if part.animation ~= nil then
			if jointIndex == i then
				self:playAnimation(part.animation, -1, nil, true);
			end;
		end;
	end;
end;