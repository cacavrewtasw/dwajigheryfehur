-- ==========================================
-- TestAuthAndSurg.lua (Growlauncher Test File)
-- Modern Purple Card UI (Vend Master Style)
-- ==========================================
local is_authenticated = true -- Enabled by default for direct UI testing!
local user_tier = "PREMIUM"
local autoSurgEnabled = false
local autoWrenchEnabled = false
local isSurgeryActive = false
local lowSupplyItem = nil
local currentOperatingDummy = nil
local failedTiles = {}
local autoWrenchRunning = false
local wrenchSessionId = 0
local script_name = "AutoSurg (ZamaStore)"
local enteredKey = "vip"
local keyStatusText = "Status: `2Verified (VIP Lifetime)``"

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

notifyUser("`9[AutoSurg Test] `2UI Loaded Successfully! Opening Menu...")

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

local function useTool(itemID)
    local pkt = "action|dialog_return\ndialog_name|surgery\nbuttonClicked|tool" .. tostring(itemID) .. "\n"
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
-- MODERN PURPLE CARD UI (VEND MASTER STYLE)
-- ====================================
local keyInputBuffer = "vip"

local function zamaImGuiLoop()
    -- Safe Style Application
    local stylePushed = 0
    if ImGui and ImGui.PushStyleColor and ImVec4 then
        pcall(function()
            ImGui.PushStyleColor(2, ImVec4(0.09, 0.10, 0.14, 0.96))  -- WindowBg (Dark slate navy)
            ImGui.PushStyleColor(5, ImVec4(0.28, 0.24, 0.45, 0.50))  -- Border
            ImGui.PushStyleColor(7, ImVec4(0.13, 0.14, 0.20, 1.00))  -- FrameBg
            ImGui.PushStyleColor(21, ImVec4(0.48, 0.36, 0.98, 1.00)) -- Button (#7B5CFA Purple)
            ImGui.PushStyleColor(22, ImVec4(0.56, 0.44, 1.00, 1.00)) -- ButtonHovered
            ImGui.PushStyleColor(23, ImVec4(0.40, 0.28, 0.88, 1.00)) -- ButtonActive
            stylePushed = 6
        end)
    end

    if ImGui.SetNextWindowSize and ImVec2 then
        pcall(function() ImGui.SetNextWindowSize(ImVec2(320, 480), 4) end)
    end

    local winOpen = ImGui.Begin("Auto Surg##vend_autosurg")
    if winOpen then
        -- 1. HEADER SECTION (Card with badge + Title)
        if ImGui.TextColored and ImVec4 then
            pcall(function() ImGui.TextColored(ImVec4(0.65, 0.55, 1.0, 1.0), "[*] Auto Surg") end)
            pcall(function() ImGui.TextColored(ImVec4(0.60, 0.62, 0.72, 1.0), "Zama Store // Surgery Assistant") end)
        else
            ImGui.Text("[*] Auto Surg")
            ImGui.Text("Zama Store // Surgery Assistant")
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 2. GET KEY BUTTON (Purple Pill)
        local btnW = (ImGui.GetContentRegionAvailWidth and ImGui.GetContentRegionAvailWidth()) or 0
        local btnSize = ImVec2 and ImVec2(btnW, 32) or nil
        
        local getPressed = false
        if btnSize then
            getPressed = ImGui.Button("Get Key (Free)##get_key", btnSize)
        else
            getPressed = ImGui.Button("Get Key (Free)##get_key")
        end
        if getPressed then
            notifyUser("`oDiscord: `bdiscord.gg/ekuVdjF4F9 `o(Use /freekey)")
        end

        -- 3. KEY INPUT & VERIFY (Matching screenshot)
        ImGui.Text("Key")
        if ImGui.InputText then
            local changed, newKey = pcall(function()
                return ImGui.InputText("##key_input", keyInputBuffer, 64)
            end)
            if changed and type(newKey) == "string" then
                keyInputBuffer = newKey
            end
        end

        local verifyPressed = false
        if btnSize then
            verifyPressed = ImGui.Button("Verify Key##verify_btn", btnSize)
        else
            verifyPressed = ImGui.Button("Verify Key##verify_btn")
        end
        if verifyPressed then
            if keyInputBuffer == "vip" or keyInputBuffer == "premium" then
                user_tier = "PREMIUM"
                is_authenticated = true
                keyStatusText = "Status: `2Verified (VIP Lifetime)``"
                notifyUser("`2[AutoSurg] Verified as VIP Lifetime!")
            elseif keyInputBuffer == "1234" then
                user_tier = "FREE"
                is_authenticated = true
                keyStatusText = "Status: `2Verified (Free Session)``"
                notifyUser("`2[AutoSurg] Verified as Free Session!")
            else
                keyStatusText = "Status: `4Invalid Key! (Try 'vip' or '1234')``"
                notifyUser("`4[AutoSurg] Invalid key! Use 'vip' or '1234'.")
            end
        end

        -- 4. STATUS LINE
        if ImGui.TextColored and ImVec4 then
            if is_authenticated then
                pcall(function() ImGui.TextColored(ImVec4(0.3, 1.0, 0.4, 1.0), keyStatusText) end)
            else
                pcall(function() ImGui.TextColored(ImVec4(1.0, 0.3, 0.3, 1.0), keyStatusText) end)
            end
        else
            ImGui.Text(keyStatusText)
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 5. ENABLE / MASTER TOGGLE (Matching screenshot)
        local masterActive = autoSurgEnabled or autoWrenchEnabled
        local masterLabel = masterActive and "Enable: [ ON ]##master" or "Enable: [ OFF ]##master"
        local masterPressed = false
        if btnSize then
            masterPressed = ImGui.Button(masterLabel, btnSize)
        else
            masterPressed = ImGui.Button(masterLabel)
        end
        if masterPressed then
            local newState = not masterActive
            autoSurgEnabled = newState
            autoWrenchEnabled = newState
            if newState then
                notifyUser("`2[AutoSurg] All Features Enabled!")
                startAutoWrenchLoop()
            else
                notifyUser("`4[AutoSurg] All Features Disabled!")
                isSurgeryActive = false
                currentOperatingDummy = nil
                enableFly(false)
            end
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 6. MODE SECTION & ACTION PILL BUTTONS (Matching screenshot)
        if ImGui.TextColored and ImVec4 then
            pcall(function() ImGui.TextColored(ImVec4(1.0, 0.45, 0.45, 1.0), "Mode: Surg-E Auto Farm") end)
        else
            ImGui.Text("Mode: Surg-E Auto Farm")
        end

        -- Set Add Stock / Auto Surg Pill
        local surgPillLabel = autoSurgEnabled and "Set Auto Surg (Tools) [ON]##surg" or "Set Auto Surg (Tools) [OFF]##surg"
        local sPressed = false
        if btnSize then
            sPressed = ImGui.Button(surgPillLabel, btnSize)
        else
            sPressed = ImGui.Button(surgPillLabel)
        end
        if sPressed then
            autoSurgEnabled = not autoSurgEnabled
            notifyUser(autoSurgEnabled and "`2Auto Surg Tools Enabled" or "`4Auto Surg Tools Disabled")
        end

        -- Set Empty Stock / Smooth Move Pill
        local stepPressed = false
        if btnSize then
            stepPressed = ImGui.Button("4-5 Tiles Smooth Move (Active)##step", btnSize)
        else
            stepPressed = ImGui.Button("4-5 Tiles Smooth Move (Active)##step")
        end
        if stepPressed then
            notifyUser("`2[AutoSurg] Smooth Pathfinding is Active!")
        end

        -- Set Lock Withdraw / Auto Wrench Pill
        local wrenchPillLabel = autoWrenchEnabled and "Set Auto Wrench Surg-E [ON]##wr" or "Set Auto Wrench Surg-E [OFF]##wr"
        local wPressed = false
        if btnSize then
            wPressed = ImGui.Button(wrenchPillLabel, btnSize)
        else
            wPressed = ImGui.Button(wrenchPillLabel)
        end
        if wPressed then
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

        if ImGui.Separator then ImGui.Separator() end

        -- 7. STATS & LIVE INFO (Matching screenshot "WLs: 46", "Refresh Stats")
        if ImGui.TextColored and ImVec4 then
            pcall(function() ImGui.TextColored(ImVec4(0.85, 0.75, 0.4, 1.0), "WLs / Supplies: Normal") end)
            local actText = isSurgeryActive and "Activity: OPERATING..." or (autoWrenchEnabled and "Activity: SEARCHING..." or "Activity: STANDBY")
            pcall(function() ImGui.TextColored(ImVec4(0.4, 0.85, 1.0, 1.0), actText) end)
        else
            ImGui.Text("WLs / Supplies: Normal")
            ImGui.Text("Activity: STANDBY")
        end

        local refPressed = false
        if btnSize then
            refPressed = ImGui.Button("Refresh Stats##ref", btnSize)
        else
            refPressed = ImGui.Button("Refresh Stats##ref")
        end
        if refPressed then
            notifyUser("`2[AutoSurg] Stats Refreshed!")
        end

        ImGui.End()
    end

    -- Safe Pop
    if stylePushed > 0 and ImGui.PopStyleColor then
        for i = 1, stylePushed do
            pcall(function() ImGui.PopStyleColor() end)
        end
    end
end

-- ====================================
-- REGISTER HOOKS TO ALL POSSIBLE VARIANTS
-- ====================================
local function safeRegisterHook(func, hookName)
    if addHook then pcall(function() addHook(func, hookName) end) end
    if AddHookCallback then pcall(function() AddHookCallback(func, hookName) end) end
    if AddHook then pcall(function() AddHook(hookName, "ZamaHook", func) end) end
end

safeRegisterHook(zamaImGuiLoop, "onDrawImGui")
safeRegisterHook(zamaImGuiLoop, "OnDrawImGui")
safeRegisterHook(zamaImGuiLoop, "on_draw_imgui")

if applyHook then pcall(applyHook) end
