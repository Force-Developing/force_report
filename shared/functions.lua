local RESOURCE = GetCurrentResourceName()
local IS_SERVER = IsDuplicityVersion()

--- Prints to the console regardless of Config.Debug (setup problems must always be visible).
--- @param level "error"|"warn"|"info"
function Log(level, message)
  local color = level == "error" and "^1" or level == "warn" and "^3" or "^2"
  print(("%s[%s] %s^7"):format(color, RESOURCE, tostring(message)))
end

--- Debug output. Errors are always printed, everything else only with Config.Debug.
function Debug(level, message, ...)
  message = tostring(message)
  if select("#", ...) > 0 then
    local ok, formatted = pcall(string.format, message, ...)
    if ok then message = formatted end
  end
  if level == "error" then
    lib.print.error(message)
    return
  end
  if not Config.Debug then return end
  local fn = ({ warn = lib.print.warn, info = lib.print.info, debug = lib.print.debug })[level] or lib.print.info
  fn(message)
end

--- Loads the configured locale. "auto" follows the replicated ox:locale convar; anything without a file -> "en".
local function InitLocale()
  local key = Config.Locale
  if type(key) ~= "string" or key == "auto" then key = GetConvar("ox:locale", "en") end
  local function hasLocale(name)
    return name and LoadResourceFile(RESOURCE, ("locales/%s.json"):format(name)) ~= nil
  end
  if not hasLocale(key) then
    local language = key:match("^(%a+)")
    key = hasLocale(language) and language or "en"
  end
  lib.locale(key)
end

-------------------------------------------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------------------------------------------

local COMMAND_KINDS = { "report", "reply", "close", "list" }
local DEFAULT_COMMANDS = { report = "report", reply = "reply", close = "closereport", list = "reports" }
local commandNames -- [kind] = { "name", ... }

--- Validates Config.Commands once per side: lower case, letters/digits/_/- only, no name used twice.
local function PrepareCommands()
  commandNames = {}
  local used = {}
  local configured = type(Config.Commands) == "table" and Config.Commands or {}
  for _, kind in ipairs(COMMAND_KINDS) do
    local list = configured[kind]
    if type(list) == "string" then list = { list } end
    if type(list) ~= "table" then
      if list ~= nil then Log("error", ("Config.Commands.%s must be a name or a list of names"):format(kind)) end
      list = { DEFAULT_COMMANDS[kind] }
    end
    local names = {}
    for _, name in ipairs(list) do
      name = type(name) == "string" and name:lower():gsub("^/", "") or nil
      if not name or not name:match("^[%w_%-]+$") then
        Log("error", ("Config.Commands.%s: '%s' is not a valid command name, skipped"):format(kind, tostring(name)))
      elseif used[name] then
        Log("error", ("Config.Commands.%s: /%s is already used by Config.Commands.%s, skipped"):format(kind, name, used[name]))
      else
        used[name] = kind
        names[#names + 1] = name
      end
    end
    if #names == 0 then
      Log("warn", ("Config.Commands.%s has no command, players can't use that action"):format(kind))
    end
    commandNames[kind] = names
  end
end

--- @return string[] every name of a command kind ("report", "reply", "close", "list")
function GetCommandNames(kind)
  return commandNames[kind] or {}
end

--- @return string the first configured name with a slash, used in help texts ("/reply")
function GetCommandLabel(kind)
  local name = GetCommandNames(kind)[1]
  return name and ("/" .. name) or ("/" .. DEFAULT_COMMANDS[kind])
end

-------------------------------------------------------------------------------------------------------------------
-- Framework (server only: the client does nothing framework-specific)
--
-- Config.Framework = "auto": qbx_core before qb-core (qbx_core `provide`s qb-core, so GetResourceState('qb-core')
-- is "started" on QBox too), then es_extended, else "custom". A framework that is installed but not started yet is
-- waited for without a time limit, with a red warning every 10 seconds. Staff checks by ACE work meanwhile.
-------------------------------------------------------------------------------------------------------------------

local FRAMEWORKS = {
  { name = "qbx", resource = "qbx_core" },
  { name = "esx", resource = "es_extended" },
  { name = "qb",  resource = "qb-core" },
}
local FRAMEWORK_RESOURCES = { qbx = "qbx_core", esx = "es_extended", qb = "qb-core" }

local framework             -- { name, resource } once decided
local frameworkInits = {}   -- [name] = init functions registered by the framework files

local function RunSafe(label, fn)
  local ok, err = pcall(fn)
  if not ok then Log("error", ("%s failed: %s"):format(label, tostring(err))) end
end

local function NormalizeFramework(name)
  if name == "qbcore" then return "qb" end
  if name == "qbox" then return "qbx" end
  return name
end

--- Framework files (server/custom/frameworks) register their body here. It runs once the framework is known.
--- @param name string "esx" | "qb" | "qbx" | "custom"
--- @param init function
function RegisterFramework(name, init)
  name = NormalizeFramework(name)
  if framework then
    if framework.name == name then RunSafe("Framework file '" .. name .. "'", init) end
    return
  end
  frameworkInits[name] = frameworkInits[name] or {}
  table.insert(frameworkInits[name], init)
end

--- Resource name of the active framework (nil for custom or while undecided)
function GetFrameworkResource()
  return framework and framework.resource
end

local function ActivateFramework(entry)
  if framework then return end
  framework = entry
  Config.Framework = entry.name
  local inits = frameworkInits[entry.name]
  frameworkInits = {}
  for _, init in ipairs(inits or {}) do RunSafe("Framework file '" .. entry.name .. "'", init) end
  Debug("info", "Framework: " .. entry.name)
end

local function IsStartedOrStarting(resource)
  local state = GetResourceState(resource)
  return state == "started" or state == "starting"
end

local function IsInstalled(resource)
  local state = GetResourceState(resource)
  return state ~= "missing" and state ~= "unknown"
end

--- First running framework, otherwise nil and the frameworks that are installed but not started yet
local function FindRunning()
  for _, entry in ipairs(FRAMEWORKS) do
    if IsStartedOrStarting(entry.resource) then return entry end
  end
  local waiting = {}
  for _, entry in ipairs(FRAMEWORKS) do
    if IsInstalled(entry.resource) then waiting[#waiting + 1] = entry.resource end
  end
  return nil, waiting
end

local function Detect()
  local function resolved(entry)
    if entry then
      ActivateFramework({ name = entry.name, resource = entry.resource })
    else
      Log("warn", "No supported framework found (qbx_core, es_extended, qb-core). Staff is decided by ACE only " ..
        "(Config.Staff.aces); add framework groups in server/custom/frameworks/custom.lua.")
      ActivateFramework({ name = "custom" })
    end
  end

  local entry, waiting = FindRunning()
  if entry or #waiting == 0 then return resolved(entry) end

  CreateThread(function()
    local nextWarning = GetGameTimer() + 10000
    while true do
      Wait(250)
      entry, waiting = FindRunning()
      if entry or #waiting == 0 then return resolved(entry) end
      if GetGameTimer() >= nextWarning then
        Log("error", ("Waiting for the framework (%s) to start. Ensure it before %s in server.cfg, or remove it if " ..
          "you don't use it. Staff with an ACE permission can already use the commands."):format(
          table.concat(waiting, ", "), RESOURCE))
        nextWarning = GetGameTimer() + 10000
      end
    end
  end)
end

local function InitServer()
  local configured = NormalizeFramework(Config.Framework)
  if configured ~= "auto" and configured ~= "custom" and not FRAMEWORK_RESOURCES[configured] then
    Log("error", ("Unknown Config.Framework '%s', using \"auto\""):format(tostring(Config.Framework)))
    configured = "auto"
  end
  if configured == "auto" then
    Detect()
  else
    ActivateFramework({ name = configured, resource = FRAMEWORK_RESOURCES[configured] })
  end
end

--- Calls getter() until it returns a value, waiting for the framework without a time limit (warning every 10 s).
--- Runs again when the framework restarts, because cached core objects go stale.
--- @param resource string
--- @param getter fun(): any
--- @param onLoaded fun(obj: any)
function LoadFrameworkObject(resource, getter, onLoaded)
  local loading = false
  local function load()
    if loading then return end
    loading = true
    CreateThread(function()
      local nextWarning = GetGameTimer() + 10000
      while true do
        if GetResourceState(resource) == "started" then
          local ok, obj = pcall(getter)
          if ok and obj then
            onLoaded(obj)
            loading = false
            return
          end
        end
        if GetGameTimer() >= nextWarning then
          Log("warn", ("Still waiting for %s to start. Ensure it before %s in server.cfg."):format(resource, RESOURCE))
          nextWarning = GetGameTimer() + 10000
        end
        Wait(250)
      end
    end)
  end

  load()
  AddEventHandler("onServerResourceStart", function(started)
    if started == resource then load() end
  end)
end

--- True when value is one of the strings in list
function ListHas(list, value)
  if type(list) ~= "table" or value == nil then return false end
  for _, entry in ipairs(list) do
    if entry == value then return true end
  end
  return false
end

if IS_SERVER then
  -- Safe default until a framework file is active: only ACE decides who is staff
  function IsFrameworkStaff() return false end
end

InitLocale()
PrepareCommands()
if IS_SERVER then RunSafe("Framework detection", InitServer) end
