-- Rate-limited Discord webhook log.
-- The URL is read from the server convar force_report:webhook only (set it with `set`, not `setr`). It is never
-- stored in config.lua, which every client downloads, and never printed.
local CONVAR = "force_report:webhook"
local REQUEST_TIMEOUT = 15000
local BACKTICK = string.char(96) -- Discord code marker, kept out of the source (cfx reads backticks as hashes)
local CODE_BLOCK = BACKTICK:rep(3)

local queue = {}       -- { payload = json string, tries = number }
local running = false
local lastLog = {}     -- [key] = GetGameTimer() of the last console line, so a broken webhook doesn't flood it

local function logThrottled(key, level, message)
  local now = GetGameTimer()
  if lastLog[key] and now - lastLog[key] < 60000 then return end
  lastLog[key] = now
  Log(level, message)
end

local function getWebhook()
  local url = GetConvar(CONVAR, "")
  if url == "" then return nil end
  if not url:match("^https://[%w%.%-]+/") then
    logThrottled("url", "warn", ("The convar %s is not an https URL, the Discord log is off."):format(CONVAR))
    return nil
  end
  return url
end

--- POSTs one payload and waits for the answer (at most REQUEST_TIMEOUT ms)
local function post(url, payload)
  local p = promise.new()
  local settled = false
  local function settle(status, body, headers)
    if settled then return end
    settled = true
    p:resolve({ status = tonumber(status) or 0, body = body, headers = headers })
  end
  PerformHttpRequest(url, function(status, body, headers) settle(status, body, headers) end, "POST", payload,
    { ["Content-Type"] = "application/json" })
  SetTimeout(REQUEST_TIMEOUT, function() settle(0) end)
  return Citizen.Await(p)
end

--- Seconds Discord asks us to wait after a 429 (JSON body retry_after, or the Retry-After header), 1 to 60
local function retryAfter(result)
  local seconds
  if type(result.body) == "string" and result.body ~= "" then
    local ok, data = pcall(json.decode, result.body)
    if ok and type(data) == "table" then seconds = tonumber(data.retry_after) end
  end
  if not seconds and type(result.headers) == "table" then
    seconds = tonumber(result.headers["Retry-After"] or result.headers["retry-after"])
  end
  return math.min(math.max(seconds or 5, 1), 60)
end

local function interval()
  return math.max(tonumber(Config.Discord.interval) or 1000, 250)
end

--- Sends the queue one message at a time, waiting Config.Discord.interval between calls and longer on a 429
local function work()
  while #queue > 0 do
    local url = getWebhook()
    if not url then
      queue = {}
      break
    end
    local entry = queue[1]
    local result = post(url, entry.payload)
    if result.status == 429 then
      entry.tries = entry.tries + 1
      if entry.tries >= 3 then
        table.remove(queue, 1)
        logThrottled("429", "warn", "Discord rate limited the webhook three times in a row, a log message was dropped.")
      end
      Wait(retryAfter(result) * 1000)
    else
      table.remove(queue, 1)
      if result.status < 200 or result.status >= 300 then
        logThrottled("status" .. result.status, "error", ("The Discord webhook answered %s, the log message was " ..
          "dropped. Check the %s convar."):format(result.status == 0 and "nothing" or result.status, CONVAR))
      end
      Wait(interval())
    end
  end
end

local function startWorker()
  if running then return end
  running = true
  CreateThread(function()
    local ok, err = pcall(work)
    running = false
    if not ok then
      queue = {}
      Log("error", "Discord log failed: " .. tostring(err))
    end
  end)
end

--- Text in an inline code span: no markdown, links or mentions are rendered
local function code(value)
  value = tostring(value or ""):gsub(BACKTICK, "'")
  if value == "" then value = " " end
  return BACKTICK .. value .. BACKTICK
end

--- Queues one embed for the Discord log. All text must already be sanitised (SanitizeText).
--- @param kind "report"|"reply"|"close"|"left" picks the embed color
--- @param title string
--- @param fields { name: string, value: string }[]
--- @param message string|nil shown as a code block
--- @return boolean queued
function SendToDiscord(kind, title, fields, message)
  if type(Config.Discord) ~= "table" or not Config.Discord.enabled then return false end
  if not getWebhook() then return false end

  local limit = tonumber(Config.Discord.queueLimit) or 50
  if #queue >= limit then
    logThrottled("queue", "warn", ("More than %s Discord log messages are waiting, new ones are dropped."):format(limit))
    return false
  end

  local embedFields = {}
  for _, field in ipairs(fields or {}) do
    embedFields[#embedFields + 1] = { name = field.name, value = code(field.value), inline = true }
  end
  local embed = {
    title = title,
    color = type(Config.Discord.colors) == "table" and tonumber(Config.Discord.colors[kind]) or nil,
    fields = embedFields,
    footer = { text = GetCurrentResourceName() },
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  if type(message) == "string" and message ~= "" then
    embed.description = CODE_BLOCK .. "\n" .. (message:gsub(BACKTICK, "'")) .. "\n" .. CODE_BLOCK
  end

  queue[#queue + 1] = {
    tries = 0,
    payload = json.encode({
      username = Config.Discord.username or "force_report",
      embeds = { embed },
      -- nobody is pinged, whatever the text contains (@everyone, role or user mentions)
      allowed_mentions = { parse = {} },
    }),
  }
  startWorker()
  return true
end
