Cranky = class('Cranky', Player)

function Cranky:initialize(params)
	self.lookAngle = 0
    Player.initialize(self,params)
end

function Cranky:update(dt)
    prof.push("Cranky update")
	
    self.angle = self.angle % 360
    self.emoTimer = self.emoTimer - dt
    if self.emoTimer <= 0 then
        self.cEmotion = "idle"
    end
	
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

function Cranky:doEyeControls()
    local eyex = (self.lookRadius) * math.cos((self.lookAngle - 90) * math.pi / 180)
	local eyey = (self.lookRadius) * math.sin((self.lookAngle - 90) * math.pi / 180)
	return eyex, eyey
end

return Cranky