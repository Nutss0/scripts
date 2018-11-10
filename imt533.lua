--
-- Speciaziation class imt533
-- V1.0
-- @author Gregor96
-- @date 29/8/17
-- Copyright (C) OldTractorTeam, All Rights Reserved.





imt533 = {}

function imt533.prerequisitesPresent(specializations)
	
	AttacherJoints.registerJointType("imt_weight")

	return true
end;

function imt533:load(savegame)
	self.imt533_propelerAnim = getXMLString(self.xmlFile, "vehicle.propelerAnimation#animName")
	self.imt533_speedDivider = getXMLInt(self.xmlFile, "vehicle.propelerAnimation#speedDivider")

	if self.imt533_propelerAnim ~= nil and self.imt533_speedDivider ~= nil then
		self.imt533_initalized = true
	else
		self.imt533_initalized = false
	end
end

function imt533:delete()
end

function imt533:mouseEvent(posX, posY, isDown, isUp, button)
end

function imt533:keyEvent(unicode, sym, modifier, isDown)
end

function imt533:update(dt)
	
	if not self.imt533_initalized then
		return
	end

	if self:getIsMotorStarted() then
		self:playAnimation(self.imt533_propelerAnim, 
							self.motor.lastMotorRpm / self.imt533_speedDivider, 
							self:getAnimationTime(self.imt533_propelerAnim), 
							true)
	else
		self:stopAnimation(self.imt533_propelerAnim)
	end
end

function imt533:draw()
end