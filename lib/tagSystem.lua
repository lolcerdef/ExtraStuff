local tags = {}
tags.UndoneTags = {"Difficulty"}

tags.vfxevents = {
	ease = true, 
	setBoolean = true, 
	setCol = true, 
	setBgCol = true, 
	easeSequence = true,
	songNameOverride = true,
	aft = true,
	advancetextdeco = true,
	deco = true,
	forcePlayerSprite = true,
	hom = true,
	loadCustomFont = true,
	noise = true,
	outline = true,
	playSound = true,
	setJoystickColor = true,
	textdeco = true,
	initobject = true,
	multiPulse = true,
	playMidi = true,
	setBG = true,
	videoBG = true,
	singlePulse = true,
	forceMidiNote = true,
	shader_uniform = true,
	shader_background = true,
	ParallaxBackground = true
}

function tags.modifierFromRatio(r, canOnly)
	if r >= 1 and canOnly then return "Only" end
	if r == 0 then return "No" end
	if r < 0.05 then return "Minimal" end
	if r < 0.15 then return "Low" end
	if r < 0.30 then return "Medium" end
	if r < 0.50 then return "High" end
	return "Extreme"
end

function tags.scrollSpeedModifier(number)
	if number < 30 then return "Very Low" end
	if number < 50 then return "Low" end
	if number < 90 then return "Normal" end
	if number < 110 then return "High" end
	if number < 130 then return "Very High" end
	return "Extreme"
end

function tags.addTag(out, mod, name)
	if mod ~= "" then
		table.insert(out, mod .. " " .. name)
	else
		table.insert(out, name)
	end
end

function tags.getEndTime(leveldata)
	for i, ev in ipairs(leveldata.events) do
		if ev.type == "showResults" then
            return ev.time
        elseif i == #leveldata.events then
			return ev.time
		end
	end
	return 0
end

function tags.getFullCombo(leveldata, levelpath, tagLoader)
	local effectiveEvents = leveldata.events
	if tagLoader then
		effectiveEvents = tags.expandTagEvents(leveldata.events, tagLoader)
	elseif levelpath then
		effectiveEvents = tags.expandTagEvents(
			leveldata.events,
			function(tagName)
				return tags.loadTagEvents(levelpath, tagName)
			end
		)
	end

	local hits = 0
	local hittableNotes = {
		block = true,
		hold = true,
		mine = true,
		mineHold = true,
		inverse = true,
		side = true,
		bounce = true,
		extraTap = true
	}
	for i, ev in ipairs(effectiveEvents) do
		if hittableNotes[ev.type] then
			if ev.type == "extraTap" then
				hits = hits + 1
			end
			if ev.type == "block" or ev.type == "inverse" or ev.type == "side" or ev.type == "mine" or ev.type == "mineHold" then
				if ev.tap then
					hits = hits + 1
				end
				if not (ev.type == "mine" or ev.type == "mineHold") then
					hits = hits + 1
				elseif effectiveEvents[i-1] then
					if (effectiveEvents[i-1].type == "mine" or effectiveEvents[i-1].type == "mineHold") and ev.time == effectiveEvents[i-1].time then
						
					else
						hits = hits + 1
					end
				end
			end
			if ev.type == "hold" then
				hits = hits + 2
				if ev.tap then
					hits = hits + 1
				end
				if ev.endTap then
					hits = hits + 1
				end
			end
			if ev.type == "bounce" then
				hits = hits + 1 + ev.bounces
				if ev.tap then
					hits = hits + 1 + ev.bounces
				end
			end
		end
	end
	return hits
end

function tags.expandTagEvents(events, tagLoader, seen)
    seen = seen or {}
    local out = {}

    for _, ev in ipairs(events) do
        if ev.type == "tag" and ev.tag then
            if seen[ev.tag] then
                print("Warning: recursive tag detected:", ev.tag)
                goto continue
            end

            seen[ev.tag] = true

            local tagEvents = tagLoader(ev.tag)
            if tagEvents then
                for _, tev in ipairs(tagEvents) do
                    local newEv = {}
                    for k, v in pairs(tev) do
                        newEv[k] = v
                    end
                    newEv.time = (tev.time or 0) + (ev.time or 0)

                    table.insert(out, newEv)
                end
            end

            seen[ev.tag] = nil
        else
            table.insert(out, ev)
        end

        ::continue::
    end

    return out
end

function tags.calculateLevelLength(timingInfo, endBeat)
	if not timingInfo or not timingInfo.initial then return 0 end
	if not endBeat then endBeat = tags.getEndTime(cs.levelData) end

	local bpm = timingInfo.initial.bpm or 100
	local lastBeat = timingInfo.initial.beatOffset or 0
	local length = 0

	local points = timingInfo.timingPoints or {}

	for _, tp in ipairs(points) do
		if tp.beat >= endBeat then
			break
		end

		local beatDelta = tp.beat - lastBeat
		if beatDelta > 0 then
			length = length + (beatDelta / bpm) * 60
		end

		lastBeat = tp.beat
		bpm = tp.bpm
	end
	
	if endBeat > (lastBeat or 0) and bpm then
		length = length + ((endBeat - (lastBeat or 0)) / bpm) * 60
	end

	return length
end

function tags.collectLevelStats(leveldata)
    local stats = {
        maxTime = 0,
        endBeat = 0,

        count = {
            blocks = 0, mines = 0, holds = 0, mineholds = 0,
            traces = 0, sides = 0, bounces = 0,
            inverses = 0, taps = 0
        },

        vfxnum = 0,
        BPMs = {},
        scrollSpeeds = {},
        objectRotations = {},
        noteTimes = {},
        jumpBeatableNotes = {},

        editsPaddle = false,
        damoclismGimmick = false
    }

    for i, ev in ipairs(leveldata.events) do
        if ev.time and ev.time > stats.maxTime then
            stats.maxTime = ev.time
        end

        if ev.objectName == "Damoclism" then
            stats.damoclismGimmick = true
            goto continue
        end

        if ev.var == "scrollSpeed" then
            table.insert(stats.scrollSpeeds, {time = ev.time, value = ev.value})
        elseif ev.var == "objectRotation" then
            table.insert(stats.objectRotations, ev.value)
        end

        if tags.vfxevents[ev.type] then
            stats.vfxnum = stats.vfxnum + 1
            goto continue
        end

        if ev.type == "paddles" then
            stats.editsPaddle = true
            goto continue
        end

        if ev.type == "showResults" then
            stats.endBeat = ev.time
            goto continue
        end

        if ev.type == "play" or ev.type == "setBPM" then
            table.insert(stats.BPMs, ev.bpm)
            goto continue
        end

        if ev.type == "extraTap" or ev.tap or ev.endTap
            or ev.type == "block" or ev.type == "mine"
            or ev.type == "inverse" or ev.type == "hold"
            or ev.type == "mineHold" or ev.type == "bounce"
            or ev.type == "side"
        then
            table.insert(stats.noteTimes, ev.time)
            if ev.type == "block" or ev.type == "hold"
                or ev.type == "inverse" or ev.type == "bounce"
            then
                table.insert(stats.jumpBeatableNotes, {
                    time = ev.time,
                    angle = ev.angle
                })
            end
        end

        if ev.type == "extraTap" or ev.tap or ev.endTap then
            stats.count.taps = stats.count.taps + 1
        elseif ev.type == "block" then
            stats.count.blocks = stats.count.blocks + 1
        elseif ev.type == "mine" then
            stats.count.mines = stats.count.mines + 1
        elseif ev.type == "inverse" then
            stats.count.inverses = stats.count.inverses + 1
        elseif ev.type == "hold" then
            stats.count.holds = stats.count.holds + 1
        elseif ev.type == "trace" then
            stats.count.traces = stats.count.traces + 1
        elseif ev.type == "mineHold" then
            stats.count.mineholds = stats.count.mineholds + 1
        elseif ev.type == "bounce" then
            stats.count.bounces = stats.count.bounces + 1
        elseif ev.type == "side" then
            stats.count.sides = stats.count.sides + 1
        end

        ::continue::
    end

    stats.endBeat = stats.endBeat > 0 and stats.endBeat or stats.maxTime or 1
    return stats
end

function tags.calculateDerivedStats(stats, leveldata)
    -- scroll stats
    table.sort(stats.scrollSpeeds, function(a,b) return a.time < b.time end)

    local scrollMin, scrollMax, scrollAvg = nil, nil, 0
    local scrollTotalTime = 0

    for i, spd in ipairs(stats.scrollSpeeds) do
        local startTime = spd.time
        local duration = (stats.scrollSpeeds[i+1] and
            stats.scrollSpeeds[i+1].time or stats.endBeat) - startTime

        duration = math.max(duration, 0)
        scrollAvg = scrollAvg + spd.value * duration
        scrollTotalTime = scrollTotalTime + duration

        scrollMin = scrollMin and math.min(scrollMin, spd.value) or spd.value
        scrollMax = scrollMax and math.max(scrollMax, spd.value) or spd.value
    end

    if scrollTotalTime > 0 then
        scrollAvg = scrollAvg / scrollTotalTime
    end

    stats.scrollMin = scrollMin
    stats.scrollMax = scrollMax
    stats.scrollAvg = scrollAvg
    stats.scrollVaried = scrollMin and scrollMax
        and scrollAvg > 0
        and (scrollMax - scrollMin) / scrollAvg > 0.15

    -- BPM
    local bpmSum = 0
    for _, bpm in ipairs(stats.BPMs) do bpmSum = bpmSum + bpm end
    stats.avgBPM = #stats.BPMs > 0 and bpmSum / #stats.BPMs or 100

    -- note density
    table.sort(stats.noteTimes)
    if #stats.noteTimes >= 2 then
        local dist = 0
        for i = 2, #stats.noteTimes do
            dist = dist + (stats.noteTimes[i] - stats.noteTimes[i-1])
        end
        stats.avgNoteDist = dist / (#stats.noteTimes - 1)
    end

    return stats
end

function tags.addGameplayTags(out, stats)
    local ttlNotes, gpNotes = 0, 0
    for _, n in pairs(stats.count) do ttlNotes = ttlNotes + n end
    gpNotes = ttlNotes - stats.count.traces

    if gpNotes <= 0 then
        tags.addTag(out, "No", "Gameplay")
        return
    end

    local c = stats.count
    tags.addTag(out, tags.modifierFromRatio(c.mines/gpNotes, true), "Mines")
    tags.addTag(out, tags.modifierFromRatio(c.holds/gpNotes, true), "Holds")
    tags.addTag(out, tags.modifierFromRatio(c.mineholds/gpNotes, true), "MineHolds")
    tags.addTag(out, tags.modifierFromRatio(c.blocks/gpNotes, true), "Blocks")
    tags.addTag(out, tags.modifierFromRatio(c.sides/gpNotes, true), "Sides")
    tags.addTag(out, tags.modifierFromRatio(c.bounces/gpNotes, true), "Bounces")
    tags.addTag(out, tags.modifierFromRatio(c.inverses/gpNotes, true), "Inverses")
    tags.addTag(out, tags.modifierFromRatio(c.taps/gpNotes, true), "Taps")

    if stats.avgNoteDist then
        tags.addTag(out, tags.modifierFromRatio(1/(4*stats.avgNoteDist), false), "Note Density")
    else
        tags.addTag(out, "Literaly", "One Note")
    end

    tags.addTag(out, tags.modifierFromRatio(c.traces/ttlNotes, true), "Traces")
end

function tags.addTimingTags(out, stats, leveldata)
    local lvlLen = (stats.endBeat / stats.avgBPM) * 60

    if lvlLen <= 60 then tags.addTag(out, "Tiny", "Length")
    elseif lvlLen <= 120 then tags.addTag(out, "Small", "Length")
    elseif lvlLen <= 180 then tags.addTag(out, "Medium", "Length")
    elseif lvlLen <= 240 then tags.addTag(out, "Big", "Length")
    elseif lvlLen <= 300 then tags.addTag(out, "Large", "Length")
    else tags.addTag(out, "Insane", "Length") end

    tags.addTag(out, #stats.BPMs > 1 and "Varied" or "Static", "BPM")

    if stats.scrollAvg and stats.scrollAvg > 0 then
        tags.addTag(out,
            tags.scrollSpeedModifier(stats.scrollAvg * (leveldata.properties.speed or 70)),
            "Scroll Speed"
        )
        tags.addTag(out, stats.scrollVaried and "Varied" or "Static", "Scroll Speed")
    end
end

function tags.addMiscTags(out, stats)
    tags.addTag(out,
        tags.modifierFromRatio(stats.vfxnum / (stats.endBeat * 2), false),
        "VFX"
    )

    if stats.damoclismGimmick then
        tags.addTag(out, "", "Damoclism Gimmick")
    end
    if stats.editsPaddle then
        tags.addTag(out, "", "Changes Paddle")
    end
end

function tags.loadTagEvents(levelpath, tagName)
	local tagPath = levelpath .. "tags/" .. tagName .. ".json"
	local pathinfo = love.filesystem.getInfo(tagPath)
	if tagName ~= "" and levelpath and pathinfo and pathinfo.type == "file" then
		return dpf.loadJson(tagPath, {})
	end
	return {}
end

function tags.generateTags(leveldata, levelpath)
    local out = {}
	local expandedEvents = tags.expandTagEvents(
        leveldata.events,
        function(tagName)
            return tags.loadTagEvents(levelpath, tagName)
        end
    )
	local expandedLevelData = {
		events = expandedEvents,
		properties = leveldata.properties
	}
	
    local stats = tags.collectLevelStats(expandedLevelData)
    tags.calculateDerivedStats(stats, expandedLevelData)

    tags.addGameplayTags(out, stats)
    tags.addTimingTags(out, stats, expandedLevelData)
    tags.addMiscTags(out, stats)

    return out
end

function tags.generateTagFile(leveldata, path)
	local data = ""
	
	local tagList = tags.generateTags(leveldata)
	for _, tag in ipairs(tagList) do
		data = data .. tag .. "\n"
	end
	love.filesystem.write(path, data)
end

return tags