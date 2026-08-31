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

local auth_dialog = "set_default_color|`o\nadd_label_with_icon|big|`w" .. script_name .. " // AUTH``|left|1374|\nadd_spacer|small|\nadd_smalltext|Please enter your license key to unlock.|\nadd_spacer|small|\nadd_textbox|📢 Try typing '1234' for testing!|\nadd_spacer|small|\nadd_text_input|freekey|Secret Key:||50|\nend_dialog|test_auth_dialog|Cancel|UNLOCK ENGINE|\n"
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

    local v1 = ""
    local v2 = ""
    if type(var) == "table" then
        v1 = var[0] or var.v1 or ""
        v2 = var[1] or var.v2 or ""
    end

    if type(v1) ~= "string" then return false end

    if v1 == "OnDialogRequest" then
        local dialog = v2
        if type(dialog) ~= "string" then return false end

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
