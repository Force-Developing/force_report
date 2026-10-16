-- Runs once force_report knows the framework is "qb" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("qb", function()
  local QBCore
  local resource = GetFrameworkResource() or "qb-core"
  -- Loaded again when qb-core restarts: the old core object points at the stopped resource
  LoadFrameworkObject(resource, function()
    return exports[resource]:GetCoreObject()
  end, function(obj)
    QBCore = obj
  end)

  --- Staff by QBCore permission (Config.Staff.qbPermissions). ACE permissions are checked before this.
  --- @param source number
  --- @return boolean
  function IsFrameworkStaff(source)
    local permissions = Config.Staff.qbPermissions
    if type(permissions) ~= "table" or #permissions == 0 then return false end
    local hasPermission = QBCore and QBCore.Functions and QBCore.Functions.HasPermission
    for _, permission in ipairs(permissions) do
      if hasPermission then
        if hasPermission(source, permission) then return true end
      elseif IsPlayerAceAllowed(source, permission) then
        return true
      end
    end
    return false
  end
end)
