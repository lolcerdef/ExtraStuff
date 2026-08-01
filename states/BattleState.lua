local st = Gamestate:new('BattleState')

function st:delayTurn(seconds, callback)
    flux.to({}, seconds, {}):oncomplete(callback)
end

local easiness = 1.9

function st:addEnemy(className, params)
    local enemy = em.init(className, params)
    table.insert(self.enemies, enemy)
    return enemy
end

function st:getLivingEnemies()
    local alive = {}
    for _, e in ipairs(self.enemies) do
        if not e.dead and e.hp > 0 then
            table.insert(alive, e)
        end
    end
    return alive
end

st:setInit(function(self, enemies, turnMessages)
	shuv.resetPal()
	shuv.pal[2] = {r= 205, g=205, b=205}
	shuv.pal[3] = {r= 255, g=52, b=50}
	shuv.pal[4] = {r= 224, g=227, b=0}
	shuv.pal[5] = {r= 44, g=255, b=57}
	shuv.pal[6] = {r= 0, g=222, b=229}
	shuv.pal[7] = {r= 63, g=38, b=255}
	shuv.showBadColors = true

	self.autoplay = true
	self.bg = cs.bg or em.init('MenuBackground')
	
	self.selectedIndex = 1
	
	self.cbg = em.init('cbackground')
	self.enemies = {}
	self.activeEnemy = nil
	
	for i = 1, #enemies do
		self:addEnemy(enemies[i][1], enemies[i][2])
	end
	
	self.cranky = em.init('Cranky')
	self.cranky.lookAngle = 50
	self.cranky.angle = 300
	self.cranky.defaultAngle = 300
	self.cranky.ogx = 200
	self.cranky.x = 200
	self.cranky.y = 180
	self.cranky.maxhp = 200
	self.cranky.maxsp = 100
	self.cranky.hp = 200
	self.cranky.sp = 100
	self.cranky.inventory = {}
	
	self.selectionColors = {{1,0.99,0,1}, {0,0.99,0,1}, {0,0,0.99,1}, {0.99,0,0,1}}
	self.crankyActions = require "Mods.ExtraStuff.actions.cranky"
	self.menu = helpers.copytable(self.crankyActions)
	
	st.turnMessages = turnMessages or {
		"..."
	}
	
	self.text = self.turnMessages[math.random(#self.turnMessages)]
	self.turnState = "player_turn"
	self.selectedEnemy = nil
	self.pendingAction = nil
	
	
	self.parry = {
		active = false,

		duration = 40,
		timer = 0,

		blockSize   = 0.18,
		parrySize   = 0.07,
		counterSize = 0.025,

		blockStart   = 0,
		parryStart   = 0,
		counterStart = 0,

		cursor = 0,
		enemySoundPlayed = false
	}

	self.isTimerBarVisible = false
	
	self:idleCranky()
	for i = 1, # self.enemies do
		self:playEnemyAnim(self.enemies[i], "startFight")
	end
	
	self.winanim = false
end)

function st:swapBackground(bgName)
    if self.bg then
        self.bg.delete = true
    end
    self.bg = em.init(bgName)
end

st:setUpdate(function(self, dt)
    self.bg:update(dt)
	
	if self.cranky.hp <= 0 then
		self.cranky.hp = 1
		self.menu = helpers.copytable(self.crankyActions)
		self.selectedIndex = 5
	end
	local alive = self:getLivingEnemies()
	if self.cranky.emoTimer > 0 and #alive>0 then
		self.cranky.x = self.cranky.ogx + math.sin(self.cranky.emoTimer * 40) * 2
	end
	
    -- player turn
    if self.turnState == "player_turn" then
        local function moveSelection(dir)
            local len = #self.menu
            local nextIndex = self.selectedIndex

            repeat
                nextIndex = nextIndex + dir
                if nextIndex < 1 then nextIndex = len end
                if nextIndex > len then nextIndex = 1 end
                if self.menu[nextIndex].displayCond(self) then
                    self.selectedIndex = nextIndex
                    break
                end
            until nextIndex == self.selectedIndex
        end
		
		if maininput:pressed("up") or maininput:pressed("down") or maininput:pressed("accept") then
			te.playOne(sounds.hold,"static",'sfx',0.5)
		end
        if maininput:pressed("up") then
            moveSelection(-1)
        elseif maininput:pressed("down") then
            moveSelection(1)
        elseif maininput:pressed("accept") and self.menu[self.selectedIndex].displayCond(self) then
			local action = self.menu[self.selectedIndex]
			if action.isMenu then
				self.menu = helpers.copytable(action.options)
				self.selectedIndex = 1
			elseif action.displayCond(self) then
				if action.selectEnemy then
					self.pendingAction = action
					self.selectedEnemy = 1
					self.turnState = "enemy_select"
					return
				else

					if action.exec then
						action.exec(self)
					end

					self.menu = helpers.copytable(self.crankyActions)
					self.turnState = "waiting"
					self:delayTurn(50, function()
						self.turnState = "enemy_turn"
						
					end)
				end
			end
        elseif maininput:pressed("back") then
            self.menu = helpers.copytable(self.crankyActions)
        end

    elseif self.turnState == "enemy_turn" then
		self.parry.counterSoundPlayed = false
		if #alive == 0 then
			self.text = "Victory."
			if not self.winanim then
				self.winanim = true
				self.cranky.emoTimer = 9999
				self.cranky.cEmotion = "happy"
				self.cranky.lookAngle = 90
				flux.to(self.cranky, 60, {ogx = 700, x = 700}) -- move Cranky to right offscreen
					:ease("inSine")
			end
			return
		end

		self.activeEnemy = alive[love.math.random(#alive)]

		-- pick attack from THAT enemy
		local keys = {}
		for k in pairs(self.activeEnemy.attacks) do
			table.insert(keys, k)
		end

		self.currentAttack = self.activeEnemy.attacks[keys[love.math.random(#keys)]]
		if self.currentAttack.sound then
			te.playOne(
				self.currentAttack.sound,
				"static",
				"sfx",
				1
			)
		end

		-- difficulty scaling
		self.parry.duration    = self.currentAttack.duration
		self.parry.blockSize   = (self.currentAttack.block or 0) * easiness
		self.parry.parrySize   = (self.currentAttack.parry or 0) * easiness
		self.parry.counterSize = (self.currentAttack.counter or 0) * easiness

		self.parry.timer = self.parry.duration
		self.parry.cursor = 0
		self.parry.active = true

		-- nested windows
		self.parry.blockStart = love.math.random() * (1 - self.parry.blockSize)
		if self.currentAttack.ptime then
			self.parry.blockStart = self.currentAttack.ptime/self.currentAttack.duration
		end
		self.parry.parryStart =
			self.parry.blockStart +
			love.math.random() * (self.parry.blockSize - self.parry.parrySize)
		self.parry.counterStart =
			self.parry.parryStart +
			love.math.random() * (self.parry.parrySize - self.parry.counterSize)

		self.isTimerBarVisible = true
		self.turnState = "enemy_attack"

		self.text = self.activeEnemy.name .. " uses " .. self.currentAttack.name .. "!"
	elseif self.turnState == "enemy_attack" and self.parry.active then
		local prevCursor = self.parry.cursor
	
		self.parry.timer = self.parry.timer - dt
		self.parry.cursor = 1 - (self.parry.timer / self.parry.duration)

		local c = self.parry.cursor
		local dmg = self.currentAttack.damage
		local counterStart = self.parry.counterStart
		local counterEnd   = counterStart + self.parry.counterSize

		local parryStart = self.parry.parryStart
		local parryEnd   = parryStart + self.parry.parrySize

		local blockStart = self.parry.blockStart
		local blockEnd   = blockStart + self.parry.blockSize
		
		if maininput:pressed("accept") then
			self.parry.active = false
			self.isTimerBarVisible = false

			if c >= counterStart and c <= counterEnd then
				self.text = "CRANKY COUNTERED!\n" .. math.floor(dmg*0.75) .. " damage dealt."
				te.playOne(sounds.click, "static", "sfx", 1)
				self.activeEnemy.hp = self.activeEnemy.hp - math.floor(dmg * 1.5)

				if self.activeEnemy.anim then
					self.activeEnemy:anim("hurt")
				end
				self.cranky.sp = helpers.clamp(self.cranky.sp + 25, 0, self.cranky.maxsp)
				self:playEnemyAnim(self.activeEnemy, "hurt")

			elseif c >= parryStart and c <= parryEnd then
				self.text = self.currentAttack.parryText or "CRANKY PARRIED!\nDamage negated."
				te.playOne(sounds.hold, "static", "sfx", 1)
				self.cranky.sp = helpers.clamp(self.cranky.sp + 15, 0, self.cranky.maxsp)
				self.cranky.sp = helpers.clamp(self.cranky.sp + 15, 0, self.cranky.maxsp)

			elseif c >= blockStart and c <= blockEnd then
				local reduced = math.floor(dmg * 0.4)
				self.text = "CRANKY BLOCKED!\n" .. reduced .. " health lost."
				te.playOne(sounds.barely,"static",'sfx',2)
				self.cranky.hp = math.max(self.cranky.hp - reduced, 0)
				self:playPlayerAnim("hurt")
				self.cranky.sp = helpers.clamp(self.cranky.sp + 5, 0, self.cranky.maxsp)
			else
				self.text = "CRANKY HIT!\n" .. dmg .. " health lost."
				te.playOne(sounds.mine,"static",'sfx',1)
				self.cranky.hp = math.max(self.cranky.hp - dmg, 0)
				self:playPlayerAnim("hurt")
				self.cranky.sp = helpers.clamp(self.cranky.sp -5, 0, self.cranky.maxsp)
			end

			self:delayTurn(40, function()
				
				self.turnState = "player_turn"
				self.text = self.turnMessages[math.random(#self.turnMessages)]
			end)
		end

		-- full hit
		if self.parry.timer <= 0 then
			self.parry.active = false
			self.isTimerBarVisible = false
			te.playOne(sounds.mine,"static",'sfx',2)
			self.text = "CRANKY HIT HARD!"
			self.cranky.hp = helpers.clamp(self.cranky.hp - dmg * 1.5, 0, self.cranky.maxhp)
			self:playPlayerAnim("hurt")
			self.cranky.sp = helpers.clamp(self.cranky.sp - 25, 0, self.cranky.maxsp)
			self:delayTurn(40, function()
				self.turnState = "player_turn"
				self.text = self.turnMessages[math.random(#self.turnMessages)]
			end)
		end
	elseif self.turnState == "enemy_select" then
		local enemies = self:getLivingEnemies()
		if #enemies == 0 then return end
		if #enemies == 1 then 
			self.selectedEnemy = 1
			maininput:forceInput("accept", 1)
		end

		if maininput:pressed("left") then
			self.selectedEnemy = self.selectedEnemy - 1
			if self.selectedEnemy < 1 then
				self.selectedEnemy = #enemies
			end
		elseif maininput:pressed("right") then
			self.selectedEnemy = self.selectedEnemy + 1
			if self.selectedEnemy > #enemies then
				self.selectedEnemy = 1
			end
		elseif maininput:pressed("back") then
			self.turnState = "player_turn"
			self.pendingAction = nil
			return
		elseif maininput:pressed("accept") then
			self.selectedEnemy = enemies[self.selectedEnemy]

			if self.pendingAction.exec then
				self.pendingAction.exec(self)
			end

			self.pendingAction = nil
			self.menu = helpers.copytable(self.crankyActions)

			self.turnState = "waiting"
			self:delayTurn(50, function()
				self.turnState = "enemy_turn"
			end)
		end
	end
end)

function st:idleCranky()
	if not self.playeranim then
		flux.to(self.cranky, 100, {angle = self.cranky.defaultAngle + 5, lookAngle = self.cranky.lookAngle - 5})
			:ease("inOutSine")
			:oncomplete(function()
				flux.to(self.cranky, 100, {angle = self.cranky.defaultAngle - 5, lookAngle = self.cranky.lookAngle + 5})
					:ease("inOutSine")
					:oncomplete(function()
						self:idleCranky()
					end)
			end)
	end
end

function st:playPlayerAnim(anim)
	self.playeranim = true
    if anim == "run" then
        self.cranky.emoTimer = 99999
        self.cranky.cEmotion = "><"
			
        flux.to(self.cranky, 25, {
            ogx = -100,
			angle = 500,
            lookAngle = -90
        })
        :ease("inCirc")
        :oncomplete(function()
			self.playeranim = false
            cs = bs.load('Menu')
            cs:init()
        end)

    elseif anim == "hurt" then
        self.cranky:hurtPulse()
        self.cranky.emoTimer = 15
        self.cranky.cEmotion = "miss"
		self.playeranim = false
    end
end

function st:playEnemyAnim(enemy, anim)
    if not enemy or not enemy.anim then return end

    enemy:anim(anim)
end

st:setBgDraw(function(self)
	love.graphics.setColor(1,1,1,1)
	love.graphics.rectangle("fill", 0,0,600,360)
end)

function st:drawOptions()
    local startX, startY = 62, 293
    local spacingY = 8
	
    love.graphics.setFont(fonts.action)

    local visibleIndex = 0
    for i, action in ipairs(self.menu) do
        if action.displayCond(self) then
            visibleIndex = visibleIndex + 1
            local xOffset = 0
			
            if i == self.selectedIndex and self.turnState == "player_turn" then
                xOffset = 7
                love.graphics.draw(sprites.fight.select, 62, 300 + (visibleIndex-1) * spacingY, 0, 1, 1, 0, 7)
                if action.isMenu and self.selectionColors[i] then
                    love.graphics.setColor(self.selectionColors[i])
                else
                    love.graphics.setColor(1, 0.99, 0, 1)
                end
            else
                love.graphics.setColor(1, 1, 1, 1)
            end

            love.graphics.print(action.display, startX + xOffset, startY + (visibleIndex-1)*spacingY)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

st:setFgDraw(function(self)
	love.graphics.draw(sprites.fight.border)
	
	love.graphics.setColor(0.99, 0, 0, 1)
	love.graphics.rectangle("fill", 31, 327, 64 * (self.cranky.hp/self.cranky.maxhp), 2)
	love.graphics.setColor(0, 0.99, 0, 1)
	love.graphics.rectangle("fill", 31, 331, 64 * (self.cranky.sp/self.cranky.maxsp), 2)
	love.graphics.setColor(1, 1, 1, 1)
	
	love.graphics.draw(sprites.fight.cardui, 20, 340, 0, 1, 1, 0, 63)
	
	if self.cranky.hp <= 10 then
		love.graphics.draw(sprites.fight.lowhealth, 20, 340, 0, 1, 1, 0, 63)
	else
		love.graphics.draw(sprites.fight.normal, 20, 340, 0, 1, 1, 0, 63)
	end
	
	love.graphics.draw(sprites.fight.diagboxui, 131, 340, 0, 1, 1, 0, 63)
	love.graphics.setFont(fonts.action)
	love.graphics.printf(self.text, 136, 292, 212, "left")
	
	--[[love.graphics.setFont(fonts.action)
	for i = 1, #self.selections do
		local selectoffset = 0
		local text = "DEBUG"
		if type(self.selections[i]) == "string" then
			text = self.selections[i]
		else
			text = self.selections[i].name
		end
		
		local yoffset =  (i - 1) * 8
		if i == self.selectedindex and self.selectAvailable then
			selectoffset = 7
			love.graphics.draw(sprites.fight.select, 20, 340 + yoffset, 0, 1, 1, 0, 63)
			if self.selections == self.defaultselections then
				love.graphics.setColor(self.selectionColors[i])
			else
				love.graphics.setColor(0, 1, 1, 1)
			end
		end
		
		love.graphics.print(text, 62 + selectoffset, 300 + yoffset - 7, 0, 1, 1)
		love.graphics.setColor(1, 1, 1, 1)
	end]]
	self:drawOptions()
	
	love.graphics.setFont(fonts.smallnums)
	local hp = string.format("%03d", self.cranky.hp)
	local sp = string.format("%03d", self.cranky.sp)
	
	love.graphics.print(hp .. "/" .. self.cranky.maxhp, 98, 327, 0, 1, 1)
	love.graphics.print(sp .. "/" .. self.cranky.maxsp, 98, 331, 0, 1, 1)
	
	if self.turnState == "enemy_select" then
		love.graphics.setFont(fonts.rpgtitle)
		local enemies = self:getLivingEnemies()
		for i, enemy in ipairs(enemies) do
			if i == self.selectedEnemy then
				love.graphics.draw(
					sprites.fight.select,
					enemy.x,
					enemy.y - 40,
					math.rad(90),
					2,
					2,
					3,
					3
				) --, 62, 300 + (visibleIndex-1) * spacingY, 0, 1, 1, 0, 7)
				color('white')
				local x, y = enemy.x-50, enemy.y - 60
				love.graphics.printf(enemy.name, x-1, y, 100, "center")
				love.graphics.printf(enemy.name, x+1, y, 100, "center")
				love.graphics.printf(enemy.name, x, y-1, 100, "center")
				love.graphics.printf(enemy.name, x, y+1, 100, "center")
				color('black')
				love.graphics.printf(enemy.name, x, y, 100, "center")
			end
		end
	end
	
	if self.isTimerBarVisible then
		local barX = 100
		local barY = 260
		local barW = 200
		local barH = 6

		love.graphics.setColor(0.15, 0.15, 0.15, 1)
		love.graphics.rectangle("fill", barX, barY, barW, barH)

		love.graphics.setColor(0.3, 0.6, 1, 1)
		love.graphics.rectangle(
			"fill",
			barX + barW * self.parry.blockStart,
			barY,
			barW * self.parry.blockSize,
			barH
		)

		love.graphics.setColor(1, 1, 0.2, 1)
		love.graphics.rectangle(
			"fill",
			barX + barW * self.parry.parryStart,
			barY,
			barW * self.parry.parrySize,
			barH
		)

		love.graphics.setColor(1, 0.3, 0.3, 1)
		love.graphics.rectangle(
			"fill",
			barX + barW * self.parry.counterStart,
			barY,
			barW * self.parry.counterSize,
			barH
		)

		love.graphics.setColor(1, 1, 1, 1)
		local cx = barX + barW * self.parry.cursor
		love.graphics.rectangle("fill", cx - 1, barY - 6, 2, barH + 12)

		love.graphics.setColor(1, 1, 1, 1)
	end
end)

return st