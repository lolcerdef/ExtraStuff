PublicoBG = class('PublicoBG', Entity)

function PublicoBG:initialize(params)
	self.layer = -99
	self.upLayer = -99
	self.x = 0
	self.y = 0
	self.uvdx = 0.05
	self.uvdy = -0.15
	self.showWall = true
	self.showBars = true
	self.barX = 0
	self.barY = 270
	self.barXScroll = 0
	self.barDx = -1
	self.barCount = 12
	self.baseBarHeight = 1
	self.barHeight = self.baseBarHeight
	self.barColor = 4
	
	self.spr = love.graphics.newImage("levels/Finished levels/publicocautivo/wallpaper.png")
	
	Entity.initialize(self, params)
	self.bars = em.init('PublicoBars', {dx = self.barDx, x = self.barX, y = self.barY, xScroll = self.barXScroll, barCount = self.barCount, barHeight = self.barHeight, color = self.barColor})
	self.bars.skipUpdate = true
	self.bars.skipRender = true
	self.tween = nil
end

function PublicoBG.onBeatHook(b)
	if b % 2 == 0 then
	else
		local bars = cs.bg.bars
		local minimum = -20
		local maximum = 180
		bars.barHeight = cs.bg.baseBarHeight
		for i=1,bars.barCount do
			bars.bars[i] = math.random(minimum,maximum)
		end
		local dur = 50
		if cs.bg.tween then cs.bg.tween:stop() end
		
		cs.bg.tween = flux.to(bars, dur, {barHeight = 0}):ease("outQuad")
	end
end

function PublicoBG:update(dt)
	
	self.scrollX = (self.scrollX or 0) + self.uvdx * dt * 5
	self.scrollY = (self.scrollY or 0) + self.uvdy * dt * 5
	
	self.bars:update(dt)
end

function PublicoBG:draw()
	color()
	if self.showWall then
		local iw, ih = self.spr:getDimensions()
		local w, h = love.graphics.getDimensions()

		self.scrollX = (self.scrollX or 0) % iw
		self.scrollY = (self.scrollY or 0) % ih

		for x = -iw, w + iw, iw do
			for y = -ih, h + ih, ih do
				love.graphics.draw(
					self.spr,
					x - self.scrollX,
					y - self.scrollY
				)
			end
		end
	end
	
	if self.showBars then
		self.bars:draw(dt)
	end
end

return PublicoBG
