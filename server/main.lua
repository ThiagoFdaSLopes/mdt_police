RegisterNetEvent("mdt:server:saveProfile", function(pfp, information, cid, fName, sName, tags, gallery, fingerprint, licenses)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	ManageLicenses(cid, licenses)
	if Player then
		local JobType = GetJobType(Player.PlayerData.job.name)
		if JobType == 'doj' then JobType = 'police' end
		MySQL.Async.insert('INSERT INTO mdt_data (cid, information, pfp, jobtype, tags, gallery, fingerprint) VALUES (:cid, :information, :pfp, :jobtype, :tags, :gallery, :fingerprint) ON DUPLICATE KEY UPDATE cid = :cid, information = :information, pfp = :pfp, tags = :tags, gallery = :gallery, fingerprint = :fingerprint', {
			cid = cid,
			information = information,
			pfp = pfp,
			jobtype = JobType,
			tags = json.encode(tags),
			gallery = json.encode(gallery),
			fingerprint = fingerprint,
		})
	end
end)-----------------------------------------------------------------------------------------------------------------------------------------
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
-- Locals
-----------------------------------------------------------------------------------------------------------------------------------------
local dispatchMessages = {}
local isDispatchRunning = false
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION/DISCONNECT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("nc-mdt:server:BateuCartao")
AddEventHandler("nc-mdt:server:BateuCartao", function(source)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)

	if PlayerData[1] ~= nil then
		activeUnits[PlayerData[1].registration] = {
			cid = PlayerData[1].registration,
			callSign = PlayerData[1].phone,
			firstName = PlayerData[1].name,
			lastName = PlayerData[1].name2,
			radio = 50,
			unitType = "police",
			duty = true
		}
	end
end)

local function IsPolice(job)
	for k, v in pairs(Config.PoliceJobs) do
        if job == k then
            return true
        end
    end
    return false
end

AddEventHandler("playerDropped", function(reason)
	--// Delete player from the MDT on logout
	local src = source
	local userPlayerId = vRP.getUserId(src)
	local PlayerData = vRP.query("vRP/get_vrp_users",{ id = userPlayerId })
	if PlayerData[1] ~= nil then
		activeUnits[PlayerData[1].registration] = nil
	else
		for _, v in pairs(activeUnits) do
				activeUnits[PlayerData[1].registration] = nil
			end
		end
end)

RegisterNetEvent("nc-mdt:server:ToggleDuty")
AddEventHandler("nc-mdt:server:ToggleDuty", function(source)
	local src = source
	local PlayerData = vRP.getInformation(src)
	print("Deslogado "..PlayerData[1].name)
	--// Remove from MDT
	activeUnits[PlayerData[1].registration] = nil
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

	local JobType = "police"
	local bulletin = GetBulletins(JobType)
	local calls = exports['nc-dispatch']:GetDispatchCalls()
	TriggerClientEvent('mdt:client:dashboardbulletin', src, bulletin)
	TriggerClientEvent('mdt:client:open', src, bulletin, activeUnits, calls, PlayerData[1].registration, PlayerData[1])
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- EVENTS MAIN PAGE
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:server:deleteBulletin', function(id)
	if not id then return false end
  	local src = source
	local userPlayerId = vRP.getUserId(src)
	local PlayerData = vRP.query("vRP/get_vrp_users",{ id = userPlayerId })

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

function cRP.getAllWarrants()
    local WarrantData = {}
    local data = MySQL.query.await("SELECT * FROM mdt_convictions")
    for _, value in pairs(data) do
        if value.warrant == "1" then
			WarrantData[#WarrantData+1] = {
                cid = value.cid,
                linkedincident = value.linkedincident,
                name = GetNameFromId(value.cid),
                time = value.time
            }
        end
    end
	return WarrantData
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHAT DISPATCH
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:server:setWaypoint', function(callid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local JobType = "police"
	if JobType == 'police' or JobType == 'ambulance' then
		if callid then
			if isDispatchRunning then
				local calls = exports['nc-dispatch']:GetDispatchCalls()
				TriggerClientEvent('mdt:client:setWaypoint', src, calls[callid])
			end
		end
	end
end)

RegisterNetEvent('mdt:server:sendMessage', function(message, time)
	if message and time then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			MySQL.scalar("SELECT pfp FROM `mdt_data` WHERE cid=:id LIMIT 1", {
				id = PlayerData[1].registration -- % wildcard, needed to search for all alike results
			}, function(data)
				if data == "" then data = nil end
				local ProfilePicture = ProfPic(PlayerData[1].sex, data)
				local callsign = "50"
				local Item = {
					profilepic = ProfilePicture,
					callsign = "50",
					cid = PlayerData[1].registration,
					name = '('..callsign..') '..PlayerData[1].name.." "..PlayerData[1].name2,
					message = message,
					time = time,
					job = "police"
				}
				dispatchMessages[#dispatchMessages+1] = Item
				TriggerClientEvent('mdt:client:dashboardMessage', -1, Item)
				-- Send to all clients, for auto updating stuff, ya dig.
			end)
		end
	end
end)

RegisterNetEvent('mdt:server:setWaypoint:unit', function(cid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerCoords = GetEntityCoords(GetPlayerPed(user_id))
	TriggerClientEvent("mdt:client:setWaypoint:unit", src, PlayerCoords)
end)

RegisterNetEvent('mdt:server:refreshDispatchMsgs', function()
	if IsJobAllowedToMDT("police") then
		TriggerClientEvent('mdt:client:dashboardMessages', src, dispatchMessages)
	end
end)

RegisterServerEvent("nc-mdt:dispatchStatus", function(bool)
	isDispatchRunning = bool
end)

RegisterNetEvent('mdt:server:callDetach', function(callid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local playerdata = {
		fullname = PlayerData[1].name.. " "..PlayerData[1].name2,
		job = "police",
		cid = PlayerData[1].registration,
		callsign = "50"
	}
	local JobType = "police"
	if JobType == 'police' or JobType == 'ambulance' then
		if callid then
			TriggerEvent('dispatch:removeUnit', callid, playerdata, function(newNum)
				TriggerClientEvent('mdt:client:callDetach', -1, callid, newNum)
			end)
		end
	end
end)

RegisterNetEvent('mdt:server:callDispatchDetach', function(callid, cid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local playerdata = {
		fullname = PlayerData[1].name.. " "..PlayerData[1].name2,
		job = "police",
		cid = PlayerData[1].registration,
		callsign = "50"
	}
	local callid = tonumber(callid)
	local JobType = "police"
	if JobType == 'police' or JobType == 'ambulance' then
		if callid then
			TriggerEvent('dispatch:removeUnit', callid, playerdata, function(newNum)
				TriggerClientEvent('mdt:client:callDetach', -1, callid, newNum)
			end)
		end
	end
end)

RegisterNetEvent('mdt:server:callAttach', function(callid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local playerdata = {
		fullname = PlayerData[1].name.. " "..PlayerData[1].name2,
		job = "police",
		cid = PlayerData[1].registration,
		callsign = "50"
	}
	local JobType = "police"
	if JobType == 'police' or JobType == 'ambulance' then
		if callid then
			TriggerEvent('dispatch:addUnit', callid, playerdata, function(newNum)
				TriggerClientEvent('mdt:client:callAttach', -1, callid, newNum)
			end)
		end
	end
end)

RegisterNetEvent('mdt:server:setDispatchWaypoint', function(callid, cid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local callId = tonumber(callid)
	local JobType = "police"
	if JobType == 'police' or JobType == 'ambulance' then
		if callId then
			if isDispatchRunning then
				local calls = exports['nc-dispatch']:GetDispatchCalls()
				TriggerClientEvent('mdt:client:setWaypoint', src, calls[callId])
			end
		end
	end
end)

RegisterNetEvent('mdt:server:callDragAttach', function(callid, cid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local playerdata = {
		fullname = PlayerData[1].name.. " "..PlayerData[1].name2,
		job = "police",
		cid = PlayerData[1].registration,
		callsign = "50"
	}
	local callId = tonumber(callid)
	local JobType = "police"
	if JobType == 'police' or JobType == 'ambulance' then
		if callid then
			TriggerEvent('dispatch:addUnit', callId, playerdata, function(newNum)
				TriggerClientEvent('mdt:client:callAttach', -1, callId, newNum)
			end)
		end
	end
end)

RegisterNetEvent('mdt:server:attachedUnits', function(callid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local JobType = "police"
	if JobType == 'police' or JobType == 'ambulance' then
		if callid then
			if isDispatchRunning then
				local calls = exports['nc-dispatch']:GetDispatchCalls()
				TriggerClientEvent('mdt:client:attachedUnits', src, calls[callid]['units'], callid)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:getCallResponses', function(callid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if IsPolice("police") then
		if isDispatchRunning then
			local calls = exports['nc-dispatch']:GetDispatchCalls()
			TriggerClientEvent('mdt:client:getCallResponses', src, calls[callid]['responses'], callid)
		end
	end
end)

RegisterNetEvent('mdt:server:sendCallResponse', function(message, time, callid)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local name = PlayerData[1].name.. " "..PlayerData[1].name2
	if IsPolice("police") then
		TriggerEvent('dispatch:sendCallResponse', src, callid, message, time, function(isGood)
			if isGood then
				TriggerClientEvent('mdt:client:sendCallResponse', -1, message, time, callid, name)
			end
		end)
	end
end)

------------------------------------------------------------------------------------------------------------------------
-- GET ALL REPORTS
------------------------------------------------------------------------------------------------------------------------

RegisterServerEvent("mdt:server:AddLog", function(text)
	AddLog(text)
end)

RegisterNetEvent('mdt:server:getAllReports', function()
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		local JobType = "police"
		if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
			if JobType == 'doj' then JobType = 'police' end
			local matches = MySQL.query.await("SELECT * FROM `mdt_reports` WHERE jobtype = :jobtype ORDER BY `id` DESC LIMIT 30", {
				jobtype = JobType
			})
			TriggerClientEvent('mdt:client:getAllReports', src, matches)
		end
	end
end)

RegisterNetEvent('mdt:server:getReportData', function(sentId)
	if sentId then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			local JobType = "police"
			if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
				if JobType == 'doj' then JobType = 'police' end
				local matches = MySQL.query.await("SELECT * FROM `mdt_reports` WHERE `id` = :id AND `jobtype` = :jobtype LIMIT 1", {
					id = sentId,
					jobtype = JobType
				})
				local data = matches[1]
				data['tags'] = json.decode(data['tags'])
				data['officersinvolved'] = json.decode(data['officersinvolved'])
				data['civsinvolved'] = json.decode(data['civsinvolved'])
				data['gallery'] = json.decode(data['gallery'])
				TriggerClientEvent('mdt:client:getReportData', src, data)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:searchReports', function(sentSearch)
	if sentSearch then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			local JobType = "police"
			if JobType == 'police' or JobType == 'doj' or JobType == 'ambulance' then
				if JobType == 'doj' then JobType = 'police' end
				local matches = MySQL.query.await("SELECT * FROM `mdt_reports` WHERE `id` LIKE :query OR LOWER(`author`) LIKE :query OR LOWER(`title`) LIKE :query OR LOWER(`type`) LIKE :query OR LOWER(`details`) LIKE :query OR LOWER(`tags`) LIKE :query AND `jobtype` = :jobtype ORDER BY `id` DESC LIMIT 50", {
					query = string.lower('%'..sentSearch..'%'), -- % wildcard, needed to search for all alike results
					jobtype = JobType
				})

				TriggerClientEvent('mdt:client:getAllReports', src, matches)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:newReport', function(existing, id, title, reporttype, details, tags, gallery, officers, civilians, time)
	if id then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			local JobType = "police"
			if JobType ~= nil then
				local fullname = PlayerData[1].name.." "..PlayerData[1].name2
				local function InsertReport()
					MySQL.insert('INSERT INTO `mdt_reports` (`title`, `author`, `type`, `details`, `tags`, `gallery`, `officersinvolved`, `civsinvolved`, `time`, `jobtype`) VALUES (:title, :author, :type, :details, :tags, :gallery, :officersinvolved, :civsinvolved, :time, :jobtype)', {
						title = title,
						author = fullname,
						type = reporttype,
						details = details,
						tags = json.encode(tags),
						gallery = json.encode(gallery),
						officersinvolved = json.encode(officers),
						civsinvolved = json.encode(civilians),
						time = tostring(time),
						jobtype = JobType,
					}, function(r)
						if r then
							TriggerClientEvent('mdt:client:reportComplete', src, r)
							TriggerEvent('mdt:server:AddLog', "A new report was created by "..fullname.." with the title ("..title..") and ID ("..id..")")
						end
					end)
				end

				local function UpdateReport()
					MySQL.update("UPDATE `mdt_reports` SET `title` = :title, type = :type, details = :details, tags = :tags, gallery = :gallery, officersinvolved = :officersinvolved, civsinvolved = :civsinvolved, jobtype = :jobtype WHERE `id` = :id LIMIT 1", {
						title = title,
						type = reporttype,
						details = details,
						tags = json.encode(tags),
						gallery = json.encode(gallery),
						officersinvolved = json.encode(officers),
						civsinvolved = json.encode(civilians),
						jobtype = JobType,
						id = id,
					}, function(affectedRows)
						if affectedRows > 0 then
							TriggerClientEvent('mdt:client:reportComplete', src, id)
							TriggerEvent('mdt:server:AddLog', "A report was updated by "..fullname.." with the title ("..title..") and ID ("..id..")")
						end
					end)
				end

				if existing then
					UpdateReport()
				elseif not existing then
					InsertReport()
				end
			end
		end
	end
end)
----------------------------------------------------------------------------------------
-- PAGE PROFILE
----------------------------------------------------------------------------------------
function cRP.SearchProfileMdt(source, cb, sentData)
	if not sentData then  return cb({}) end
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		local JobType = "police"
		if JobType ~= nil then
			local people = MySQL.query.await("SELECT p.registration, p.name, p.name2, md.pfp FROM vrp_users AS p LEFT JOIN mdt_data AS md on p.registration = md.cid WHERE LOWER(CONCAT(JSON_VALUE(p.name, '$.firstname'), ' ', JSON_VALUE(p.name2, '$.lastname'))) LIKE :query OR LOWER(`p.name`) LIKE :query OR LOWER(`registration`) LIKE :query OR LOWER(`fingerprint`) LIKE :query AND jobtype = :jobtype LIMIT 20", { query = string.lower('%'..sentData..'%'), jobtype = JobType })
			local citizenIds = {}
			local citizenIdIndexMap = {}
			if not next(people) then cb({}) return end

			for index, data in pairs(people) do
				people[index]['warrant'] = false
				people[index]['convictions'] = 0
				people[index]['licences'] = {
                    ['driver'] = false,
                    ['business'] = false,
                    ['weapon'] = false,
                    ['pilot'] = false
                }
				people[index]['pp'] = ProfPic(data.sex)
				citizenIds[#citizenIds+1] = data.registration
				citizenIdIndexMap[data.registration] = index
			end

			local convictions = GetConvictions(citizenIds)

			if next(convictions) then
				for _, conv in pairs(convictions) do
					if conv.warrant then people[citizenIdIndexMap[conv.cid]].warrant = true end

					local charges = json.decode(conv.charges)
					people[citizenIdIndexMap[conv.cid]].convictions = people[citizenIdIndexMap[conv.cid]].convictions + #charges
				end
			end


			return cb(people)
		end
	end

	return cb({})
end

RegisterNetEvent("mdt:server:saveProfile", function(pfp, information, cid, fName, sName, tags, gallery, fingerprint, licenses)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	-- ManageLicenses(cid, licenses)
	if PlayerData[1] then
		local JobType = "police"
		if JobType == 'doj' then JobType = 'police' end
		MySQL.Async.insert('INSERT INTO mdt_data (cid, information, pfp, jobtype, tags, gallery, fingerprint) VALUES (:cid, :information, :pfp, :jobtype, :tags, :gallery, :fingerprint) ON DUPLICATE KEY UPDATE cid = :cid, information = :information, pfp = :pfp, tags = :tags, gallery = :gallery, fingerprint = :fingerprint', {
			cid = cid,
			information = information,
			pfp = pfp,
			jobtype = JobType,
			tags = json.encode(tags),
			gallery = json.encode(gallery),
			fingerprint = fingerprint,
		})
	end
end)