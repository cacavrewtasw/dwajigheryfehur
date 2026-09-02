-- ==========================================
-- TestAuthAndSurg.lua (Growlauncher Test File)
-- Modern Purple Card UI (Vend Master Style - Fixed)
-- ==========================================
local is_authenticated = true
local user_tier = "PREMIUM"
local autoSurgEnabled = false
local autoWrenchEnabled = false
local isSurgeryActive = false
local lowSupplyItem = nil
local currentOperatingDummy = nil
local failedTiles = {}
local autoWrenchRunning = false
local wrenchSessionId = 0
local keyInputBuffer = "vip"
local keyStatusText = "Status: [ Verified - VIP Lifetime ]"

-- Cleanup old hooks
pcall(function()
    if removeHook then
        removeHook("onDrawImGui")
        removeHook("OnDrawImGui")
        removeHook("on_draw_imgui")
        removeHook("onVariant")
        removeHook("OnVariant")
    end
end)

-- Safe Notification Helper
local function notifyUser(text)
    if growtopia and growtopia.notify then
        pcall(function() growtopia.notify(text) end)
    elseif logToConsole then
        pcall(function() logToConsole(text) end)
    elseif print then
        print(text)
    end
end

notifyUser("`9[AutoSurg Test] `2Module Active! Check `6'AutoSurg' `2or `6'Scripts' `2tab in Growlauncher.")

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

local function enableFly(enable)
    if toggleCheat then
        pcall(function() toggleCheat(1, enable) end)
    elseif setCheat then
        pcall(function() setCheat("Fly", enable) end)
    end
end

local function isTileReachable(tileX, tileY)
    local t = getTileAt(tileX, tileY)
    if not t then return true end
    local fg = t.fg or (t.getFg and t.getFg()) or (t.header and t.header.fg) or 0
    if fg ~= 0 then return false end
    return true
end

local function findAdjacentWalkableTile(targetX, targetY)
    local currentX, currentY = getPosXY()
    local bestX, bestY = nil, nil
    local bestDist = 999999

    local offsets = {
        {0, 0},
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}
    }

    for _, off in ipairs(offsets) do
        local checkX = targetX + off[1]
        local checkY = targetY + off[2]
        if isTileReachable(checkX, checkY) then
            local dist = math.abs(currentX - checkX) + math.abs(currentY - checkY)
            if dist < bestDist then
                bestDist = dist
                bestX = checkX
                bestY = checkY
            end
        end
    end

    if bestX and bestY then
        return bestX, bestY
    end
    return targetX, targetY
end

local function goToDummy(targetX, targetY, session)
    local destX, destY = findAdjacentWalkableTile(targetX, targetY)

    local function callFindPath(x, y)
        if findPath then return findPath(x, y)
        elseif FindPath then return FindPath(x, y)
        end
        return false
    end

    local function checkDistanceToGoal()
        local curX, curY = getPosXY()
        return math.abs(curX - targetX) <= 1 and math.abs(curY - targetY) <= 1
    end

    if checkDistanceToGoal() then
        return true
    end

    local maxTries = 40
    local tries = 0

    while tries < maxTries do
        if session and (session ~= wrenchSessionId or not autoWrenchEnabled) then
            return false
        end

        local curX, curY = getPosXY()
        if checkDistanceToGoal() then
            return true
        end

        local diffX = destX - curX
        local diffY = destY - curY
        local stepX = math.max(-4, math.min(4, diffX))
        local stepY = math.max(-4, math.min(4, diffY))

        local nextX = curX + stepX
        local nextY = curY + stepY

        local ok = callFindPath(nextX, nextY)
        if not ok then
            callFindPath(destX, destY)
        end

        if sleep then sleep(180) end

        local newX, newY = getPosXY()
        if newX == curX and newY == curY and (diffX ~= 0 or diffY ~= 0) then
            callFindPath(destX, destY)
            if sleep then sleep(220) end
        end

        if checkDistanceToGoal() then
            return true
        end

        tries = tries + 1
    end

    return checkDistanceToGoal()
end

-- ====================================
-- AUTO SURG & SURG-E CORE LOGIC
-- ====================================
local item_ids = {
    SPONGE = 1258,
    SCALPEL = 1260,
    ANESTHETIC = 1262,
    ANTISEPTIC = 1264,
    ANTIBIOTIC = 1266,
    SPLINT = 1268,
    PINS = 1270,
    TRANSFUSION = 4308,
    DEFIBRILLATOR = 4310,
    LABKIT = 4312,
    STITCHES = 4314,
    ULTRASOUND = 4316,
    SURG_E = 4296
}

local function getItemIdByName(name)
    if type(name) == "number" then return name end
    if type(name) == "string" then
        if name:find("Stitches") then return 1270
        elseif name:find("Antibiotic") then return 1266
        elseif name:find("Antiseptic") then return 1264
        elseif name:find("Anesthetic") then return 1262
        elseif name:find("Scalpel") then return 1260
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
    return 1270
end

local function useTool(tool)
    local toolId = getItemIdByName(tool)
    local pkt = "action|dialog_return\ndialog_name|surgery\nbuttonClicked|tool" .. tostring(toolId) .. "\n"
    if sendPacket then
        sendPacket(2, pkt)
    elseif SendPacket then
        SendPacket(2, pkt)
    end
end

local function wrenchDummy(x, y)
    if wrenchTile then
        wrenchTile(x, y)
    elseif sendPacketRaw then
        local p = {
            type = 3,
            value = 32,
            px = x,
            py = y,
            x = x * 32,
            y = y * 32
        }
        sendPacketRaw(false, p)
    end
end

local function scanForSurgEDummy()
    local currentX, currentY = getPosXY()
    local bestTile = nil
    local bestDistance = 999999

    for y = 0, 59 do
        for x = 0, 99 do
            local key = x .. "," .. y
            if not failedTiles[key] then
                local t = getTileAt(x, y)
                if t then
                    local fg = t.fg or (t.getFg and t.getFg()) or (t.header and t.header.fg) or 0
                    if fg == item_ids.SURG_E then
                        local dist = math.abs(currentX - x) + math.abs(currentY - y)
                        if dist < bestDistance then
                            bestDistance = dist
                            bestTile = {x = x, y = y}
                        end
                    end
                end
            end
        end
    end
    return bestTile
end

local function startAutoWrenchLoop()
    if autoWrenchRunning then return end
    autoWrenchRunning = true
    wrenchSessionId = wrenchSessionId + 1
    local mySession = wrenchSessionId

    local function loop()
        enableFly(true)
        while autoWrenchEnabled and mySession == wrenchSessionId do
            if not isSurgeryActive then
                local dummy = scanForSurgEDummy()
                if dummy then
                    currentOperatingDummy = dummy
                    local reached = goToDummy(dummy.x, dummy.y, mySession)
                    if reached and autoWrenchEnabled and mySession == wrenchSessionId then
                        wrenchDummy(dummy.x, dummy.y)
                        if sleep then sleep(500) end
                    else
                        local key = dummy.x .. "," .. dummy.y
                        failedTiles[key] = true
                        if sleep then sleep(300) end
                    end
                else
                    failedTiles = {}
                    if sleep then sleep(1000) end
                end
            else
                if sleep then sleep(300) end
            end
        end
        enableFly(false)
        autoWrenchRunning = false
    end

    if runThread then
        runThread(loop)
    elseif RunThread then
        RunThread(loop)
    else
        loop()
    end
end

-- ====================================
-- SURGERY DIALOG ENGINE (ONVARIANT)
-- ====================================
local function onVariant(var)
    local v1 = var.v1 or (var.get and var:get(0) and var:get(0):getString()) or var[0] or var[1]
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
        notifyUser(value and "`2[AutoSurg] Tools Enabled!" or "`4[AutoSurg] Tools Disabled!")
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
        autoSurgEnabled = false
        autoWrenchEnabled = false
        isSurgeryActive = false
        currentOperatingDummy = nil
        enableFly(false)
        if editValue then
            pcall(function() editValue("surg_master_toggle", false) end)
            pcall(function() editValue("surg_tools_toggle", false) end)
            pcall(function() editValue("surg_wrench_toggle", false) end)
        end
        notifyUser("`4[AutoSurg] All operations stopped!")
    elseif alias == "btn_refresh_surg" then
        local act = isSurgeryActive and "OPERATING SURGERY" or (autoWrenchEnabled and "SEARCHING SURG-E" or "STANDBY (IDLE)")
        notifyUser("`9[AutoSurg Status] `oActivity: `2" .. act)
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
    end)
end

-- Global hook function for module value changes
function OnValue(menuType, name, value)
    handleValue(name, value)
end
onValue = OnValue

local function safeRegisterHook(func, hookName)
    if addHook then pcall(function() addHook(func, hookName) end) end
    if AddHookCallback then pcall(function() AddHookCallback(func, hookName) end) end
    if AddHook then pcall(function() AddHook(hookName, "ZamaHook", func) end) end
end

-- Register hooks for variant and module value
safeRegisterHook(onVariant, "onVariant")
safeRegisterHook(onVariant, "OnVariant")
safeRegisterHook(onVariant, "on_variant")
safeRegisterHook(OnValue, "onValue")
safeRegisterHook(OnValue, "OnValue")

-- Build and Register Native Module UI (Only 1 single category: AutoSurg)
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
