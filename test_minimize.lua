-- ==========================================
-- AutoSurg + Auto Wrench Surg-E by zama10
-- Module Integration for Growlauncher
-- Discord: discord.gg/ekuVdjF4F9
-- ==========================================

-- Cleanup old hooks on rerun
pcall(function()
    if removeHook then
        removeHook("onvariant")
        removeHook("onvalue")
        removeHook("onVariant")
        removeHook("OnVariant")
        removeHook("onValue")
        removeHook("OnValue")
    end
end)

local autoSurgEnabled = false
local autoWrenchEnabled = false
local isSurgeryActive = false
local lowSupplyItem = nil
local currentOperatingDummy = nil
local failedTiles = {}
local wrenchSessionId = 0
local isInitialized = false

-- ====================================
-- NOTIFICATION (ONLY growtopia.notify)
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

        if dx == 0 and dy == 0 then
            break
        end

        local stepX = px
        local stepY = py

        -- Step 4-5 tiles towards target
        if math.abs(dx) <= 4 then
            stepX = targetX
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
                if (curX == stepX and curY == stepY) or not autoWrenchEnabled or (session and wrenchSessionId ~= session) then
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

    if editValue then
        pcall(function() editValue("surg_master_toggle", false) end)
        pcall(function() editValue("surg_tools_toggle", false) end)
        pcall(function() editValue("surg_wrench_toggle", false) end)
    end

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
            if autoWrenchEnabled or autoSurgEnabled then
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

        -- 3. Only run tool actions if autoSurgEnabled is ON
        if not autoSurgEnabled then return false end

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

        if dialog:find("You succeeded") or dialog:find("You failed") or dialog:find("destroyed in the process") then
            isSurgeryActive = false
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
-- GROWLAUNCHER NATIVE MODULE INTEGRATION
-- ====================================
local function handleValue(alias, value)
    -- Guard: Ignore default launcher value events while initializing
    if not isInitialized then
        if alias == "surg_master_toggle" then
            autoSurgEnabled = value
            autoWrenchEnabled = value
        elseif alias == "surg_tools_toggle" then
            autoSurgEnabled = value
        elseif alias == "surg_wrench_toggle" then
            autoWrenchEnabled = value
        end
        return
    end

    if alias == "surg_master_toggle" then
        autoSurgEnabled = value
        autoWrenchEnabled = value
        if value then
            notifyUser("`2[AutoSurg] Master Enabled!")
            startAutoWrenchLoop()
        else
            notifyUser("`4[AutoSurg] Master Disabled!")
            isSurgeryActive = false
            currentOperatingDummy = nil
            enableFly(false)
        end
    elseif alias == "surg_tools_toggle" then
        autoSurgEnabled = value
    elseif alias == "surg_wrench_toggle" then
        autoWrenchEnabled = value
        if value then
            notifyUser("`2[AutoSurg] Auto Wrench Enabled!")
            startAutoWrenchLoop()
        else
            notifyUser("`4[AutoSurg] Auto Wrench Disabled!")
            isSurgeryActive = false
            currentOperatingDummy = nil
            enableFly(false)
        end
    elseif alias == "btn_stop_all_surg" then
        turnOffAutoSurg("Manual Stop")
    elseif alias == "btn_refresh_surg" then
        local act = isSurgeryActive and "OPERATING SURGERY" or (autoWrenchEnabled and "SEARCHING SURG-E" or "STANDBY (IDLE)")
        notifyUser("`9[AutoSurg Status] `oActivity: `2" .. act)
    elseif alias == "btn_stop_script" then
        -- 1. Stop all operations and loops
        turnOffAutoSurg("Script Unloaded")

        -- 2. Remove all hooks
        pcall(function()
            if removeHook then
                removeHook("onvariant")
                removeHook("onvalue")
                removeHook("onVariant")
                removeHook("OnVariant")
                removeHook("onValue")
                removeHook("OnValue")
            end
        end)

        -- 3. Clear module via official addIntoModule("{}") API
        pcall(function()
            if addIntoModule then
                addIntoModule("{}", "AutoSurg")
            end
        end)
    end
end

-- Hook into module events via setOnValue if available
if setOnValue then
    pcall(function()
        setOnValue("surg_master_toggle", function(val) handleValue("surg_master_toggle", val) end)
        setOnValue("surg_tools_toggle", function(val) handleValue("surg_tools_toggle", val) end)
        setOnValue("surg_wrench_toggle", function(val) handleValue("surg_wrench_toggle", val) end)
        setOnValue("btn_stop_all_surg", function(val) handleValue("btn_stop_all_surg", val) end)
        setOnValue("btn_refresh_surg", function(val) handleValue("btn_refresh_surg", val) end)
        setOnValue("btn_stop_script", function(val) handleValue("btn_stop_script", val) end)
    end)
end

-- Global hook function for module value changes
function OnValue(menuType, name, value)
    handleValue(name, value)
end
onValue = OnValue

-- Register hooks cleanly
if addHook then
    pcall(function() addHook(onVariant, "onvariant") end)
    pcall(function() addHook(OnValue, "onvalue") end)
end

-- Build and Register Native Module UI (Single Category: AutoSurg)
pcall(function()
    if UserInterface and UserInterface.new then
        local ui = UserInterface.new("AutoSurg", "Verified")
        ui:addLabelApp("AutoSurg // Zama Store", "Verified")
        ui:addTooltip("Information", "Surg-E & Surgery Automation", "Info", false)
        ui:addDivider()
        ui:addToggle("Master Enable", false, "surg_master_toggle", false)
        ui:addToggle("Auto Surg (Tools)", false, "surg_tools_toggle", false)
        ui:addToggle("Auto Wrench Surg-E", false, "surg_wrench_toggle", false)
        ui:addTooltip("Movement Mode", "4-5 Tiles Smooth Pathfinding (Anti-Kick)", "Verified", true)
        ui:addButton("Refresh Status", "btn_refresh_surg")
        ui:addButton("Stop All Operations", "btn_stop_all_surg")
        ui:addButton("Stop Script (Unload)", "btn_stop_script")

        local json = ui:generateJSON()

        if addCategory then
            pcall(function() addCategory("AutoSurg", "Verified") end)
        end

        if addIntoModule then
            pcall(function() addIntoModule(json, "AutoSurg") end)
        end
    end
end)

if applyHook then pcall(applyHook) end

-- Mark initialization complete and show single startup notice
isInitialized = true
notifyUser("AutoSurg by zama")