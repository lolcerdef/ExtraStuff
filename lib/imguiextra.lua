local imguiextra = {}

local function swap(t, a, b)
    t[a], t[b] = t[b], t[a]
end

function imguiextra.IntInput(label, value)
	local buf = ffi.new("int[1]", value or 0)
	local val = value
	if imgui.InputInt(label, buf) then
		val = buf[0]
	end
	
	return val
end

function imguiextra.DrawReorderableList(imgui, items, list_id, size)
    list_id = list_id or "reorder"
	local bsize = size or {30, 16}

    for i = 1, #items do
        local label = items[i] .. "##" .. list_id .. "_" .. i

        imgui.Button(label, bsize)

        if imgui.BeginDragDropSource() then
            local payload = ffi.new("int[1]", i)
            imgui.SetDragDropPayload(
                "REORDER_ITEM",
                payload,
                ffi.sizeof(payload)
            )
            imgui.Text(items[i])
            imgui.EndDragDropSource()
        end

        if imgui.BeginDragDropTarget() then
            local payload = imgui.AcceptDragDropPayload("REORDER_ITEM")
            if payload ~= nil then
                local src = ffi.cast("int*", payload.Data)[0]
                if src ~= i then
                    swap(items, src, i)
                end
            end
            imgui.EndDragDropTarget()
        end
    end
end

local function swapRadialOption(list, a, b)
    swap(list.options[list.submenu], a, b)
    swap(list.icons[list.submenu], a, b)
end

function imguiextra.DrawReorderableRadialList(radialList, list_id, buttonSize)
    list_id = list_id or "radialList"
    buttonSize = buttonSize or {120, 24}

    local options = radialList.options[radialList.submenu]
    local hiddenOptions = radialList.hiddenOptions or {}

    imgui.Text("Enabled Options")
    for i, opt in ipairs(options) do
        local label = opt.text .. "##" .. list_id .. "_enabled_" .. i
        imgui.Button(label, buttonSize)

        if imgui.BeginDragDropSource() then
            local payload = ffi.new("int[2]", {i, 0})
            imgui.SetDragDropPayload("REORDER_RADIAL_ITEM", payload, ffi.sizeof(payload))
            imgui.Text(opt.text)
            imgui.EndDragDropSource()
        end

        if imgui.BeginDragDropTarget() then
            local payload = imgui.AcceptDragDropPayload("REORDER_RADIAL_ITEM")
            if payload ~= nil then
                local data = ffi.cast("int*", payload.Data)
                local srcIndex = data[0]
                local srcHidden = data[1] == 1

                if srcHidden then
                    local id = hiddenOptions[srcIndex]._id
                    radialList:restoreHidden({id})
                elseif srcIndex ~= i then
                    swapRadialOption(radialList, srcIndex, i)
                end
            end
            imgui.EndDragDropTarget()
        end
    end

    imgui.Separator()
    imgui.Text("Hidden Options")

    if #hiddenOptions == 0 then
        local dummySize = {buttonSize[1], buttonSize[2]}
        imgui.InvisibleButton("EmptyHiddenTarget##"..list_id, dummySize)

        if imgui.BeginDragDropTarget() then
            local payload = imgui.AcceptDragDropPayload("REORDER_RADIAL_ITEM")
            if payload ~= nil then
                local data = ffi.cast("int*", payload.Data)
                local srcIndex = data[0]
                local srcHidden = data[1] == 1

                if not srcHidden and #options > 1 then
                    local id = options[srcIndex]._id
                    radialList:addHidden({id})
                end
            end
            imgui.EndDragDropTarget()
        end
    else
        for i, opt in ipairs(hiddenOptions) do
            local label = opt.text .. " (hidden)##" .. list_id .. "_hidden_" .. i
            imgui.Button(label, buttonSize)

            if imgui.BeginDragDropSource() then
                local payload = ffi.new("int[2]", {i, 1})
                imgui.SetDragDropPayload("REORDER_RADIAL_ITEM", payload, ffi.sizeof(payload))
                imgui.Text(opt.text)
                imgui.EndDragDropSource()
            end

            if imgui.BeginDragDropTarget() then
                local payload = imgui.AcceptDragDropPayload("REORDER_RADIAL_ITEM")
                if payload ~= nil then
                    local data = ffi.cast("int*", payload.Data)
                    local srcIndex = data[0]
                    local srcHidden = data[1] == 1

                    if srcHidden and srcIndex ~= i then
                        swap(hiddenOptions, srcIndex, i)
                    elseif not srcHidden and #options > 1 then
                        local id = options[srcIndex]._id
                        radialList:addHidden({id})
                    end
                end
                imgui.EndDragDropTarget()
            end
        end
    end
end

local function find_value(tbl, val_to_find)
    for key, value in pairs(tbl) do
        if value == val_to_find then
            return key
        end
    end
    return nil
end

function imguiextra.Dropdown(label, positions, currentValue)
    local selectedIndex = find_value(positions, currentValue) or 1

    imgui.Text(label)

    if imgui.BeginCombo("##" .. label, positions[selectedIndex], true) then
        for i, pos in ipairs(positions) do
            local disabled = (selectedIndex == i)

            if disabled then
                imgui.BeginDisabled()
            end

            if imgui.Button(pos) then
                selectedIndex = i
            end

            if disabled then
                imgui.EndDisabled()
            end
        end
        imgui.EndCombo()
    end

    return positions[selectedIndex]
end

function imguiextra.drawValue(label, value, setter, allowedTypes)
    local t = type(value)

    if allowedTypes and not allowedTypes[t] then
        return
    end

    if t == "number" then
        local v = ffi.new("float[1]", value)
        if imgui.InputFloat(label, v) then
            setter(v[0])
        end
		
    elseif t == "string" then
        local buf = ffi.new("char[256]", value)
        if imgui.InputText(label, buf, 256, 0, nil, nil) then
            setter(ffi.string(buf))
        end

    elseif t == "boolean" then
        local b = ffi.new("bool[1]", value)
        if imgui.Checkbox(label, b) then
            setter(b[0])
        end

    elseif t == "table" then
        if imgui.TreeNode_Str(label) then
            imguiextra.drawTable(value)
            imgui.TreePop()
        end

    else
        imgui.Text("%s (%s)", label, t)
    end
end

function imguiextra.drawTable(tbl, types, skipkeys)
    for k, v in pairs(tbl) do
		if skipkeys and skipkeys[k] then
			goto continue
		end
		imgui.PushID_Str(tostring(k))
		imguiextra.drawValue(
			tostring(k),
			v,
			function(newVal)
				tbl[k] = newVal
			end, types
		)
		imgui.PopID()
		::continue::
    end
end

function imguiextra.drawStringList(label, tbl, options)
    options = options or {}
    local allowEmpty = options.allowEmpty or false
    local inputWidth = options.inputWidth or 150
    local removeText = options.removeText or "-"
    local addText = options.addText or "+"

    imgui.Text(label)

    for key, _ in pairs(tbl) do
        imgui.PushID_Str(tostring(key))

        imgui.TextUnformatted(tostring(key))
        imgui.SameLine()

        if imgui.SmallButton(tostring(removeText)) then
            tbl[key] = nil
        end

        imgui.PopID()
    end

    imguiextra._stringListBuffers = imguiextra._stringListBuffers or {}
    local buf = imguiextra._stringListBuffers[label]
    if not buf then
        buf = ffi.new("char[256]")
        buf[0] = 0
        imguiextra._stringListBuffers[label] = buf
    end

    imgui.PushItemWidth(inputWidth)
    imgui.InputText("##add_" .. label, buf, 256)
    imgui.PopItemWidth()

    imgui.SameLine()

    if imgui.Button(tostring(addText) .. "##" .. label) then
        local str = ffi.string(buf)

        if (allowEmpty or str ~= "") and tbl[str] == nil then
            tbl[str] = true
            buf[0] = 0
        end
    end
end

function imguiextra.LabeledSeparator(label, size)
	local s = size or 1
	local lineY = imgui.GetCursorPosY()
	imgui.SetWindowFontScale(s)
	local lineHeight = imgui.GetTextLineHeight()
	imgui.Text(label)
	imgui.SameLine()
	imgui.SetCursorPosY(lineY + lineHeight/2)
	imgui.Separator()
	imgui.SetWindowFontScale(1)
end

function imguiextra.PositionEditor(id, x, y, r, edit, offx, offy)
	imgui.SetNextWindowSize({80,80})
	local ox = offx or 0
	local oy = offy or 0

	local flags = imgui.ImGuiWindowFlags_NoResize
		+ imgui.ImGuiWindowFlags_NoCollapse
		+ imgui.ImGuiWindowFlags_NoTitleBar
		+ imgui.ImGuiWindowFlags_NoScrollbar
		
	imgui.SetNextWindowPos({(ox + x)*2-40, (oy + y)*2-40},imgui.ImGuiCond_FirstUseEver)
	if edit then
		imgui.SetNextWindowPos({(ox + x)*2-40, (oy + y)*2-40})
		flags = flags + imgui.ImGuiWindowFlags_NoMove
	end

	imgui.Begin("##posedit_" .. id, true, flags)
	local pos = imgui.GetWindowPos()

	if edit then
		imgui.SetCursorPos({5,5})
		x = helpers.clamp(helpers.InputFloat("X##" .. id, x), 0 - ox, 600 - ox)

		imgui.SetCursorPos({5,22})
		y = helpers.clamp(helpers.InputFloat("Y##" .. id, y), 0 - oy, 360 - oy)
		if r then
			imgui.SetCursorPos({5,39})
			r = helpers.InputFloat("R##" .. id, r) % 360
		end
	else
		x = (pos.x + 40) / 2 - ox
		y = (pos.y + 40) / 2 - oy

		imgui.SetCursorPos({5,5})
		imgui.Text("X: " .. tostring(x))

		imgui.SetCursorPos({5,22})
		imgui.Text("Y: " .. tostring(y))
		if r then
			imgui.SetCursorPos({5,39})
			imgui.Text("R: " .. tostring(r))
		end
	end

	imgui.SetCursorPos({5,56})
	if edit then
		if imgui.Button("Apply Num##" .. id) then
			edit = false
		end
	else
		if imgui.Button("Edit Num##" .. id) then
			edit = true
		end
	end

	imgui.End()

	return x, y, r, edit
end

return imguiextra