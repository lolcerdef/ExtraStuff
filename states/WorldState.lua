local st = Gamestate:new('WorldState')
local showCollision = false

st:setInit(function(self, roomPath, location)
	shuv.resetPal()
	
    self.roomData = dpf.loadJson(roomPath)
    
    self.tileset = cs.tileset or ez.new(sprites.tilesheet, { width = 32, height = 32 })
    self.moveTimer = 0
	
	self.objects = self.roomData.objects or {}
	
	if location then
		self.tilePos = { location[1], location[2] }
	elseif self.roomData.roomInfo.spawn then
		local spawnpos = self.roomData.roomInfo.spawn
		self.tilePos = { spawnpos[1], spawnpos[2] }
	else
		self.tilePos = { 1, 1 }
	end

	self.position = {
		x = self.tilePos[1] * 32 - 16,
		y = self.tilePos[2] * 32 - 16
	}
	self.direction = "down"
	
	self.cameraPos = {
		x = math.ceil(self.position.x - 300), y = math.ceil(self.position.y - 180)
	}
end)

function st:getLayer(name)
    for _, layer in ipairs(self.roomData.layers) do
        if layer.name == name then
            return layer
        end
    end
end

function st:isWalkable(tx, ty)
    local layer = self:getLayer("floor")

    if not layer then return false end

    if tx < 1 or ty < 1
    or tx > self.roomData.roomInfo.width
    or ty > self.roomData.roomInfo.height then
        return false
    end

    return layer.data[ty][tx] ~= 0
end

function st:isInsideObject(obj, tx, ty)
    local ox = obj.position[1] + (obj.sizeOffset and obj.sizeOffset[1] or 0)
	local oy = obj.position[2] + (obj.sizeOffset and obj.sizeOffset[2] or 0)
    local w = (obj.size and obj.size[1]) or 1
    local h = (obj.size and obj.size[2]) or 1

    return tx >= ox
       and tx <  ox + w
       and ty >= oy
       and ty <  oy + h
end

function st:getObjectAt(tx, ty)
    for _, obj in ipairs(self.objects) do
        if self:isInsideObject(obj, tx, ty) then
            return obj
        end
    end
end

function st:getObjectById(id)
    for _, obj in ipairs(self.objects) do
        if obj.id == id then
            return obj
        end
    end
end

function st:setObjectVariable(path, value)
    local objectId, field = path:match("([^%.]+)%.(.+)")
    if not objectId or not field then return end

    local target = self:getObjectById(objectId)
    if not target then return end

    target[field] = value
end

function st:collectRoomState()
    local state = {}
    for _, obj in ipairs(self.objects) do
        if obj.id then
            state[obj.id] = {
                collision = obj.collision,
                visible = obj.visible,
                sprite = obj.sprite
            }
        end
    end
    return state
end

function st:activateObject(obj)
    if obj.type == "transition" then
		cs = bs.load(obj.to)

        if obj.toParams then
            cs:init(unpack(obj.toParams))
        else
            cs:init()
        end
    end

    if obj.type == "door" then
		if love.filesystem.getInfo(obj.toParams[1]) then
			cs = bs.load(obj.to)

			if obj.toParams then
				cs:init(unpack(obj.toParams))
			else
				cs:init()
			end
		else
			print("room doesn't exist oopsies")
		end
    end
	
	if obj.type == "button" then
        if obj.variable then
            local objectId, field = obj.variable:match("([^%.]+)%.(.+)")
            local target = self:getObjectById(objectId)

            if target then
                if obj.setsTo ~= nil then
                    target[field] = obj.setsTo
                else
                    target[field] = not target[field]
                end

                if target.type == "door" then
					if target.collision == false and target.opensprite then
						target.sprite = target.opensprite
					elseif target.collision == true and target.closesprite then
						target.sprite = target.closesprite
					end
				end
            end
        end

        if obj.oneShot then
            obj.collision = false
            obj.visible = false
            obj.used = true
        end

        return
    end
end

st:setUpdate(function(self, dt)
	flux.to(self.cameraPos, 20, {x = math.ceil(self.position.x - 300), y =math.ceil(self.position.y - 180)})

    if self.moveTimer > 0 then
        self.moveTimer = self.moveTimer - dt
        return
    end

    local dx, dy = 0, 0

    if maininput:down("up") then
        dy = -1
        self.direction = "up"
    elseif maininput:down("down") then
        dy = 1
        self.direction = "down"
    elseif maininput:down("left") then
        dx = -1
        self.direction = "left"
    elseif maininput:down("right") then
        dx = 1
        self.direction = "right"
    end

    if dx ~= 0 or dy ~= 0 then
        local nx = self.tilePos[1] + dx
        local ny = self.tilePos[2] + dy

        if self:isWalkable(nx, ny) then
			local obj = self:getObjectAt(nx, ny)

			if obj then
				if obj.collision then
					return
				end
				
				if obj.type == "door" then
					self:activateObject(obj)
					return
				end
			end

			self.tilePos[1] = nx
			self.tilePos[2] = ny

			flux.to(self.position, 10, {
				x = nx * 32 - 16,
				y = ny * 32 - 16
			}):oncomplete(function()
				self.position.x = self.tilePos[1] * 32 - 16
				self.position.y = self.tilePos[2] * 32 - 16
			end)
		end

        self.moveTimer = 10
    end
	
	if maininput:pressed("accept") then
		local x, y = 0, -1
		if self.direction == "right" then
			x, y = 1, 0
		elseif self.direction == "left" then
			x, y = -1, 0
		elseif self.direction == "down" then
			x, y = 0, 1
		end
		local obj = self:getObjectAt(self.tilePos[1] + x, self.tilePos[2] + y)
		print(x,y, obj)
		if obj then
			self:activateObject(obj)
		end
	end
end)

st:setBgDraw(function(self)
    prof.push("worldbgdraw")

    love.graphics.push()
    love.graphics.translate(-self.cameraPos.x, -self.cameraPos.y)

    love.graphics.clear(0,0,0,1)
    love.graphics.setColor(1,1,1,1)
	
	local layer = self:getLayer("floor")
    for y = 1, self.roomData.roomInfo.height do
        for x = 1, self.roomData.roomInfo.width do
            local layerInfo = self.roomData.roomInfo[layer.name]

            self.tileset:draw(
                layer.data[y][x],
                x * 32 - 32 + (layerInfo.xOffset or 0),
                y * 32 - 32 + (layerInfo.yOffset or 0)
            )
        end
    end

    love.graphics.pop()
    prof.pop("worldbgdraw")
end)

function st:getObjectsDrawY()
    local allObjects = helpers.copytable(self.objects)

    local playerSpr = sprites.crankyup
    if self.direction == "down" then
        playerSpr = sprites.crankydown
    elseif self.direction == "right" then
        playerSpr = sprites.crankyside
    elseif self.direction == "left" then
        playerSpr = sprites.crankyside
    end

    table.insert(allObjects, {
        sprite = playerSpr,
        position = {
            self.position.x / 32 + 1,
            self.position.y / 32 + 1
        },
        drawOffset = {0, 0},
        isPlayer = true,
        flipX = (self.direction == "left")
    })

    table.sort(allObjects, function(a, b)
        return a.position[2] < b.position[2]
    end)

    return allObjects
end

st:setFgDraw(function(self)
    prof.push("worldfgdraw")

    love.graphics.push()
    love.graphics.translate(-self.cameraPos.x, -self.cameraPos.y)

    local drawList = self:getObjectsDrawY()

    for _, obj in ipairs(drawList) do
        local dx = (obj.drawOffset and obj.drawOffset[1] or 0)
        local dy = (obj.drawOffset and obj.drawOffset[2] or 0)

        if obj.isPlayer then
            love.graphics.draw(
                obj.sprite,
                self.position.x,
                self.position.y,
                0,
                obj.flipX and -1 or 1,
                1,
                16,
                16
            )
        else
            if obj.visible ~= false then
                love.graphics.draw(
                    sprites[obj.sprite],
                    (obj.position[1] + dx) * 32 - 32,
                    (obj.position[2] + dy) * 32 - 32
                )
            end
        end
    end

    if showCollision then
        for _, obj in ipairs(self.objects) do
            if obj.collision then
                local ox = obj.position[1] + (obj.sizeOffset and obj.sizeOffset[1] or 0)
                local oy = obj.position[2] + (obj.sizeOffset and obj.sizeOffset[2] or 0)
                local w = (obj.size and obj.size[1] or 1)
                local h = (obj.size and obj.size[2] or 1)

                love.graphics.setColor(1, 0, 0, 0.4)
                love.graphics.rectangle(
                    "fill",
                    ox * 32 - 32,
                    oy * 32 - 32,
                    w * 32,
                    h * 32
                )
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end

    love.graphics.pop()
    prof.pop("worldfgdraw")
end)


return st
