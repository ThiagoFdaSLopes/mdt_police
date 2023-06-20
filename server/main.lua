-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPC = Tunnel.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
cRP = {}
Tunnel.bindInterface(GetCurrentResourceName(), cRP)

vCLIENT = Tunnel.getInterface(GetCurrentResourceName())
-----------------------------------------------------------------------------------------------------------------------------------------
function cRP.checkPermission()
  local source = source
  local user_id = vRP.getUserId(source)
  if vRP.hasPermission(user_id, "Police") then
      return true
  else
    TriggerClientEvent("Notify", source, "negado", "Você não possui permissao", 3000)
  end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:server:openMDT', function()
	local src = source
	local PlayerData = vRP.query("vRP/get_vrp_users",{ id = src })
	local activeUnits = {}
	activeUnits[PlayerData[1].registration] = {
		cid = PlayerData[1].registration,
		callSign = PlayerData[1].phone,
		firstName = PlayerData[1].name,
		lastName = PlayerData[1].name2,
		radio = 50,
		unitType = "Police",
		duty = true
	}


	local JobType = "police"
	local bulletin = GetBulletins(JobType)
	-- local calls = exports['nc-dispatch']:GetDispatchCalls()
	TriggerClientEvent('mdt:client:dashboardbulletin', src, bulletin)
	TriggerClientEvent('mdt:client:open', src, bulletin, activeUnits, calls, PlayerData[1].registration)
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTS MAIN PAGE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:server:deleteBulletin', function(id)
	if not id then return false end
  	local src = source
	local PlayerData = vRP.query("vRP/get_vrp_users",{ id = src })

  	local result = MySQL.query.await('SELECT title FROM mdt_bulletin WHERE id = ?', { id })

	MySQL.query.await('DELETE FROM `mdt_bulletin` where id = ?', {id})
	AddLog("Bulletin with Title: "..result[1].title.." was deleted by " .. PlayerData[1].name .. ".")
end)

RegisterNetEvent('mdt:server:NewBulletin', function(title, info, time)
  local src = source
  local user_id = vRP.getUserId(src)
	local PlayerData = vRP.query("vRP/get_vrp_users",{ id = user_id })
	local JobType = "police"
	local playerName = PlayerData[1].name

	AddLog(("A new bulletin was added by %s with the title: %s!"):format(playerName, title))
end)