if not love.filesystem.getInfo("Mods/ExtraStuff") then
	error("Check if your ExtraStuff folder is named 'ExtraStuff' not something like 'ExtraStuff-master'")
end --im not ficing this shite bruh 
tags = require("Mods.ExtraStuff.lib.tagSystem")
imguiextra = require("Mods.ExtraStuff.lib.imguiextra")

math.randomseed(os.time())

adTimer = 0

getNewAdKeys = false
landscapeAdKeys = {"c1", "c2", "c3", "c4"}
portraitAdKeys = {"c1", "c2", "c3", "c4"}
squareAdKeys = {"c1", "c2", "c3", "c4"}
currentLandscapeAd = landscapeAdKeys[math.random(1, 4)]
currentPortraitAd = portraitAdKeys[math.random(1, 4)]
currentSquareAd = squareAdKeys[math.random(1, 4)]

jumpscareAnim = ez.newjson(
	"Mods/ExtraStuff/assets/jumpscare.png",
	"Mods/ExtraStuff/assets/jumpscare.json"
)

fonts.smallnums = love.graphics.newFont("Mods/ExtraStuff/assets/fonts/smallnum/smallnum.ttf", 5)
fonts.action = love.graphics.newFont("Mods/ExtraStuff/assets/fonts/action/action.ttf", 10)
fonts.rpgtitle = love.graphics.newFont("Mods/ExtraStuff/assets/fonts/rpgtitle/rpgtitle.ttf", 10)

jumpscareInst = nil
jumpscareActive = false
tryjumpscaretimer = 0

local function fillMissingKeys(data, default)
    for key, value in pairs(default) do
        if data[key] == nil then
            data[key] = value
        elseif type(value) == "table" and type(data[key]) == "table" then
            fillMissingKeys(data[key], value)
        end
    end
    return data
end

extraDefaultSave = dpf.loadJson("Mods/ExtraStuff/defaultSav.json")
extrasavedata = dpf.loadJson("savedata/extraMod.sav", extraDefaultSave)

extrasavedata = fillMissingKeys(extrasavedata, extraDefaultSave)
dpf.saveJson("savedata/extraMod.sav", extrasavedata)
log("[EXTRASTUFF]: loaded extrasavedata")

if mods["betterFishing"] then
	extrasavedata.replayFish = false
	extrasavedata.fishingBookText = false
	extrasavedata.fishPerPage = mods["betterFishing"].config.fishPerPage or 4
end

if extrasavedata.apfladdSplashes ~= false and splashes then
	local numberofsplashes = loc.get("extrastuffsplashtext_num")
	for i = 0, numberofsplashes do
		local value = loc.get("extrastuffsplashtext_" .. i)
		value = value:gsub("\n", " ")
		table.insert(splashes, value)
	end
end

exstuff = {}

function exstuff.tryTriggerJumpscare()
	if jumpscareActive then return end

	if math.random() <= ((extrasavedata.foxyJumpscareChance or 0.1) / 100) then
		jumpscareInst = jumpscareAnim:instance("all")
		jumpscareInst:play("all", 0, function()
			jumpscareActive = false
		end)
		te.playOne(sounds.foxyjumpscare,"static",'sfx',1)
		jumpscareActive = true
		if cs.name == "Game" then
			cs.gotJumpscared = cs.gotJumpscared or 0
			cs.gotJumpscared = cs.gotJumpscared + 1
		end
	end
end

function exstuff.jumpscareUpdate(d)
	tryjumpscaretimer = tryjumpscaretimer + d
	if tryjumpscaretimer > 1 and extrasavedata.foxyJumpscare then
		if not extrasavedata.onlyInGamefj or cs.name == "Game" then
			exstuff.tryTriggerJumpscare()
			tryjumpscaretimer = 0
		end
	end
	if jumpscareActive and jumpscareInst then
		jumpscareInst:update(d, 1200)
	end
end

function exstuff.adsUpdate(d)
	if not getNewAdKeys then
		landscapeAdKeys = {}
		portraitAdKeys = {}
		squareAdKeys = {}
		for key, value in pairs(sprites.ads.landscape) do
			table.insert(landscapeAdKeys, key)
		end
		for key, value in pairs(sprites.ads.portrait) do
			table.insert(portraitAdKeys, key)
		end
		for key, value in pairs(sprites.ads.square) do
			table.insert(squareAdKeys, key)
		end
		getNewAdKeys = true
	end
	if adTimer < 0 and extrasavedata.robloxAds then
		currentLandscapeAd = landscapeAdKeys[math.random(1, #landscapeAdKeys)]
		currentPortraitAd = portraitAdKeys[math.random(1, #portraitAdKeys)]
		currentSquareAd = squareAdKeys[math.random(1, #squareAdKeys)]
		adTimer = 5
	elseif extrasavedata.robloxAds then
		adTimer = adTimer - d
	end
end