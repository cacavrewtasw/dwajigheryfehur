-- =======================================================
-- GROWLAUNCHER DISCORD WEBHOOK & DISCORD ID TEST SCRIPT
-- =======================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1545485199834480712/DrfQI97OHYB0LSzDq6ke8sYZ-G182FI1dOa4GBMLEPaNVEHFGnm3SSi-6go0w9KtDGrB"
local FALLBACK_DISCORD_ID = "991882071809200188"

local function consoleLog(msg)
    local formatted = "`o[`3WH-Test`o] " .. msg
    if LogToConsole then
        pcall(LogToConsole, formatted)
    elseif logMessage then
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
local rawId = (getDiscordID and getDiscordID()) or ""
local activeId = rawId
if not activeId or activeId == "123" or #activeId < 6 then
    activeId = FALLBACK_DISCORD_ID
    consoleLog("`eNote: getDiscordID() returned '" .. tostring(rawId) .. "'. Fallback ID: `1" .. activeId)
else
    consoleLog("`2Active Discord ID: `1" .. tostring(activeId))
end
local mention = "<@" .. activeId .. ">"

-- 2. Scan available global networking APIs
local apis = {}
for _, name in ipairs({"makeRequest", "MakeRequest", "sendWebhook", "SendWebhook", "webhook", "Webhook", "fetch", "runThread", "LogToConsole"}) do
    if _G[name] ~= nil then
        table.insert(apis, name .. "(" .. type(_G[name]) .. ")")
    end
end
consoleLog("`9APIs in _G: `2" .. (#apis > 0 and table.concat(apis, ", ") or "NONE"))

-- 3. Prepare Payloads
local headers = { ["Content-Type"] = "application/json" }

local hookTable = {
    url = WEBHOOK_URL,
    content = mention .. " Growlauncher Webhook Test (Table Method)!",
    username = "Growlauncher Tracker",
    avatar_url = "https://static.wikia.nocookie.net/growtopia/images/b/be/Operating_Table.png",
    embed = {
        title = "🎉 Webhook Test Berhasil!",
        description = "Discord ID: " .. activeId .. "\nStatus: OK",
        color = 65280,
        fields = {
            { name = "Mention", value = mention, inline = true },
            { name = "Client", value = "Growlauncher", inline = true }
        },
        footer = { text = "Auto Surg // Zama Store" }
    }
}

local jsonPayload = string.format([[
{
  "content": "%s Growlauncher Webhook Test (JSON Method)!",
  "username": "Growlauncher Tracker",
  "avatar_url": "https://static.wikia.nocookie.net/growtopia/images/b/be/Operating_Table.png",
  "embeds": [
    {
      "title": "🎉 Webhook Test Berhasil!",
      "description": "Discord ID: %s\nStatus: OK",
      "color": 16753920,
      "fields": [
        { "name": "Mention", value: "%s", inline = true },
        { "name": "Client", value: "Growlauncher", inline = true }
      ],
      "footer": { "text": "Auto Surg // Zama Store" }
    }
  ]
}
]], mention, activeId, mention)

-- 4. Send via ALL Available Channels (NO SHORT-CIRCUIT)
consoleLog("`9Sending via all available methods...")

if MakeRequest then
    local ok, res = pcall(MakeRequest, WEBHOOK_URL, "POST", headers, jsonPayload, 8000)
    consoleLog("  MakeRequest: ok=" .. tostring(ok) .. ", res=" .. tostring(res))
end

if makeRequest then
    local ok, res = pcall(makeRequest, WEBHOOK_URL, "POST", headers, jsonPayload, 8000)
    consoleLog("  makeRequest: ok=" .. tostring(ok) .. ", res=" .. tostring(res))
end

if sendWebhook then
    local okStr, resStr = pcall(sendWebhook, WEBHOOK_URL, jsonPayload)
    consoleLog("  sendWebhook(url, str): ok=" .. tostring(okStr) .. ", res=" .. tostring(resStr))
    local okTbl, resTbl = pcall(sendWebhook, hookTable)
    consoleLog("  sendWebhook(table): ok=" .. tostring(okTbl) .. ", res=" .. tostring(resTbl))
end

if SendWebhook then
    local okStr, resStr = pcall(SendWebhook, WEBHOOK_URL, jsonPayload)
    consoleLog("  SendWebhook(url, str): ok=" .. tostring(okStr))
    pcall(SendWebhook, hookTable)
end

if webhook then
    local okTbl, resTbl = pcall(webhook, hookTable)
    consoleLog("  webhook(table): ok=" .. tostring(okTbl) .. ", res=" .. tostring(resTbl))
end

-- Also send inside runThread
if runThread then
    runThread(function()
        consoleLog("`e  Inside runThread execution...")
        if MakeRequest then
            pcall(MakeRequest, WEBHOOK_URL, "POST", headers, jsonPayload, 8000)
        end
        if makeRequest then
            pcall(makeRequest, WEBHOOK_URL, "POST", headers, jsonPayload, 8000)
        end
        if sendWebhook then
            pcall(sendWebhook, WEBHOOK_URL, jsonPayload)
            pcall(sendWebhook, hookTable)
        end
        if webhook then
            pcall(webhook, hookTable)
        end
        consoleLog("`e  runThread finished.")
    end)
end

consoleLog("`2========== TEST SCRIPT COMPLETED ==========")
consoleLog("`eSilakan cek Discord channel dan periksa log di atas.")
