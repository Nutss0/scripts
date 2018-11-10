AnimalPedestrian = {};
AnimalPedestrian_mt = Class(AnimalPedestrian, Object);

function AnimalPedestrian.onCreate(id)
    local object = AnimalPedestrian:new(g_server ~= nil, g_client ~= nil);
	g_currentMission:addOnCreateLoadedObject(object);
    object:load(id);
	object:register(true);
end

function AnimalPedestrian:new(isServer, isClient, customMt)
    if customMt == nil then
        customMt = AnimalPedestrian_mt;
    end
    local self = Object:new(isServer, isClient, AnimalPedestrian_mt);
    return self;
end;

AnimalPedestrian.curModDir = g_currentModDirectory;
function AnimalPedestrian:load(id)
	self.spline = id;
	self.splineLength = getSplineLength(self.spline);
	local i3dFilename = AnimalPedestrian.curModDir..getUserAttribute(id, "i3dFilename");
	if fileExists(i3dFilename) then
		local animalRoot = Utils.loadSharedI3DFile(i3dFilename);
		self.skeletonId = getChildAt(animalRoot, 0);
		self.graphId = getChildAt(animalRoot, 1);
		self.PRTG = createTransformGroup("PedestrianRoot");
		link(self.PRTG, self.skeletonId);
		link(getRootNode(), self.graphId);
		delete(animalRoot);
		self.clipDistance = Utils.getNoNil(getUserAttribute(id, "playClipDistance"), 200);
		self.animCharSet = getAnimCharacterSet(self.skeletonId);
		if self.animCharSet ~= 0 then
			self.isEnabled = true;
			local clips = getUserAttribute(id, "clips");
			self.clips = Utils.splitString(" ", clips);
			local walkClips = getUserAttribute(id, "walkClips");
			self.walkTracks = Utils.splitString(" ", walkClips);
			for i=1, #self.walkTracks do
				self.walkTracks[i] = tonumber(self.walkTracks[i]);
			end;
			self.numTracks = 0;
			for i=1, #self.clips do
				local clip = getAnimClipIndex(self.animCharSet, self.clips[i]);
				if clip > -1 then
					assignAnimTrackClip(self.animCharSet, i, clip);
					setAnimTrackLoopState(self.animCharSet, i, true);
					setAnimTrackSpeedScale(self.animCharSet, i, 1);
					self.numTracks = self.numTracks + 1;
				else
					print("AnimalPedestrian: clip "..self.clips[i].." not found");
				end;
			end;
			self.activeTrack = 1; self.nextTrack = 1;
			self.timer1 = 0;
			self.timer2 = 0;
			local soundFile = getUserAttribute(id, "soundFile");
			if soundFile then
				if string.find(soundFile, "data") == nil then
					soundFile = AnimalPedestrian.curModDir..soundFile;
				end;
				self.sound = createAudioSource("AS", soundFile, 30, 15, 1, 10000);
				local sample = getAudioSourceSample(self.sound);
				self.soundDuration = getSampleDuration(sample);
				link(getRootNode(), self.sound);
				setVisibility(self.sound, false);
			end;
			self.soundTimer = math.random(15000, 60000);
			self.splinePosition = 0;
		end;
		setVisibility(self.graphId, false);
		local numChild = getNumOfChildren(id);
		if numChild > 0 then
			local childId = getChildAt(id, 0);
			local object = AnimalPedestrian:new(g_server ~= nil, g_client ~= nil);
			g_currentMission:addOnCreateLoadedObject(object);
			object:load(childId);
			object:register(true);
			object.parent = self;
		end;
	else
		print("AnimalPedestrian: can't find "..i3dFilename);
	end;
	return true;
end;

function AnimalPedestrian:delete()
	if self.PRTG then
		delete(self.graphId);
		delete(self.skeletonId);
	end;
	AnimalPedestrian:superClass().delete(self);
end;

function AnimalPedestrian:readStream(streamId, connection)
end

function AnimalPedestrian:writeStream(streamId, connection)
end;

function AnimalPedestrian:update(dt)
	if self.isEnabled then
		local cam = getCamera();
		local cx, cy, cz = getWorldTranslation(cam);
		local x,y,z = getSplinePosition(self.spline, self.splinePosition);
		local distance = Utils.vector3Length(x-cx, y-cy, z-cz);
		if distance > self.clipDistance then
			if getVisibility(self.graphId) then
				if not g_currentMission.environment.currentRain == nil then
					setVisibility(self.graphId, true);
				end;
				if isAnimTrackEnabled(self.animCharSet, self.activeTrack) then
					disableAnimTrack(self.animCharSet, self.activeTrack);
				end;
				if isAnimTrackEnabled(self.animCharSet, self.nextTrack) then
					disableAnimTrack(self.animCharSet, self.nextTrack);
				end;
			elseif g_currentMission.environment.currentRain == nil	then
				setVisibility(self.graphId, true);
			end;
		end;
		if distance < self.clipDistance and getVisibility(self.graphId) then
			if not isAnimTrackEnabled(self.animCharSet, self.activeTrack) then
				enableAnimTrack(self.animCharSet, self.activeTrack);
			end;
			self.timer1 = self.timer1 - dt;
			if self.timer1 <= 0 then
				self.timer1 = math.random(5000, 15000);
				self.nextTrack = math.random(1, self.numTracks);
				enableAnimTrack(self.animCharSet, self.nextTrack);
			end;
			if self.nextTrack ~= self.activeTrack then
				self.timer2 = math.min(self.timer2 + 0.05, 1);
				setAnimTrackBlendWeight(self.animCharSet, self.nextTrack, self.timer2);
				if isAnimTrackEnabled(self.animCharSet, self.activeTrack) then
					local ATBW = 1 - getAnimTrackBlendWeight(self.animCharSet, self.nextTrack);
					setAnimTrackBlendWeight(self.animCharSet, self.activeTrack, ATBW);
				end;
				if self.timer2 == 1 then
					self.timer2 = 0;
					disableAnimTrack(self.animCharSet, self.activeTrack);
					setAnimTrackBlendWeight(self.animCharSet, self.activeTrack, 1);
					self.activeTrack = self.nextTrack;
				end;
			end;
			if self.walkTracks[self.activeTrack] > 0 or self.walkTracks[self.nextTrack] > 0 then
				local speed = self.walkTracks[self.activeTrack];
				if self.walkTracks[self.nextTrack] > self.walkTracks[self.activeTrack] then
					speed = Utils.clamp(self.walkTracks[self.nextTrack]*self.timer2, self.walkTracks[self.activeTrack], self.walkTracks[self.nextTrack]);
				elseif self.walkTracks[self.nextTrack] < self.walkTracks[self.activeTrack] then
					speed = math.max(self.walkTracks[self.activeTrack]*(1 - self.timer2), self.walkTracks[self.nextTrack]);
				end;
				local timeScale = (speed/3.6) / self.splineLength;
				if self.parent then
					self.splinePosition = self.parent.splinePosition;
				else
					self.splinePosition = self.splinePosition - 0.001*dt*timeScale;
				end;
			end;
			local x,y,z = getSplinePosition(self.spline, self.splinePosition);
			local rx,ry,rz = getSplineOrientation(self.spline, self.splinePosition, 0, -1, 0);
			setTranslation(self.PRTG, x, y, z);
			setRotation(self.PRTG, rx,ry,rz);
			if self.sound then
				self.soundTimer = self.soundTimer - dt;
				if self.soundTimer <= 0 then
					if getVisibility(self.sound) then
						setVisibility(self.sound, false);
						self.soundTimer = math.random(15000, 60000);
					else
						local x,y,z = getWorldTranslation(self.PRTG);
						setTranslation(self.sound, x, y, z);
						setVisibility(self.sound, true);
						self.soundTimer = self.soundDuration+500;
					end;
				end;
			end;
		end;
	end;
end;

function AnimalPedestrian:updateTick()
end;

g_onCreateUtil.addOnCreateFunction("AnimalPedestrian", AnimalPedestrian.onCreate);
