ESX = nil

TriggerEvent(Config.ESX, function(obj) ESX = obj end)

Citizen.CreateThread(function()
	while true do
		Wait(5)
		RegisterCommand('klar', function(source, args)
			local template = '<div style="padding: 0.5vw; margin: 0.5vw; background: linear-gradient(90deg, rgba(2,0,36,0.7) 0%, rgba(0,255,38,0.7) 0%, rgba(18,77,21,0.7) 100%); border-radius: 3px;"><i class="fas fa-exclamation-circle"></i> {0}:<br> {1}</div>'
			local message = "Du har inte tillåtelse att göra detta!"
			local grupos = getIdentity(source)

			local Players = ESX.GetPlayers()

			for i = 1, #Players do
				local xPlayer = ESX.GetPlayerFromId(Players[i])
				local rank = xPlayer.getGroup()
				if grupos.group ~= 'user' then
					if (rank == "admin" or rank == "mod" or rank == "superadmin" and xPlayer.source ~= source) or xPlayer.source == source then
						SendDiscordMessage('**' .. GetPlayerName(source) .. ' ' .. '(' .. source .. ')' .. '**' .. ' *' .. 'har gjort klart ett ärrende!' .. '*', 'ID: ' ..table.concat(args, " "), 65280)
						TriggerClientEvent('esx-qalle-chat:sendMessage', xPlayer.source, xPlayer.source, "KLAR " .. GetPlayerName(source) .." ("..source..")", "Klar med ärendet hos id: " .. table.concat(args, " ") .. "!", template)
					end
				else
					TriggerClientEvent('esx-qalle-chat:sendMessage', source, source, "KLAR", message, template)
				end
			end
		end)
		
		RegisterCommand('svara', function(source, color, msg)
		
			local template = '<div style="padding: 0.5vw; margin: 0.5vw; background: linear-gradient(90deg, rgba(2,0,36,0.7) 0%, rgba(255,158,0,0.7) 0%, rgba(61,27,27,0.7) 100%); border-radius: 3px;"><i class="fas fa-exclamation-circle"></i> {0}:<br> {1}</div>'
		
			local message = "Du har inte tillåtelse att göra detta!"
		
			cm = stringsplit(msg, " ")
			local tPID = tonumber(cm[2])
			local names2 = GetPlayerName(tPID)
			local names3 = GetPlayerName(source)
			local textmsg = ""
			for i=1, #cm do
				if i ~= 1 and i ~=2 then
					textmsg = (textmsg .. " " .. tostring(cm[i]))
				end
			end
			TriggerClientEvent('esx-qalle-chat:sendMessage', source, source, "SVAR", " Svar skickat till:^0 " .. names2 .."  ".."^0  ID: " .. tPID, template)
			TriggerClientEvent('esx-qalle-chat:sendMessage', tPID, tPID, "SVAR", "  Staff: " .. names2 .. " " .. "(" .. tPID .. ")" ..  "^0: " .. textmsg, template)
		end)
		
		RegisterCommand('report', function(source, args, user)
			
			local template = '<div style="padding: 0.5vw; margin: 0.5vw; background: linear-gradient(90deg, rgba(2,0,36,0.7) 0%, rgba(255,0,0,0.7) 0%, rgba(61,27,27,0.7) 100%); border-radius: 3px;"><i class="fas fa-exclamation-circle"></i> {0}:<br> {1}</div>'
		
			local message = "Meddelande: " ..table.concat(args, " ")
		
			if not hasCooldown then

				local Players = ESX.GetPlayers()

				for i = 1, #Players do
					local xPlayer = ESX.GetPlayerFromId(Players[i])
					local rank = xPlayer.getGroup()

					if (rank == "admin" or rank == "mod" or rank == "superadmin" and xPlayer.source ~= source) or xPlayer.source == source then
						TriggerClientEvent('esx-qalle-chat:sendMessage', xPlayer.source, xPlayer.source, "REPORT: " .. GetPlayerName(source) .." ("..source..")", message, template)
					end
				end
				hasCooldown = true
				SendDiscordMessage('**' .. GetPlayerName(source) .. ' ' .. '(' .. source .. ')' .. '**' .. ' *' .. 'har skickat en report!' .. '*', message, 16711680)
			else
				local template = '<div style="padding: 0.5vw; margin: 0.5vw; background: linear-gradient(90deg, rgba(2,0,36,0.7) 0%, rgba(255,158,0,0.7) 0%, rgba(61,27,27,0.7) 100%); border-radius: 3px;"><i class="fas fa-exclamation-circle"></i> {0}:<br> {1}</div>'
				local message = "Du måste vänta 10sek innan du kan skriva i report igen!"
		
				TriggerClientEvent('esx-qalle-chat:sendMessage', source, source, "Cooldown", message, template)
			end
		end, false)
	end
end)

Citizen.CreateThread(function()
	while true do
		Wait(5)
		if hasCooldown then
			Wait(10000)
			hasCooldown = false
		end
	end
end)

function getIdentity(source)
	local identifier = GetPlayerIdentifiers(source)[1]
	local result = MySQL.Sync.fetchAll("SELECT * FROM users WHERE identifier = @identifier", {['@identifier'] = identifier})
	if result[1] ~= nil then
		local identity = result[1]

		return {
			identifier = identity['identifier'],
			name = identity['name'],
			firstname = identity['firstname'],
			lastname = identity['lastname'],
			dateofbirth = identity['dateofbirth'],
			sex = identity['sex'],
			height = identity['height'],
			job = identity['job'],
			group = identity['group']
		}
	else
		return nil
	end
end


function loadExistingPlayers()
	TriggerEvent("es:getPlayers", function(curPlayers)
		for k,v in pairs(curPlayers)do
			TriggerClientEvent("reply:setGroup", v.get('source'), v.get('group'))
		end
	end)
end

loadExistingPlayers()

AddEventHandler('es:playerLoaded', function(Source, user)
	TriggerClientEvent('reply:setGroup', Source, user.getGroup())
end)


function stringsplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function SendDiscordMessage(textdiscord, reportMessage, color)
    local embeds = {
        {
            type = "rich",
			color = color,
			title = textdiscord,
			author = {
				["name"] = 'Force - Report',
				['icon_url'] = 'https://cdn.discordapp.com/attachments/751211990227091517/953255119401676820/force-developing.png'
			},
			description = reportMessage,
			footer = {
				icon_url = 'https://cdn.discordapp.com/attachments/751211990227091517/953255208618700820/dariman.png',
				text = os.date("%d") .. "/" .. os.date("%m") .. "/" .. os.date("%Y") .. " - " .. os.date("%H") .. ":" .. os.date("%M")
			}
        }
	}

	PerformHttpRequest(Config.discordWebhook, function(err, text, headers) end, "POST", json.encode({username = "force_report", embeds = embeds}), { ["Content-Type"] = "application/json" })
end