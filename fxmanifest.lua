fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

version '1.0.0'

client_script {

  'client.lua'

}

server_scripts {

  '@mysql-async/lib/MySQL.lua',
  'config.lua',
  'server.lua'

}