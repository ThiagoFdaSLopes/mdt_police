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
local activeUnits = {}
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
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("nc-mdt:server:OnPlayerUnload", function()
	--// Delete player from the MDT on logout
	local src = source
	local player = QBCore.Functions.GetPlayer(src)
	if GetActiveData(player.PlayerData.citizenid) then
		activeUnits[player.PlayerData.citizenid] = nil
	end
end)

AddEventHandler("playerDropped", function(reason)
	--// Delete player from the MDT on logout
	local src = source
	local player = QBCore.Functions.GetPlayer(src)
	if player ~= nil then
		if GetActiveData(player.PlayerData.citizenid) then
			activeUnits[player.PlayerData.citizenid] = nil
		end
	else
		local license = QBCore.Functions.GetIdentifier(src, "license")
		local citizenids = GetCitizenID(license)

		for _, v in pairs(citizenids) do
			if GetActiveData(v.citizenid) then
				activeUnits[v.citizenid] = nil
			end
		end
	end
end)

RegisterNetEvent("nc-mdt:server:ToggleDuty", function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player.PlayerData.job.onduty then
	--// Remove from MDT
	if GetActiveData(player.PlayerData.citizenid) then
		activeUnits[player.PlayerData.citizenid] = nil
	end
    end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- PEGA TODOS OS USUARIOS COM PERMISSAO DE POLICIA
-----------------------------------------------------------------------------------------------------------------------------------------
function cRP.getUsersByPermissions()
	local permissions = {
		["Police"] = {},
		["Paramedic"] = {},
	}
	local users = vRP.getUsers()

	for k, v in pairs(users) do
		if vRP.hasPermission(v, "Police") then
			table.insert(permissions["Police"], v)
		end
	end
	return permissions
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTS
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:server:openMDT', function()
	local src = source
	local userPlayerId = vRP.getUserId(src)
	local PlayerData = vRP.query("vRP/get_vrp_users",{ id = userPlayerId })

	activeUnits[PlayerData[1].registration] = {
		cid = PlayerData[1].registration,
		callSign = PlayerData[1].phone,
		firstName = PlayerData[1].name,
		lastName = PlayerData[1].name2,
		radio = 50,
		unitType = "police",
		duty = true
	}


	local JobType = "police"
	local bulletin = GetBulletins(JobType)
	-- local calls = exports['nc-dispatch']:GetDispatchCalls()
	TriggerClientEvent('mdt:client:dashboardbulletin', src, bulletin)
	TriggerClientEvent('mdt:client:open', src, bulletin, activeUnits, calls, PlayerData[1].registration, PlayerData[1])
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
	local playerName = PlayerData[1].name.." "..PlayerData[1].name2
	MySQL.insert.await('INSERT INTO `mdt_bulletin` (`title`, `desc`, `author`, `time`, `jobtype`) VALUES (:title, :desc, :author, :time, :jt)', {
		title = title,
		desc = info,
		author = playerName,
		time = tostring(time),
		jt = JobType
	})

	AddLog(("A new bulletin was added by %s with the title: %s!"):format(playerName, title))
end)