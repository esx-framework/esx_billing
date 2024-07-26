fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Allows Players to recieve and Send Bills'
version '1.0'

shared_scripts {
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'config.lua',
	'locales/*.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/main.lua'
}

client_script 'client/main.lua'

dependency 'es_extended'
