-- =======================================================
-- GROWLAUNCHER DISCORD WEBHOOK DIAGNOSTIC & TEST SCRIPT
-- =======================================================
local WEBHOOK_URL = "https://discord.com/api/webhooks/1545485199834480712/DrfQI97OHYB0LSzDq6ke8sYZ-G182FI1dOa4GBMLEPaNVEHFGnm3SSi-6go0w9KtDGrB"

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

consoleLog("`2========== STARTING WEBHOOK DIAGNOSTIC ==========")

-- 1. Scan available global networking APIs
consoleLog("`9[1] Scanning Global Networking Functions in _G...")
local candidateNames = {
    "makeRequest", "MakeRequest", "httpRequest", "HttpRequest",
    "sendWebhook", "SendWebhook", "webhook", "Webhook",
    "fetch", "Fetch", "request", "Request",
    "runThread", "runCoroutine", "HttpClient", "http"
}

for _, name in ipairs(candidateNames) do
    local val = _G[name]
    if val ~= nil then
        consoleLog("`2  FOUND: `1" .. name .. " `o(`e" .. type(val) .. "`o)")
    end
end

-- Scan any other function in _G containing hook, http, request, or fetch
local scannedMatches = {}
for k, v in pairs(_G) do
    if type(k) == "string" and type(v) == "function" then
        local lk = k:lower()
        if lk:find("webhook") or lk:find("httpreq") or lk:find("makereq") then
            table.insert(scannedMatches, k)
        end
    end
end
if #scannedMatches > 0 then
    consoleLog("`9  Other matches: `o" .. table.concat(scannedMatches, ", "))
end

-- Prepare test payloads
local simplePayload = '{"content":"Growlauncher Webhook Test: Connection Successful!"}'
local embedPayload = [[
{
  "content": "<@1407053020306341969>",
  "username": "Growlauncher Webhook Test",
  "embeds": [
    {
      "title": "🎉 Test Webhook Berhasil!",
      "description": "Script pengirim webhook berfungsi dengan baik di Growlauncher.",
      "color": 65280,
      "fields": [
        { "name": "Status", "value": "SUCCESS", "inline": true },
        { "name": "Client", "value": "Growlauncher", "inline": true }
      ]
    }
  ]
}
]]

-- 2. Test makeRequest directly (Sync / Main Thread)
consoleLog("`9[2] Testing makeRequest (Direct / Sync)...")
if makeRequest then
    local headers = { ["Content-Type"] = "application/json" }
    
    -- Try format 1: (url, method, headers, payload, timeout)
    consoleLog("  Attempt 1: makeRequest(url, 'POST', headers, payload, 8000)")
    local ok1, res1 = pcall(makeRequest, WEBHOOK_URL, "POST", headers, simplePayload, 8000)
    consoleLog("  Result 1: ok=" .. tostring(ok1) .. ", res=" .. tostring(res1))
    if ok1 and type(res1) == "table" then
        for k, v in pairs(res1) do
            consoleLog("    res." .. tostring(k) .. " = " .. tostring(v):sub(1, 100))
        end
    end

    -- Try format 2: (url, method, headers, payload)
    if not ok1 then
        consoleLog("  Attempt 2: makeRequest(url, 'POST', headers, payload)")
        local ok2, res2 = pcall(makeRequest, WEBHOOK_URL, "POST", headers, simplePayload)
        consoleLog("  Result 2: ok=" .. tostring(ok2) .. ", res=" .. tostring(res2))
    end
else
    consoleLog("`4  makeRequest is NOT available.")
end

-- 3. Test sendWebhook if exists
consoleLog("`9[3] Testing sendWebhook...")
local hookFn = sendWebhook or SendWebhook or webhook or Webhook
if hookFn then
    local okH, resH = pcall(hookFn, WEBHOOK_URL, simplePayload)
    consoleLog("  sendWebhook Result: ok=" .. tostring(okH) .. ", res=" .. tostring(resH))
else
    consoleLog("`4  sendWebhook is NOT available.")
end

-- 4. Test fetch if exists
consoleLog("`9[4] Testing fetch...")
local fetchFn = fetch or Fetch
if fetchFn then
    -- Try POST options
    local okF1, resF1 = pcall(fetchFn, WEBHOOK_URL, {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = simplePayload
    })
    consoleLog("  fetch (options) Result: ok=" .. tostring(okF1) .. ", res=" .. tostring(resF1))
    
    -- Try direct fetch
    local okF2, resF2 = pcall(fetchFn, WEBHOOK_URL, simplePayload)
    consoleLog("  fetch (raw body) Result: ok=" .. tostring(okF2) .. ", res=" .. tostring(resF2))
else
    consoleLog("`4  fetch is NOT available.")
end

-- 5. Test inside runThread (Background Thread)
consoleLog("`9[5] Testing inside runThread...")
if runThread then
    runThread(function()
        consoleLog("`e  Inside runThread execution...")
        if makeRequest then
            local okT, resT = pcall(makeRequest, WEBHOOK_URL, "POST", { ["Content-Type"] = "application/json" }, embedPayload, 8000)
            consoleLog("  runThread makeRequest Result: ok=" .. tostring(okT) .. ", res=" .. tostring(resT))
        elseif hookFn then
            local okT, resT = pcall(hookFn, WEBHOOK_URL, embedPayload)
            consoleLog("  runThread sendWebhook Result: ok=" .. tostring(okT) .. ", res=" .. tostring(resT))
        else
            consoleLog("`4  runThread: no suitable HTTP function found.")
        end
    end)
else
    consoleLog("`4  runThread is NOT available.")
end

consoleLog("`2========== DIAGNOSTIC SCRIPT FINISHED ==========")
consoleLog("`eSilakan screenshot / copy hasil log di atas dan infokan ke chat.")

