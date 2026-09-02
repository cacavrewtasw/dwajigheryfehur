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
-- ORIGINAL CLEAN IMGUI WITH MINIMIZE
-- ====================================
local function safeColoredText(colorVec, text)
    local ok = false
    if ImGui and ImGui.TextColored then
        if ImVec4 then
            ok = pcall(function() ImGui.TextColored(ImVec4(colorVec[1], colorVec[2], colorVec[3], colorVec[4]), text) end)
        end
        if not ok then
            ok = pcall(function() ImGui.TextColored(colorVec, text) end)
        end
    end
    if not ok and ImGui and ImGui.Text then
        ImGui.Text(text)
    end
end

local isMinimized = false
local windowOpen = true

local function zamaImGuiLoop()
    if not windowOpen then return end

    local currentTier = _G.USER_TIER or user_tier or "PREMIUM"
    local winTitle = "AutoSurg // ZAMA STORE##main_win"
    if currentTier == "PREMIUM" then
        winTitle = "AutoSurg [PREMIUM VIP] - ZamaStore##main_win"
    elseif currentTier == "FREE" then
        winTitle = "AutoSurg [FREE TIER] - ZamaStore##main_win"
    end

    -- 1. IF MINIMIZED: SHOW COMPACT FLOATING BAR
    if isMinimized then
        if ImGui.SetNextWindowSize and ImVec2 then
            pcall(function() ImGui.SetNextWindowSize(ImVec2(180, 42), 4) end)
        end
        local visible = ImGui.Begin("AutoSurg (Mini)##mini_win", true)
        if visible then
            local actStatus = isSurgeryActive and "[Surg]" or (autoWrenchEnabled and "[Find]" or "[Idle]")
            local label = "[+] Expand " .. actStatus .. "##exp_btn"
            if ImGui.Button and ImGui.Button(label) then
                isMinimized = false
            end
        end
        ImGui.End()
        return
    end

    -- 2. NORMAL WINDOW: FULL CONTROLS WITH MINIMIZE BUTTON
    if ImGui.SetNextWindowSize and ImVec2 then
        pcall(function() ImGui.SetNextWindowSize(ImVec2(310, 360), 4) end)
    end

    local visible, p_open = ImGui.Begin(winTitle, windowOpen)
    if p_open == false then
        windowOpen = false
    end

    -- Also check native ImGui collapse state (e.g. double-click title bar)
    if ImGui.IsWindowCollapsed and ImGui.IsWindowCollapsed() then
        ImGui.End()
        return
    end

    if visible then
        -- Header Banner + Minimize Button
        if currentTier == "PREMIUM" then
            safeColoredText({1, 0.84, 0, 1}, "[*] USER: PREMIUM VIP")
        else
            safeColoredText({0.3, 0.85, 1, 1}, "[i] USER: FREE TRIAL")
        end
        
        ImGui.SameLine()
        if ImGui.Button("[-] Minimize##min_btn") then
            isMinimized = true
            pcall(function()
                if ImGui.SetWindowCollapsed then
                    ImGui.SetWindowCollapsed(true, 0)
                end
            end)
        end

        if ImGui.Separator then ImGui.Separator() end

        -- SECTION 1: SURGERY TOOLS
        safeColoredText({0.35, 0.85, 1, 1}, "=== SURGERY ASSISTANT ===")
        ImGui.Text("Auto Surg (Tools)")
        ImGui.SameLine()
        if autoSurgEnabled then
            if ImGui.Button("[ ON ]##surg_btn") then
                autoSurgEnabled = false
                notifyUser("`4AutoSurg Disabled")
            end
        else
            if ImGui.Button("[ OFF ]##surg_btn") then
                autoSurgEnabled = true
                notifyUser("`2AutoSurg Enabled")
            end
        end

        -- SECTION 2: SURG-E AUTOMATION
        if ImGui.Separator then ImGui.Separator() end
        safeColoredText({1, 0.8, 0.3, 1}, "=== SURG-E AUTOMATION ===")
        ImGui.Text("Auto Wrench Surg-e")
        ImGui.SameLine()
        if autoWrenchEnabled then
            if ImGui.Button("[ ON ]##wrench_btn") then
                autoWrenchEnabled = false
                isSurgeryActive = false
                currentOperatingDummy = nil
                lowSupplyItem = nil
                wrenchSessionId = (wrenchSessionId or 0) + 1
                enableFly(false)
                notifyUser("`4Auto Wrench Disabled")
            end
        else
            if ImGui.Button("[ OFF ]##wrench_btn") then
                autoWrenchEnabled = true
                notifyUser("`2Auto Wrench Enabled")
                startAutoWrenchLoop()
            end
        end

        -- SECTION 3: STEPPED 4-5 TILE PATHFINDING INFO
        if ImGui.Separator then ImGui.Separator() end
        safeColoredText({0.4, 0.9, 0.6, 1}, "Movement: 4-5 Tile Clamped (Anti-Kick)")

        -- SECTION 4: LIVE STATUS
        if ImGui.Separator then ImGui.Separator() end
        ImGui.Text("Activity Status:")
        ImGui.SameLine()
        if isSurgeryActive then
            safeColoredText({0.2, 1, 0.2, 1}, "OPERATING SURGERY...")
        elseif autoWrenchEnabled then
            safeColoredText({1, 1, 0.3, 1}, "SEARCHING SURG-E...")
        else
            safeColoredText({0.6, 0.6, 0.6, 1}, "STANDBY (IDLE)")
        end

        -- FOOTER
        if ImGui.Separator then ImGui.Separator() end
        if currentTier == "FREE" then
            safeColoredText({1, 0.75, 0.2, 1}, "[*] Upgrade to Premium at discord.gg/ekuVdjF4F9")
        else
            safeColoredText({0.4, 1, 0.4, 1}, "[*] VIP Lifetime Active")
        end
        safeColoredText({0.5, 0.7, 1, 1}, "Discord: discord.gg/ekuVdjF4F9")

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
