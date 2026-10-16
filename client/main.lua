-- The client only adds chat suggestions. Reports, staff checks and messages are handled by the server.
local CHAT = Config.ChatResource or "chat"

local function suggestions()
  local message = { name = locale("param_message"), help = locale("param_message_help") }
  local target = { name = locale("param_target"), help = locale("param_target_help") }
  local reply = { name = locale("param_message"), help = locale("param_reply_help") }
  return {
    report = { help = locale("suggest_report"), params = { message } },
    reply = { help = locale("suggest_reply"), params = { target, reply } },
    close = { help = locale("suggest_close"), params = { target } },
    list = { help = locale("suggest_list"), params = {} },
  }
end

local function forEachCommand(fn)
  for kind, suggestion in pairs(suggestions()) do
    for _, name in ipairs(GetCommandNames(kind)) do fn("/" .. name, suggestion) end
  end
end

local function addSuggestions()
  forEachCommand(function(name, suggestion)
    TriggerEvent("chat:addSuggestion", name, suggestion.help, suggestion.params)
  end)
end

-- The chat resource may start after this one on the client, or restart
AddEventHandler("onClientResourceStart", function(resource)
  if resource == CHAT then addSuggestions() end
end)

AddEventHandler("onClientResourceStop", function(resource)
  if resource ~= cache.resource then return end
  forEachCommand(function(name) TriggerEvent("chat:removeSuggestion", name) end)
end)

addSuggestions()
