fx_version 'cerulean'
games { 'gta5' }

author 'GraveDigger7863'
lua54 'yes'

name 'Repair Shops'
description 'A resource for managing vehicle repair shops with ingame configurable locations, using ESX and Ox_lib for menus and MySQL for data storage.'
version '1.0'

client_scripts {
    'Client/client_main.lua',
    'Client/client_menu.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'Server/server_main.lua',
}

shared_scripts {
    'config.lua',
    '@ox_lib/init.lua'
}

dependencies {
    'es_extended'
}
