config = extrasavedata

local function versionCheck(version, actualversion)
	local function splitVersion(v)
		local t = {}
		for part in string.gmatch(v, "[^%.]+") do
			t[#t+1] = tonumber(part) or 0
		end
		return t
	end

	local v1 = splitVersion(version)
	local v2 = splitVersion(actualversion)

	local maxLen = math.max(#v1, #v2)

	for i = 1, maxLen do
		local a = v1[i] or 0
		local b = v2[i] or 0

		if a > b then
			return 1
		elseif a < b then
			return -1
		end
	end

	return 0
end

seeUnfinished = seeUnfinished or false

if config then
	seeUnfinished = helpers.InputBool("See Unfinished Options", (seeUnfinished or false))

	if seeUnfinished then
		if imgui.Button("Chimaera Fight") then
			cs:loadMainMenu()
			cs.chimaera = true
			
			if savedata.options.game.customCursorInMenu
			and (savedata.options.game.cursorMode ~= "default") then
				love.mouse.setVisible(false)
			end
		end
		helpers.imguiHelpMarker("Fight the Chimaera. NOT DONE")
		
		_G.extrastuff_baftransnext = helpers.InputBool("Blow A Fuse Transition", (_G.extrastuff_baftransnext or false))
		helpers.imguiHelpMarker("BAF Transition next result screen.")
		
		config.coydressReplaceFoxy = helpers.InputBool("Coydress Instead of Foxy", (config.coydressReplaceFoxy or false))
		helpers.imguiHelpMarker("No image.")
		
		config.alwaysLoadWorkshop = helpers.InputBool("Always load workshop", (config.alwaysLoadWorkshop or true))
		helpers.imguiHelpMarker("Probably impossible.")
		
		config.showTags = helpers.InputBool("Show Generated Tags for Levels", (config.showTags or false))
		helpers.imguiHelpMarker("Where do I put this?")
		
		config.playingCrank = helpers.InputBool("Bonky Plays", (config.playingCrank or false))
		helpers.imguiHelpMarker("This bot doesn't understand mines.")
	end
	
	imguiextra.LabeledSeparator("Main Menu", 1)
	
	if imgui.Button("Edit Main Menu") then
		cs:loadMainMenu()
		cs.editMenu = true

		-- return to ingame cursor if the settings say so
		if savedata.options.game.customCursorInMenu
		and (savedata.options.game.cursorMode ~= "default") then
			love.mouse.setVisible(false)
		end
	end
	imgui.SameLine()
	config.randomizeMenuOnStart = helpers.InputBool("Randomize Menu On Start", (config.randomizeMenuOnStart or false))
	imgui.Text("Press F9 to edit the menu if Mods is hidden.")
	
	imguiextra.LabeledSeparator("Songselect", 1)
	
	if not config.chartinfoplus then
		config.chartinfoplus = helpers.copy(extraDefaultSave.chartinfoplus)
	end
	config.chartinfoplus.enabled = helpers.InputBool("More Chart Info", (config.chartinfoplus.enabled or false))
	if config.chartinfoplus.enabled then
		config.chartinfoplus.levelLength = helpers.InputBool("Show Level Length", (config.chartinfoplus.levelLength or false))
		config.chartinfoplus.fullCombo = helpers.InputBool("Show Full Combo", (config.chartinfoplus.fullCombo or false))
		imgui.Separator()
	end
	
	config.openDemoLevelWarning = helpers.InputBool("Editing Demo Warning", (config.openDemoLevelWarning or false))

	config.randomLevelButton = helpers.InputBool("Random Level Picker (Press R)", (config.randomLevelButton or false))
	config.allowRandomLevelFolder = helpers.InputBool("Allow Entering Folder for Random Level", (config.allowRandomLevelFolder or false))
	
	imguiextra.LabeledSeparator("In Game", 1)
	
	if type(config.randomSongs) == "nil" then
		config.randomSongs = true
	end
	config.randomSongs = helpers.InputBool("Allow Random Song", (config.randomSongs or false))
	
	config.showAccessibility = helpers.InputBool("Show Accessibility", (config.showAccessibility or false))
	config.showAccessibilityOnPause = helpers.InputBool("Only Show Accessibility on Pause", (config.showAccessibilityOnPause or false))

	local positions = {"topLeft", "topRight", "bottomLeft", "bottomRight"}

	if imgui.BeginCombo("Accessibility Position", config.accessibilityPos) then
        for i, v in ipairs(positions) do
            local isSelected = (v == config.accessibilityPos)
            if imgui.Selectable_Bool(v, isSelected) then
                config.accessibilityPos = v
            end
        end
        imgui.EndCombo()
    end 
	
	if not config.allowedEases then
		config.allowedEases = {}
	end
	
	imguiextra.drawStringList(
		"Allowed Eases in No VFX:",
		config.allowedEases,
		{
			inputWidth = 200, addText = " + ", removeText = " - "
		}
	)
	
	imguiextra.LabeledSeparator("Fishing", 1)
	
	if mods["betterFishing"] then
		imgui.BeginDisabled()
	end
	if type(config.replayFish) == 'nil' then config.replayFish = true end
	config.replayFish = helpers.InputBool("Replay Fish Dialogue", (config.replayFish or false))
	config.fishingBookText = helpers.InputBool("Book Texture", (config.fishingBookText or false))

	config.fishPerPage = helpers.clamp(imguiextra.IntInput("Fish Per Page", config.fishPerPage or 4), 1, 16)
	if mods["betterFishing"] then
		imgui.EndDisabled()
		config.replayFish = false
		config.fishingBookText = false
		config.fishPerPage = mods["betterFishing"].config.fishPerPage or 4
		imgui.TextWrapped("BetterFishing detected. Disabling Fishing configs.")
	end
	
	imguiextra.LabeledSeparator("Fun Stuff", 1)
	imguiextra.LabeledSeparator("-  Arrow Keys", 1)
	
	config.arrowKeyControls = helpers.InputBool("Arrow Key Controls", (config.arrowKeyControls or false))
	config.onlyArrowKeys = helpers.InputBool("Only Arrow Key Controls", (config.onlyArrowKeys or false))
	
	imguiextra.LabeledSeparator("-  Cranky Moves Towards the Mouse", 1)
	
	config.movesTowardsMouse = helpers.InputBool("Cranky Moves Towards the Mouse", (config.movesTowardsMouse or false))
	config.moveToRadiusCranky = helpers.InputFloat("Distance Cranky Stops", (config.moveToRadiusCranky or 25))
	config.crankySpeedToMouse = helpers.InputFloat("Cranky Time to Reach Mouse", (config.crankySpeedToMouse or 5))
	
	imguiextra.LabeledSeparator("-  Foxy Jumpscare", 1)
	
	config.foxyJumpscare = helpers.InputBool("Do Jumpscare", (config.foxyJumpscare or false))
	config.onlyInGamefj = helpers.InputBool("Only Ingame", (config.onlyInGamefj or false))
	config.foxyJumpscareChance = helpers.InputFloat("Chance (in Percent)", (config.foxyJumpscareChance or 0.1))
	config.foxyJumpscareAlpha = helpers.clamp(helpers.InputFloat("Alpha", (config.foxyJumpscareAlpha or 1)),0,1)

	imguiextra.LabeledSeparator("-  Ads", 1)
	
	config.robloxAds = helpers.InputBool("Ads on the sides", (config.robloxAds or false))
	imgui.Text("ads are made by noob_y")
	
	imguiextra.LabeledSeparator("-  Modifiers", 1)
	
	config.alwaysNegativeSC = helpers.InputBool("Always Negative Scrollspeed", (config.alwaysNegativeSC or false))
	
	config.allInverse = helpers.InputBool("All Inverses", (config.allInverse or false))
	--config.allMine = helpers.InputBool("All Mines", (config.allMine or false))
	config.allTap = helpers.InputBool("All Taps", (config.allTap or false))
	
	imguiextra.LabeledSeparator("Extra Configs", 1)

	config.extraConfigOtherMods = helpers.InputBool("Extra Config for Other Mods?", (config.extraConfigOtherMods or false))
	
	if config.extraConfigOtherMods then
		-- lowkey dont even use DetailedAcc anyways
		imgui.Text("Nothing to see.")
	end
	
	imgui.Separator()
	dpf.saveJson("savedata/extraMod.sav", extrasavedata)
else
	imgui.Text("ENABLE TO SEE CONFIGS!")
end
