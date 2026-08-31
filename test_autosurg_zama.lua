local is_authenticated = false
local autoSurgEnabled = false
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
        pcall(function() sendVariant({[0] = "OnDialogRequest", [1] = dialog}) end)
        pcall(function() sendVariant({v1 = "OnDialogRequest", v2 = dialog}) end)
    end
end

local auth_dialog = "set_default_color|`o\nadd_label_with_icon|big|`w" .. script_name .. " // AUTH``|left|1374|\nadd_spacer|small|\nadd_smalltext|Please enter your license key to unlock.|\nadd_spacer|small|\nadd_textbox|[TIP] Try typing '1234' for testing!|\nadd_spacer|small|\nadd_text_input|freekey|Secret Key:||50|\nend_dialog|test_auth_dialog|Cancel|UNLOCK ENGINE|\n"
crossSendDialog(auth_dialog)

local toolIds = {
    ["Sponge"] = 1258, ["Splint"] = 1268, ["Antibiotic"] = 1266, ["Anesthetic"] = 1262,
    ["Scalpel"] = 1260, ["Stitches"] = 1270, ["Lab kit"] = 4318, ["Pins"] = 4308,
    ["Clamp"] = 4314, ["Transfusion"] = 4310, ["Ultrasound"] = 4316, ["Defibrillator"] = 4312,
    ["Fix it"] = 1296,
}

local function useTool(toolName)
    local itool = toolIds[toolName]
    if not itool then return end
    sendPacket(2, "action|dialog_return\ndialog_name|surgery\nbuttonClicked|tool" .. itool)
    if growtopia and growtopia.notify then growtopia.notify("`9[`cTools`9] `c" .. toolName) end
end

local function HookOutgoing(a, b, c)
    local pkt = ""
    if type(a) == "string" then pkt = a end
    if type(b) == "string" then pkt = b end
    if type(c) == "string" then pkt = c end

    if pkt:find("test_auth_dialog") then
        local key = pkt:match("freekey|([^%c]+)")
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
    return false
end

function Surg(var)
    if not is_authenticated or not autoSurgEnabled then return false end

    local dialog = ""
    local v1 = ""
    local v2 = ""
    
    if type(var) == "table" or type(var) == "userdata" then
        v1 = var.v1 or var[1] or var[0] or ""
        v2 = var.v2 or var[2] or var[1] or ""
    end

    if type(v1) == "string" and v1 == "OnDialogRequest" then
        dialog = v2
    end
    
    if type(dialog) == "string" and dialog ~= "" then

        if dialog:find("add_button|surgery|`%$Perform Surgery``|noflags|0|0|") then
            local netID = dialog:match("netID|(%d+)")
            if netID then
                sendPacket(2, "action|dialog_return\ndialog_name|popup\nnetID|" .. netID .. "|\nbuttonClicked|surgery")
                return true
            end
        end

        if dialog:find("end_dialog|surge|Cancel|Okay!|") then
            local tilex = dialog:match("tilex|(%d+)")
            local tiley = dialog:match("tiley|(%d+)")
            if tilex and tiley then
                sendPacket(2, "action|dialog_return\ndialog_name|surge\ntilex|" .. tilex .. "|\ntiley|" .. tiley .. "|")
                return true
            end
        end

        if (dialog:find("heart has stopped") or dialog:find("Heart stopped")) and dialog:find("tool4312") then
            useTool("Defibrillator")
            return true
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

if addHook then
    pcall(function() addHook(Surg, "onVariant") end)
    pcall(function() addHook(HookOutgoing, "onSendPacket") end)
end

-- ==========================================
-- IMGUI INTERFACE
-- ==========================================
function zamaImGuiLoop(deltaTime)
    -- ALWAYS SHOW GUI TO ENSURE IT WORKS
    ImGui.Begin("Auto Surg by zama10")
    
    if not is_authenticated then
        ImGui.Text("Status: WAITING FOR AUTHENTICATION...")
        ImGui.Text("Please check the Growtopia dialog box.")
    else
        ImGui.Text("Auto Surg")
        ImGui.SameLine()
        if autoSurgEnabled then
            if ImGui.Button("ON##surg_toggle") then
                autoSurgEnabled = false
            end
        else
            if ImGui.Button("OFF##surg_toggle") then
                autoSurgEnabled = true
            end
        end
    end
    
    ImGui.End()
end

if addHook then
    pcall(function() addHook(zamaImGuiLoop, "onDrawImGui") end)
end

if applyHook then pcall(applyHook) end
