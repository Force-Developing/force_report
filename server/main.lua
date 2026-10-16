local RESOURCE = GetCurrentResourceName()

local reports = {}      -- [id] = { id, source, name, message, created (os.time), handledBy }
local nextId = 0
local lastReport = {}   -- [source] = GetGameTimer() of the player's last accepted report

local CHAT_COLORS = {
  report = { 231, 76, 60 },
  reply = { 230, 126, 34 },
  close = { 46, 204, 113 },
  info = { 170, 170, 170 },
  error = { 231, 76, 60 },
}
local NOTIFY_TYPES = { report = "warning", reply = "inform", close = "success", info = "inform", error = "error" }

-------------------------------------------------------------------------------------------------------------------
-- Text
-------------------------------------------------------------------------------------------------------------------

--- Removes everything a chat or HUD could interpret: control characters, ^0-^9 colour codes, ~x~ GTA text codes
--- and < > (HTML in chat templates). Collapses whitespace and cuts to maxLength characters (UTF-8 aware).
--- @param value any
--- @param maxLength number|nil
--- @return string
function SanitizeText(value, maxLength)
  if type(value) ~= "string" then return "" end
  local text = value:gsub("%c", " ")
  if not utf8.len(text) then text = text:gsub("[\128-\255]", "") end -- invalid UTF-8: keep the ASCII part
  local removed
  repeat -- loops, because removing one code can join the characters around it into a new one ("^^11")
    text, removed = text:gsub("%^%d", "")
    local more
    text, more = text:gsub("~[%a%d_]~", "")
    removed = removed + more
  until removed == 0
  text = text:gsub("[<>]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
  maxLength = tonumber(maxLength)
  if maxLength and utf8.len(text) > maxLength then
    text = text:sub(1, utf8.offset(text, maxLength + 1) - 1):match("^(.-)%s*$")
  end
  return text
end

local function playerName(source)
  if source == 0 then return locale("console") end
  local name = SanitizeText(GetPlayerName(source), 32)
  return name ~= "" and name or locale("unknown_player_name")
end

local function playerExists(source)
  return source ~= nil and source > 0 and DoesPlayerExist(tostring(source)) == true
end

-------------------------------------------------------------------------------------------------------------------
-- Output
-------------------------------------------------------------------------------------------------------------------

local function useChat()
  return Config.Output ~= "notify" and GetResourceState(Config.ChatResource or "chat") == "started"
end

--- Sends a message to one player (chat or ox_lib notify) or prints it for the server console (target 0)
--- @param target number
--- @param kind "report"|"reply"|"close"|"info"|"error"
--- @param title string
--- @param text string
--- @param hint string|nil second, grey line
local function send(target, kind, title, text, hint)
  if target == 0 then
    print(("[%s] %s: %s%s"):format(RESOURCE, title, text, hint and (" (" .. hint .. ")") or ""))
    return
  end
  if useChat() then
    TriggerClientEvent("chat:addMessage", target, { color = CHAT_COLORS[kind], multiline = true, args = { title, text } })
    if hint then
      TriggerClientEvent("chat:addMessage", target, { color = CHAT_COLORS.info, multiline = true, args = { hint } })
    end
  else
    TriggerClientEvent("ox_lib:notify", target, {
      title = title,
      description = hint and (text .. "  \n" .. hint) or text,
      type = NOTIFY_TYPES[kind] or "inform",
      duration = kind == "report" and 15000 or 8000,
    })
  end
end

-------------------------------------------------------------------------------------------------------------------
-- Staff
-------------------------------------------------------------------------------------------------------------------

--- ACE (Config.Staff.aces) on every framework, then the framework bridge (ESX groups, QBCore permissions).
--- The server console (0) is staff.
--- @param source number
--- @return boolean
local function isStaff(source)
  source = tonumber(source)
  if source == 0 then return true end
  if not playerExists(source) then return false end
  for _, ace in ipairs(type(Config.Staff) == "table" and Config.Staff.aces or {}) do
    if type(ace) == "string" and IsPlayerAceAllowed(source, ace) then return true end
  end
  local ok, result = pcall(IsFrameworkStaff, source)
  if not ok then
    Debug("error", "IsFrameworkStaff failed: %s", tostring(result))
    return false
  end
  return result == true
end

--- Server ids of every online staff member
local function onlineStaff()
  local list = {}
  for _, id in ipairs(GetPlayers()) do
    id = tonumber(id)
    if id and isStaff(id) then list[#list + 1] = id end
  end
  return list
end

local function sendToStaff(kind, title, text, hint)
  local staff = onlineStaff()
  for _, id in ipairs(staff) do send(id, kind, title, text, hint) end
  return staff
end

-------------------------------------------------------------------------------------------------------------------
-- Reports
-------------------------------------------------------------------------------------------------------------------

local function copyReport(report)
  return {
    id = report.id, source = report.source, name = report.name, message = report.message,
    created = report.created, handledBy = report.handledBy,
  }
end

local function openReportsOf(source)
  local list = {}
  for _, report in pairs(reports) do
    if report.source == source then list[#list + 1] = report end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

--- "#12" -> report 12, "5" -> player 5 (and their newest open report, if any)
--- @return number|nil target, table|nil report, string|nil error locale key
local function resolveTarget(arg)
  if type(arg) ~= "string" then return nil, nil, "bad_target" end
  local reportId = arg:match("^#(%d%d?%d?%d?%d?%d?%d?)$")
  if reportId then
    local report = reports[tonumber(reportId)]
    if not report then return nil, nil, "unknown_report", reportId end
    return report.source, report
  end
  local playerId = arg:match("^(%d%d?%d?%d?%d?%d?)$")
  if playerId then
    playerId = tonumber(playerId)
    if not playerExists(playerId) then return nil, nil, "unknown_player", playerId end
    local open = openReportsOf(playerId)
    return playerId, open[#open]
  end
  return nil, nil, "bad_target"
end

--- Removes a report and tells the reporter, the staff and Discord. by = staff source, or nil when the player left.
local function closeReport(report, by)
  if reports[report.id] ~= report then return end
  reports[report.id] = nil

  local closedBy = by and playerName(by) or nil
  if by then
    if playerExists(report.source) then send(report.source, "close", locale("report_title"), locale("closed_player", report.id)) end
    sendToStaff("close", locale("report_title"), locale("closed_staff", report.id, report.name, report.source, closedBy))
    SendToDiscord("close", locale("discord_closed", report.id), {
      { name = locale("discord_player"), value = ("%s [%s]"):format(report.name, report.source) },
      { name = locale("discord_staff"), value = by == 0 and closedBy or ("%s [%s]"):format(closedBy, by) },
    })
  else
    sendToStaff("info", locale("report_title"), locale("closed_left", report.id, report.name, report.source))
    SendToDiscord("left", locale("discord_left", report.id), {
      { name = locale("discord_player"), value = ("%s [%s]"):format(report.name, report.source) },
    })
  end
  TriggerEvent("force_report:reportClosed", copyReport(report), by)
end

-------------------------------------------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------------------------------------------

local function onReport(source, args, raw)
  if source == 0 then return send(0, "error", locale("report_title"), locale("console_cannot_report")) end
  local title = locale("report_title")
  local cfg = Config.Report
  -- from the raw line: cfx strips double quotes from args
  local message = SanitizeText(type(raw) == "string" and raw:match("^/?%S+%s*(.*)$") or table.concat(args, " "),
    cfg.maxLength)
  if utf8.len(message) < (tonumber(cfg.minLength) or 1) then
    return send(source, "error", title, locale("report_usage", GetCommandLabel("report"), cfg.minLength))
  end

  local now = GetGameTimer()
  local cooldown = (tonumber(cfg.cooldown) or 0) * 1000
  if lastReport[source] and now - lastReport[source] < cooldown then
    return send(source, "error", title, locale("cooldown", math.ceil((cooldown - (now - lastReport[source])) / 1000)))
  end
  local maxOpen = tonumber(cfg.maxOpenPerPlayer) or 3
  if #openReportsOf(source) >= maxOpen then
    return send(source, "error", title, locale("too_many_open", maxOpen))
  end

  lastReport[source] = now
  nextId = nextId + 1
  local report = { id = nextId, source = source, name = playerName(source), message = message, created = os.time() }
  reports[report.id] = report

  local staff = sendToStaff("report", locale("staff_report_title", report.id, report.name, source), message,
    locale("staff_report_hint", GetCommandLabel("reply"), report.id, GetCommandLabel("close"), report.id))
  send(source, "info", title, locale(#staff > 0 and "report_sent" or "report_sent_no_staff", report.id))
  SendToDiscord("report", locale("discord_report", report.id), {
    { name = locale("discord_player"), value = ("%s [%s]"):format(report.name, source) },
  }, message)
  Debug("info", "Report #%s from %s [%s], %s staff online", report.id, report.name, source, #staff)
  TriggerEvent("force_report:reportCreated", copyReport(report))
end

local function onReply(source, args, raw)
  local title = locale("staff_title")
  if not isStaff(source) then return send(source, "error", title, locale("not_staff")) end
  local message = SanitizeText(type(raw) == "string" and raw:match("^/?%S+%s+%S+%s*(.*)$") or table.concat(args, " ", 2),
    Config.Reply.maxLength)
  if not args[1] or message == "" then
    return send(source, "error", title, locale("reply_usage", GetCommandLabel("reply")))
  end
  local target, report, problem, value = resolveTarget(args[1])
  if not target then return send(source, "error", title, locale(problem, value)) end

  local staffName = playerName(source)
  local targetName = report and report.name or playerName(target)
  local playerTitle = Config.Reply.showStaffName and locale("reply_title_player", staffName)
      or locale("reply_title_player_anonymous")
  send(target, "reply", playerTitle, message)
  local staffTitle = report and locale("reply_title_staff_report", staffName, report.id, targetName, target)
      or locale("reply_title_staff", staffName, targetName, target)
  sendToStaff("reply", staffTitle, message)
  if source == 0 then send(0, "reply", staffTitle, message) end

  if report then report.handledBy = report.handledBy or staffName end
  SendToDiscord("reply", report and locale("discord_reply_report", report.id) or locale("discord_reply"), {
    { name = locale("discord_staff"), value = source == 0 and staffName or ("%s [%s]"):format(staffName, source) },
    { name = locale("discord_player"), value = ("%s [%s]"):format(targetName, target) },
  }, message)
  TriggerEvent("force_report:reportReplied", report and copyReport(report) or nil, source, target, message)
end

local function onClose(source, args)
  local title = locale("staff_title")
  if not isStaff(source) then return send(source, "error", title, locale("not_staff")) end
  if not args[1] then return send(source, "error", title, locale("close_usage", GetCommandLabel("close"))) end
  local target, report, problem, value = resolveTarget(args[1])
  if not target then return send(source, "error", title, locale(problem, value)) end

  -- "#12" closes that report, a player id closes every open report of that player
  local list = args[1]:sub(1, 1) == "#" and { report } or openReportsOf(target)
  if #list == 0 then return send(source, "error", title, locale("no_open_reports_of", target)) end
  for _, entry in ipairs(list) do
    closeReport(entry, source)
    if source == 0 then send(0, "close", title, locale("closed_staff", entry.id, entry.name, entry.source, playerName(0))) end
  end
end

local function onList(source)
  local title = locale("staff_title")
  if not isStaff(source) then return send(source, "error", title, locale("not_staff")) end
  local list = {}
  for _, report in pairs(reports) do list[#list + 1] = report end
  if #list == 0 then return send(source, "info", title, locale("list_empty")) end
  table.sort(list, function(a, b) return a.id < b.id end)

  local limit = math.max(math.floor(tonumber(Config.ListLimit) or 10), 1)
  send(source, "info", title, locale("list_title", #list))
  local first = math.max(#list - limit + 1, 1)
  for i = first, #list do
    local report = list[i]
    local minutes = math.floor((os.time() - report.created) / 60)
    local line = report.handledBy
        and locale("list_entry_handled", report.id, report.name, report.source, minutes, report.handledBy)
        or locale("list_entry", report.id, report.name, report.source, minutes)
    send(source, "report", line, report.message)
  end
  if first > 1 then send(source, "info", title, locale("list_more", first - 1)) end
end

local HANDLERS = { report = onReport, reply = onReply, close = onClose, list = onList }

local function registerCommands()
  local others = {}
  for _, command in ipairs(GetRegisteredCommands and GetRegisteredCommands() or {}) do
    if command.resource and command.resource ~= RESOURCE then others[command.name] = command.resource end
  end
  for kind, handler in pairs(HANDLERS) do
    for _, name in ipairs(GetCommandNames(kind)) do
      if others[name] then
        Log("warn", ("/%s is also registered by %s; the resource that starts last owns it. Rename it in " ..
          "Config.Commands.%s."):format(name, others[name], kind))
      end
      RegisterCommand(name, function(source, args, raw)
        local ok, err = pcall(handler, tonumber(source) or 0, type(args) == "table" and args or {}, raw)
        if not ok then Debug("error", "/%s failed: %s", name, tostring(err)) end
      end, false)
    end
  end
end

registerCommands()

-------------------------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------------------------

AddEventHandler("playerDropped", function()
  local source = tonumber(source)
  if not source then return end
  lastReport[source] = nil
  for _, report in ipairs(openReportsOf(source)) do closeReport(report, nil) end
end)

AddEventHandler("onResourceStop", function(resource)
  if resource ~= RESOURCE then return end
  local open = 0
  for _ in pairs(reports) do open = open + 1 end
  if open > 0 then Log("warn", ("%s open report(s) were discarded by the stop."):format(open)) end
  reports, lastReport = {}, {}
end)

-------------------------------------------------------------------------------------------------------------------
-- Exports
-------------------------------------------------------------------------------------------------------------------

--- @return table[] copies of the open reports, oldest first
exports("getOpenReports", function()
  local list = {}
  for _, report in pairs(reports) do list[#list + 1] = copyReport(report) end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end)

--- @param source number
--- @return boolean
exports("isStaff", function(source)
  source = tonumber(source)
  return source ~= nil and source > 0 and isStaff(source)
end)
