-- Runs once force_report knows the framework is "esx" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("esx", function()
  local ESX
  local resource = GetFrameworkResource() or "es_extended"
  -- Loaded again when es_extended restarts: the old shared object points at the stopped resource
  LoadFrameworkObject(resource, function()
    return exports[resource]:getSharedObject()
  end, function(obj)
    ESX = obj
  end)

  --- Staff by ESX group (Config.Staff.esxGroups). ACE permissions are checked before this in server/main.lua.
  --- @param source number
  --- @return boolean
  function IsFrameworkStaff(source)
    local xPlayer = ESX and ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local group = type(xPlayer.getGroup) == "function" and xPlayer.getGroup() or xPlayer.group
    return ListHas(Config.Staff.esxGroups, group)
  end
end)
