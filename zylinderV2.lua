-- Zylinder
-- Spezi für einfache Hydraulikzylinder oder Zylinder aller Arten
-- Ebenfalls sind einfache setDirections möglich

-- V2 Rotations die von einem Objekt ausgehend die Bewegung auf ein anderes übertragen sind nun auch möglich.
-- Damit kann man nun die komplette Animation einer Lenkung oder einer Heckhydraulik hierüber laufen lassen!

-- by modelleicher
-- www.schwabenmodding.bplaced.net


zylinderV2 = {};

function zylinderV2.prerequisitesPresent(specializations)
    return true;
end;

function zylinderV2:load(savegame)

	self.zylinderCount = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.ZylinderV2.Zylinder#count"), 0);
	self.zylinder = {};	
	if self.zylinderCount ~= 0 then
		for i=1, self.zylinderCount do
			local zyl = {};
			local path = string.format("vehicle.ZylinderV2.Zylinder.Zylinder%d", i);
			zyl.dir1 = Utils.indexToObject(self.components, getXMLString(self.xmlFile, path .. "#dir1"));
			zyl.dir2 = Utils.indexToObject(self.components, getXMLString(self.xmlFile, path .. "#dir2"));
			table.insert(self.zylinder, zyl);
		end;
	end;
	
	self.rotationsCount = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.ZylinderV2.Rotations#count"), 0);
	self.rotations = {};
	if self.rotationsCount ~= 0 then
		for i=1, self.rotationsCount do
			local rot = {};
			local path = string.format("vehicle.ZylinderV2.Rotations.Rotation%d", i);
			rot.index = Utils.indexToObject(self.components, getXMLString(self.xmlFile, path .. "#index"));
			rot.ref = Utils.indexToObject(self.components, getXMLString(self.xmlFile, path .. "#ref"));
			rot.addDegrees = Utils.getNoNil(getXMLFloat(self.xmlFile, path .. "#addDegrees"), 0.0);
			rot.rotAxis = string.lower(Utils.getNoNil(getXMLString(self.xmlFile, path .. "#rotAxis"), "x"));
			rot.getRotAxis = string.lower(Utils.getNoNil(getXMLString(self.xmlFile, path .. "#getRotAxis"), "y"));
			rot.lengthMultiplicator = Utils.getNoNil(getXMLFloat(self.xmlFile, path .. "#lengthMultiplicator"), 1);
			table.insert(self.rotations, rot);
		end;
	end;
		
	self.directionsCount = Utils.getNoNil(getXMLInt(self.xmlFile, "vehicle.ZylinderV2.Directions#count"), 0);
	self.directions = {};
	if self.directionsCount ~= 0 then
		for i=1, self.directionsCount do
			local dir = {};
			local path = string.format("vehicle.ZylinderV2.Directions.Direction%d", i);
			dir.index = Utils.indexToObject(self.components, getXMLString(self.xmlFile, path .. "#index"));
			dir.ref = Utils.indexToObject(self.components, getXMLString(self.xmlFile, path .. "#ref"));
			dir.doScaleBool = Utils.getNoNil(getXMLBool(self.xmlFile, path .. "#doScaleBool"));
			if dir.doScaleBool == true then
				dir.scaleRef = Utils.indexToObject(self.components, getXMLString(self.xmlFile, path .. "#scaleRef"));			
				ax, ay, az = getWorldTranslation(dir.index);
				bx, by, bz = getWorldTranslation(dir.scaleRef);
				dir.scaleDistance = Utils.vector3Length(ax-bx, ay-by, az-bz);	
			end;
			table.insert(self.directions, dir);
		end;
	end;
end;

function zylinderV2:delete()
end;
function zylinderV2:mouseEvent(posX, posY, isDown, isUp, button)
end;
function zylinderV2:keyEvent(unicode, sym, modifier, isDown)
end;
function zylinderV2:update(dt)	
	if self:getIsActive() then	
		if self.zylinderCount ~= 0 and self.zylinderCount ~= nil then
			for i=1, self.zylinderCount do
				if self.zylinder[i].dir1 ~= nil and self.zylinder[i].dir2 ~= nil then
				local ax, ay, az = getWorldTranslation(self.zylinder[i].dir1);
				local bx, by, bz = getWorldTranslation(self.zylinder[i].dir2);
				x, y, z = worldDirectionToLocal(getParent(self.zylinder[i].dir1), bx-ax, by-ay, bz-az);
				local upx, upy, upz = 0,1,0;
				if math.abs(y) > 0.99*Utils.vector3Length(x, y, z) then
					upy = 0;
					if y > 0 then
						upy = 1;
					else
						upy = -1;
					end;
				end;
				setDirection(self.zylinder[i].dir1, x, y, z, upx, upy, upz);
				local ax2, ay2, az2 = getWorldTranslation(self.zylinder[i].dir2);
				local bx2, by2, bz2 = getWorldTranslation(self.zylinder[i].dir1);
				x2, y2, z2 = worldDirectionToLocal(getParent(self.zylinder[i].dir2), bx2-ax2, by2-ay2, bz2-az2);
				local upx2, upy2, upz2 = 0,1,0;
				if math.abs(y2) > 0.99*Utils.vector3Length(x, y, z) then
					upy2 = 0;
					if y2 > 0 then
						upy2 = 1;
					else
						upy2 = -1;
					end;
				end;
				setDirection(self.zylinder[i].dir2, x2, y2, z2, upx, upy, upz); 
				end;
			end;
		end;
		if self.rotationsCount ~= 0 and self.rotationsCount ~= nil then
			for i=1, self.rotationsCount do
				if self.rotations[i].index ~= nil and self.rotations[i].ref ~= nil then
					local rx, ry, rz = getRotation(self.rotations[i].ref);
					local rw = 0;
					if self.rotations[i].getRotAxis == "y" then -- ask first for y because it is the most used in this case (for performance reasons)
						rw = ry*self.rotations[i].lengthMultiplicator;
					elseif self.rotations[i].getRotAxis == "x" then
					    rw = rx*self.rotations[i].lengthMultiplicator;
					elseif self.rotations[i].getRotAxis == "z" then
						rw = rz*self.rotations[i].lengthMultiplicator;
					end;
					if self.rotations[i].rotAxis == "x" then -- ask first for x because it is the most used in this case(for performance reasons)
						setRotation(self.rotations[i].index, rw+Utils.degToRad(self.rotations[i].addDegrees), 0, 0);
					elseif self.rotations[i].rotAxis == "y" then
						setRotation(self.rotations[i].index, 0, rw+Utils.degToRad(self.rotations[i].addDegrees), 0);
					elseif self.rotations[i].rotAxis == "z" then
						setRotation(self.rotations[i].index, 0, 0, rw+Utils.degToRad(self.rotations[i].addDegrees));
					end;
				end;
			end;
		end;
		if self.directionsCount ~= 0 and self.directionsCount ~= nil then
			for i=1, self.directionsCount do
				if self.directions[i].index ~= nil and self.directions[i].ref ~= nil then
					local ax, ay, az = getWorldTranslation(self.directions[i].index);
					local bx, by, bz = getWorldTranslation(self.directions[i].ref);
					x, y, z = worldDirectionToLocal(getParent(self.directions[i].index), bx-ax, by-ay, bz-az);
					local upx, upy, upz = 0,1,0;
					if math.abs(y) > 0.99*Utils.vector3Length(x, y, z) then
						upy = 0;
						if y > 0 then
							upy = 1;
						else
							upy = -1;
						end;
					end;
					setDirection(self.directions[i].index, x, y, z, upx, upy, upz);
					if self.directions[i].doScaleBool == true and self.directions[i].scaleRef ~= nil then
						local distance = Utils.vector3Length(ax-bx, ay-by, az-bz);
						local scaleX, scaleY, scaleZ = getScale(self.directions[i].index);
						local setScaleWert = scaleZ * (distance / self.directions[i].scaleDistance);
						setScale(self.directions[i].index, 1, 1, setScaleWert);
					end;
				end;
			end;
		end;
    end; 
end;

function zylinderV2:draw()
end;
