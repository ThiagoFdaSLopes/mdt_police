fx_version 'cerulean'
game 'gta5'

author 'Tz And Leo'
description 'MDT For VRPEX'
version '0.9.9'

lua54 'yes'

shared_script 'shared/config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@vrp/lib/utils.lua',
    'server/utils.lua',
    'server/dbm.lua',
    'server/main.lua'
}
client_scripts{
    '@vrp/lib/utils.lua',
    'client/main.lua',
    'client/cl_impound.lua',
    'client/camera.lua'
} 

ui_page 'ui/dashboard.html'

files {
    'ui/img/*.png',
    'ui/img/*.webp',
    'ui/dashboard.html',
    'ui/dmv.html',
    'ui/bolos.html',
    'ui/incidents.html',
    'ui/penalcode.html',
    'ui/reports.html',
    'ui/warrants.html',
    'ui/app.js',
    'ui/style.css',
}