fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name 'force_report'
author 'Force Developments <discord:@force3883>'
description 'Player reports for staff with ids, replies and a rate-limited Discord log. ESX, QBCore and QBox.'
version '2.0.0'

dependencies {
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/functions.lua',
}

server_scripts {
    'server/custom/frameworks/*.lua',
    'server/discord.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'locales/*.json',
}
