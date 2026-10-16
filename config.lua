Config = {}

-- Prints extra info to the server console. Setup errors are always printed.
Config.Debug = false

-- "en", "sv" or "auto" (follows the replicated ox:locale convar: setr ox:locale "sv")
Config.Locale = "en"

-- "auto" (detected by the server: qbx_core, es_extended, qb-core), "esx", "qb", "qbx" or "custom".
-- The framework is only used for the optional staff groups below; reports work on any server.
Config.Framework = "auto"

-- Chat commands. Each entry is one name or a list of names; the first name is the one shown in help texts.
-- The Swedish names from version 1 (/svara, /klar) are kept as extra names so staff can keep using them.
-- Remove them if you don't want them, e.g. reply = "reply".
Config.Commands = {
  report = { "report" },              -- players: /report <message>
  reply = { "reply", "svara" },       -- staff:   /reply <#report or player id> <message>
  close = { "closereport", "klar" },  -- staff:   /closereport <#report or player id>
  list = { "reports" },               -- staff:   /reports
}

-- Who is staff. A player is staff when ANY of these matches.
Config.Staff = {
  -- ACE permissions, checked on every framework. Grant the first one in server.cfg:
  --   add_ace group.admin force_report.staff allow
  -- "command" is the ACE of players allowed to run every command (group.admin in the default server.cfg),
  -- so admins are staff out of the box. Remove it to decide staff by force_report.staff only.
  aces = { "force_report.staff", "command" },
  -- ESX: player groups (xPlayer.getGroup())
  esxGroups = { "superadmin", "admin", "mod" },
  -- QBCore: permissions checked with QBCore.Functions.HasPermission
  qbPermissions = { "god", "admin", "mod" },
  -- QBox has no own staff groups; its admins are in group.admin and covered by the ACE above.
}

Config.Report = {
  -- Seconds between two reports of the same player
  cooldown = 30,
  -- Characters a report must have
  minLength = 3,
  -- Longer reports are cut off
  maxLength = 250,
  -- Open reports one player may have at the same time
  maxOpenPerPlayer = 3,
}

Config.Reply = {
  -- Longer replies are cut off
  maxLength = 250,
  -- Show the staff member's name to the player ("Staff (Name)"), or only "Staff"
  showStaffName = true,
}

-- Most reports listed by the list command (the newest are shown)
Config.ListLimit = 10

-- "chat": messages in the chat (chat:addMessage); falls back to ox_lib notifications when the chat resource isn't
-- running. "notify": always ox_lib notifications.
Config.Output = "chat"
-- Name of your chat resource
Config.ChatResource = "chat"

--[[
  Discord log. The webhook URL is NOT set here: this file is sent to every client. Set it in server.cfg with `set`
  (not `setr`, which would send it to the clients too):
    set force_report:webhook "https://discord.com/api/webhooks/..."
]]
Config.Discord = {
  enabled = true,
  username = "force_report",
  -- Embed colors (decimal)
  colors = { report = 15158332, reply = 15105570, close = 3066993, left = 9807270 },
  -- Milliseconds between two webhook calls. Discord allows about 5 calls per 2 seconds per webhook.
  interval = 1000,
  -- Messages waiting to be sent; more are dropped with a console warning
  queueLimit = 50,
}
