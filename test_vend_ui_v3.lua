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

notifyUser("`9[AutoSurg Test] `2UI Updated! Opening Clean Vend Menu...")

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
-- SAFE PURPLE UI RENDERING (VEND MASTER STYLE)
-- ====================================
local function purpleButton(label, height)
    local h = height or 28
    local pushed = false
    if ImGui.PushStyleColor and ImVec4 then
        pcall(function()
            -- Purple theme #7B5CFA
            ImGui.PushStyleColor(21, ImVec4(0.48, 0.36, 0.98, 1.0)) -- Button
            ImGui.PushStyleColor(22, ImVec4(0.58, 0.46, 1.00, 1.0)) -- Hovered
            ImGui.PushStyleColor(23, ImVec4(0.40, 0.28, 0.88, 1.0)) -- Active
            pushed = true
        end)
    end

    local clicked = false
    if ImVec2 then
        clicked = ImGui.Button(label, ImVec2(-1, h))
    else
        clicked = ImGui.Button(label)
    end

    if pushed and ImGui.PopStyleColor then
        pcall(function() ImGui.PopStyleColor(3) end)
    end
    return clicked
end

local function darkButton(label, height)
    local h = height or 28
    local pushed = false
    if ImGui.PushStyleColor and ImVec4 then
        pcall(function()
            -- Dark gray theme #222530
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

    if pushed and ImGui.PopStyleColor then
        pcall(function() ImGui.PopStyleColor(3) end)
    end
    return clicked
end

local function safeTextColored(r, g, b, text)
    local ok = false
    if ImGui.TextColored and ImVec4 then
        ok = pcall(function() ImGui.TextColored(ImVec4(r, g, b, 1.0), text) end)
    end
    if not ok and ImGui.Text then
        ImGui.Text(text)
    end
end

local function zamaImGuiLoop()
    -- Ensure window size
    if ImGui.SetNextWindowSize and ImVec2 then
        pcall(function() ImGui.SetNextWindowSize(ImVec2(310, 490), 4) end)
    end

    if ImGui.Begin("Auto Surg##vend_panel") then
        -- 1. HEADER CARD (Vend Master style)
        safeTextColored(0.70, 0.60, 1.0, "[*] Auto Surg")
        safeTextColored(0.65, 0.68, 0.78, "Zama Store // Surgery Automation")

        if ImGui.Separator then ImGui.Separator() end

        -- 2. GET KEY (FREE) BUTTON
        if purpleButton("Get Key (Free)##get_key_btn", 30) then
            notifyUser("`oDiscord: `bdiscord.gg/ekuVdjF4F9 `o(Use /freekey)")
        end

        -- 3. KEY INPUT & VERIFY
        ImGui.Text("Key:")
        if ImGui.InputText then
            local ok, newTxt = pcall(function() return ImGui.InputText("##key_in", keyInputBuffer, 64) end)
            if ok and type(newTxt) == "string" then
                keyInputBuffer = newTxt
            end
        end

        if purpleButton("Verify Key##verify_btn", 30) then
            if keyInputBuffer == "vip" or keyInputBuffer == "premium" then
                user_tier = "PREMIUM"
                is_authenticated = true
                keyStatusText = "Status: [ Verified - VIP Lifetime ]"
                notifyUser("`2[AutoSurg] Verified as VIP Lifetime!")
            elseif keyInputBuffer == "1234" then
                user_tier = "FREE"
                is_authenticated = true
                keyStatusText = "Status: [ Verified - Free Session ]"
                notifyUser("`2[AutoSurg] Verified as Free Session!")
            else
                keyStatusText = "Status: [ Invalid Key! Try 'vip' or '1234' ]"
                notifyUser("`4[AutoSurg] Invalid key! Use 'vip' or '1234'.")
            end
        end

        -- 4. STATUS DISPLAY (Green when verified, Red when invalid)
        if is_authenticated then
            safeTextColored(0.3, 1.0, 0.4, keyStatusText)
        else
            safeTextColored(1.0, 0.35, 0.35, keyStatusText)
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 5. MASTER ENABLE TOGGLE (Purple when ON, Dark when OFF)
        local masterActive = autoSurgEnabled or autoWrenchEnabled
        local enableBtnLabel = masterActive and "Enable: [ ON ]##master_toggle" or "Enable: [ OFF ]##master_toggle"
        
        local masterClicked = false
        if masterActive then
            masterClicked = purpleButton(enableBtnLabel, 32)
        else
            masterClicked = darkButton(enableBtnLabel, 32)
        end

        if masterClicked then
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

        -- 6. MODE SECTION (Vend style action buttons)
        safeTextColored(1.0, 0.50, 0.50, "Mode: Surg-E Auto Farm")

        -- Auto Surg Tools
        local surgLabel = autoSurgEnabled and "Set Auto Surg (Tools) [ON]##surg_tog" or "Set Auto Surg (Tools) [OFF]##surg_tog"
        if autoSurgEnabled then
            if purpleButton(surgLabel, 30) then
                autoSurgEnabled = false
                notifyUser("`4Auto Surg Tools Disabled")
            end
        else
            if darkButton(surgLabel, 30) then
                autoSurgEnabled = true
                notifyUser("`2Auto Surg Tools Enabled")
            end
        end

        -- Pathfinding Info Pill
        if purpleButton("4-5 Tiles Smooth Move (Active)##step_pill", 30) then
            notifyUser("`2[AutoSurg] Stepped Pathfinding is Active!")
        end

        -- Auto Wrench Surg-E
        local wrenchLabel = autoWrenchEnabled and "Set Auto Wrench Surg-E [ON]##wrench_tog" or "Set Auto Wrench Surg-E [OFF]##wrench_tog"
        if autoWrenchEnabled then
            if purpleButton(wrenchLabel, 30) then
                autoWrenchEnabled = false
                isSurgeryActive = false
                currentOperatingDummy = nil
                enableFly(false)
                notifyUser("`4Auto Wrench Disabled")
            end
        else
            if darkButton(wrenchLabel, 30) then
                autoWrenchEnabled = true
                notifyUser("`2Auto Wrench Enabled")
                startAutoWrenchLoop()
            end
        end

        if ImGui.Separator then ImGui.Separator() end

        -- 7. STATS & REFRESH (Matching "WLs: 46", "Refresh Stats")
        safeTextColored(0.9, 0.8, 0.4, "Supplies: Normal")
        local actText = isSurgeryActive and "Activity: OPERATING SURGERY..." or (autoWrenchEnabled and "Activity: SEARCHING SURG-E..." or "Activity: STANDBY (IDLE)")
        safeTextColored(0.4, 0.85, 1.0, actText)

        if purpleButton("Refresh Stats##refresh_stats_btn", 30) then
            notifyUser("`2[AutoSurg] Stats Refreshed!")
        end

        ImGui.End()
    end
end

-- ====================================
-- REGISTER HOOKS
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
