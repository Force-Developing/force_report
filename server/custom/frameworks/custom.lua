-- Runs once force_report knows the framework is "custom": Config.Framework = "custom", or "auto" when none
-- of qbx_core, es_extended and qb-core is installed. Keep your code inside this function.
RegisterFramework("custom", function()
  --- TODO (optional): return true for players your framework treats as staff. ACE permissions
  --- (Config.Staff.aces) are checked first and work without this.
  --- @param source number
  --- @return boolean
  function IsFrameworkStaff(source)
    return false
  end
end)
