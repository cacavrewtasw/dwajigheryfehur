-- =======================================================
-- GROWLAUNCHER DISCORD WEBHOOK & DISCORD ID TEST SCRIPT
-- =======================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1545485199834480712/DrfQI97OHYB0LSzDq6ke8sYZ-G182FI1dOa4GBMLEPaNVEHFGnm3SSi-6go0w9KtDGrB"
local FALLBACK_DISCORD_ID = "991882071809200188"

local function consoleLog(msg)
    local formatted = "`o[`3WH-Test`o] " .. msg
    if logMessage then
        pcall(logMessage, formatted)
    elseif log then
        pcall(log, formatted)
    elseif sendConsoleMessage then
        pcall(sendConsoleMessage, formatted)
    end
    print("[WH-Test] " .. msg)
end

consoleLog("`2========== STARTING WEBHOOK & DISCORD ID TEST ==========")

-- 1. Test Discord ID Detection
consoleLog("`9[1] Testing Discord ID Detection...")
local discordIdCandidates = {
    "getDiscordID", "GetDiscordID", "getDiscordId", "getDiscord",
    "getUserId", "GetUserId", "discordId", "discord_id", "DISCORD_ID"
}

local detectedDiscordId = nil
local detectedVia = "none"

for _, fnName in ipairs(discordIdCandidates) do
    local fn = _G[fnName]
    if fn ~= nil then
        if type(fn) == "function" then
            local ok, id = pcall(fn)
            if ok and id and tostring(id):gsub("%s+", "") ~= "" then
                detectedDiscordId = tostring(id):gsub("%s+", "")
                detectedVia = fnName .. "()"
                consoleLog("`2  FOUND via " .. fnName .. "(): `1" .. detectedDiscordId)
                break
            else
                consoleLog("`e  Checked " .. fnName .. "(): returned " .. tostring(id))
            end
        else
            detectedDiscordId = tostring(fn):gsub("%s+", "")
            detectedVia = "_G." .. fnName
            consoleLog("`2  FOUND via _G." .. fnName .. ": `1" .. detectedDiscordId)
            break
        end
    end
end

if not detectedDiscordId then
    pcall(function()
        if client and client.getDiscordID then
            local id = client:getDiscordID()
            if id and tostring(id) ~= "" then
                detectedDiscordId = tostring(id)
                detectedVia = "client:getDiscordID()"
                consoleLog("`2  FOUND via client:getDiscordID(): `1" .. detectedDiscordId)
            end
        end
    end)
end

-- Fallback if dummy "123" or empty
local activeId = detectedDiscordId
if not activeId or activeId == "123" or #activeId < 6 then
    consoleLog("`e  Note: getDiscordID returned dummy '" .. tostring(activeId) .. "'. Using Fallback ID: `1" .. FALLBACK_DISCORD_ID)
    activeId = FALLBACK_DISCORD_ID
else
    consoleLog("`2>>> ACTIVE DISCORD ID: `1" .. activeId .. " `2(Source: " .. detectedVia .. ")")
end

local mentionText = "<@" .. activeId .. ">"

-- 2. Scan available global networking APIs
consoleLog("`9[2] Scanning Global Networking Functions in _G...")
local candidateNames = {
    "webhook", "Webhook", "sendWebhook", "SendWebhook",
    "makeRequest", "MakeRequest", "httpRequest", "HttpRequest",
    "fetch", "Fetch", "request", "Request",
    "runThread", "runCoroutine", "HttpClient", "http"
}

for _, name in ipairs(candidateNames) do
    local val = _G[name]
    if val ~= nil then
        consoleLog("`2  FOUND: `1" .. name .. " `o(`e" .. type(val) .. "`o)")
    end
end

-- Prepare Native Table Payload (as documented in Growlauncher)
local hookTable = {
    url = WEBHOOK_URL,
    content = mentionText,
    username = "Surgery Tracker (Test)",
    avatar_url = "https://static.wikia.nocookie.net/growtopia/images/b/be/Operating_Table.png",
    embed = {
        title = "🎉 Congratulations! (Test Reward)",
        description = "# Congratulations\n**You got :** 1 Candy Striper Cap\n**Activity :** Surgery Success\n\n> 🛒 **Order script & services:** <#1407257693365862510>",
        color = 15844367,
        fields = {
            { name = "🏥 Activity", value = "Surgery Success", inline = true },
            { name = "🎁 Rare Item", value = "1 Candy Striper Cap", inline = true },
            { name = "👤 Mentioned ID", value = activeId, inline = true }
        },
        footer = {
            text = "Auto Surg // Zama Store"
        }
    }
}

-- 3. Test Native Table Webhook APIs
consoleLog("`9[3] Testing Native Table Webhook API (webhook / sendWebhook)...")
local tableHookSent = false

if webhook then
    local ok, res = pcall(webhook, hookTable)
    consoleLog("  Attempt webhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then tableHookSent = true end
end

if not tableHookSent and sendWebhook then
    local ok, res = pcall(sendWebhook, hookTable)
    consoleLog("  Attempt sendWebhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then tableHookSent = true end
end

if not tableHookSent and SendWebhook then
    local ok, res = pcall(SendWebhook, hookTable)
    consoleLog("  Attempt SendWebhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then tableHookSent = true end
end

if not tableHookSent and Webhook then
    local ok, res = pcall(Webhook, hookTable)
    consoleLog("  Attempt Webhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then tableHookSent = true end
end

-- 4. Test inside runThread if table hook was sent or fallback
consoleLog("`9[4] Testing inside runThread...")
if runThread then
    runThread(function()
        consoleLog("`e  Inside runThread execution...")
        local hookFn = webhook or Webhook or sendWebhook or SendWebhook
        if hookFn then
            local okT, resT = pcall(hookFn, hookTable)
            consoleLog("  runThread hookFn(table) Result: ok=" .. tostring(okT) .. ", res=" .. tostring(resT))
        else
            consoleLog("`4  runThread: no hook function found.")
        end
    end)
else
    consoleLog("`4  runThread is NOT available.")
end

consoleLog("`2========== DIAGNOSTIC SCRIPT FINISHED ==========")
consoleLog("`eCek Discord apakah pesan dengan Mention ID " .. activeId .. " sudah masuk!")
