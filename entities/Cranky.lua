Cranky = class('Cranky',Entity)


--load costumes here
Costumes = {}
	--[[
	costume format changelog:
	0: restructure overlay, hat, tail, to use tables
	1: rename "overOverCranky" to "onTop"
	]]--
local costumeCurrentVersion = 1

function Cranky.newCostume()
	return {
		metadata = {
			version = costumeCurrentVersion,
			name = 'Name',
			desc = 'Description'
		},
		files = {
			images = {}
		}
	}

end
function Cranky.updateCostume(data)


	if not data.metadata.version then
		data.metadata.version = -1
	end

	local function tableize(d)
		if not d then return d end
		if d.layers then
			return helpers.copy(d.layers)
		else
			return {helpers.copy(d)}
		end
	end

	if data.metadata.version < 0 then
		data.metadata.version = 0
		data.hat = tableize(data.hat)
		data.overlay = tableize(data.overlay)
		data.tail = tableize(data.tail)
	end

	if data.metadata.version < 1 then
		data.metadata.version = 1
		if data.face then
			data.face.onTop = data.face.overOverCranky
			data.face.overOverCranky = nil
		end
	end

	return data

end

local costumePaths = {}
local isWorkshop = {}

local function findFiles(dir,workshop)
	local files = love.filesystem.getDirectoryItems(dir)
	for i,v in ipairs(files) do
		local path = dir..v..'/'
		local info = love.filesystem.getInfo(path)
		if info.type == 'directory' then
			if love.filesystem.exists(path..'costume.json') then
				table.insert(costumePaths,{name = v, path = path})
				isWorkshop[v] = workshop
			else
				findFiles(path)
			end
		end
	end
end

function Cranky.loadCostumeImages(data,path,errorDescription)
	local success = true

	local files = {}
	if data.files.images then
		for i,v in ipairs(data.files.images) do
			local imageSuccess = pcall(function ()
				files[v] = love.graphics.newImage(path..v..'.png')
			end)
			if not imageSuccess then
				errorDescription = loc.get('costumeErrorImage',{v..'.png'})
				success = false
			end
		end
	end
	if love.filesystem.exists(path..'preview.png') then
		data.preview = love.graphics.newImage(path..'preview.png')
	else
		data.preview = sprites.costumes.previewbase
	end

	data.loadedFiles = files

	return success,data,errorDescription
end


findFiles('costumes/')

for costumeI, costumePath in ipairs(costumePaths) do
	local name, path = costumePath.name, costumePath.path

	--print('loading costume '.. name)
	local data = dpf.loadJson(path..'costume.json')
	local files = {}
	if data.files.images then
		for i,v in ipairs(data.files.images) do
			files[v] = love.graphics.newImage(path..v..'.png')
		end
	end
	if love.filesystem.exists(path..'preview.png') then
		data.preview = love.graphics.newImage(path..'preview.png')
	end

	data.loadedFiles = files
	Costumes[name] = Cranky.updateCostume(data)


end

function Cranky:reloadCustomCostumes()
	local customCostumeList = {}
	--print('!!!!!!!reloading custom costumes!!!!!!!!')
	costumePaths = {}
	if not love.filesystem.getInfo('Custom Costumes','directory') then
		love.filesystem.createDirectory('Custom Costumes')
	end
	findFiles('Custom Costumes/')

	if project.mountedWorkshop then
		findFiles('Workshop/',true)
	end

	for costumeI, costumePath in ipairs(costumePaths) do
		local name, path = costumePath.name, costumePath.path
		table.insert(customCostumeList,name)
		--print('loading costume '.. name)
		local errorDescription = ''
		local errorPreventLoad = nil
		local success, data = pcall(function ()
			return dpf.loadJson(path..'costume.json')
		end)
		if success then
			success,data,errorDescription = Cranky.loadCostumeImages(data,path,errorDescription)
		else
			errorDescription = loc.get('costumeErrorJson')
			errorPreventLoad = true
		end

		if success then
			data.metadata = data.metadata or {name = 'MISSING NAME', desc = 'MISSING DESC'}
			data.metadata.name = data.metadata.name or 'MISSING NAME'
			data.metadata.desc = data.metadata.desc or 'MISSING DESC'
			Costumes[name] = Cranky.updateCostume(data)
		else
			if errorPreventLoad then
				Costumes[name] = {
					metadata = {
						name = name,
						desc = errorDescription,
					},
					errorPreventLoad = errorPreventLoad,

					preview = sprites.costumes.errorpreview
				}
			else
				data.metadata = {
					name = name,
					desc = errorDescription
				}
				data.preview = sprites.costumes.errorpreview
				Costumes[name] = data
			end
		end
		Costumes[name].isWorkshop = isWorkshop[name]
		Costumes[name].isCustom = true
		Costumes[name].path = path

	end
	Costumes.customCostumeList = customCostumeList
end





Cranky:reloadCustomCostumes()

function Cranky:initialize(params)

  self.layer = 0
  self.uCranky = 0
  self.batchOutline = false --there's only ever one cranky, and we need to be able to dither.

	--[[
  self.spr = {
    idle = sprites.Cranky.idle,
    happy = sprites.Cranky.happy,
    miss = sprites.Cranky.miss,
		angry = sprites.Cranky.angry
  }
	self.spr[':3'] = sprites.Cranky.colonthree
	self.spr['><'] = sprites.Cranky.eyesclosed
	]]--

	self.canvas = love.graphics.newCanvas(project.res.x,project.res.y)

	self.spr = {}
	self.faceIndex = {
		idle = 0,
		miss = 1,
		happy = 2,
		angry = 3
	}
	self.faceIndex[':3'] = 4
	self.faceIndex['><'] = 5


  self.x=self.x or 0
  self.y=self.y or 0
  self.time=0
  self.angle = 0
  self.extend = 0
	self.drawScale = 1
  self.outlineColor = 1
  self.fillColor = 0
	self.faceColor = -1
  self.cEmotion = "idle"
  self.emoTimer = 0
  self.paddleCount = 1
	self.paddleDistance = 31
	self.lightRad = 64
	self.disableCostume = false

  -- new paddle handling.
  -- why do i do this

  self.paddles = {}
  table.insert(self.paddles, self:newPaddle()) -- Adds default paddle

	for i=1, 7 do
		table.insert(self.paddles, self:newPaddle(false))
	end

  self.lookRadius = 6
	self.lookAngle = 0
  self.maxBodyPulse = 0.2
	self.bodyRadius = 20
  self.bodyPulse = 0
  self.ouchTime = 15
	self.forceSprite = ''
	self.useFaceStencil = false
	self.lineWidth = 2
	self.circleX = 0
	self.circleY = 0
	self.snapX = 0
	self.snapY = 0
	self.angleHistory = {}

	--feedback stuff

	if self.feedbackTween then self.feedbackTween:stop() end
	self.feedbackTween = nil
	self.feedbackAmplitude = 2.5
	self.feedbackDuration = 4
	self.feedbackEase = 'outQuad'

	self.feedbackOffset = 0

	--self.arcTooBigTimer = 0
	--self.arcTooSmallTimer = 0
	self.transitionTween = nil

	self.unpauseCooldown = 0

	local costumeUnlocks = UnlockManager.checkCostumeUnlocks(Costumes)
	local unlockedCostumeList = {}
	local excludeFromRandomCostumes = {"_customCostumes", "_defaultCostumes", "_createCostume", "random", "none", "invisible"}

	local function containedInExcludeList(name)
		for _,v in ipairs(excludeFromRandomCostumes) do
			if name == v then
				return true
			end
		end
		return false
	end

	for i,v in pairs(costumeUnlocks) do
		if (v == true) and (not containedInExcludeList(i)) then
			table.insert(unlockedCostumeList, i)
		end
	end

	self.randomCostume = unlockedCostumeList[math.random(#unlockedCostumeList)]

  Entity.initialize(self,params)
end

function Cranky:getDistance()
	return self.paddles[1].paddleWidth + self.paddleDistance + self.extend + cs.noteRadius - 1
end

function Cranky:doPaddleFeedback(inverse)
	if self.feedbackTween then self.feedbackTween:stop() end

	self.feedbackOffset = self.feedbackAmplitude * -1
	if inverse then
		self.feedbackOffset = self.feedbackAmplitude
	end

	self.feedbackTween = flux.to(self,self.feedbackDuration,{feedbackOffset = 0}):ease(self.feedbackEase)
end


function Cranky:doEyeControls(costume)
	local lookRadius = self.lookRadius
	if costume and costume.face and costume.face.lookRadiusMultiplier then
		lookRadius = lookRadius * costume.face.lookRadiusMultiplier
	end
	local eyex = (lookRadius) * math.cos((self.lookAngle - 90) * math.pi / 180)
	local eyey = (lookRadius) * math.sin((self.lookAngle - 90) * math.pi / 180)
	return eyex, eyey
end


function Cranky:hurtPulse()
  self.bodyPulse = self.maxBodyPulse
  flux.to(self,self.ouchTime,{bodyPulse=0}):ease("outSine")
end

function Cranky:newPaddle(enabled, width, size, baseAngle)

	local paddleID = #self.paddles

	if enabled == nil then
		enabled = true
	end

	width = width or 11
	size = size or 70
	local sizePrevFrame = size
	baseAngle = baseAngle or 0
	local handleSize = 10

	return {paddleID = paddleID, enabled = enabled, paddleWidth = width, paddleSize = size, paddleSizePrevFrame = sizePrevFrame, baseAngle = baseAngle, handleSize = handleSize}
end

function Cranky:update(dt)
    prof.push("Cranky update")

    -- Keep animation timers
    self.angle = self.angle % 360
    self.emoTimer = self.emoTimer - dt
    if self.emoTimer <= 0 then
        self.cEmotion = "idle"
    end

    -- Keep previous angle for delta calculations
    self.anglePrevFrame = self.anglePrevFrame or self.angle
    self.angleDelta = helpers.angdelta(self.anglePrevFrame, (self.angle + 360) % 360)
    if self.cumulativeAngle then
        self.cumulativeAngle = self.cumulativeAngle + self.angleDelta
    else
        self.cumulativeAngle = self.angle
    end

    self.time = self.time + dt

    prof.pop("Cranky update")
end


function Cranky:savePaddleSize() --paddle size needs to be saved *before* eases are run, so we'll run it outside of update()
	for i = 1, #self.paddles do
		self.paddles[i].paddleSizePrevFrame = self.paddles[i].paddleSize
	end
end


function Cranky:getCostume()
	--Eventually if we want to do something like having multiple costumes at once, we can handle
	--that in this function.
	--for now we can just return the single costume we are using. -DPS
	if self.forceCostume then
		if type(self.forceCostume) == 'string' then
			return Costumes[self.forceCostume]
		else
			return self.forceCostume
		end
	end
	if self.disableCostume then return {} end
    if savedata.costumes.currentCostume == "random" then
        return Costumes[self.randomCostume]
    end
	return Costumes[savedata.costumes.currentCostume] or {}
end


function Cranky:getCostumeFile(costume,image)
	return costume.loadedFiles[image] or sprites.costumes.defaultImage
end

function Cranky:drawHat(costume,hat)

	if not hat then return end

	love.graphics.push()
	love.graphics.setStencilTest('notequal',3)
		--todo: make a getFinalRadius function or smth
		color()
		local rotationInfluence = hat.rotationInfluence or 15
		local r = rotationInfluence * math.cos((self.angle - 90) * math.pi / 180) * -1

		local radius = math.abs(self.bodyRadius+self.extend/2+(math.sin(self.time*0.03))/2)
		--you may ask yourself, why the math.abs?
		--because some FREAKS (positive) figured out you can get a cool octagonal cranky by giving him a negative body radius
		--so now i guess i have to account for that!
		local hatImage = self:getCostumeFile(costume,hat.image)
		love.graphics.translate(self.x,self.y)
		local bodyPulseScale = (1 + self.bodyPulse) *self.drawScale
		local hatScale = 1
		local yOffset = (hat.yOffset or 0) + radius
		if hat.scaled then
			hatScale = radius / 20
			yOffset = hat.yOffset
		end
		love.graphics.scale(bodyPulseScale)
		wbRecolor(self.fillColor,self.outlineColor)
			love.graphics.draw(
				hatImage, 0, 0,
				math.rad(r), hatScale, hatScale,
				hat.xOffset, yOffset
			)
		wbRecolor()

	love.graphics.setStencilTest()
	love.graphics.pop()

end

function Cranky:drawOverlay(costume,overlay)

	if not overlay then return end

	love.graphics.push()
	love.graphics.setStencilTest('notequal',3)
		--todo: make a getFinalRadius function or smth
		color()
		--local r = -15 * math.cos((self.angle - 90) * math.pi / 180)

		local bobMultiplier = overlay.bobMultiplier or 1
		local scaleInsteadOfBob = overlay.scaleInsteadOfBob or false
		local radiusMultiplier = overlay.radiusMultiplier or 1
		local rotationSpeed = overlay.rotationSpeed or 0
		local pivotAngle = overlay.pivotAngle or 0
		local baseRadius = self.bodyRadius
		if overlay.noRadiusScale then
			baseRadius = 20
		end
		local radius = math.abs(baseRadius+self.extend/2+(math.sin(self.time*0.03)*bobMultiplier)/2) * radiusMultiplier

		love.graphics.translate(self.x,self.y)
		local bodyPulseScale = (1 + self.bodyPulse) *self.drawScale
		love.graphics.scale(bodyPulseScale)

		local rotation = self.time*0.00325*rotationSpeed

		local overlayImage = self:getCostumeFile(costume,overlay.image)

		local pivotMultiplier = overlay.pivotMultiplier or 1
		local pivotOffset = overlay.pivotOffset or 0

		local mode = overlay.mode or 'default'

		wbRecolor(self.fillColor,self.outlineColor)
		if mode == 'centerScaled' then

			local pivot = helpers.rotate(radius*pivotMultiplier+pivotOffset, pivotAngle,0,0)
			love.graphics.draw(
				overlayImage, pivot[1], pivot[2],
				rotation, radius/20, radius/20,
				(overlay.xOffset or 0), (overlay.yOffset or 0)
			)
		else --default
			if scaleInsteadOfBob then
				local CrankyRadiusMultiplier = (self.bodyRadius+self.extend/2)/self.bodyRadius
				local r1 = math.abs(self.bodyRadius) * radiusMultiplier
				local r2 = (math.sin(self.time*0.03)*bobMultiplier)/20

				local pivot = helpers.rotate(r1*pivotMultiplier+pivotOffset, pivotAngle,0,0)
				love.graphics.draw(
					overlayImage, pivot[1], pivot[2],
					rotation, CrankyRadiusMultiplier+r2, CrankyRadiusMultiplier+r2,
					overlay.xOffset, (overlay.yOffset or 0)
				)
			else
				local pivot = helpers.rotate(radius*pivotMultiplier+pivotOffset, pivotAngle,0,0)
				love.graphics.draw(
					overlayImage, pivot[1], pivot[2],
					rotation, 1, 1,
					overlay.xOffset, (overlay.yOffset or 0)
				)
			end
		end
		wbRecolor()


	love.graphics.setStencilTest()
	love.graphics.pop()

end

function Cranky:drawTail(costume,tail)

	if not tail then return end

	if tail.bunny then
		love.graphics.push()

		love.graphics.translate(self.x,self.y)
		local bodyPulseScale = (1 + self.bodyPulse) *self.drawScale
		love.graphics.scale(bodyPulseScale)
		local r = -15 * math.cos((self.angle - 90) * math.pi / 180)
		local x = r
		local y =10
		color(self.fillColor)
		love.graphics.circle("fill",x,y,8)
		color(self.outlineColor)
		love.graphics.circle("line",x,y,8)

		love.graphics.pop()
	end


	if tail.image then

		love.graphics.push()
		love.graphics.translate(self.x,self.y)
		local bodyPulseScale = (1 + self.bodyPulse) *self.drawScale
		love.graphics.scale(bodyPulseScale)
		local r = -15 * (tail.moveMult or 1) * math.cos((self.angle - 90) * math.pi / 180)
		local scaleFlip = (not tail.lockScale) and -math.cos((self.angle - 90) * math.pi / 180) or 1
		local x = r
		local y =10
		color(self.fillColor)

		local tailImage = self:getCostumeFile(costume,tail.image)

		wbRecolor(self.fillColor,self.outlineColor)
			love.graphics.draw(tailImage, x + (tail.xOffset or 0), y + (tail.yOffset or 0), 0, scaleFlip, 1, 0, tailImage:getHeight())
		wbRecolor()
		love.graphics.pop()

	end



end

function Cranky:drawFace(costume)
	-- draw the eyes
	color()
	local white,black=0,1
	if self.faceColor ~= -1 then
		--color(self.faceColor)
		--love.graphics.setShader(shaders.recolor)
		if costume.body and costume.body.bodyInvert then
			black = self.outlineColor
			white = self.fillColor
		else
			black = self.faceColor
			white = self.fillColor
		end
	else
		--color()
	end
	if self.forceSprite ~= 'none' then
		local useFaceStencil = self.useFaceStencil or (costume.face and costume.face.useFaceStencil)

		if useFaceStencil then
			love.graphics.setStencilTest('equal',1)
		end

		-- determine x and y offsets of the eyes
		local eyex, eyey
		if costume.body and costume.body.bodyInvisible then
			eyex = 0
			eyey = math.sin(self.time*0.03)
		else
			eyex, eyey = self:doEyeControls(costume)
		end

		local emotion = self.cEmotion

		if self.forceSprite ~= '' then
			emotion = self.forceSprite
		end

		local faceSpr = self.spr[emotion]

		if not faceSpr then --draw face sprite from costume (or default)
			local faceAnimation = animations.crankyFace
			local forceFrame = nil
			local faceImage = faceAnimation.image
			if costume.face then
				faceImage = nil
				if costume.face.image then

					faceImage = self:getCostumeFile(costume,costume.face.image)
					if faceImage == sprites.costumes.defaultImage then
						forceFrame = 0
					end
				end

				if costume.face.lawrence then

					if self.faceColor == -1 then
						color(1)
					else
						color(self.faceColor)
					end
					love.graphics.circle('fill', eyex/2, eyey/2,6)
					love.graphics.setLineWidth(1)
					love.graphics.translate( eyex/2, eyey/2)
					love.graphics.rotate(self.time*0.04)


					love.graphics.ellipse('line',0,0,math.max(math.abs(math.sin(self.time*0.03)*12),1),12)
					love.graphics.rotate(self.time*-0.06)
					love.graphics.ellipse('line',0,0,math.max(math.abs(math.sin(self.time*0.02+1)*12),1),12)

				end
			end
			if faceImage then
				wbRecolor(white,black)
				faceAnimation:drawImage(faceImage,forceFrame or self.faceIndex[emotion],eyex, eyey,0,1,1,faceAnimation.width/2,faceAnimation.height/2)
				wbRecolor()
			end
		else
			wbRecolor(white,black)
			love.graphics.draw(faceSpr, eyex, eyey,0,1,1,faceSpr:getWidth()/2,faceSpr:getHeight()/2)
			wbRecolor()
		end
		if useFaceStencil then
			love.graphics.setStencilTest()
		end
	end
	if self.faceColor ~= -1 then
		love.graphics.setShader()
	end

end


function Cranky:drawAllTails(costume)
	if not costume.tail then return end
	for i,v in ipairs(costume.tail) do
		self:drawTail(costume,v)
	end
end

function Cranky:drawAllHats(costume,under)
	if not costume.hat then return end
	for i,v in ipairs(costume.hat) do
		if under == (v.underCranky or false) then
			self:drawHat(costume,v)
		end
	end
end

function Cranky:drawAllOverlays(costume,under)
	if not costume.overlay then return end
	for i,v in ipairs(costume.overlay) do
		if under == (v.underCranky or false) then
			self:drawOverlay(costume,v)
		end
	end
end

function Cranky:drawBody(costume, bodyShape, offset, fillColor, outlineColor, skipBody)
	-- adjusting x and y so they're unaffected by scaling
	local finalX = offset-- +self.x / bodyPulseScale
	local finalY = offset-- +self.y / bodyPulseScale

	local radius = self.bodyRadius+self.extend/2+(math.sin(self.time*0.03))/2

	local bodySegments = nil
	local paddleSegments = nil

	if costume.body then
		bodySegments = costume.body.bodySegments
		paddleSegments = costume.body.paddleSegments
	end

	fillColor = fillColor or self.fillColor
	outlineColor = outlineColor or self.outlineColor




	love.graphics.stencil(function()
	-- draw the circle
	local function drawCircle()
		love.graphics.setColorMask()
		if not skipBody then
			color(fillColor)
			love.graphics.circle("fill",finalX,finalY,radius,bodySegments)
		end
		color(outlineColor)
		love.graphics.circle("line",finalX,finalY,radius,bodySegments)
	end

	if bodyShape == "square" then
		love.graphics.setColorMask()
		if not skipBody then
			color(fillColor)
			love.graphics.rectangle("fill",finalX-0.85*radius,finalY-0.85*radius,1.7*radius,1.7*radius,radius/5,radius/5)
		end
		color(outlineColor)
		love.graphics.rectangle("line",finalX-0.85*radius,finalY-0.85*radius,1.7*radius,1.7*radius,radius/5,radius/5)
	elseif bodyShape == "spike" then
		local rotation = (self.time*0.00325) % (2 * math.pi)
		love.graphics.setColorMask()
		local vertexCount = 18
		local vertices = {}
		for i=0,(vertexCount/2-1) do
			table.insert(vertices, finalX+1.2*radius*math.cos(2*math.pi*2*i/vertexCount+rotation))
			table.insert(vertices, finalY+1.2*radius*math.sin(2*math.pi*2*i/vertexCount+rotation))
			table.insert(vertices, finalX+0.8*radius*math.cos(2*math.pi*(2*i+1)/vertexCount+rotation))
			table.insert(vertices, finalY+0.8*radius*math.sin(2*math.pi*(2*i+1)/vertexCount+rotation))
		end

		if not skipBody then
			local triangles = love.math.triangulate(vertices)
			color(fillColor)
			for i=1,#triangles do
				love.graphics.polygon("fill", triangles[i])
			end
		end

		color(outlineColor)
		love.graphics.polygon("line", vertices)
	elseif bodyShape == "triangle" then
		local rotation = math.rad(self.angle+30)
		local offset = 0.3
		radius = radius * 0.85
		love.graphics.setColorMask()
		if not skipBody then
		color(fillColor)
			love.graphics.polygon("fill",
				finalX+1.2*radius*math.cos(rotation-offset),finalY+1.2*radius*math.sin(rotation-offset),
				finalX+1.3*radius*math.cos(rotation-offset/2),finalY+1.3*radius*math.sin(rotation-offset/2),
				finalX+1.33*radius*math.cos(rotation),finalY+1.33*radius*math.sin(rotation),
				finalX+1.3*radius*math.cos(rotation+offset/2),finalY+1.3*radius*math.sin(rotation+offset/2),
				finalX+1.2*radius*math.cos(rotation+offset),finalY+1.2*radius*math.sin(rotation+offset),
				finalX+1.2*radius*math.cos(rotation+2*math.pi/3-offset),finalY+1.2*radius*math.sin(rotation+2*math.pi/3-offset),
				finalX+1.3*radius*math.cos(rotation+2*math.pi/3-offset/2),finalY+1.3*radius*math.sin(rotation+2*math.pi/3-offset/2),
				finalX+1.33*radius*math.cos(rotation+2*math.pi/3),finalY+1.33*radius*math.sin(rotation+2*math.pi/3),
				finalX+1.3*radius*math.cos(rotation+2*math.pi/3+offset/2),finalY+1.3*radius*math.sin(rotation+2*math.pi/3+offset/2),
				finalX+1.2*radius*math.cos(rotation+2*math.pi/3+offset),finalY+1.2*radius*math.sin(rotation+2*math.pi/3+offset),
				finalX+1.2*radius*math.cos(rotation+4*math.pi/3-offset),finalY+1.2*radius*math.sin(rotation+4*math.pi/3-offset),
				finalX+1.3*radius*math.cos(rotation+4*math.pi/3-offset/2),finalY+1.3*radius*math.sin(rotation+4*math.pi/3-offset/2),
				finalX+1.33*radius*math.cos(rotation+4*math.pi/3),finalY+1.33*radius*math.sin(rotation+4*math.pi/3),
				finalX+1.3*radius*math.cos(rotation+4*math.pi/3+offset/2),finalY+1.3*radius*math.sin(rotation+4*math.pi/3+offset/2),
				finalX+1.2*radius*math.cos(rotation+4*math.pi/3+offset),finalY+1.2*radius*math.sin(rotation+4*math.pi/3+offset))
		end
		color(outlineColor)
		love.graphics.polygon("line",
			finalX+1.2*radius*math.cos(rotation-offset),finalY+1.2*radius*math.sin(rotation-offset),
			finalX+1.3*radius*math.cos(rotation-offset/2),finalY+1.3*radius*math.sin(rotation-offset/2),
			finalX+1.33*radius*math.cos(rotation),finalY+1.33*radius*math.sin(rotation),
			finalX+1.3*radius*math.cos(rotation+offset/2),finalY+1.3*radius*math.sin(rotation+offset/2),
			finalX+1.2*radius*math.cos(rotation+offset),finalY+1.2*radius*math.sin(rotation+offset),
			finalX+1.2*radius*math.cos(rotation+2*math.pi/3-offset),finalY+1.2*radius*math.sin(rotation+2*math.pi/3-offset),
			finalX+1.3*radius*math.cos(rotation+2*math.pi/3-offset/2),finalY+1.3*radius*math.sin(rotation+2*math.pi/3-offset/2),
			finalX+1.33*radius*math.cos(rotation+2*math.pi/3),finalY+1.33*radius*math.sin(rotation+2*math.pi/3),
			finalX+1.3*radius*math.cos(rotation+2*math.pi/3+offset/2),finalY+1.3*radius*math.sin(rotation+2*math.pi/3+offset/2),
			finalX+1.2*radius*math.cos(rotation+2*math.pi/3+offset),finalY+1.2*radius*math.sin(rotation+2*math.pi/3+offset),
			finalX+1.2*radius*math.cos(rotation+4*math.pi/3-offset),finalY+1.2*radius*math.sin(rotation+4*math.pi/3-offset),
			finalX+1.3*radius*math.cos(rotation+4*math.pi/3-offset/2),finalY+1.3*radius*math.sin(rotation+4*math.pi/3-offset/2),
			finalX+1.33*radius*math.cos(rotation+4*math.pi/3),finalY+1.33*radius*math.sin(rotation+4*math.pi/3),
			finalX+1.3*radius*math.cos(rotation+4*math.pi/3+offset/2),finalY+1.3*radius*math.sin(rotation+4*math.pi/3+offset/2),
			finalX+1.2*radius*math.cos(rotation+4*math.pi/3+offset),finalY+1.2*radius*math.sin(rotation+4*math.pi/3+offset))
	elseif bodyShape == "invert" then
		love.graphics.setColorMask()
		local lineWidth = love.graphics.getLineWidth()
		if not skipBody then
			color(fillColor)
			love.graphics.circle("fill",finalX,finalY,radius+lineWidth/2,bodySegments)
			color(outlineColor)
			love.graphics.circle("line",finalX,finalY,radius+lineWidth/2,bodySegments)
			color(outlineColor)
			love.graphics.circle("fill",finalX,finalY,radius-lineWidth,bodySegments)
		else
			color(outlineColor)
			love.graphics.circle("line",finalX,finalY,radius+lineWidth/2,bodySegments)
		end
	elseif bodyShape == "blob" then
		local rotation = 20+(self.time*0.03)
		local function x(a,r)
			return finalX+(1+0.15*math.cos(101.138*r+(r+0.17892834)*rotation+0.41*(2+math.cos(1.1+rotation))))*radius*math.cos((a/11)*2*math.pi)
		end
		local function y(a,r)
			return finalY+(1+0.15*math.cos(92.317*r+(r+0.12384918)*rotation+0.67*(2+math.cos(rotation))))*radius*math.sin((a/11)*2*math.pi)
		end
		love.graphics.setColorMask()
		if not skipBody then
			color(fillColor)
			love.graphics.polygon("fill",
				x(0,1.1), y(0,1.3),
				x(1,1.3), y(1,0.9),
				x(2,0.7), y(2,1.1),
				x(3,1.2), y(3,1.3),
				x(4,1.0), y(4,1.2),
				x(5,1.0), y(5,0.8),
				x(6,0.9), y(6,1.4),
				x(7,1.4), y(7,1.0),
				x(8,1.1), y(8,0.7),
				x(9,0.8), y(9,0.9),
				x(10,1.1), y(10,1.0))
		end
		color(outlineColor)
		love.graphics.polygon("line",
			x(0,1.1), y(0,1.3),
			x(1,1.3), y(1,0.9),
			x(2,0.7), y(2,1.1),
			x(3,1.2), y(3,1.3),
			x(4,1.0), y(4,1.2),
			x(5,1.0), y(5,0.8),
			x(6,0.9), y(6,1.4),
			x(7,1.4), y(7,1.0),
			x(8,1.1), y(8,0.7),
			x(9,0.8), y(9,0.9),
			x(10,1.1), y(10,1.0))
	elseif bodyShape == "novena" then
		drawCircle()

		local function drawRhombus(mode, offset, radius)
			local x = finalX + offset
			local y = finalY + offset
			love.graphics.polygon(mode,
			x + (radius*math.cos(2*math.pi*1/6)), y - (radius*math.sin(2*math.pi*1/6)),
			x, y,
			x + (radius*math.cos(2*math.pi*1/2)), y - (radius*math.sin(2*math.pi*1/2)),
			x + (radius*math.cos(2*math.pi*1/3)), y - (radius*math.sin(2*math.pi*1/3)))
		end

		local offset = 0
		local rhombusRadius = 0.886 * radius

		color(outlineColor)
		drawRhombus("fill", offset, rhombusRadius)

	else
		drawCircle()
	end

	end,'replace',1,true)
end

function Cranky:drawToCanvas(costume, bodyShape, offset)
	local bodySegments = nil
	local paddleSegments = nil
	local redrawOutline = false
	if costume.body then
		bodySegments = costume.body.bodySegments
		paddleSegments = costume.body.paddleSegments
		redrawOutline = costume.body.redrawOutline
	end

	love.graphics.setLineWidth(self.lineWidth/self.drawScale)

	local paddleFeedbackPosition = helpers.rotate(self.feedbackOffset, self.angle,self.x,self.y)


	self:drawAllTails(costume)

	self:drawAllHats(costume,true)

	self:drawAllOverlays(costume,true)


	if bodyShape ~= "invisible" then
		for i = 1, #self.paddles, 1 do
			local p = self.paddles[i]
			if p.enabled then
				-- draw the paddle
				love.graphics.push()
				love.graphics.translate(paddleFeedbackPosition[1]+offset*self.drawScale,paddleFeedbackPosition[2]+offset*self.drawScale)
				love.graphics.rotate((self.angle - p.baseAngle - 90) * math.pi / 180)
				love.graphics.scale(self.drawScale)

				--HANDLE
				--fill in handle
				color(self.fillColor)
				local tempPaddleDistance = self.paddleDistance

				if i <= 1 then
					if p.paddleSize < 20 and p.handleSize > 0.5*p.paddleSize then
							p.handleSize = math.floor(p.paddleSize/2)
					elseif p.paddleSize >= 20 and p.handleSize < 10 then
							p.handleSize = 10
					end

					local dist = tempPaddleDistance + self.extend + p.paddleWidth * 0.5
					local x1 = dist * math.cos(p.handleSize * math.pi / 180)
					local y1 = dist * math.sin(p.handleSize * math.pi / 180)
					local x2 = dist * math.cos(-p.handleSize * math.pi / 180)
					local y2 = dist * math.sin(-p.handleSize * math.pi / 180)
					love.graphics.stencil(function()
						love.graphics.setColorMask( )
						love.graphics.polygon('fill', 0, 0, x1, y1, x2, y2)
						color(self.outlineColor)
						-- draw handle lines
						love.graphics.line(0, 0, x1, y1)
						love.graphics.line(0, 0, x2, y2)
					end,'replace',2,true)
				end


				--PADDLE
				local paddleAngle = helpers.clamp(p.paddleSize,0,360) / 2
				local paddlePoly = {}
				local segments = 10 + math.max(0, math.floor((paddleAngle-90) / 5)) -- number of segments to draw the paddle with
				if paddleSegments then
					segments = paddleSegments
				end
				local function addVert(pos)
					table.insert(paddlePoly,pos[1])
					table.insert(paddlePoly,pos[2])
				end
				for i=0,segments-1 do
					addVert(helpers.rotate((self.paddleDistance + self.extend), helpers.lerp(paddleAngle, -paddleAngle, i/(segments-1))+90, 0, 0))
				end

				for i=0,segments-1 do
					addVert(helpers.rotate((self.paddleDistance + self.extend)+ p.paddleWidth, helpers.lerp(paddleAngle, -paddleAngle, 1-i/(segments-1))+90, 0, 0))
				end

				love.graphics.stencil(function()
					love.graphics.setColorMask()
					color(self.fillColor)
					pcall(function()
						--quick hack to prevent gritted crash on mac, investigate further!
						for i,v in ipairs(love.math.triangulate(paddlePoly)) do
								love.graphics.polygon('fill',v)
						end

						color(self.outlineColor)
						love.graphics.polygon('line',paddlePoly)
					end)
				end,'replace',3,true)
				love.graphics.pop()
			end
		end
	end


	local bodyPulseScale = (1 + self.bodyPulse) *self.drawScale

	love.graphics.push()
		-- scaling circle and face for hurt animation

		love.graphics.translate(self.x,self.y)
		love.graphics.scale(bodyPulseScale)
		love.graphics.setLineWidth(self.lineWidth/bodyPulseScale)

		self:drawBody(costume, bodyShape, offset)

		local faceOnTop = costume.face and costume.face.onTop
		if not faceOnTop then
			self:drawFace(costume)
		end

		if redrawOutline then
			self:drawBody(costume,bodyShape,offset,nil,nil,true)
		end

	love.graphics.pop()
	self:drawAllHats(costume,false)
	self:drawAllOverlays(costume,false)
	if faceOnTop then
		love.graphics.push()
		love.graphics.translate(self.x,self.y)
		love.graphics.scale(bodyPulseScale)
		self:drawFace(costume)
		love.graphics.pop()
	end
end

function Cranky:draw()

	local oldCanvas = love.graphics.getCanvas()
	love.graphics.setCanvas({self.canvas,stencil=true})
	love.graphics.clear()

	local costume = self:getCostume()
	local bodyShape = "circle"
	local bodySegments = nil
	local paddleSegments = nil


	--to do: tear this all out, holy SHIT
	if costume.body then
		bodySegments = costume.body.bodySegments
		paddleSegments = costume.body.paddleSegments
		if costume.body.bodySquare then
			bodyShape = "square"
		elseif costume.body.bodySpike then
			bodyShape = "spike"
		elseif costume.body.bodyTriangle then
			bodyShape = "triangle"
		elseif costume.body.bodyInvert then
			bodyShape = "invert"
		elseif costume.body.bodyBlob then
			bodyShape = "blob"
		elseif costume.body.body2p5d then
			bodyShape = "2p5d"
		elseif costume.body.bodyNovena then
			bodyShape = "novena"
		elseif costume.body.bodyInvisible then
			bodyShape = "invisible"
		end
	end

	if bodyShape == "2p5d" then
		self:drawToCanvas(costume, "circle", 3)
		self:drawToCanvas(costume, "circle", 0)
	else
		self:drawToCanvas(costume, bodyShape, 0)
	end

	love.graphics.setCanvas({oldCanvas,stencil = true})
	local doDither = nil
	if cs.cBeat and cs.pauseBeat and cs.pauseBeat > cs.cBeat then
		doDither = 1
	end

	outline(function()
		color()
		love.graphics.draw(self.canvas)
	end, cs.outline,doDither)
	if cs.vfx then
		cs.vfx.darkness.addLight(self.x, self.y, self.lightRad)
	end
end

return Cranky