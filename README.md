# force_report

In-game reports for staff. A player types `/report <message>`, every online staff member sees it with a report id, staff answer the player with `/reply` and close the report with `/closereport`. Every step can be logged to a Discord webhook.

Free and open source. Works on ESX Legacy, QBCore and QBox, and on servers without a framework.

## Features

- `/report`, `/reply`, `/closereport` and `/reports` (open reports); the names are configurable, and the Swedish names from version 1 (`/svara`, `/klar`) still work by default
- Reports get an id: staff answer and close with `#12` (report 12) or a player's server id
- Staff is checked on the server for every command: ACE permission `force_report.staff` (and `command`, so admins work out of the box), plus ESX groups and QBCore permissions
- Per-player cooldown, a limit of open reports per player and a length limit
- Colour codes, GTA text codes, HTML and control characters are removed from reports, replies and player names
- Open reports close automatically when the player leaves
- Messages in the chat (`chat:addMessage`) with chat suggestions; ox_lib notifications when the chat resource isn't running
- Discord log through a server-only convar, rate limited, with mentions disabled
- Server events and exports for your own integrations
- English and Swedish locales
- No database

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- Optional: ESX Legacy, QBCore or QBox (only used for staff groups), the cfx `chat` resource

## Installation

1. Put the folder in your resources as `force_report`.
2. Add `ensure force_report` to `server.cfg` below `ensure ox_lib`.
3. Give your staff the permission in `server.cfg`:
   ```
   add_ace group.admin force_report.staff allow
   ```
4. Optional Discord log, also in `server.cfg`. Use `set`, not `setr`, so the URL never reaches the clients:
   ```
   set force_report:webhook "https://discord.com/api/webhooks/..."
   ```

## Upgrading from 1.x

Version 1 shipped a Discord webhook URL in `config.lua`. It is still in this repository's git history, so treat it as public. The webhook now only comes from the `force_report:webhook` convar.

## Documentation

https://docs.forcedevelopments.com/free-resources/force_report/introduction

## License

Apache 2.0, see [LICENSE](LICENSE).
