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
local rawDiscordId = nil
local detectedVia = "none"

if getDiscordID then
    local ok, id = pcall(getDiscordID)
    if ok and id and tostring(id):gsub("%s+", "") ~= "" then
        rawDiscordId = tostring(id):gsub("%s+", "")
        detectedVia = "getDiscordID()"
        consoleLog("`2  getDiscordID() returned: `1" .. rawDiscordId)
    end
end

if not rawDiscordId and GetDiscordID then
    local ok, id = pcall(GetDiscordID)
    if ok and id and tostring(id):gsub("%s+", "") ~= "" then
        rawDiscordId = tostring(id):gsub("%s+", "")
        detectedVia = "GetDiscordID()"
        consoleLog("`2  GetDiscordID() returned: `1" .. rawDiscordId)
    end
end

local activeId = rawDiscordId
if not activeId or activeId == "123" or #activeId < 6 then
    consoleLog("`e  Note: Discord ID is '" .. tostring(activeId) .. "'. Using Fallback ID: `1" .. FALLBACK_DISCORD_ID)
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
    "fetch", "Fetch", "runThread"
}

for _, name in ipairs(candidateNames) do
    local val = _G[name]
    if val ~= nil then
        consoleLog("`2  FOUND: `1" .. name .. " `o(`e" .. type(val) .. "`o)")
    end
end

-- 3. Prepare Table Payload (as documented in Growlauncher)
local hookTable = {
    url = WEBHOOK_URL,
    content = mentionText,
    username = "Growlauncher Diagnostic",
    avatar_url = "https://static.wikia.nocookie.net/growtopia/images/b/be/Operating_Table.png",
    embed = {
        title = "🎉 Test Webhook Growlauncher Berhasil!",
        description = "# Webhook Test\n**Discord ID:** " .. activeId .. "\n**Status:** Berhasil Terkirim!",
        color = 65280,
        fields = {
            { name = "👤 Mention ID", value = mentionText, inline = true },
            { name = "🎮 Client", value = "Growlauncher", inline = true }
        },
        footer = {
            text = "Zama Store // Diagnostic Tool"
        }
    }
}

-- 4. Test Table-based Webhook functions
consoleLog("`9[3] Testing Table-based Webhook APIs...")
local sent = false

-- Test webhook(table)
if not sent and webhook then
    local ok, res = pcall(webhook, hookTable)
    consoleLog("  Attempt webhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then sent = true end
end

-- Test sendWebhook(table)
if not sent and sendWebhook then
    local ok, res = pcall(sendWebhook, hookTable)
    consoleLog("  Attempt sendWebhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then sent = true end
end

-- Test SendWebhook(table)
if not sent and SendWebhook then
    local ok, res = pcall(SendWebhook, hookTable)
    consoleLog("  Attempt SendWebhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then sent = true end
end

-- Test Webhook(table)
if not sent and Webhook then
    local ok, res = pcall(Webhook, hookTable)
    consoleLog("  Attempt Webhook(table): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
    if ok then sent = true end
end

-- 5. Fallback to String/JSON if table-based didn't succeed
if not sent then
    consoleLog("`9[4] Table method not sent, trying String/JSON fallbacks...")
    local simplePayload = '{"content":"' .. mentionText .. ' Growlauncher Webhook Test (JSON fallback)"}'
    
    if makeRequest then
        local headers = { ["Content-Type"] = "application/json" }
        local ok, res = pcall(makeRequest, WEBHOOK_URL, "POST", headers, simplePayload, 8000)
        consoleLog("  Attempt makeRequest: ok=" .. tostring(ok) .. ", res=" .. tostring(res))
        if ok then sent = true end
    end

    if not sent and sendWebhook then
        local ok, res = pcall(sendWebhook, WEBHOOK_URL, simplePayload)
        consoleLog("  Attempt sendWebhook(url, payload): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
        if ok then sent = true end
    end

    if not sent and fetch then
        local ok, res = pcall(fetch, WEBHOOK_URL, {
            method = "POST",
            headers = { ["Content-Type"] = "application/json" },
            body = simplePayload
        })
        consoleLog("  Attempt fetch(url, options): ok=" .. tostring(ok) .. ", res=" .. tostring(res))
        if ok then sent = true end
    end
end

-- 6. Also try inside runThread
if runThread then
    runThread(function()
        consoleLog("`e[5] Testing inside runThread...")
        local hookFn = webhook or Webhook or sendWebhook or SendWebhook
        if hookFn then
            local okT, resT = pcall(hookFn, hookTable)
            consoleLog("  runThread hookFn(table): ok=" .. tostring(okT) .. ", res=" .. tostring(resT))
        end
    end)
end

consoleLog("`2========== DIAGNOSTIC SCRIPT FINISHED ==========")
consoleLog("`eStatus Pengiriman Akhir: " .. tostring(sent))
