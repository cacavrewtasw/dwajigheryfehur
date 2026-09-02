-- ==========================================
-- AutoSurg + Auto Wrench Surg-E by zama10
-- Native ImGui + Growlauncher Module Toggle
-- Discord: discord.gg/ekuVdjF4F9
-- ==========================================

-- Cleanup old hooks on rerun
pcall(function()
    if removeHook then
        removeHook("onvariant")
        removeHook("onVariant")
        removeHook("onvalue")
        removeHook("onValue")
        removeHook("ondrawimgui")
        removeHook("onDrawImGui")
    end
end)

-- ---@type Preferences
local pref = require and pcall(require, "preferences") and require("preferences") or nil
local saved = pref and pref.new and pref:new("autosurg_prefs.json") or nil

-- ImGui window open by default on script run
local imgui_opened = true
local is_authenticated = false
local keyInputBuffer = saved and saved:get("auth_key", "") or ""
local user_tier = "FREE"
local keyStatusText = "Status: [ Not Verified ]"

if keyInputBuffer ~= "" then
    local k = keyInputBuffer:gsub("%s+", "")
    if k == "vip" or k == "premium" or k:lower() == "zama" or k:sub(1,3) == "FK-" or #k >= 4 then
        is_authenticated = true
        user_tier = (k == "vip" or k == "premium") and "PREMIUM" or "FREE"
        keyStatusText = "Status: [ Verified (" .. user_tier .. ") ]"
    end
end

local autoSurgEnabled = false
local autoWrenchEnabled = false
local isSurgeryActive = false
local lowSupplyItem = nil
local currentOperatingDummy = nil
local failedTiles = {}
local wrenchSessionId = 0

-- ====================================
-- NOTIFICATION (STRICTLY growtopia.notify ONLY)
-- (NO in-game chat messages / sendChat allowed)
-- ====================================
local function notifyUser(text)
    if growtopia and growtopia.notify then
        pcall(function() growtopia.notify(text) end)
    end
end

-- ====================================
-- HELPER FUNCTIONS & AIR-MOVEMENT
-- ====================================
local function getPosXY()
    if pos then
        local x, y = pos()
        return math.floor(x), math.floor(y)
    elseif Pos then
        local x, y = Pos()
        return math.floor(x), math.floor(y)
    end
    local p = (getLocal and getLocal()) or (GetLocal and GetLocal())
    if p then
        local rawX = p.posX or (p.pos and p.pos.x)
        local rawY = p.posY or (p.pos and p.pos.y)
        if rawX and rawY then
            return math.floor(rawX / 32), math.floor(rawY / 32)
        end
    end
    return 0, 0
end

local function getTileAt(x, y)
    if getTile then return getTile(x, y)
    elseif GetTile then return GetTile(x, y)
    end
    return nil
end

local function getAllTiles()
    if getTiles then return getTiles()
    elseif GetTiles then return GetTiles()
    elseif getTileMap then
        local tm = getTileMap()
        if tm and tm.tiles then return tm.tiles end
    end
    return {}
end

local function getObjects()
    if getObjectList then return getObjectList()
    elseif GetObjectList then return GetObjectList()
    end
    return {}
end

local function hoverAt(tx, ty)
    local px = tx * 32
    local py = ty * 32

    if sendVariant then
        pcall(function() sendVariant({ v1 = "OnSetPos", v2 = { px, py } }) end)
        pcall(function() sendVariant({ [0] = "OnSetPos", [1] = { px, py } }) end)
        pcall(function() sendVariant({ "OnSetPos", { px, py } }) end)
    end

    local pkt = {
        type = 0,
        x = px,
        y = py,
        px = tx,
        py = ty,
        xspeed = 0,
        yspeed = 0
    }
    if sendPacketRaw then sendPacketRaw(false, pkt)
    elseif SendPacketRaw then SendPacketRaw(false, pkt)
    end
end

local function enableFly(state)
    if editToggle then pcall(function() editToggle("ModFly", state) end) end
    if EditToggle then pcall(function() EditToggle("ModFly", state) end) end
    if editValue then pcall(function() editValue("ModFly", state) end) end
    if EditValue then pcall(function() EditValue("ModFly", state) end) end
    if setValue then pcall(function() setValue("ModFly", state) end) end
    if SetValue then pcall(function() SetValue("ModFly", state) end) end
    if editToggle then pcall(function() editToggle("cheat_modfly", state) end) end
    if editValue then pcall(function() editValue("cheat_modfly", state) end) end
    if editToggle then pcall(function() editToggle("Fly", state) end) end
    if editValue then pcall(function() editValue("Fly", state) end) end
    if state then
        pcall(function()
            if sendPacket then
                sendPacket(2, "action|input\n|text|/fly\n")
                sendPacket(2, "action|input\n|text|/modfly\n")
            end
        end)
    end
end

local function goToDummy(targetX, targetY, session)
    local maxTotalSteps = 60
    local totalSteps = 0

    while autoWrenchEnabled and (not session or wrenchSessionId == session) and totalSteps < maxTotalSteps do
        totalSteps = totalSteps + 1
        local px, py = getPosXY()
        local dx = targetX - px
        local dy = targetY - py

        -- Within wrench interaction range (adjacent <= 1 tile)
        if math.abs(dx) <= 1 and math.abs(dy) <= 1 then
            break
        end

        local stepX = px
        local stepY = py

        -- Step 4-5 tiles towards target
        if math.abs(dx) <= 4 then
            stepX = targetX > px and (targetX - 1) or (targetX < px and (targetX + 1) or targetX)
        elseif dx > 0 then
            stepX = px + 4
        else
            stepX = px - 4
        end

        if math.abs(dy) <= 4 then
            stepY = targetY
        elseif dy > 0 then
            stepY = py + 4
        else
            stepY = py - 4
        end

        local pathOk = false
        if FindPath then
            pcall(function() pathOk = FindPath(stepX, stepY) end)
        elseif findPath then
            pcall(function() pathOk = findPath(stepX, stepY) end)
        end

        if pathOk then
            for wait = 1, 15 do
                local curX, curY = getPosXY()
                if (math.abs(curX - stepX) <= 1 and math.abs(curY - stepY) <= 1) or not autoWrenchEnabled or (session and wrenchSessionId ~= session) then
                    break
                end
                if sleep then sleep(100) end
            end
        else
            hoverAt(stepX, stepY)
            if sleep then sleep(120) end
        end
    end

    hoverAt(targetX, targetY)
    if sleep then sleep(100) end
end

local function collectRaw(objId, posX, posY)
    if spr then
        spr(11, objId, posX, posY)
    elseif sendPacketRaw then
        sendPacketRaw(false, {type = 11, value = objId, px = math.floor(posX/32), py = math.floor(posY/32), x = posX, y = posY})
    elseif SendPacketRaw then
        SendPacketRaw(false, {type = 11, value = objId, px = math.floor(posX/32), py = math.floor(posY/32), x = posX, y = posY})
    end
end

local function Collect()
    local px, py = getPosXY()
    for _, obj in pairs(getObjects()) do
        local ox = math.floor(obj.posX / 32)
        local oy = math.floor(obj.posY / 32)

        if math.abs(ox - px) <= 5 and math.abs(oy - py) <= 5 then
            collectRaw(obj.id, obj.posX, obj.posY)
        end
    end
end

local function doWrench(tx, ty)
    if wrench then
        pcall(function() wrench(tx, ty) end)
        return
    end
    if Wrench then
        pcall(function() Wrench(tx, ty) end)
        return
    end
    if wrenchTile then
        pcall(function() wrenchTile(tx, ty) end)
        return
    end

    local pkt = {
        type = 3,
        value = 32,
        px = tx,
        py = ty,
        x = tx * 32,
        y = ty * 32
    }

    if sendPacketRaw then
        sendPacketRaw(false, pkt)
    elseif SendPacketRaw then
        SendPacketRaw(false, pkt)
    end
end

-- ====================================
-- AUTO SURG TOOLS & LOGIC
-- ====================================
local toolIds = {
    ["Sponge"]        = 1258,
    ["Splint"]        = 1268,
    ["Antibiotic"]    = 1266,
    ["Anesthetic"]    = 1262,
    ["Scalpel"]       = 1260,
    ["Stitches"]      = 1270,
    ["Lab kit"]       = 4318,
    ["Pins"]          = 4308,
    ["Clamp"]         = 4314,
    ["Transfusion"]   = 4310,
    ["Ultrasound"]    = 4316,
    ["Defibrillator"] = 4312,
    ["Fix it"]        = 1296,
}

local function useTool(toolName)
    local itool = toolIds[toolName]
    if not itool then return end
    if sendPacket then
        sendPacket(2, "action|dialog_return\ndialog_name|surgery\nbuttonClicked|tool" .. itool)
    elseif SendPacket then
        SendPacket(2, "action|dialog_return\ndialog_name|surgery\nbuttonClicked|tool" .. itool)
    end
    notifyUser("`9[`cTools`9] `c" .. toolName)
end

local function getItemIdByName(name)
    local id = findItemID and findItemID(name)
    if not id or id == 0 or id == -1 then
        if name:find("Stitches") then return 1270
        elseif name:find("Scalpel") then return 1260
        elseif name:find("Anesthetic") then return 1262
        elseif name:find("Antiseptic") then return 1264
        elseif name:find("Antibiotic") then return 1266
        elseif name:find("Splint") then return 1268
        elseif name:find("Sponge") then return 1258
        elseif name:find("Defibrillator") then return 4312
        elseif name:find("Clamp") then return 4314
        elseif name:find("Ultrasound") then return 4316
        elseif name:find("Lab") then return 4318
        elseif name:find("Pins") then return 4308
        elseif name:find("Transfusion") then return 4310
        elseif name:find("Fix it") then return 1296
        end
    end
    return id or 1270
end

local function findNearestSurgE()
    local px, py = getPosXY()
    local allTiles = getAllTiles()
    local nearest = nil
    local minDist = 999999
    local now = os.clock()

    for _, t in pairs(allTiles) do
        local fg = t.fg or (t.getFg and t.getFg()) or (t.header and t.header.fg) or 0
        if fg == 4296 then
            local tx = t.x or (t.getX and t.getX()) or 0
            local ty = t.y or (t.getY and t.getY()) or 0
            local key = tx .. "," .. ty
            if not failedTiles[key] or failedTiles[key] < now then
                local dist = math.abs(tx - px) + math.abs(ty - py)
                if dist < minDist then
                    minDist = dist
                    nearest = {x = tx, y = ty}
                end
            end
        end
    end
    return nearest
end

local function turnOffAutoSurg(reason)
    autoWrenchEnabled = false
    autoSurgEnabled = false
    isSurgeryActive = false
    currentOperatingDummy = nil
    wrenchSessionId = (wrenchSessionId or 0) + 1
    enableFly(false)

    notifyUser("`4[AutoSurg] " .. (reason or "Stopped") .. "!")
end

local function handleLowSupply(itemToFind, session)
    local targetId = getItemIdByName(itemToFind or "Surgical Stitches")
    notifyUser("`6[Auto Surg-E]`4 Low Supply! `oSearching dropped items...")

    local foundObj = nil
    for _, obj in pairs(getObjects()) do
        if obj.itemid == targetId then
            foundObj = obj
            break
        end
    end

    if foundObj then
        local ox = math.floor(foundObj.posX / 32)
        local oy = math.floor(foundObj.posY / 32)
        notifyUser("`2[Auto Surg-E]`o Moving to supplies at (" .. ox .. ", " .. oy .. ")")

        goToDummy(ox, oy, session)
        if sleep then sleep(300) end
        Collect()
        if sleep then sleep(500) end
        Collect()
        if sleep then sleep(500) end
    else
        notifyUser("`4[Auto Surg-E]`o No dropped " .. (itemToFind or "Stitches") .. " found in world!")
        if sleep then sleep(1500) end
    end
end

-- ====================================
-- AUTO WRENCH THREAD LOOP
-- ====================================
local function startAutoWrenchLoop()
    if not is_authenticated then
        turnOffAutoSurg("Access Denied! Please verify key first")
        return
    end

    wrenchSessionId = (wrenchSessionId or 0) + 1
    local currentSession = wrenchSessionId
    isSurgeryActive = false
    currentOperatingDummy = nil
    lowSupplyItem = nil
    failedTiles = {}

    enableFly(true)

    local function worker()
        while autoWrenchEnabled and (wrenchSessionId == currentSession) do
            if lowSupplyItem then
                handleLowSupply(lowSupplyItem, currentSession)
                lowSupplyItem = nil
            end

            if isSurgeryActive then
                if currentOperatingDummy then
                    hoverAt(currentOperatingDummy.x, currentOperatingDummy.y)
                end
                if sleep then sleep(200) end
            else
                local dummy = findNearestSurgE()
                if not dummy then
                    failedTiles = {}
                    if sleep then sleep(1000) end
                else
                    goToDummy(dummy.x, dummy.y, currentSession)

                    if autoWrenchEnabled and (wrenchSessionId == currentSession) then
                        if sleep then sleep(200) end
                        doWrench(dummy.x, dummy.y)

                        for i = 1, 30 do
                            hoverAt(dummy.x, dummy.y)
                            if isSurgeryActive or lowSupplyItem or not autoWrenchEnabled or (wrenchSessionId ~= currentSession) then
                                break
                            end
                            if sleep then sleep(100) end
                        end

                        if isSurgeryActive and autoWrenchEnabled and (wrenchSessionId == currentSession) then
                            currentOperatingDummy = dummy
                            local waitTimeout = 0
                            while isSurgeryActive and autoWrenchEnabled and (wrenchSessionId == currentSession) do
                                hoverAt(dummy.x, dummy.y)
                                if sleep then sleep(200) end
                                waitTimeout = waitTimeout + 1

                                local t = getTileAt(dummy.x, dummy.y)
                                if t and (t.fg or (t.getFg and t.getFg()) or 0) ~= 4296 then
                                    if sleep then sleep(1000) end
                                    isSurgeryActive = false
                                    break
                                end

                                if waitTimeout > 300 then
                                    isSurgeryActive = false
                                    break
                                end
                            end
                            failedTiles[dummy.x .. "," .. dummy.y] = os.clock() + 180
                            currentOperatingDummy = nil
                        else
                            failedTiles[dummy.x .. "," .. dummy.y] = os.clock() + 20
                            if sleep then sleep(500) end
                        end
                    end
                end
            end
            if sleep then sleep(100) end
        end
        enableFly(false)
    end

    if runThread then
        runThread(worker)
    elseif runCoroutine then
        runCoroutine(worker)
    else
        local co = coroutine.create(worker)
        coroutine.resume(co)
    end
end

-- ====================================
-- SURGERY DIALOG ENGINE (ONVARIANT)
-- ====================================
function onVariant(var, pkt)
    local v1 = var.v1 or (var.get and var:get(0) and var:get(0):getString()) or var[0] or var[1]
    if type(v1) ~= "string" then return false end

    if v1 == "OnDialogRequest" then
        local dialog = var.v2 or (var.get and var:get(1) and var:get(1):getString()) or var[1] or var[2]
        if type(dialog) ~= "string" then return false end

        -- 1. Check Low Supply Warning on Surg-E pre-popup
        if dialog:find("Low Supply Warning:") or dialog:find("Low Supply Warning") then
            local lowName = dialog:match("You only have [^|]*``%s*([^\r\n|]+)") or "Surgical Stitches"
            lowName = lowName:gsub("`.", ""):match("^%s*(.-)%s*$")
            lowSupplyItem = lowName
            isSurgeryActive = false

            if sendPacket then
                sendPacket(2, "action|dialog_return\ndialog_name|surge\nbuttonClicked|cancel\n")
            end
            notifyUser("`4[Low Supply Warning]`o " .. lowName .. "! Collecting...")
            return true
        end

        -- 2. Check Surg-E pre-popup (Accept surgery)
        if dialog:find("end_dialog|surge|Cancel|Okay!|") then
            if (autoWrenchEnabled or autoSurgEnabled) and is_authenticated then
                local tilex = dialog:match("tilex|(%d+)")
                local tiley = dialog:match("tiley|(%d+)")
                isSurgeryActive = true
                if tilex and tiley then
                    currentOperatingDummy = {x = tonumber(tilex), y = tonumber(tiley)}
                end
                if sendPacket then
                    sendPacket(2, "action|dialog_return\ndialog_name|surge\ntilex|" .. (tilex or "") .. "|\ntiley|" .. (tiley or "") .. "|\n")
                end
                return true
            end
        end

        -- 3. Only run tool actions if autoSurgEnabled is ON and authenticated
        if not autoSurgEnabled or not is_authenticated then return false end

        if dialog:find("add_button|surgery|`%$Perform Surgery``|noflags|0|0|") then
            local netID = dialog:match("netID|(%d+)")
            if sendPacket and netID then
                sendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|" .. netID .. "|\nbuttonClicked|surgery")
            end
            return true
        end

        if (dialog:find("heart has stopped") or dialog:find("Heart stopped")) and dialog:find("tool4312") then
            if sleep then sleep(50) end
            useTool("Defibrillator")
            return true
        end

        if dialog:find("You succeeded") or dialog:find("You failed") or dialog:find("destroyed in the process") or dialog:find("The patient survived") or dialog:find("patient died") or dialog:find("Surgery Summary") then
            isSurgeryActive = false
            if currentOperatingDummy then
                failedTiles[currentOperatingDummy.x .. "," .. currentOperatingDummy.y] = os.clock() + 180
            end
        end

        local rules = {
            { tool = "Anesthetic",    need = { "`4The patient wakes up!",              "tool1262" } },
            { tool = "Anesthetic",    need = { "`4The patient screams and flails!",    "tool1262" } },
            { tool = "Defibrillator", need = { "Status: `4Heart stopped!",             "tool4312" } },
            { tool = "Anesthetic",    need = { "Status: `6Coming to",                  "tool1262" } },
            { tool = "Transfusion",   need = { "Pulse: `4",                            "tool4310" } },
            { tool = "Antibiotic",    need = { "Temp: `4",                             "tool1266" } },
            { tool = "Lab kit",       need = { "Temp: `4",                             "tool4318" } },
            { tool = "Antibiotic",    need = { "Temp: `6",                             "tool1266" } },
            { tool = "Lab kit",       need = { "Temp: `6",                             "tool4318" } },
            { tool = "Antibiotic",    need = { "Temp: `3",                             "tool1266" } },
            { tool = "Lab kit",       need = { "Temp: `3",                             "tool4318" } },
            { tool = "Clamp",         need = { "Patient is losing blood `4very quickly!", "tool4314" } },
            { tool = "Stitches",      need = { "Patient is losing blood `4very quickly!", "tool1270" } },
            { tool = "Clamp",         need = { "Patient is `6losing blood!",           "tool4314" } },
            { tool = "Stitches",      need = { "Patient is `6losing blood!",           "tool1270" } },
            { tool = "Fix it",        need = { "tool1296" } },
            { tool = "Fix it",        need = { "Incisions: `20",                       "tool1296" } },
            { tool = "Fix it",        need = { "Incisions: `30",                       "tool1296" } },
            { tool = "Ultrasound",    need = { "The patient has not been diagnosed.",  "tool4316" } },
            { tool = "Anesthetic",    need = { "Status: `4Awake",                      "tool1262" } },
            { tool = "Splint",        need = { "Bones: `6", " broken``",               "tool1268" } },
            { tool = "Splint",        need = { "Bones: `4", " broken``",               "tool1268" } },
            { tool = "Stitches",      need = { "Patient broke his arm.",               "tool1270" } },
            { tool = "Anesthetic",    need = { "Status: `3Awake",                      "tool1262" } },
            { tool = "Transfusion",   need = { "Pulse: `6",                            "tool4310" } },
            { tool = "Defibrillator", need = { "The patient's heart has stopped!",    "tool4312" } },
            { tool = "Sponge",        need = { "`4You can't see what you are doing!",  "tool1258" } },
            { tool = "Pins",          need = { "Bones: `6", ", `6", " shattered",     "tool4308" } },
            { tool = "Scalpel",       need = { "Bones: `6", ", `6", " shattered",     "tool1260" } },
            { tool = "Pins",          need = { "Bones: `4", ", `6", " shattered",     "tool4308" } },
            { tool = "Scalpel",       need = { "Bones: `4", ", `6", " shattered",     "tool1260" } },
            { tool = "Pins",          need = { "Bones: `6", ", `4", " shattered",     "tool4308" } },
            { tool = "Scalpel",       need = { "Bones: `6", ", `4", " shattered",     "tool1260" } },
            { tool = "Pins",          need = { "Bones: `4", ", `4", " shattered",     "tool4308" } },
            { tool = "Scalpel",       need = { "Bones: `4", ", `4", " shattered",     "tool1260" } },
            { tool = "Pins",          need = { "Bones: `6", " shattered",             "tool4308" } },
            { tool = "Scalpel",       need = { "Bones: `6", " shattered",             "tool1260" } },
            { tool = "Pins",          need = { "Bones: `4", " shattered",             "tool4308" } },
            { tool = "Scalpel",       need = { "Bones: `4", " shattered",             "tool1260" } },
            { tool = "Stitches",      need = { "Incisions: `6",                        "tool1270" } },
            { tool = "Stitches",      need = { "Patient broke his leg.",               "tool1270" } },
            { tool = "Clamp",         need = { "Patient is losing blood `3slowly.",   "tool4314" } },
            { tool = "Scalpel",       need = { "tool1260" } },
        }

        for _, rule in ipairs(rules) do
            local ok = true
            for _, pattern in ipairs(rule.need) do
                if not dialog:find(pattern, 1, true) then
                    ok = false
                    break
                end
            end
            if ok then
                useTool(rule.tool)
                return true
            end
        end
    end

    return false
end

-- ====================================
-- PURPLE IMGUI INTERFACE & CONTROLS
-- ====================================
local function purpleButton(label, height)
    local h = height or 28
    local pushed = false
    if ImGui and ImGui.PushStyleColor and ImVec4 then
        pcall(function()
            ImGui.PushStyleColor(21, ImVec4(0.48, 0.36, 0.98, 1.0))
            ImGui.PushStyleColor(22, ImVec4(0.58, 0.46, 1.00, 1.0))
            ImGui.PushStyleColor(23, ImVec4(0.40, 0.28, 0.88, 1.0))
            pushed = true
        end)
    end

    local clicked = false
    if ImVec2 then
        clicked = ImGui.Button(label, ImVec2(-1, h))
    else
        clicked = ImGui.Button(label)
    end

    if pushed and ImGui and ImGui.PopStyleColor then
        pcall(function() ImGui.PopStyleColor(3) end)
    end
    return clicked
end

local function darkButton(label, height)
    local h = height or 28
    local pushed = false
    if ImGui and ImGui.PushStyleColor and ImVec4 then
        pcall(function()
            ImGui.PushStyleColor(21, ImVec4(0.18, 0.19, 0.26, 1.0))
            ImGui.PushStyleColor(22, ImVec4(0.24, 0.26, 0.35, 1.0))
            ImGui.PushStyleColor(23, ImVec4(0.14, 0.15, 0.20, 1.0))
            pushed = true
        end)
    end

    local clicked = false
    if ImVec2 then
        clicked = ImGui.Button(label, ImVec2(-1, h))
    else
        clicked = ImGui.Button(label)
    end

    if pushed and ImGui and ImGui.PopStyleColor then
        pcall(function() ImGui.PopStyleColor(3) end)
    end
    return clicked
end

local function safeTextColored(r, g, b, text)
    local ok = false
    if ImGui and ImGui.TextColored and ImVec4 then
        ok = pcall(function() ImGui.TextColored(ImVec4(r, g, b, 1.0), text) end)
    end
    if not ok and ImGui and ImGui.Text then
        ImGui.Text(text)
    end
end

function onDrawImGui(delta)
    if not imgui_opened then return end

    if ImGui.SetNextWindowSize and ImVec2 then
        pcall(function() ImGui.SetNextWindowSize(ImVec2(330, 480), 4) end)
    end

    if ImGui.Begin("AutoSurg // Zama Store") then
        -- 1. HEADER & HIDE BUTTON
        safeTextColored(0.70, 0.60, 1.0, "[*] AutoSurg // Zama Store")
        safeTextColored(0.65, 0.68, 0.78, "Surg-E & Surgery Automation")
        if ImGui.SameLine then ImGui.SameLine() end
        if darkButton("Hide GUI##hide_top", 22) then
            imgui_opened = false
            if editToggle then pcall(function() editToggle("enable_autosurg_imgui", false) end) end
            if editValue then pcall(function() editValue("enable_autosurg_imgui", false) end) end
            if saved then saved:set("opened", false) saved:save() end
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 2. AUTH SECTION
        safeTextColored(1.0, 0.84, 0.0, "=== KEY AUTHENTICATION ===")
        if purpleButton("Get Key (Free)##get_key_btn", 28) then
            notifyUser("Get key in Discord: discord.gg/ekuVdjF4F9 (Command: /freekey AutoSurg)")
        end

        ImGui.Text("Key:")
        if ImGui.InputText then
            local changed, newTxt = ImGui.InputText("##key_in", keyInputBuffer, 64)
            if changed and newTxt then
                keyInputBuffer = newTxt
            end
        end

        if purpleButton("Verify Key##verify_btn", 28) then
            local k = (keyInputBuffer or ""):gsub("%s+", "")
            if k == "vip" or k == "premium" or k:lower() == "zama" or k:sub(1,3) == "FK-" or #k >= 4 then
                is_authenticated = true
                user_tier = (k == "vip" or k == "premium") and "PREMIUM" or "FREE"
                keyStatusText = "Status: [ Verified (" .. user_tier .. ") ]"
                notifyUser("`2[AutoSurg] Key Verified! Access Granted (" .. user_tier .. ")")

                if saved then
                    saved:set("auth_key", keyInputBuffer)
                    saved:save()
                end
            else
                is_authenticated = false
                keyStatusText = "Status: [ Invalid Key! ]"
                notifyUser("`4[AutoSurg] Invalid Key! Get key from Discord: discord.gg/ekuVdjF4F9")
            end
        end

        -- Key Status Badge
        if is_authenticated then
            safeTextColored(0.3, 1.0, 0.4, keyStatusText)
        else
            safeTextColored(1.0, 0.35, 0.35, keyStatusText)
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 3. SURGERY AUTOMATION CONTROLS
        safeTextColored(0.35, 0.85, 1.0, "=== SURGERY AUTOMATION ===")

        -- Master Enable Toggle Button
        local masterActive = autoSurgEnabled and autoWrenchEnabled
        local masterBtnLabel = masterActive and "Master Enable: [ ON ]##master_tog" or "Master Enable: [ OFF ]##master_tog"
        local masterClicked = masterActive and purpleButton(masterBtnLabel, 30) or darkButton(masterBtnLabel, 30)

        if masterClicked then
            if not is_authenticated then
                notifyUser("`4[AutoSurg] Access Denied! Please verify key first.")
            else
                local newState = not masterActive
                autoSurgEnabled = newState
                autoWrenchEnabled = newState
                if newState then
                    notifyUser("`2[AutoSurg] Master Enabled!")
                    startAutoWrenchLoop()
                else
                    notifyUser("`4[AutoSurg] Master Disabled!")
                    isSurgeryActive = false
                    currentOperatingDummy = nil
                    enableFly(false)
                end
            end
        end

        -- Auto Surg (Tools) Button
        local surgLabel = autoSurgEnabled and "Auto Surg (Tools) [ ON ]##surg_tog" or "Auto Surg (Tools) [ OFF ]##surg_tog"
        local surgClicked = autoSurgEnabled and purpleButton(surgLabel, 28) or darkButton(surgLabel, 28)
        if surgClicked then
            if not is_authenticated then
                notifyUser("`4[AutoSurg] Access Denied! Please verify key first.")
            else
                autoSurgEnabled = not autoSurgEnabled
                if autoSurgEnabled then
                    notifyUser("`2Auto Surg Tools Enabled")
                else
                    notifyUser("`4Auto Surg Tools Disabled")
                end
            end
        end

        -- Auto Wrench Surg-E Button
        local wrenchLabel = autoWrenchEnabled and "Auto Wrench Surg-E [ ON ]##wrench_tog" or "Auto Wrench Surg-E [ OFF ]##wrench_tog"
        local wrenchClicked = autoWrenchEnabled and purpleButton(wrenchLabel, 28) or darkButton(wrenchLabel, 28)
        if wrenchClicked then
            if not is_authenticated then
                notifyUser("`4[AutoSurg] Access Denied! Please verify key first.")
            else
                autoWrenchEnabled = not autoWrenchEnabled
                if autoWrenchEnabled then
                    notifyUser("`2Auto Wrench Enabled")
                    startAutoWrenchLoop()
                else
                    notifyUser("`4Auto Wrench Disabled")
                    isSurgeryActive = false
                    currentOperatingDummy = nil
                    enableFly(false)
                end
            end
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 4. LIVE STATUS & FOOTER
        local actText = isSurgeryActive and "OPERATING SURGERY..." or (autoWrenchEnabled and "SEARCHING SURG-E..." or "STANDBY (IDLE)")
        safeTextColored(0.4, 0.85, 1.0, "Activity: " .. actText)

        if purpleButton("Refresh Status##refresh_btn", 26) then
            notifyUser("`9[AutoSurg Status] `oActivity: `2" .. actText)
        end

        safeTextColored(0.5, 0.7, 1.0, "Discord: discord.gg/ekuVdjF4F9")

        ImGui.End()
    end
end
OnDrawImGui = onDrawImGui

-- ====================================
-- GROWLAUNCHER NATIVE MODULE (TOGGLE ON/OFF IMGUI)
-- ====================================
function onValue(type, name, value)
    if name == "enable_autosurg_imgui" then
        imgui_opened = value
        if saved then
            saved:set("opened", value)
            saved:save()
        end
        if value then
            notifyUser("`2[AutoSurg] ImGui Window Opened")
        else
            notifyUser("`4[AutoSurg] ImGui Window Hidden")
        end
    elseif name == "btn_refresh_surg" then
        local act = isSurgeryActive and "OPERATING SURGERY" or (autoWrenchEnabled and "SEARCHING SURG-E" or "STANDBY (IDLE)")
        notifyUser("`9[AutoSurg Status] `oActivity: `2" .. act)
    elseif name == "btn_stop_script" then
        turnOffAutoSurg("Script Unloaded")
        imgui_opened = false

        pcall(function()
            if removeHook then
                removeHook("onvariant")
                removeHook("onVariant")
                removeHook("onvalue")
                removeHook("onValue")
                removeHook("ondrawimgui")
                removeHook("onDrawImGui")
            end
        end)

        pcall(function()
            if addIntoModule then
                addIntoModule("{}", "ImGui")
            end
        end)
    end
end
OnValue = onValue

-- Register hooks cleanly
if addHook then
    pcall(function() addHook(onVariant, "onVariant") end)
    pcall(function() addHook(onValue, "onValue") end)
    pcall(function() addHook(onDrawImGui, "onDrawImGui") end)
end

if applyHook then pcall(applyHook) end

-- Build and Register Native Module UI under ImGui Category
pcall(function()
    if UserInterface and UserInterface.new then
        local ui = UserInterface.new("AutoSurg", "Wysiwyg")
        ui:addLabelApp("AutoSurg", "Wysiwyg")
        ui:addTooltip("Information", "Surg-E & Surgery Automation // Zama Store", "Info", false)
        ui:addToggle("Enable ImGui", true, "enable_autosurg_imgui", false)
        ui:addButton("Refresh Status", "btn_refresh_surg")
        ui:addButton("Stop Script (Unload)", "btn_stop_script")

        local json = ui:generateJSON()

        if addCategory then
            pcall(function() addCategory("ImGui", "Wysiwyg") end)
        end

        if addIntoModule then
            pcall(function() addIntoModule(json, "ImGui") end)
        end
    end
end)

notifyUser("AutoSurg by zama")