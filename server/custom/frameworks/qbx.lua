-- Runs once force_report knows the framework is "qbx" (Config.Framework, or detected by the server).
-- Keep your code inside this function.
RegisterFramework("qbx", function()
  --- QBox has no staff groups of its own: admins are in the group.admin principal and are staff through the ACE
  --- permissions in Config.Staff.aces. Return true here for anything else you want to count as staff.
  --- @param source number
  --- @return boolean
  function IsFrameworkStaff(source)
    return false
  end
end)
