NoBG = class('NoBG', Entity)
function NoBG:initialize(params)
	self.x = 0
	self.y = 0
	Entity.initialize(self, params)
end
function NoBG:update(dt)
end
function NoBG:draw()
end
return NoBG
