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
function cRP.getProfile(sentId)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local JobType = "police"
	local JobName = "police"

	local licencesdata = PlayerData[1].metadata or {
        ['driver'] = false,
        ['business'] = false,
        ['weapon'] = false,
		['pilot'] = false
	}

	local person = {
		cid = PlayerData[1].registration,
		firstname = PlayerData[1].name,
		lastname = PlayerData[1].name2,
		job = "police",
		grade = "lspd",
		pp = ProfPic(PlayerData[1].sex),
		licences = licencesdata,
		dob = ((2023 - PlayerData[1].age) - 1),
		mdtinfo = '',
		fingerprint = '',
		tags = {},
		vehicles = {},
		properties = {},
		gallery = {},
		isLimited = false
	}

	if Config.PoliceJobs[JobName] then
		local convictions = GetConvictions(person.cid)
		person.convictions2 = {}
		local convCount = 1
		if next(convictions) then
			for _, conv in pairs(convictions) do
				if conv.warrant then person.warrant = true end
				local charges = json.decode(conv.charges)
				for _, charge in pairs(charges) do
					person.convictions2[convCount] = charge
					convCount = convCount + 1
				end
			end
		end
		local hash = {}
		person.convictions = {}

		for _,v in ipairs(person.convictions2) do
			if (not hash[v]) then
				person.convictions[#person.convictions+1] = v -- found this dedupe method on sourceforge somewhere, copy+pasta dev, needs to be refined later
				hash[v] = true
			end
		end
		local vehicles = GetPlayerVehicles(user_id)

		if vehicles then
			person.vehicles = vehicles
		end
		-- local Coords = {}
		-- local Houses = {}
		-- local properties= GetPlayerProperties(user_id)
		-- for k, v in pairs(properties) do
		-- 	Coords[#Coords+1] = {
        --         coords = json.decode(v["coords"]),
        --     }
		-- end
		-- for index = 1, #Coords, 1 do
		-- 	Houses[#Houses+1] = {
        --         label = properties[index]["label"],
        --         coords = tostring(Coords[index]["coords"]["enter"]["x"]..",".. Coords[index]["coords"]["enter"]["y"].. ",".. Coords[index]["coords"]["enter"]["z"]),
        --     }
        -- end
		-- -- if properties then
		-- 	person.properties = Houses
		-- -- end
	end

	local mdtData = GetPersonInformation(sentId, JobType)
	if mdtData then
		person.mdtinfo = mdtData.information
		person.fingerprint = mdtData.fingerprint
		person.profilepic = mdtData.pfp
		person.tags = json.decode(mdtData.tags)
		person.gallery = json.decode(mdtData.gallery)
	end

	local mdtData2 = GetPfpFingerPrintInformation(sentId)
	if mdtData2 then
		person.fingerprint = mdtData2.fingerprint
		person.profilepic = mdtData and mdtData.pfp or ""
	end

	return person
end

function cRP.SearchProfileMdt(sentData)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		local JobType = "police"
		if JobType ~= nil then
			local people = MySQL.query.await("SELECT p.registration, p.name, p.name2, p.sex FROM vrp_users p LEFT JOIN mdt_data md on p.registration = md.cid WHERE LOWER(CONCAT(JSON_VALUE(p.name, '$.name'), ' ', JSON_VALUE(p.name2, '$.name2'))) LIKE @query OR LOWER(`name`) LIKE @query OR LOWER(`registration`) LIKE @query OR LOWER(`fingerprint`) LIKE @query AND jobtype = @jobtype LIMIT 20", { query = string.lower('%'..sentData..'%'), jobtype = JobType })
			local citizenIds = {}
			local citizenIdIndexMap = {}

			for index, data in pairs(people) do
				people[index]['warrant'] = false
				people[index]['convictions'] = 0
				people[index]['licences'] = GetPlayerLicenses(PlayerData[1].registration, user_id)
				people[index]['pp'] = ProfPic(data.sex)
				citizenIds[#citizenIds+1] = data.registration
				citizenIdIndexMap[data.registration] = index
			end

			if #people ~= 0 then
				local convictions = GetConvictions(PlayerData[1].registration)

				if next(convictions) then
					for _, conv in pairs(convictions) do
						if conv.warrant then people[citizenIdIndexMap[conv.cid]].warrant = true end

						local charges = json.decode(conv.charges)
						people[citizenIdIndexMap[conv.cid]].convictions = people[citizenIdIndexMap[conv.cid]].convictions + #charges
					end
				end
			end
			return people
		end
	end
end

RegisterNetEvent("mdt:server:saveProfile", function(pfp, information, cid, fName, sName, tags, gallery, fingerprint, licenses)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	ManageLicenses(user_id, cid, licenses)
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

RegisterNetEvent("mdt:server:updateLicense", function(cid, type, status)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		if GetJobType("police") == 'police' then
			ManageLicense(user_id, cid, type, status)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------
-- INCIDENTS
-----------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:server:searchIncidents', function(query)
	if query then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			local JobType = "police"
			if JobType == 'police' or JobType == 'doj' then
				local matches = MySQL.query.await("SELECT * FROM `mdt_incidents` WHERE `id` LIKE :query OR LOWER(`title`) LIKE :query OR LOWER(`author`) LIKE :query OR LOWER(`details`) LIKE :query OR LOWER(`tags`) LIKE :query OR LOWER(`officersinvolved`) LIKE :query OR LOWER(`civsinvolved`) LIKE :query OR LOWER(`author`) LIKE :query ORDER BY `id` DESC LIMIT 50", {
					query = string.lower('%'..query..'%') -- % wildcard, needed to search for all alike results
				})

				TriggerClientEvent('mdt:client:getIncidents', src, matches)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:getIncidentData', function(sentId)
	if sentId then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			local JobType = "police"
			if JobType == 'police' or JobType == 'doj' then
				local matches = MySQL.query.await("SELECT * FROM `mdt_incidents` WHERE `id` = :id", {
					id = sentId
				})
				local data = matches[1]
				data['tags'] = json.decode(data['tags'])
				data['officersinvolved'] = json.decode(data['officersinvolved'])
				data['civsinvolved'] = json.decode(data['civsinvolved'])
				data['evidence'] = json.decode(data['evidence'])


				local convictions = MySQL.query.await("SELECT * FROM `mdt_convictions` WHERE `linkedincident` = :id", {
					id = sentId
				})
				if convictions ~= nil then
					for i=1, #convictions do
						local res = GetNameFromId(convictions[i]['cid'])
						if res ~= nil then
							convictions[i]['name'] = res
						else
							convictions[i]['name'] = "Unknown"
						end
						convictions[i]['charges'] = json.decode(convictions[i]['charges'])
					end
				end
				TriggerClientEvent('mdt:client:getIncidentData', src, data, convictions)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:incidentSearchPerson', function(query)
    if query then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			local JobType = "police"
			if JobType == 'police' or JobType == 'doj' then
				local function ProfPic(gender, profilepic)
					if profilepic then return profilepic end;
					if gender == "Female" then return "img/female.png" end;
					return "img/male.png"
				end

				local result = MySQL.query.await("SELECT p.registration, p.name, p.name2, md.pfp from vrp_users p LEFT JOIN mdt_data md on p.registration = md.cid WHERE LOWER(`name`) LIKE :query OR LOWER(`registration`) LIKE :query AND `jobtype` = :jobtype LIMIT 30", {
					query = string.lower('%'..query..'%'), -- % wildcard, needed to search for all alike results
					jobtype = JobType
				})
				local data = {}
				for i=1, #result do
					local charinfo = result[1]
					data[i] = {id = result[i].registration, firstname = charinfo.name, lastname = charinfo.name2, profilepic = ProfPic(charinfo.sex, result[i].pfp)}
				end
				TriggerClientEvent('mdt:client:incidentSearchPerson', src, data)
            end
        end
    end
end)

RegisterNetEvent('mdt:server:saveIncident', function(id, title, information, tags, officers, civilians, evidence, associated, time)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		if GetJobType("police") == 'police' then
			if id == 0 then
				local fullname = PlayerData[1].name.. ' ' ..PlayerData[1].name2
				MySQL.insert('INSERT INTO `mdt_incidents` (`author`, `title`, `details`, `tags`, `officersinvolved`, `civsinvolved`, `evidence`, `time`, `jobtype`) VALUES (:author, :title, :details, :tags, :officersinvolved, :civsinvolved, :evidence, :time, :jobtype)',
				{
					author = fullname,
					title = title,
					details = information,
					tags = json.encode(tags),
					officersinvolved = json.encode(officers),
					civsinvolved = json.encode(civilians),
					evidence = json.encode(evidence),
					time = time,
					jobtype = 'police',
				}, function(infoResult)
					if infoResult then
						for i=1, #associated do
							MySQL.insert('INSERT INTO `mdt_convictions` (`cid`, `linkedincident`, `warrant`, `guilty`, `processed`, `associated`, `charges`, `fine`, `sentence`, `recfine`, `recsentence`, `time`) VALUES (:cid, :linkedincident, :warrant, :guilty, :processed, :associated, :charges, :fine, :sentence, :recfine, :recsentence, :time)', {
								cid = associated[i]['Cid'],
								linkedincident = infoResult,
								warrant = associated[i]['Warrant'],
								guilty = associated[i]['Guilty'],
								processed = associated[i]['Processed'],
								associated = associated[i]['Isassociated'],
								charges = json.encode(associated[i]['Charges']),
								fine = tonumber(associated[i]['Fine']),
								sentence = tonumber(associated[i]['Sentence']),
								recfine = tonumber(associated[i]['recfine']),
								recsentence = tonumber(associated[i]['recsentence']),
								time = time
							})
						end
						TriggerClientEvent('mdt:client:updateIncidentDbId', src, infoResult)
						--TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") was added to the vehicle information database by "..player['fullname'])
					end
				end)
			elseif id > 0 then
				MySQL.update("UPDATE mdt_incidents SET title=:title, details=:details, civsinvolved=:civsinvolved, tags=:tags, officersinvolved=:officersinvolved, evidence=:evidence WHERE id=:id", {
					title = title,
					details = information,
					tags = json.encode(tags),
					officersinvolved = json.encode(officers),
					civsinvolved = json.encode(civilians),
					evidence = json.encode(evidence),
					id = id
				})
				for i=1, #associated do
					TriggerEvent('mdt:server:handleExistingConvictions', associated[i], id, time)
				end
			end
		end
	end
end)

RegisterNetEvent('mdt:server:handleExistingConvictions', function(data, incidentid, time)
	MySQL.query('SELECT * FROM mdt_convictions WHERE cid=:cid AND linkedincident=:linkedincident', {
		cid = data['Cid'],
		linkedincident = incidentid
	}, function(convictionRes)
		if convictionRes and convictionRes[1] and convictionRes[1]['id'] then
			MySQL.update('UPDATE mdt_convictions SET cid=:cid, linkedincident=:linkedincident, warrant=:warrant, guilty=:guilty, processed=:processed, associated=:associated, charges=:charges, fine=:fine, sentence=:sentence, recfine=:recfine, recsentence=:recsentence WHERE cid=:cid AND linkedincident=:linkedincident', {
				cid = data['Cid'],
				linkedincident = incidentid,
				warrant = data['Warrant'],
				guilty = data['Guilty'],
				processed = data['Processed'],
				associated = data['Isassociated'],
				charges = json.encode(data['Charges']),
				fine = tonumber(data['Fine']),
				sentence = tonumber(data['Sentence']),
				recfine = tonumber(data['recfine']),
				recsentence = tonumber(data['recsentence']),
			})
		else
			MySQL.insert('INSERT INTO `mdt_convictions` (`cid`, `linkedincident`, `warrant`, `guilty`, `processed`, `associated`, `charges`, `fine`, `sentence`, `recfine`, `recsentence`, `time`) VALUES (:cid, :linkedincident, :warrant, :guilty, :processed, :associated, :charges, :fine, :sentence, :recfine, :recsentence, :time)', {
				cid = data['Cid'],
				linkedincident = incidentid,
				warrant = data['Warrant'],
				guilty = data['Guilty'],
				processed = data['Processed'],
				associated = data['Isassociated'],
				charges = json.encode(data['Charges']),
				fine = tonumber(data['Fine']),
				sentence = tonumber(data['Sentence']),
				recfine = tonumber(data['recfine']),
				recsentence = tonumber(data['recsentence']),
				time = time
			})
		end
	end)
end)

RegisterNetEvent('mdt:server:removeIncidentCriminal', function(cid, incident)
	MySQL.update('DELETE FROM mdt_convictions WHERE cid=:cid AND linkedincident=:linkedincident', {
		cid = cid,
		linkedincident = incident
	})
end)

RegisterNetEvent('mdt:server:getAllIncidents', function()
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		local JobType = GetJobType("police")
		if JobType == 'police' or JobType == 'doj' then
			local matches = MySQL.query.await("SELECT * FROM `mdt_incidents` ORDER BY `id` DESC LIMIT 30", {})

			TriggerClientEvent('mdt:client:getAllIncidents', src, matches)
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------
-- BOLOS PAGE
-----------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:server:searchBolos', function(sentSearch)
	if sentSearch then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		local JobType = GetJobType("police")
		if JobType == 'police' or JobType == 'ambulance' then
			local matches = MySQL.query.await("SELECT * FROM `mdt_bolos` WHERE `id` LIKE :query OR LOWER(`title`) LIKE :query OR `plate` LIKE :query OR LOWER(`owner`) LIKE :query OR LOWER(`individual`) LIKE :query OR LOWER(`detail`) LIKE :query OR LOWER(`officersinvolved`) LIKE :query OR LOWER(`tags`) LIKE :query OR LOWER(`author`) LIKE :query AND jobtype = :jobtype", {
				query = string.lower('%'..sentSearch..'%'), -- % wildcard, needed to search for all alike results
				jobtype = JobType
			})
			TriggerClientEvent('mdt:client:getBolos', src, matches)
		end
	end
end)

RegisterNetEvent('mdt:server:getAllBolos', function()
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	local JobType = GetJobType("police")
	if JobType == 'police' or JobType == 'ambulance' then
		local matches = MySQL.query.await("SELECT * FROM `mdt_bolos` WHERE jobtype = :jobtype", {jobtype = JobType})
		TriggerClientEvent('mdt:client:getAllBolos', src, matches)
	end
end)

RegisterNetEvent('mdt:server:getBoloData', function(sentId)
	if sentId then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		local JobType = GetJobType("police")
		if JobType == 'police' or JobType == 'ambulance' then
			local matches = MySQL.query.await("SELECT * FROM `mdt_bolos` WHERE `id` = :id AND jobtype = :jobtype LIMIT 1", {
				id = sentId,
				jobtype = JobType
			})

			local data = matches[1]
			data['tags'] = json.decode(data['tags'])
			data['officersinvolved'] = json.decode(data['officersinvolved'])
			data['gallery'] = json.decode(data['gallery'])
			TriggerClientEvent('mdt:client:getBoloData', src, data)
		end
	end
end)

RegisterNetEvent('mdt:server:newBolo', function(existing, id, title, plate, owner, individual, detail, tags, gallery, officersinvolved, time)
	if id then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		local JobType = GetJobType("police")
		if JobType == 'police' or JobType == 'ambulance' then
			local fullname = PlayerData[1].name.. ' ' ..PlayerData[1].name2

			local function InsertBolo()
				MySQL.insert('INSERT INTO `mdt_bolos` (`title`, `author`, `plate`, `owner`, `individual`, `detail`, `tags`, `gallery`, `officersinvolved`, `time`, `jobtype`) VALUES (:title, :author, :plate, :owner, :individual, :detail, :tags, :gallery, :officersinvolved, :time, :jobtype)', {
					title = title,
					author = fullname,
					plate = plate,
					owner = owner,
					individual = individual,
					detail = detail,
					tags = json.encode(tags),
					gallery = json.encode(gallery),
					officersinvolved = json.encode(officersinvolved),
					time = tostring(time),
					jobtype = JobType
				}, function(r)
					if r then
						TriggerClientEvent('mdt:client:boloComplete', src, r)
						TriggerEvent('mdt:server:AddLog', "A new BOLO was created by "..fullname.." with the title ("..title..") and ID ("..id..")")
					end
				end)
			end

			local function UpdateBolo()
				MySQL.update("UPDATE mdt_bolos SET `title`=:title, plate=:plate, owner=:owner, individual=:individual, detail=:detail, tags=:tags, gallery=:gallery, officersinvolved=:officersinvolved WHERE `id`=:id AND jobtype = :jobtype LIMIT 1", {
					title = title,
					plate = plate,
					owner = owner,
					individual = individual,
					detail = detail,
					tags = json.encode(tags),
					gallery = json.encode(gallery),
					officersinvolved = json.encode(officersinvolved),
					id = id,
					jobtype = JobType
				}, function(r)
					if r then
						TriggerClientEvent('mdt:client:boloComplete', src, id)
						TriggerEvent('mdt:server:AddLog', "A BOLO was updated by "..fullname.." with the title ("..title..") and ID ("..id..")")
					end
				end)
			end

			if existing then
				UpdateBolo()
			elseif not existing then
				InsertBolo()
			end
		end
	end
end)

RegisterNetEvent('mdt:server:deleteBolo', function(id)
	if id then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		local JobType = GetJobType("police")
		if JobType == 'police' then
			local fullname = PlayerData[1].name.. ' ' ..PlayerData[1].name2
			MySQL.update("DELETE FROM `mdt_bolos` WHERE id=:id", { id = id, jobtype = JobType })
			TriggerEvent('mdt:server:AddLog', "A BOLO was deleted by "..fullname.." with the ID ("..id..")")
		end
	end
end)

RegisterNetEvent('mdt:server:deleteICU', function(id)
	if id then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		local JobType = GetJobType("police")
		if JobType == 'ambulance' then
			local fullname = PlayerData[1].name.. ' ' ..PlayerData[1].name2
			MySQL.update("DELETE FROM `mdt_bolos` WHERE id=:id", { id = id, jobtype = JobType })
			TriggerEvent('mdt:server:AddLog', "A ICU Check-in was deleted by "..fullname.." with the ID ("..id..")")
		end
	end
end)

-----------------------------------------------------------------------------------------------------------------------
-- DMV PAGE
-----------------------------------------------------------------------------------------------------------------------
function cRP.SearchVehicles(sentData)
	if not sentData then return {} end
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		local JobType = GetJobType("police")
		if JobType == 'police' or JobType == 'doj' then
			local vehicles = MySQL.query.await("SELECT pv.id, pv.user_id, pv.plate, pv.vehicle, pv.desmanchado, pv.engine, pv.body, pv.fuel, pv.detido, p.name, p.name2 FROM `vrp_vehicles` pv LEFT JOIN vrp_users p ON pv.user_id = p.id WHERE LOWER(`plate`) LIKE :query OR LOWER(`vehicle`) LIKE :query LIMIT 25", {
				query = string.lower('%'..sentData..'%')
			})

			if not next(vehicles) then return {} end

			for _, value in ipairs(vehicles) do
				if value.detido == 0 then
					value.state = "Out"
				elseif value.desmanchado == 1 then
					value.state = "Garaged"
				elseif value.detido == 1 then
					value.state = "Impounded"
				end

				value.bolo = false
				local boloResult = GetBoloStatus(value.plate)
				if boloResult then
					value.bolo = true
				end

				value.code = false
				value.stolen = false
				value.image = "img/not-found.webp"
				local info = GetVehicleInformation(value.plate)
				if info then
					value.code = info['code5']
					value.stolen = info['stolen']
					value.image = info['image']
				end

				value.owner = PlayerData[1].name.. ' ' ..PlayerData[1].name2
			end
			-- idk if this works or I have to call cb first then return :shrug:
			return vehicles
		end
		return {}
	end
end

RegisterNetEvent('mdt:server:getVehicleData', function(plate)
	if plate then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			local JobType = GetJobType("police")
			if JobType == 'police' or JobType == 'doj' then
				local vehicle = MySQL.query.await("SELECT pv.*, p.name, p.name2 from vrp_vehicles pv LEFT JOIN vrp_users p ON pv.user_id = p.id where pv.plate = :plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
				if vehicle and vehicle[1] then
					vehicle[1]['impound'] = false
					if vehicle[1].detido == 1 then
						vehicle[1]['impound'] = true
					end

					vehicle[1]['bolo'] = GetBoloStatus(vehicle[1]['plate'])
					vehicle[1]['information'] = ""

					vehicle[1]['name'] = "Unknown Person"

					vehicle[1]['name'] = PlayerData[1].name.. ' ' ..PlayerData[1].name2

					vehicle[1]['color1'] = 1

					vehicle[1]['dbid'] = 0

					local info = GetVehicleInformation(vehicle[1]['plate'])
					if info then
						vehicle[1]['information'] = info['information']
						vehicle[1]['dbid'] = info['id']
						vehicle[1]['image'] = info['image']
						vehicle[1]['code'] = info['code5']
						vehicle[1]['stolen'] = info['stolen']
					end

					if vehicle[1]['image'] == nil then vehicle[1]['image'] = "img/not-found.webp" end -- Image
				end

				TriggerClientEvent('mdt:client:getVehicleData', src, vehicle)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:saveVehicleInfo', function(dbid, plate, imageurl, notes, stolen, code5, impoundInfo)
	if plate then
		local src = source
		local user_id = vRP.getUserId(src)
		local PlayerData = vRP.getInformation(user_id)
		if PlayerData[1] then
			if GetJobType("police") == 'police' then
				if dbid == nil then dbid = 0 end;
				local fullname = PlayerData[1].name.. ' ' ..PlayerData[1].name2
				TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") has a new image ("..imageurl..") edited by "..fullname)
				if tonumber(dbid) == 0 then
					MySQL.insert('INSERT INTO `mdt_vehicleinfo` (`plate`, `information`, `image`, `code5`, `stolen`) VALUES (:plate, :information, :image, :code5, :stolen)', { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1"), information = notes, image = imageurl, code5 = code5, stolen = stolen }, function(infoResult)
						if infoResult then
							TriggerClientEvent('mdt:client:updateVehicleDbId', src, infoResult)
							TriggerEvent('mdt:server:AddLog', "A vehicle with the plate ("..plate..") was added to the vehicle information database by "..fullname)
						end
					end)
				elseif tonumber(dbid) > 0 then
					MySQL.update("UPDATE mdt_vehicleinfo SET `information`= :information, `image`= :image, `code5`= :code5, `stolen`= :stolen WHERE `plate`= :plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1"), information = notes, image = imageurl, code5 = code5, stolen = stolen })
				end

				if impoundInfo.impoundChanged then
					local vehicle = MySQL.single.await("SELECT p.id, p.plate, i.vehicleid AS impoundid FROM `vrp_vehicles` p LEFT JOIN `mdt_impound` i ON i.vehicleid = p.id WHERE plate=:plate", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1") })
					if impoundInfo.impoundActive then
						local plateVehicl, linkedreport, fee, time = impoundInfo['plate'], impoundInfo['linkedreport'], impoundInfo['fee'], impoundInfo['time']
						if (plateVehicl and linkedreport and fee and time) then
							if vehicle.impoundid == nil then
								-- This section is copy pasted from request impound and needs some attention.
								-- sentVehicle doesnt exist.
								-- data is defined twice
								-- INSERT INTO will not work if it exists already (which it will)
								local data = vehicle
								MySQL.insert('INSERT INTO `mdt_impound` (`vehicleid`, `linkedreport`, `fee`, `time`) VALUES (:vehicleid, :linkedreport, :fee, :time)', {
									vehicleid = data['id'],
									linkedreport = linkedreport,
									fee = fee,
									time = os.time() + (time * 60)
								}, function(res)
									-- notify?
									local dataVeh = {
										vehicleid = data['id'],
										plate = plate,
										beingcollected = 0,
										vehicle = sentVehicle,
										officer = PlayerData[1].name.. ' ' ..PlayerData[1].name2,
										number = PlayerData[1].phone,
										time = os.time() * 1000,
										src = src,
									}
									local vehiclePl = NetworkGetEntityFromNetworkId(sentVehicle)
									FreezeEntityPosition(vehiclePl, true)
									local impound = {}
									impound[#impound+1] = dataVeh

									TriggerClientEvent("police:client:ImpoundVehicle", src, true, fee)
								end)
								-- Read above commenting
							end
						end
					else
						if vehicle.impoundid ~= nil then
							local data = vehicle
							local result = MySQL.single.await("SELECT id, vehicle, fuel, engine, body FROM `vrp_vehicles` WHERE plate=:plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
							if result then
								local data = result
								MySQL.update("DELETE FROM `mdt_impound` WHERE vehicleid=:vehicleid", { vehicleid = data['id'] })

								result.currentSelection = impoundInfo.CurrentSelection
								result.plate = plate
								TriggerClientEvent('nc-mdt:client:TakeOutImpound', src, result)
							end

						end
					end
				end
			end
		end
	end
end)

RegisterNetEvent('police:server:TakeOutImpound', function(plate)
    local src = source
	MySQL.query.await('UPDATE vrp_vehicles SET detido = ? WHERE plate  = ?', {0, plate})
    TriggerClientEvent('Notify', src, "Vehicle unimpounded!", 'success')
end)

RegisterNetEvent('police:server:Impound', function(plate, fullImpound, price, body, engine, fuel)
    local src = source
    local price = price and price or 0
    if IsVehicleOwned(plate) then
        if not fullImpound then
            MySQL.query.await(
                'UPDATE vrp_vehicles SET detido = ?, body = ?, engine = ?, fuel = ? WHERE plate = ?',
                {0, body, engine, fuel, plate})
            TriggerClientEvent('Notify', src, "Vehicle taken into depot for $" .. price .. "!")
        else
            MySQL.query.await(
                'UPDATE vrp_vehicles SET detido = ?, body = ?, engine = ?, fuel = ? WHERE plate = ?',
                {1, body, engine, fuel, plate})
			TriggerClientEvent('Notify', src, "Vehicle seized!")
        end
    end
end)

local function isRequestVehicle(vehId)
	local found = false
	for i=1, #impound do
		if impound[i]['vehicle'] == vehId then
			found = true
			impound[i] = nil
			break
		end
	end
	return found
end

exports('isRequestVehicle', isRequestVehicle)

RegisterNetEvent('mdt:server:getAllLogs', function()
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		if Config.LogPerms["police"] then
			if Config.LogPerms["police"][4] then

				local JobType = GetJobType("police")
				local infoResult = MySQL.query.await('SELECT * FROM mdt_logs WHERE `jobtype` = :jobtype ORDER BY `id` DESC LIMIT 250', {jobtype = JobType})

				TriggerLatentClientEvent('mdt:client:getAllLogs', src, 30000, infoResult)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:getPenalCode', function()
	local src = source
	TriggerClientEvent('mdt:client:getPenalCode', src, Config.PenalCodeTitles, Config.PenalCode)
end)

local function IsCidFelon(sentCid, cb)
	if sentCid then
		local convictions = MySQL.query.await('SELECT charges FROM mdt_convictions WHERE cid=:cid', { cid = sentCid })
		local Charges = {}
		for i=1, #convictions do
			local currCharges = json.decode(convictions[i]['charges'])
			for x=1, #currCharges do
				Charges[#Charges+1] = currCharges[x]
			end
		end
		local PenalCode = Config.PenalCode
		for i=1, #Charges do
			for p=1, #PenalCode do
				for x=1, #PenalCode[p] do
					if PenalCode[p][x]['title'] == Charges[i] then
						if PenalCode[p][x]['class'] == 'Felony' then
							cb(true)
							return
						end
						break
					end
				end
			end
		end
		cb(false)
	end
end

exports('IsCidFelon', IsCidFelon) -- exports['erp_mdt']:IsCidFelon()

RegisterCommand("isfelon", function(source, args, rawCommand)
	IsCidFelon(1998, function(res)
	end)
end, false)

RegisterNetEvent('mdt:server:removeImpound', function(plate, currentSelection)
	print("Removing impound", plate, currentSelection)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		if GetJobType("police") == 'police' then
			local result = MySQL.single.await("SELECT id, vehicle FROM `vrp_vehicles` WHERE plate=:plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
			if result and result[1] then
				local data = result[1]
				MySQL.update("DELETE FROM `mdt_impound` WHERE vehicleid=:vehicleid", { vehicleid = data['id'] })
				TriggerClientEvent('police:client:TakeOutImpound', src, currentSelection)
			end
		end
	end
end)

RegisterNetEvent('mdt:server:statusImpound', function(plate)
	local src = source
	local user_id = vRP.getUserId(src)
	local PlayerData = vRP.getInformation(user_id)
	if PlayerData[1] then
		if GetJobType("police") == 'police' then
			local vehicle = MySQL.query.await("SELECT id, plate FROM `vrp_vehicles` WHERE plate=:plate LIMIT 1", { plate = string.gsub(plate, "^%s*(.-)%s*$", "%1")})
			if vehicle and vehicle[1] then
				local data = vehicle[1]
				local impoundinfo = MySQL.query.await("SELECT * FROM `mdt_impound` WHERE vehicleid=:vehicleid LIMIT 1", { vehicleid = data['id'] })
				if impoundinfo and impoundinfo[1] then
					TriggerClientEvent('mdt:client:statusImpound', src, impoundinfo[1], plate)
				end
			end
		end
	end
end)