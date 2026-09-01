-- ==========================================
-- TestAuthAndSurg.lua (Growlauncher Test File)
-- ==========================================
local is_authenticated = false
local autoSurgEnabled = false
local autoWrenchEnabled = false
local isSurgeryActive = false
local lowSupplyItem = nil
local currentOperatingDummy = nil
local failedTiles = {}
local autoWrenchRunning = false
local wrenchSessionId = 0
local script_name = "AutoSurg (ZamaStore)"
local user_tier = "NONE" -- "FREE" or "PREMIUM"

pcall(function() removeHook("onVariant") end)
pcall(function() removeHook("onSendPacket") end)
pcall(function() removeHook("onDrawImGui") end)

local function verifyKey(key)
    if key == "1234" then
        user_tier = "FREE"
        return true
    elseif key == "vip" or key == "premium" or key == "12345" then
        user_tier = "PREMIUM"
        return true
    end
    return false
end

local function crossSendDialog(dialog)
    if growtopia and growtopia.sendDialog then
        growtopia.sendDialog(dialog)
    elseif sendVariant then
        pcall(function() sendVariant({v1 = "OnDialogRequest", v2 = dialog}) end)
    end
end

local auth_dialog = "set_default_color|`o\n" ..
    "add_label_with_icon|big|`9ZAMA STORE `w// `cAutoSurg Engine``|left|1374|\n" ..
    "add_spacer|small|\n" ..
    "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|left|\n" ..
    "add_smalltext|`eLicense Status: `4NOT ACTIVATED``|left|\n" ..
    "add_smalltext|`wPlease enter your `bSecret License Key`w to unlock features.|left|\n" ..
    "add_spacer|small|\n" ..
    "add_textbox|`9[FREE TIER] `oType '`21234`o' for Free Access|left|\n" ..
    "add_textbox|`6[VIP TIER]  `oType '`6vip`o' for Lifetime Premium VIP|left|\n" ..
    "add_spacer|small|\n" ..
    "add_text_input|freekey|Secret Key:||50|\n" ..
    "add_spacer|small|\n" ..
    "add_textbox|`oGet official key at: `bdiscord.gg/ekuVdjF4F9|left|\n" ..
    "end_dialog|test_auth_dialog|Cancel|⚡ UNLOCK ENGINE ⚡|\n"

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
        crossSendDialog("set_default_color|`o\n" ..
            "add_label_with_icon|big|`4ACCESS DENIED `w// `4NO KEY``|left|242|\n" ..
            "add_spacer|small|\n" ..
            "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|left|\n" ..
            "add_smalltext|`4✖ No key was entered.|left|\n" ..
            "add_smalltext|`wPlease try again with a valid license key.|left|\n" ..
            "end_dialog|auth_fail|TRY AGAIN||\n")
        return true
    end
    key = key:match("^%s*(.-)%s*$")

    if verifyKey(key) then
        if user_tier == "PREMIUM" then
            crossSendDialog("set_default_color|`o\n" ..
                "add_label_with_icon|big|`6⭐ PREMIUM VIP `w// `eLIFETIME ACCESS``|left|2480|\n" ..
                "add_spacer|small|\n" ..
                "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|left|\n" ..
                "add_smalltext|`2✔ VIP Verified: `bLifetime License Active!|left|\n" ..
                "add_smalltext|`eWelcome back, `6VIP Surgeon`e!|left|\n" ..
                "add_smalltext|`wAll AutoSurg & Auto Wrench features unlocked.|left|\n" ..
                "add_spacer|small|\n" ..
                "add_textbox|`dThank you for supporting Zama Store!|left|\n" ..
                "add_spacer|small|\n" ..
                "end_dialog|premium_ok|START SURGERY!||\n")
        else
            crossSendDialog("set_default_color|`o\n" ..
                "add_label_with_icon|big|`2ACCESS GRANTED `w// `aFREE TIER``|left|1374|\n" ..
                "add_spacer|small|\n" ..
                "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|left|\n" ..
                "add_smalltext|`2✔ License Valid: `eFree Single-Session Active!|left|\n" ..
                "add_smalltext|`wAutoSurg ImGui menu is now unlocked.|left|\n" ..
                "add_spacer|small|\n" ..
                "add_textbox|`6⭐ `eWant permanent access without daily keys?|left|\n" ..
                "add_textbox|`6⭐ `eUpgrade to `3Premium VIP `ein our Discord!|left|\n" ..
                "add_spacer|small|\n" ..
                "add_textbox|`oDiscord: `bdiscord.gg/ekuVdjF4F9|left|\n" ..
                "end_dialog|auth_ok|START NOW!||\n")
        end
        is_authenticated = true
    else
        crossSendDialog("set_default_color|`o\n" ..
            "add_label_with_icon|big|`4ACCESS DENIED `w// `4INVALID KEY``|left|242|\n" ..
            "add_spacer|small|\n" ..
            "add_textbox|`o━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━|left|\n" ..
            "add_smalltext|`4✖ Key is invalid, expired, or already used.|left|\n" ..
            "add_smalltext|`wType '`21234`w' (Free) or '`6vip`w' (Premium) for testing.|left|\n" ..
            "add_smalltext|`oGet official key at: `bdiscord.gg/ekuVdjF4F9|left|\n" ..
            "end_dialog|auth_fail|OK||\n")
    end
    return true
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
                sleep(100)
            end
        else
            hoverAt(stepX, stepY)
            sleep(120)
        end
    end

    hoverAt(targetX, targetY)
    sleep(100)
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
            growtopia.notify("`2[Auto Surg-E]`o Moving to supplies at (" .. ox .. ", " .. oy .. ")")
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

local function enableFly(state)
    if editToggle then pcall(function() editToggle("ModFly", state) end) end
    if EditToggle then pcall(function() EditToggle("ModFly", state) end) end
    if editValue then pcall(function() editValue("ModFly", state) end) end
    if EditValue then pcall(function() EditValue("ModFly", state) end) end
    if setValue then pcall(function() setValue("ModFly", state) end) end
    if SetValue then pcall(function() SetValue("ModFly", state) end) end
    if state then
        pcall(function() sendPacket(2, "action|input\n|text|/fly\n") end)
        pcall(function() sendPacket(2, "action|input\n|text|/modfly\n") end)
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
-- IMGUI INTERFACE (PREMIUM & FREE)
-- MODERN PURPLE CARD INTERFACE (VEND STYLE)
-- ====================================
local function applyVendStyle()
    local pushedColors = 0
    local pushedVars = 0

    local function pushCol(idx, r, g, b, a)
        if ImGui and ImGui.PushStyleColor then
            local vec = ImVec4 and ImVec4(r, g, b, a) or {r, g, b, a}
            if pcall(function() ImGui.PushStyleColor(idx, vec) end) then
                pushedColors = pushedColors + 1
            end
        end
    end

    local function pushVar(idx, val1, val2)
        if ImGui and ImGui.PushStyleVar then
            local ok = false
            if val2 and ImVec2 then
                ok = pcall(function() ImGui.PushStyleVar(idx, ImVec2(val1, val2)) end)
            else
                ok = pcall(function() ImGui.PushStyleVar(idx, val1) end)
            end
            if ok then pushedVars = pushedVars + 1 end
        end
    end

    -- Window Styling (Dark slate navy + vibrant purple accents)
    pushCol(2, 0.09, 0.10, 0.14, 0.96)  -- ImGuiCol_WindowBg
    pushCol(5, 0.28, 0.24, 0.45, 0.50)  -- ImGuiCol_Border
    pushCol(7, 0.13, 0.14, 0.20, 1.00)  -- ImGuiCol_FrameBg
    pushCol(8, 0.17, 0.18, 0.26, 1.00)  -- ImGuiCol_FrameBgHovered
    pushCol(9, 0.22, 0.23, 0.33, 1.00)  -- ImGuiCol_FrameBgActive
    pushCol(21, 0.48, 0.36, 0.98, 1.00) -- ImGuiCol_Button (#7B5CFA Purple)
    pushCol(22, 0.56, 0.44, 1.00, 1.00) -- ImGuiCol_ButtonHovered
    pushCol(23, 0.40, 0.28, 0.88, 1.00) -- ImGuiCol_ButtonActive
    pushCol(18, 0.48, 0.36, 0.98, 1.00) -- ImGuiCol_CheckMark
    pushCol(27, 0.20, 0.22, 0.32, 0.50) -- ImGuiCol_Separator

    pushVar(1, 14.0)                     -- ImGuiStyleVar_WindowRounding
    pushVar(11, 8.0)                     -- ImGuiStyleVar_FrameRounding (Pill buttons)
    pushVar(2, 1.0)                      -- ImGuiStyleVar_WindowBorderSize
    pushVar(3, 14.0, 14.0)               -- ImGuiStyleVar_WindowPadding
    pushVar(13, 8.0, 8.0)                -- ImGuiStyleVar_ItemSpacing

    return pushedColors, pushedVars
end

local function popVendStyle(colors, vars)
    if ImGui and ImGui.PopStyleColor and colors > 0 then
        pcall(function() ImGui.PopStyleColor(colors) end)
    end
    if ImGui and ImGui.PopStyleVar and vars > 0 then
        pcall(function() ImGui.PopStyleVar(vars) end)
    end
end

local function pillButton(label, active, height)
    local pushed = 0
    local h = height or 32
    if active ~= nil then
        if active then
            if ImGui and ImGui.PushStyleColor then
                pcall(function() ImGui.PushStyleColor(21, ImVec4(0.48, 0.36, 0.98, 1.0)) end)
                pcall(function() ImGui.PushStyleColor(22, ImVec4(0.56, 0.44, 1.00, 1.0)) end)
                pcall(function() ImGui.PushStyleColor(23, ImVec4(0.40, 0.28, 0.88, 1.0)) end)
                pushed = 3
            end
        else
            if ImGui and ImGui.PushStyleColor then
                pcall(function() ImGui.PushStyleColor(21, ImVec4(0.16, 0.17, 0.24, 1.0)) end)
                pcall(function() ImGui.PushStyleColor(22, ImVec4(0.22, 0.24, 0.32, 1.0)) end)
                pcall(function() ImGui.PushStyleColor(23, ImVec4(0.12, 0.13, 0.18, 1.0)) end)
                pushed = 3
            end
        end
    end

    local clicked = false
    local sizeVec = ImVec2 and ImVec2(-1, h) or nil
    if sizeVec then
        clicked = ImGui.Button(label, sizeVec)
    else
        clicked = ImGui.Button(label)
    end

    if pushed > 0 and ImGui.PopStyleColor then
        pcall(function() ImGui.PopStyleColor(pushed) end)
    end
    return clicked
end

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

local function zamaImGuiLoop()
    local winTitle = "AutoSurg // ZAMA STORE"
    if user_tier == "PREMIUM" then
        winTitle = "AutoSurg [PREMIUM VIP] - ZamaStore"
    elseif user_tier == "FREE" then
        winTitle = "AutoSurg [FREE TIER] - ZamaStore"
    local winTitle = "Auto Surg##zama_autosurg"

    local cCount, vCount = applyVendStyle()

    if ImGui.SetNextWindowSize and ImVec2 then
        pcall(function() ImGui.SetNextWindowSize(ImVec2(300, 0), 4) end)
    end

    if ImGui.Begin(winTitle) then
        if not is_authenticated then
            safeColoredText({1, 0.3, 0.3, 1}, "[!] STATUS: NOT ACTIVATED")
            ImGui.Text("Please enter your key in the Growtopia dialog!")
            safeColoredText({1.0, 0.4, 0.4, 1.0}, "Status: NOT ACTIVATED")
            safeColoredText({0.60, 0.62, 0.72, 1.0}, "Please enter key in Growtopia dialog!")
            if pillButton("Open Community Discord##comm_btn", true, 32) then
                growtopia.notify("`oDiscord: `bdiscord.gg/ekuVdjF4F9")
            end
        else
            -- 1. HEADER SECTION
            safeColoredText({0.65, 0.55, 1.0, 1.0}, "[*] Auto Surg")
            safeColoredText({0.60, 0.62, 0.72, 1.0}, "Zama Store // Surgery Assistant")

            if ImGui.Separator then ImGui.Separator() end
            ImGui.Text("Community: discord.gg/ekuVdjF4F9")
        else
            -- Header Banner

            -- 2. TIER / VERIFIED STATUS
            if user_tier == "PREMIUM" then
                safeColoredText({1, 0.84, 0, 1}, "[*] USER: PREMIUM VIP")
                ImGui.SameLine()
                safeColoredText({0.3, 1, 0.3, 1}, "[LIFETIME ACCESS]")
                safeColoredText({0.3, 1.0, 0.4, 1.0}, "Status: [x] Verified (VIP Lifetime)")
            else
                safeColoredText({0.3, 0.85, 1, 1}, "[i] USER: FREE TRIAL")
                ImGui.SameLine()
                safeColoredText({1, 0.7, 0.2, 1}, "[1 SESSION]")
                safeColoredText({0.3, 0.85, 1.0, 1.0}, "Status: [x] Verified (Free Session)")
                if pillButton("Get Key (Free) / Community##get_key_btn", true, 30) then
                    growtopia.notify("`oDiscord: `bdiscord.gg/ekuVdjF4F9")
                end
            end

            if ImGui.Separator then ImGui.Separator() end

            -- SECTION 1: SURGERY TOOLS
            safeColoredText({0.35, 0.85, 1, 1}, "=== SURGERY ASSISTANT ===")
            ImGui.Text("Auto Surg (Tools)")
            ImGui.SameLine()
            if autoSurgEnabled then
                if ImGui.Button("[ ON ]##surg_btn") then
                    autoSurgEnabled = false
                    growtopia.notify("`4AutoSurg Disabled")
                end
            else
                if ImGui.Button("[ OFF ]##surg_btn") then
                    autoSurgEnabled = true
                    growtopia.notify("`2AutoSurg Enabled")
                end
            -- 3. MAIN CONTROLS (FULL WIDTH PILL BUTTONS)
            local surgLabel = autoSurgEnabled and "Auto Surg (Tools): ENABLED" or "Auto Surg (Tools): DISABLED"
            if pillButton(surgLabel .. "##surg_pill", autoSurgEnabled, 34) then
                autoSurgEnabled = not autoSurgEnabled
                growtopia.notify(autoSurgEnabled and "`2AutoSurg Enabled" or "`4AutoSurg Disabled")
            end

            -- SECTION 2: SURG-E AUTOMATION
            if ImGui.Separator then ImGui.Separator() end
            safeColoredText({1, 0.8, 0.3, 1}, "=== SURG-E AUTOMATION ===")
            ImGui.Text("Auto Wrench Surg-e")
            ImGui.SameLine()
            if autoWrenchEnabled then
                if ImGui.Button("[ ON ]##wrench_btn") then
                    autoWrenchEnabled = false
            local wrenchLabel = autoWrenchEnabled and "Auto Wrench Surg-E: ENABLED" or "Auto Wrench Surg-E: DISABLED"
            if pillButton(wrenchLabel .. "##wrench_pill", autoWrenchEnabled, 34) then
                autoWrenchEnabled = not autoWrenchEnabled
                if autoWrenchEnabled then
                    growtopia.notify("`2Auto Wrench Enabled")
                    startAutoWrenchLoop()
                else
                    isSurgeryActive = false
                    currentOperatingDummy = nil
                    lowSupplyItem = nil
                    wrenchSessionId = (wrenchSessionId or 0) + 1
                    enableFly(false)
                    growtopia.notify("`4Auto Wrench Disabled")
                end
            else
                if ImGui.Button("[ OFF ]##wrench_btn") then
                    autoWrenchEnabled = true
                    growtopia.notify("`2Auto Wrench Enabled")
                    startAutoWrenchLoop()
                end
            end

            -- SECTION 3: LIVE STATUS
            if ImGui.Separator then ImGui.Separator() end
            ImGui.Text("Activity Status:")

            -- 4. MODE SECTION
            safeColoredText({1.0, 0.50, 0.50, 1.0}, "Mode: Surg-E Auto Farm")

            pillButton("Step Pathfind: 4-5 Tiles (Active)##mode1", true, 30)
            pillButton("Supplies Auto-Collector (Active)##mode2", true, 30)

            if ImGui.Separator then ImGui.Separator() end

            -- 5. LIVE ACTIVITY & STATS
            safeColoredText({0.60, 0.62, 0.72, 1.0}, "Supplies:")
            ImGui.SameLine()
            if lowSupplyItem then
                safeColoredText({1.0, 0.3, 0.3, 1.0}, "Low: " .. lowSupplyItem)
            else
                safeColoredText({0.3, 1.0, 0.4, 1.0}, "Normal")
            end

            safeColoredText({0.60, 0.62, 0.72, 1.0}, "Activity:")
            ImGui.SameLine()
            if isSurgeryActive then
                safeColoredText({0.2, 1, 0.2, 1}, "OPERATING SURGERY...")
                safeColoredText({0.2, 1.0, 0.3, 1.0}, "OPERATING...")
            elseif autoWrenchEnabled then
                safeColoredText({1, 1, 0.3, 1}, "SEARCHING SURG-E...")
                safeColoredText({1.0, 0.9, 0.2, 1.0}, "SEARCHING...")
            else
                safeColoredText({0.6, 0.6, 0.6, 1}, "STANDBY (IDLE)")
                safeColoredText({0.6, 0.6, 0.6, 1.0}, "STANDBY (IDLE)")
            end

            if pillButton("Refresh Stats##refresh_btn", true, 30) then
                growtopia.notify("`2[AutoSurg]`o Stats Refreshed!")
            end

            -- FOOTER
            if ImGui.Separator then ImGui.Separator() end
            if user_tier == "FREE" then
                safeColoredText({1, 0.75, 0.2, 1}, "[*] Want keyless access? Upgrade to VIP!")
            else
                safeColoredText({0.4, 1, 0.4, 1}, "[*] Thank you for supporting VIP!")
            end
            safeColoredText({0.5, 0.7, 1, 1}, "Discord: discord.gg/ekuVdjF4F9")
            safeColoredText({0.50, 0.55, 0.70, 1.0}, "discord.gg/ekuVdjF4F9")
        end
        ImGui.End()
    end

    popVendStyle(cCount, vCount)
end

if addHook then
    pcall(function() addHook(zamaImGuiLoop, "onDrawImGui") end)
end

if applyHook then pcall(applyHook) end


