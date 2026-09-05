-- =======================================================
-- GROWLAUNCHER MULTI-METHOD WEBHOOK TEST SCRIPT
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

consoleLog("`2========== STARTING MULTI-METHOD TEST ==========")

-- 1. Discord ID
local rawId = (getDiscordID and getDiscordID()) or ""
local activeId = rawId
if not activeId or activeId == "123" or #activeId < 6 then
    activeId = FALLBACK_DISCORD_ID
end
consoleLog("`2Active Discord ID: `1" .. tostring(activeId) .. " `o(Raw: " .. tostring(rawId) .. ")")
local mention = "<@" .. activeId .. ">"

-- 2. Scan globals
local apis = {}
for _, name in ipairs({"makeRequest", "MakeRequest", "sendWebhook", "SendWebhook", "webhook", "Webhook", "fetch", "runThread"}) do
    if _G[name] ~= nil then
        table.insert(apis, name .. "(" .. type(_G[name]) .. ")")
    end
end
consoleLog("`9Available APIs: `2" .. (#apis > 0 and table.concat(apis, ", ") or "NONE"))

-- 3. Prepare Payloads
local headers = { ["Content-Type"] = "application/json" }

local hookTable = {
    url = WEBHOOK_URL,
    content = mention .. " `[Table Hook]` Test Berhasil!",
    username = "Growlauncher Tracker",
    avatar_url = "https://static.wikia.nocookie.net/growtopia/images/b/be/Operating_Table.png",
    embed = {
        title = "🎉 Table Webhook Test Berhasil!",
        description = "Discord ID: " .. activeId .. "\nMethod: Native Table API",
        color = 65280,
        fields = {
            { name = "Status", value = "SUCCESS", inline = true },
            { name = "Mention", value = mention, inline = true }
        },
        footer = { text = "Auto Surg // Zama Store" }
    }
}

local jsonPayload = string.format([[
{
  "content": "%s `[JSON Hook]` Test Berhasil!",
  "username": "Growlauncher Tracker",
  "avatar_url": "https://static.wikia.nocookie.net/growtopia/images/b/be/Operating_Table.png",
  "embeds": [
    {
      "title": "🎉 JSON Webhook Test Berhasil!",
      "description": "Discord ID: %s\nMethod: JSON Payload",
      "color": 16753920,
      "fields": [
        { "name": "Status", "value": "SUCCESS", "inline": true },
        { "name": "Mention", "value": "%s", "inline": true }
      ],
      "footer": { "text": "Auto Surg // Zama Store" }
    }
  ]
}
]], mention, activeId, mention)

-- METHOD 1: makeRequest (JSON)
if makeRequest then
    consoleLog("`9[M1] Testing makeRequest (JSON)...")
    local ok1, res1 = pcall(makeRequest, WEBHOOK_URL, "POST", headers, jsonPayload, 8000)
    consoleLog("  makeRequest Result: ok=" .. tostring(ok1) .. ", res=" .. tostring(res1))
    if not ok1 or res1 == false then
        local ok1b, res1b = pcall(makeRequest, WEBHOOK_URL, "POST", headers, jsonPayload)
        consoleLog("  makeRequest (no timeout): ok=" .. tostring(ok1b) .. ", res=" .. tostring(res1b))
    end
else
    consoleLog("`4[M1] makeRequest NOT available")
end

-- METHOD 2: webhook(table)
if webhook then
    consoleLog("`9[M2] Testing webhook(table)...")
    local ok2, res2 = pcall(webhook, hookTable)
    consoleLog("  webhook(table) Result: ok=" .. tostring(ok2) .. ", res=" .. tostring(res2))
else
    consoleLog("`4[M2] webhook NOT available")
end

-- METHOD 3: sendWebhook(table) & sendWebhook(url, str)
if sendWebhook then
    consoleLog("`9[M3] Testing sendWebhook...")
    local ok3a, res3a = pcall(sendWebhook, hookTable)
    consoleLog("  sendWebhook(table) Result: ok=" .. tostring(ok3a) .. ", res=" .. tostring(res3a))
    
    local ok3b, res3b = pcall(sendWebhook, WEBHOOK_URL, jsonPayload)
    consoleLog("  sendWebhook(url, str) Result: ok=" .. tostring(ok3b) .. ", res=" .. tostring(res3b))
else
    consoleLog("`4[M3] sendWebhook NOT available")
end

-- METHOD 4: SendWebhook (Capitalized)
if SendWebhook then
    consoleLog("`9[M4] Testing SendWebhook (Capitalized)...")
    local ok4a, res4a = pcall(SendWebhook, hookTable)
    consoleLog("  SendWebhook(table) Result: ok=" .. tostring(ok4a) .. ", res=" .. tostring(res4a))
    local ok4b, res4b = pcall(SendWebhook, WEBHOOK_URL, jsonPayload)
    consoleLog("  SendWebhook(url, str) Result: ok=" .. tostring(ok4b) .. ", res=" .. tostring(res4b))
end

-- METHOD 5: fetch POST
if fetch then
    consoleLog("`9[M5] Testing fetch (POST)...")
    local ok5, res5 = pcall(fetch, WEBHOOK_URL, {
        method = "POST",
        headers = headers,
        body = jsonPayload
    })
    consoleLog("  fetch(options) Result: ok=" .. tostring(ok5) .. ", res=" .. tostring(res5))
end

-- METHOD 6: runThread Background Execution
if runThread then
    consoleLog("`9[M6] Testing inside runThread...")
    runThread(function()
        consoleLog("`e  runThread started...")
        if makeRequest then
            local ok, res = pcall(makeRequest, WEBHOOK_URL, "POST", headers, jsonPayload, 8000)
            consoleLog("  runThread makeRequest: ok=" .. tostring(ok))
        end
        if sendWebhook then
            pcall(sendWebhook, hookTable)
            pcall(sendWebhook, WEBHOOK_URL, jsonPayload)
        end
        if webhook then
            pcall(webhook, hookTable)
        end
        consoleLog("`e  runThread finished.")
    end)
end

consoleLog("`2========== TEST FINISHED ==========")
consoleLog("`eCek Discord & infokan pesan [M1] - [M6] apa saja yang muncul di konsol!")
