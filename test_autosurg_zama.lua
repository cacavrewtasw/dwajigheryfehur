local is_authenticated = false
local autoSurgEnabled = false
local autoWrenchEnabled = false
local isSurgeryActive = false
local lowSupplyItem = nil
local currentOperatingDummy = nil
local failedTiles = {}
local autoWrenchRunning = false
local wrenchSessionId = 0
local script_name = "AutoSurg (TEST)"

pcall(function() removeHook("onVariant") end)
pcall(function() removeHook("onSendPacket") end)
pcall(function() removeHook("onDrawImGui") end)

local function verifyKey(key)
    if key == "1234" then return true end
    return false
end

local function crossSendDialog(dialog)
    if growtopia and growtopia.sendDialog then
        growtopia.sendDialog(dialog)
    elseif sendVariant then
        pcall(function() sendVariant({v1 = "OnDialogRequest", v2 = dialog}) end)
    end
end

local auth_dialog = "set_default_color|`o\nadd_label_with_icon|big|`w" .. script_name .. " // AUTH``|left|1374|\nadd_spacer|small|\nadd_smalltext|Please enter your license key to unlock.|\nadd_spacer|small|\nadd_textbox|[TIP] Try typing '1234' for testing!|\nadd_spacer|small|\nadd_text_input|freekey|Secret Key:||50|\nend_dialog|test_auth_dialog|Cancel|UNLOCK ENGINE|\n"
crossSendDialog(auth_dialog)

-- ====================================
-- HOOK OUTGOING (AUTH)
-- ====================================
local function HookOutgoing(a, b, c)
    local pkt = ""
    if type(a) == "string" then pkt = a
    elseif type(b) == "string" then pkt = b
    elseif type(c) == "string" then pkt = c
    end

    if not pkt:find("test_auth_dialog") then return false end

    local key = pkt:match("freekey|([^\n\r]+)")
    if not key or key == "" then
        crossSendDialog("set_default_color|`o\nadd_label_with_icon|big|`4No Key Entered!``|left|18|\nadd_spacer|small|\nadd_smalltext|You did not enter a key. Please try again.|\nend_dialog|auth_fail|OK||\n")
        return true
    end
    key = key:match("^%s*(.-)%s*$")

    if verifyKey(key) then
        crossSendDialog("set_default_color|`o\nadd_label_with_icon|big|`2Key Accepted!``|left|18|\nadd_spacer|small|\nadd_smalltext|Welcome to AutoSurg! Menu is now open.|\nend_dialog|auth_ok|OK||\n")
        is_authenticated = true
    else
        crossSendDialog("set_default_color|`o\nadd_label_with_icon|big|`4Invalid Key!``|left|18|\nadd_spacer|small|\nadd_smalltext|Wrong key! (Try 1234)|\nend_dialog|auth_fail|OK||\n")
    end
    return true
end

-- ====================================
-- HELPER FUNCTIONS & AIR-MOVEMENT
-- ====================================
local function getPosXY()
    if pos then
        local x, y = pos()
        if x and y then return x, y end
    end
    local p = (getLocal and getLocal()) or (GetLocal and GetLocal())
    if p then
        local x = p.posX or (p.pos and p.pos.x) or 0
        local y = p.posY or (p.pos and p.pos.y) or 0
        return math.floor(x / 32), math.floor(y / 32)
    end
    return 0, 0
end

local function getAllTiles()
    if getTiles then return getTiles()
    elseif GetTiles then return GetTiles()
    end
    return {}
end

local function getTileAt(x, y)
    if getTile then return getTile(x, y)
    elseif GetTile then return GetTile(x, y)
    elseif tile and tile.getTile then return tile.getTile(x, y)
    end
    return nil
end

local function getObjects()
    if GetObjectList then return GetObjectList()
    elseif getObjectList then return getObjectList()
    end
    return {}
end

local function holdPosition(tx, ty)
    local pkt = {
        type = 0,
        x = tx * 32,
        y = ty * 32,
        px = tx,
        py = ty,
        xspeed = 0,
        yspeed = 0
    }
    if sendPacketRaw then
        sendPacketRaw(false, pkt)
    elseif SendPacketRaw then
        SendPacketRaw(false, pkt)
    end
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

local function goToDummy(tx, ty, session)
    local ok = false
    if FindPath then
        pcall(function() ok = FindPath(tx, ty) end)
    elseif findPath then
        pcall(function() ok = findPath(tx, ty) end)
    end

    if not ok then
        -- FindPath failed (floating dummy) -> teleport visually & packet directly to center
        hoverAt(tx, ty)
        sleep(200)
    else
        for i = 1, 25 do
            local px, py = getPosXY()
            if (px == tx and py == ty) or not autoWrenchEnabled or (session and wrenchSessionId ~= session) then
                break
            end
            sleep(100)
        end
        hoverAt(tx, ty)
        sleep(100)
    end
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

function Collect()
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
        if t.fg == 4296 then
            local key = t.x .. "," .. t.y
            if not failedTiles[key] or failedTiles[key] < now then
                local dist = math.abs(t.x - px) + math.abs(t.y - py)
                if dist < minDist then
                    minDist = dist
                    nearest = {x = t.x, y = t.y}
                end
            end
        end
    end
    return nearest
end

local function handleLowSupply(itemToFind, session)
    local targetId = getItemIdByName(itemToFind or "Surgical Stitches")

    if growtopia and growtopia.notify then
        growtopia.notify("`6[Auto Surg-E]`4 Low Supply! `oSearching dropped items...")
    end

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

        if growtopia and growtopia.notify then
            growtopia.notify("`2[Auto Surg-E]`o Flying to supplies at (" .. ox .. ", " .. oy .. ")")
        end

        goToDummy(ox, oy, session)
        sleep(300)
        Collect()
        sleep(500)
        Collect()
        sleep(500)
    else
        if growtopia and growtopia.notify then
            growtopia.notify("`4[Auto Surg-E]`o No dropped " .. (itemToFind or "Stitches") .. " found in world!")
        end
        sleep(1500)
    end
end

-- ====================================
-- AUTO WRENCH THREAD LOOP
-- ====================================
local function startAutoWrenchLoop()
    wrenchSessionId = wrenchSessionId + 1
    local currentSession = wrenchSessionId
    isSurgeryActive = false
    currentOperatingDummy = nil
    lowSupplyItem = nil
    failedTiles = {}

    pcall(function() sendPacket(2, "action|input\n|text|/fly\n") end)
    pcall(function() sendPacket(2, "action|input\n|text|/modfly\n") end)

    local function worker()
        while autoWrenchEnabled and is_authenticated and (wrenchSessionId == currentSession) do
            if lowSupplyItem then
                handleLowSupply(lowSupplyItem, currentSession)
                lowSupplyItem = nil
            end

            if isSurgeryActive then
                if currentOperatingDummy then
                    hoverAt(currentOperatingDummy.x, currentOperatingDummy.y)
                end
                sleep(200)
            else
                local dummy = findNearestSurgE()
                if not dummy then
                    sleep(1000)
                else
                    goToDummy(dummy.x, dummy.y, currentSession)

                    if autoWrenchEnabled and (wrenchSessionId == currentSession) then
                        sleep(200)
                        doWrench(dummy.x, dummy.y)

                        -- Wait for surgery popup or low supply dialog
                        for i = 1, 30 do
                            hoverAt(dummy.x, dummy.y)
                            if isSurgeryActive or lowSupplyItem or not autoWrenchEnabled or (wrenchSessionId ~= currentSession) then
                                break
                            end
                            sleep(100)
                        end

                        if isSurgeryActive and autoWrenchEnabled and (wrenchSessionId == currentSession) then
                            currentOperatingDummy = dummy
                            local waitTimeout = 0
                            while isSurgeryActive and autoWrenchEnabled and (wrenchSessionId == currentSession) do
                                hoverAt(dummy.x, dummy.y)
                                sleep(200)
                                waitTimeout = waitTimeout + 1

                                local t = getTileAt(dummy.x, dummy.y)
                                if t and t.fg ~= 4296 then
                                    sleep(1000)
                                    isSurgeryActive = false
                                    break
                                end

                                if waitTimeout > 300 then
                                    isSurgeryActive = false
                                    break
                                end
                            end
                            currentOperatingDummy = nil
                        end
                    else
                        failedTiles[dummy.x .. "," .. dummy.y] = os.clock() + 20
                        sleep(500)
                    end
                end
            end
            sleep(100)
        end
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
    sendPacket(2, "action|dialog_return\ndialog_name|surgery\nbuttonClicked|tool" .. itool)
    growtopia.notify("`9[`cTools`9] `c" .. toolName)
end

function onVariant(var, pkt)
    if not is_authenticated then return false end

    if type(var.v1) ~= "string" then
        return true
    end

    if var.v1 == "OnDialogRequest" then
        local dialog = var.v2
        if type(dialog) ~= "string" then return true end

        -- 1. Check Low Supply Warning on Surg-E pre-popup
        if dialog:find("Low Supply Warning:") or dialog:find("Low Supply Warning") then
            local lowName = dialog:match("You only have [^|]*``%s*([^\r\n|]+)") or "Surgical Stitches"
            lowName = lowName:gsub("`.", ""):match("^%s*(.-)%s*$")
            lowSupplyItem = lowName
            isSurgeryActive = false

            sendPacket(2, "action|dialog_return\ndialog_name|surge\nbuttonClicked|cancel\n")
            if growtopia and growtopia.notify then
                growtopia.notify("`4[Low Supply Warning]`o " .. lowName .. "! Collecting...")
            end
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
                sendPacket(2, "action|dialog_return\ndialog_name|surge\ntilex|" .. (tilex or "") .. "|\ntiley|" .. (tiley or "") .. "|\n")
                return true
            end
        end

        -- 3. Only run tool actions if autoSurgEnabled is ON
        if not autoSurgEnabled then return false end

        if dialog:find("add_button|surgery|`%$Perform Surgery``|noflags|0|0|") then
            local netID = dialog:match("netID|(%d+)")
            sendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|" .. netID .. "|\nbuttonClicked|surgery")
            return true
        end

        if (dialog:find("heart has stopped") or dialog:find("Heart stopped")) and dialog:find("tool4312") then
            sleep(50)
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

-- Register hooks
if addHook then
    pcall(function() addHook(onVariant, "onVariant") end)
    pcall(function() addHook(HookOutgoing, "onSendPacket") end)
end

-- ====================================
-- IMGUI INTERFACE
-- ====================================
local function zamaImGuiLoop()
    if ImGui.Begin("Auto Surg by zama10") then
        if not is_authenticated then
            ImGui.Text("Status: NOT AUTHENTICATED")
            ImGui.Text("Check the Growtopia dialog box!")
        else
            ImGui.Text("Auto Surg")
            ImGui.SameLine()
            if autoSurgEnabled then
                if ImGui.Button("ON##surg_btn") then
                    autoSurgEnabled = false
                    growtopia.notify("`4AutoSurg Disabled")
                end
            else
                if ImGui.Button("OFF##surg_btn") then
                    autoSurgEnabled = true
                    growtopia.notify("`2AutoSurg Enabled")
                end
            end

            ImGui.Text("Auto Wrench Surg-e")
            ImGui.SameLine()
            if autoWrenchEnabled then
                if ImGui.Button("ON##wrench_btn") then
                    autoWrenchEnabled = false
                    isSurgeryActive = false
                    currentOperatingDummy = nil
                    lowSupplyItem = nil
                    wrenchSessionId = wrenchSessionId + 1
                    growtopia.notify("`4Auto Wrench Disabled")
                end
            else
                if ImGui.Button("OFF##wrench_btn") then
                    autoWrenchEnabled = true
                    growtopia.notify("`2Auto Wrench Enabled")
                    startAutoWrenchLoop()
                end
            end
        end
        ImGui.End()
    end
end

if addHook then
    pcall(function() addHook(zamaImGuiLoop, "onDrawImGui") end)
end

if applyHook then pcall(applyHook) end
