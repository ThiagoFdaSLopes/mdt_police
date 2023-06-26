-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRP = Proxy.getInterface("vRP")
vRPC = Tunnel.getInterface("vRP")
vCLIENT = Tunnel.getInterface("player")
-----------------------------------------------------------------------------------------------------------------------------------------

-- Get CitizenIDs from Player License
function GetCitizenID(license)
    local result = MySQL.query.await("SELECT citizenid FROM players WHERE license = ?", {license,})
    if result ~= nil then
        return result
    else
        print("Cannot find a CitizenID for License: "..license)
        return nil
    end
end

-- (Start) Opening the MDT and sending data
function AddLog(text)
	--print(text)
    return MySQL.insert.await('INSERT INTO `mdt_logs` (`text`, `time`) VALUES (?,?)', {text, os.time() * 1000})
	-- return exports.oxmysql:execute('INSERT INTO `mdt_logs` (`text`, `time`) VALUES (:text, :time)', { text = text, time = os.time() * 1000 })
end

function GetNameFromId(cid)
	-- Should be a scalar?
	local result = MySQL.query.await('SELECT name, name2 FROM vrp_users WHERE registration = ?', { cid })
    if result ~= nil then
        local charinfo = result
        local fullname = charinfo[1].name..' '..charinfo[1].name2
        return fullname
    else
        --print('Player does not exist')
        return nil
    end
	-- return exports.oxmysql:executeSync('SELECT firstname, lastname FROM `users` WHERE id = :id LIMIT 1', { id = cid })
end

-- idk what this is used for either
function GetPersonInformation(cid, jobtype)
	local result = MySQL.query.await('SELECT information, tags, gallery, pfp, fingerprint FROM mdt_data WHERE cid = ? and jobtype = ?', { cid,  jobtype})
	return result[1]
	-- return exports.oxmysql:executeSync('SELECT information, tags, gallery FROM mdt WHERE cid= ? and type = ?', { cid, jobtype })
end

function GetPfpFingerPrintInformation(cid)
	local result = MySQL.query.await('SELECT pfp, fingerprint FROM mdt_data WHERE cid = ?', { cid })
	return result[1]
end

-- idk but I guess sure?
function GetIncidentName(id)
	-- Should also be a scalar
	return MySQL.query.await('SELECT title FROM `mdt_incidents` WHERE id = :id LIMIT 1', { id = id })
	-- return exports.oxmysql:executeSync('SELECT title FROM `mdt_incidents` WHERE id = :id LIMIT 1', { id = id })
end

function GetConvictions(cids)
	return MySQL.query.await('SELECT * FROM `mdt_convictions` WHERE `cid` IN(?)', { cids })
	-- return exports.oxmysql:executeSync('SELECT * FROM `mdt_convictions` WHERE `cid` IN(?)', { cids })
end

function GetLicenseInfo(cid)
	local result = MySQL.query.await('SELECT * FROM `licenses` WHERE `cid` = ?', { cid })
	return result
	-- return exports.oxmysql:executeSync('SELECT * FROM `licenses` WHERE `cid`=:cid', { cid = cid })
end

function CreateUser(cid, tableName)
	AddLog("A user was created with the CID: "..cid)
	-- return exports.oxmysql:insert("INSERT INTO `"..dbname.."` (cid) VALUES (:cid)", { cid = cid })
	return MySQL.insert.await("INSERT INTO `"..tableName.."` (cid) VALUES (:cid)", { cid = cid })
end

function GetPlayerVehicles(cid, cb)
	return MySQL.query.await('SELECT id, plate, vehicle FROM vrp_vehicles WHERE user_id=:cid', { cid = cid })
end

function GetBulletins(JobType)
	return MySQL.query.await('SELECT * FROM `mdt_bulletin` WHERE `jobtype` = ? LIMIT 10', { JobType })
	-- return exports.oxmysql:executeSync('SELECT * FROM `mdt_bulletin` WHERE `type`= ? LIMIT 10', { JobType })
end

function GetPlayerProperties(cid, cb)
	local result =  MySQL.query.await('SELECT houselocations.label, houselocations.coords FROM player_houses INNER JOIN houselocations ON player_houses.house = houselocations.name where player_houses.citizenid = ?', {cid})
	return result
end

function GetPlayerDataById(id)
    local Player = QBCore.Functions.GetPlayerByCitizenId(id)
    if Player ~= nil then
		local response = {citizenid = Player.PlayerData.citizenid, charinfo = Player.PlayerData.charinfo, metadata = Player.PlayerData.metadata, job = Player.PlayerData.job}
        return response
    else
        return MySQL.single.await('SELECT citizenid, charinfo, job, metadata FROM players WHERE citizenid = ? LIMIT 1', { id })
    end

	-- return exports.oxmysql:executeSync('SELECT citizenid, charinfo, job FROM players WHERE citizenid = ? LIMIT 1', { id })
end

-- Probs also best not to use
--[[ function GetImpoundStatus(vehicleid, cb)
	cb( #(exports.oxmysql:executeSync('SELECT id FROM `impound` WHERE `vehicleid`=:vehicleid', {['vehicleid'] = vehicleid })) > 0 )
end ]]

-- function DeterVeiculo()
--     print("chamou")
-- 	local src = source
-- 	local user_id = vRP.getUserId(src)
-- 	if user_id then
-- 		if vRP.hasPermission(user_id,"Police") then
-- 			if vRPclient.getHealth(source) > 101 and not vCLIENT.getHandcuff(source) then
-- 				local vehicle,vehNet,vehPlate,vehName = vRPclient.vehList(source,7)
-- 				if vehicle then
-- 					local plateUser = vRP.getVehiclePlate(vehPlate)
-- 					local inVehicle = vRP.query("vRP/get_vehicles",{ user_id = parseInt(plateUser), vehicle = vehName })
-- 					if inVehicle[1] then
-- 						if inVehicle[1].arrest <= 0 then
-- 							vRP.execute("vRP/set_arrest",{ user_id = parseInt(plateUser), vehicle = vehName, arrest = 1, time = parseInt(os.time()) })
-- 							TriggerClientEvent("Notify",source,"aviso","Veículo <b>apreendido</b>.",3000)
-- 							TriggerClientEvent("Notify",plateUser,"aviso","Veículo <b>"..vRP.vehicleName(vehName).."</b> foi conduzido para o <b>DMV</b>.",7000)
-- 						else
-- 							TriggerClientEvent("Notify",source,"amarelo","O veículo está no galpão da polícia.",5000)
-- 						end
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- end

function IsVehicleOwned(plate)
    local result = MySQL.scalar.await('SELECT plate FROM vrp_vehicles WHERE plate = ?', {plate})
    return result
end

function GetBoloStatus(plate)
	local result = MySQL.scalar.await('SELECT id FROM `mdt_bolos` WHERE LOWER(`plate`)=:plate', { plate = string.lower(plate)})
	return result
	-- return exports.oxmysql:scalarSync('SELECT id FROM `mdt_bolos` WHERE LOWER(`plate`)=:plate', { plate = string.lower(plate)})
end

function GetOwnerName(cid)
	local result = MySQL.scalar.await('SELECT charinfo FROM `players` WHERE LOWER(`citizenid`) = ? LIMIT 1', {cid})
	return result
	-- return exports.oxmysql:scalarSync('SELECT charinfo FROM `players` WHERE id=:cid LIMIT 1', { cid = cid})
end

function GetVehicleInformation(plate, cb)
    local result = MySQL.query.await('SELECT id, information FROM `mdt_vehicleinfo` WHERE plate=:plate', { plate = plate})
	return result
end

function GetPlayerLicenses(identifier, playerId)
    local Player = vRP.getInformation(playerId)
    if Player[1] ~= nil then
        return Player[1].metadata
    else
        local result = MySQL.scalar.await('SELECT metadata FROM vrp_users WHERE registration = @identifier', {['@identifier'] = identifier})
        if result ~= nil then
            local metadata = json.decode(result)
            if metadata[1]["metadata"] ~= nil and metadata[1]["metadata"] then
                return metadata[1]["metadata"]
            else
                return {
                    ['driver'] = false,
                    ['business'] = false,
                    ['weapon'] = false,
                    ['pilot'] = false
                }
            end
        end
    end
end

function ManageLicense(id, identifier, type, status)
    local Player = vRP.getInformation(id)
    local licenseStatus = nil
    if status == "give" then licenseStatus = true elseif status == "revoke" then licenseStatus = false end
    if Player[1] ~= nil then
        local licences = json.decode(Player[1].metadata)
        local newLicenses = {}
        for k, v in pairs(licences) do
            local newStatus = v
            if k == type then
                newStatus = licenseStatus
            end
            newLicenses[k] = newStatus
        end
        MySQL.query.await('UPDATE `vrp_users` SET `metadata` = @metadata WHERE registration = @identifier', {['@metadata'] = json.encode(newLicenses), ['@identifier'] = identifier})
    else
        local licenseType = '$.licences.'..type
        local result = MySQL.query.await('UPDATE `vrp_users` SET `metadata` = JSON_REPLACE(`metadata`, ?, ?) WHERE `registration` = ?', {licenseType, licenseStatus, identifier}) --seems to not work on older MYSQL versions, think about alternative
    end
end

function ManageLicenses(id, identifier, incomingLicenses)
    local Player = vRP.getInformation(id)
    if Player[1] ~= nil then
        MySQL.scalar.await('UPDATE `vrp_users` SET `metadata` = @metadata WHERE registration = @identifier', {['@metadata'] = json.encode(incomingLicenses), ['@identifier'] = identifier})
        Player[1].metadata = incomingLicenses
    else
        local result = MySQL.scalar.await('SELECT metadata FROM vrp_users WHERE registration = @registration', {['@registration'] = identifier})
        result = json.decode(result)
        print(result.metadata)

        result.metadata = result.metadata or {
            ['driver'] = true,
            ['business'] = false,
            ['weapon'] = false,
            ['pilot'] = false
        }

        for k, _ in pairs(incomingLicenses) do
            result.metadata[k] = incomingLicenses[k]
        end
        MySQL.query.await('UPDATE `vrp_users` SET `metadata` = @metadata WHERE registration = @identifier', {['@metadata'] = json.encode(result), ['@identifier'] = identifier})
    end
end
