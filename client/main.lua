-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
vRPC = Tunnel.getInterface("vRP")
vRP = Proxy.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
cRP = {}
Tunnel.bindInterface(GetCurrentResourceName(), cRP)

vSERVER = Tunnel.getInterface(GetCurrentResourceName())
-----------------------------------------------------------------------------------------------------------------------------------------
local PlayerData = {}
local isOpen = false
local tabletObj = nil
local tabletDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local tabletAnim = "base"
local tabletProp = "prop_cs_tablet"
local tabletBone = 60309
local tabletOffset = vector3(0.03, 0.002, -0.0)
local tabletRot = vector3(10.0, 160.0, 0.0)
------------------------------------------------------------------
--                COMANDO PARA ABRIR O TABLET             --
------------------------------------------------------------------
RegisterKeyMapping('mdt', 'Open Police MDT', 'keyboard', 'i')

RegisterCommand('mdt', function()
    if vSERVER.checkPermission() then
        TriggerServerEvent('mdt:server:openMDT')
    end
end, false)
-----------------------------------------------------------------------------------------------------------------------------------------
---- FUNCTIONS MDT
-----------------------------------------------------------------------------------------------------------------------------------------
local function doAnimation()
    if not isOpen then return end
    -- Animation
    RequestAnimDict(tabletDict)
    while not HasAnimDictLoaded(tabletDict) do Citizen.Wait(100) end
    -- Model
    RequestModel(tabletProp)
    while not HasModelLoaded(tabletProp) do Citizen.Wait(100) end

    local plyPed = PlayerPedId()
    tabletObj = CreateObject(tabletProp, 0.0, 0.0, 0.0, true, true, false)
    local tabletBoneIndex = GetPedBoneIndex(plyPed, tabletBone)

    AttachEntityToEntity(tabletObj, plyPed, tabletBoneIndex, tabletOffset.x, tabletOffset.y, tabletOffset.z, tabletRot.x, tabletRot.y, tabletRot.z, true, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(tabletProp)

    CreateThread(function()
        while isOpen do
            Wait(0)
            if not IsEntityPlayingAnim(plyPed, tabletDict, tabletAnim, 3) then
                TaskPlayAnim(plyPed, tabletDict, tabletAnim, 3.0, 3.0, -1, 49, 0, 0, 0, 0)
            end
        end


        ClearPedSecondaryTask(plyPed)
        Citizen.Wait(250)
        DetachEntity(tabletObj, true, false)
        DeleteEntity(tabletObj)
    end)
end

local function EnableGUI(enable)
    SetNuiFocus(enable, enable)
    SendNUIMessage({ type = "show", enable = enable, job = "police", rosterLink = Config.RosterLink["police"] })
    isOpen = enable
    doAnimation()
end

local function RefreshGUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "show", enable = false, job = "police", rosterLink = Config.RosterLink["police"] })
    isOpen = false
end

--// Non local function so above EHs can utilise
function AllowedJob(job)
    for key, _ in pairs(Config.AllowedJobs) do
        if key == job then
            return true
        end
    end
    --// Return false if current job is not in allowed list
    return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
--- EVENT OPEN MDT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent('mdt:client:open', function(bulletin, activeUnits, calls, cid, playerData)
    EnableGUI(true)
    local x, y, z = table.unpack(GetEntityCoords(PlayerPedId()))

    local currentStreetHash, intersectStreetHash = GetStreetNameAtCoord(x, y, z)
    local currentStreetName = GetStreetNameFromHashKey(currentStreetHash)
    local intersectStreetName = GetStreetNameFromHashKey(intersectStreetHash)
    local zone = tostring(GetNameOfZone(x, y, z))
    local area = GetLabelText(zone)
    local playerStreetsLocation = area

    if not zone then zone = "UNKNOWN" end;

    if intersectStreetName ~= nil and intersectStreetName ~= "" then playerStreetsLocation = currentStreetName .. ", " .. intersectStreetName .. ", " .. area
    elseif currentStreetName ~= nil and currentStreetName ~= "" then playerStreetsLocation = currentStreetName .. ", " .. area
    else playerStreetsLocation = area end

    SendNUIMessage({ type = "data", activeUnits = activeUnits, citizenid = cid, ondutyonly = Config.OnlyShowOnDuty, name = "Welcome, Police "..playerData.name.." "..playerData.name2, location = playerStreetsLocation, fullname = playerData.name.. " "..playerData.name2, bulletin = bulletin })
    SendNUIMessage({ type = "calls", data = calls })
    TriggerEvent("mdt:client:dashboardWarrants")
end)
--====================================================================================
--               MAIN PAGE              --
--====================================================================================
RegisterCommand("restartmdt", function(source, args, rawCommand)
	RefreshGUI()
end, false)

RegisterNUICallback("deleteBulletin", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:deleteBulletin', id)
    cb(true)
end)

RegisterNUICallback("newBulletin", function(data, cb)
    local title = data.title
    local info = data.info
    local time = data.time
    TriggerServerEvent('mdt:server:NewBulletin', title, info, time)
    cb(true)
end)

RegisterNUICallback('escape', function(data, cb)
    EnableGUI(false)
    cb(true)
end)

RegisterNetEvent('mdt:client:dashboardbulletin', function(sentData)
    SendNUIMessage({ type = "bulletin", data = sentData })
end)

RegisterNetEvent('mdt:client:exitMDT', function()
    EnableGUI(false)
end)

RegisterNetEvent('mdt:client:dashboardWarrants', function()
    local warrants = vSERVER.getAllWarrants()
    if warrants ~= nil then
        SendNUIMessage({ type = "warrants", data = warrants })
    end
end)

RegisterNUICallback("getAllDashboardData", function(data, cb)
    local warrants = vSERVER.getAllWarrants()
    if warrants ~= nil then
        SendNUIMessage({ type = "warrants", data = warrants })
    end
end)
-------------------------------------------------------------------------------------------
--- Events Chat Dispatach
-------------------------------------------------------------------------------------------
CreateThread(function()
    if GetResourceState('nc-dispatch') == 'started' then
        print("Started")
        TriggerServerEvent("nc-mdt:dispatchStatus", true)
    end
end)

RegisterNetEvent('mdt:client:setWaypoint:unit', function(sentData)
    SetNewWaypoint(sentData.x, sentData.y)
end)

RegisterNetEvent('mdt:client:dashboardMessage', function(sentData)
    SendNUIMessage({ type = "dispatchmessage", data = sentData })
end)

RegisterNUICallback("dispatchMessage", function(data, cb)
    TriggerServerEvent('mdt:server:sendMessage', data.message, data.time)
    cb(true)
end)

RegisterNUICallback("refreshDispatchMsgs", function(data, cb)
    TriggerServerEvent('mdt:server:refreshDispatchMsgs')
    cb(true)
end)

RegisterNetEvent('mdt:client:dashboardMessages', function(sentData)
    SendNUIMessage({ type = "dispatchmessages", data = sentData })
end)

RegisterNetEvent('dispatch:clNotify', function(sNotificationData, sNotificationId)
    sNotificationData.playerJob = "police"
    SendNUIMessage({ type = "call", data = sNotificationData })
end)

RegisterNUICallback("setWaypoint", function(data, cb)
    TriggerServerEvent('mdt:server:setWaypoint', data.callid)
    cb(true)
end)

RegisterNUICallback("callDetach", function(data, cb)
    TriggerServerEvent('mdt:server:callDetach', data.callid)
    cb(true)
end)

RegisterNUICallback("removeCallBlip", function(data, cb)
    TriggerEvent('nc-dispatch:client:removeCallBlip', data.callid)
    cb(true)
end)

RegisterNUICallback("callAttach", function(data, cb)
    TriggerServerEvent('mdt:server:callAttach', data.callid)
    cb(true)
end)

RegisterNUICallback("attachedUnits", function(data, cb)
    TriggerServerEvent('mdt:server:attachedUnits', data.callid)
    cb(true)
end)

RegisterNUICallback("callDispatchDetach", function(data, cb)
    TriggerServerEvent('mdt:server:callDispatchDetach', data.callid, data.cid)
    cb(true)
end)

RegisterNUICallback("setDispatchWaypoint", function(data, cb)
    TriggerServerEvent('mdt:server:setDispatchWaypoint', data.callid, data.cid)
    cb(true)
end)

RegisterNUICallback("callDragAttach", function(data, cb)
    TriggerServerEvent('mdt:server:callDragAttach', data.callid, data.cid)
    cb(true)
end)

RegisterNUICallback("setWaypointU", function(data, cb)
    TriggerServerEvent('mdt:server:setWaypoint:unit', data.cid)
    cb(true)
end)

RegisterNetEvent('mdt:client:setWaypoint', function(callInformation)
    SetNewWaypoint(callInformation['origin']['x'], callInformation['origin']['y'])
end)

RegisterNetEvent('mdt:client:callDetach', function(callid, sentData)
    if AllowedJob("police") then
        SendNUIMessage({ type = "callDetach", callid = callid, data = tonumber(sentData) }) 
    end
end)

RegisterNetEvent('mdt:client:callAttach', function(callid, sentData)
    if AllowedJob("police") then
        SendNUIMessage({ type = "callAttach", callid = callid, data = tonumber(sentData) })
    end
end)

RegisterNetEvent('mdt:client:attachedUnits', function(sentData, callid)
    SendNUIMessage({ type = "attachedUnits", data = sentData, callid = callid })
end)

RegisterNuiCallback("getCallResponses", function(data, cb)
    TriggerServerEvent('mdt:server:getCallResponses', data.callid)
    cb(true)
end)

RegisterNUICallback("sendCallResponse", function(data, cb)
    TriggerServerEvent('mdt:server:sendCallResponse', data.message, data.time, data.callid)
    cb(true)
end)

RegisterNetEvent('mdt:client:getCallResponses', function(sentData, sentCallId)
    SendNUIMessage({ type = "getCallResponses", data = sentData, callid = sentCallId })
end)

RegisterNetEvent('mdt:client:sendCallResponse', function(message, time, callid, name)
    SendNUIMessage({ type = "sendCallResponse", message = message, time = time, callid = callid, name = name })
end)

-- RegisterNUICallback("dispatchNotif", function(data, cb)
--     local info = data['data']
--     local mentioned = false
--     if callSign ~= "" then if string.find(string.lower(info['message']),string.lower(string.gsub(callSign,'-','%%-'))) then mentioned = true end end
--     if mentioned then

--         -- Send notification to phone??
--         TriggerEvent('erp_phone:sendNotification', {img = info['profilepic'], title = "Dispatch (Mention)", content = info['message'], time = 7500, customPic = true })

--         PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
--         PlaySoundFrontend(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset", 0)
--     else
--         TriggerEvent('erp_phone:sendNotification', {img = info['profilepic'], title = "Dispatch ("..info['name']..")", content = info['message'], time = 5000, customPic = true })
--     end
--     cb(true)
-- end)

--====================================================================================
------------------------------------------
--               REPORTS PAGE           --
------------------------------------------
--====================================================================================

RegisterNUICallback("getAllReports", function(data, cb)
    TriggerServerEvent('mdt:server:getAllReports')
    cb(true)
end)

RegisterNUICallback("getReportData", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:getReportData', id)
    cb(true)
end)

RegisterNUICallback("searchReports", function(data, cb)
    local name = data.name
    TriggerServerEvent('mdt:server:searchReports', name)
    cb(true)
end)

RegisterNUICallback("newReport", function(data, cb)
    local existing = data.existing
    local id = data.id
    local title = data.title
    local reporttype = data.type
    local details = data.details
    local tags = data.tags
    local gallery = data.gallery
    local officers = data.officers
    local civilians = data.civilians
    local time = data.time

    TriggerServerEvent('mdt:server:newReport', existing, id, title, reporttype, details, tags, gallery, officers, civilians, time)
    cb(true)
end)

RegisterNetEvent('mdt:client:getAllReports', function(sentData)
    SendNUIMessage({ type = "reports", data = sentData })
end)

RegisterNetEvent('mdt:client:getReportData', function(sentData)
    SendNUIMessage({ type = "reportData", data = sentData })
end)

RegisterNetEvent('mdt:client:reportComplete', function(sentData)
    SendNUIMessage({ type = "reportComplete", data = sentData })
end)

------------------------------------------------------------------------------------------------------------------------------
--             PROFILE PAGE             --
------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("getProfileData", function(data, cb)
    local id = data.id
    local dataPlayer = vSERVER.getProfile(id)

    --[[ local getProfileProperties = function(data)
        if pP then return end
        pP = promise.new()
        QBCore.Functions.TriggerCallback('nc-phone:server:MeosGetPlayerHouses', function(result)
            pP:resolve(result)
        end, data)
        return Citizen.Await(pP)
    end
    local propertiesResult = getProfileProperties(id)
    result.properties = propertiesResult
     ]]
    local vehicles = dataPlayer.vehicles

    for i=1,#vehicles do
        local vehicle = dataPlayer.vehicles[i].vehicle
        dataPlayer.vehicles[i]['model'] = GetLabelText(GetDisplayNameFromVehicleModel(vehicle))
    end
    cb(dataPlayer)
end)
RegisterNUICallback("searchProfiles", function(data, cb)
    local resultado = vSERVER.SearchProfileMdt(data.name)
    cb(resultado)
end)

RegisterNetEvent('mdt:client:searchProfile', function(sentData, isLimited)
    SendNUIMessage({ type = "profiles", data = sentData, isLimited = isLimited })
end)

RegisterNUICallback("saveProfile", function(data, cb)
    local profilepic = data.pfp
    local information = data.description
    local cid = data.id
    local fName = data.fName
    local sName = data.sName
    local tags = data.tags
    local gallery = data.gallery
    local fingerprint = data.fingerprint
    local licenses = data.licenses

    TriggerServerEvent("mdt:server:saveProfile", profilepic, information, cid, fName, sName, tags, gallery, fingerprint, licenses)
    cb(true)
end)

RegisterNUICallback("newTag", function(data, cb)
    if data.id ~= "" and data.tag ~= "" then
        TriggerServerEvent('mdt:server:newTag', data.id, data.tag)
    end
    cb(true)
end)

RegisterNUICallback("removeProfileTag", function(data, cb)
    local cid = data.cid
    local tagtext = data.text
    TriggerServerEvent('mdt:server:removeProfileTag', cid, tagtext)
    cb(true)
end)

RegisterNUICallback("updateLicence", function(data, cb)
    local type = data.type
    local status = data.status
    local cid = data.cid
    TriggerServerEvent('mdt:server:updateLicense', cid, type, status)
    cb(true)
end)

-- RegisterNetEvent('mdt:client:getProfileData', function(sentData, isLimited)
--     if not isLimited then
--         local vehicles = sentData['vehicles']
--         for i=1, #vehicles do
--             sentData['vehicles'][i]['plate'] = string.upper(sentData['vehicles'][i]['plate'])
--             local tempModel = vehicles[i]['model']
--             if tempModel and tempModel ~= "Unknown" then
--                 local DisplayNameModel = GetDisplayNameFromVehicleModel(tempModel)
--                 local LabelText = GetLabelText(DisplayNameModel)
--                 if LabelText == "NULL" then LabelText = DisplayNameModel end
--                 sentData['vehicles'][i]['model'] = LabelText
--             end
--         end
--     end
--     SendNUIMessage({ type = "profileData", data = sentData, isLimited = isLimited })
-- end)

-- RegisterNUICallback('SetHouseLocation', function(data, cb)
--     local coords = {}
--     for word in data.coord[1]:gmatch('[^,%s]+') do
--         coords[#coords+1] = tonumber(word)
--     end
--     SetNewWaypoint(coords[1], coords[2])
--     QBCore.Functions.Notify('GPS has been set!', 'success')
-- end)

------------------------------------------------------------------------------------------------------------------------------
--             INCIDENT PAGE             --
------------------------------------------------------------------------------------------------------------------------------
RegisterNUICallback("searchIncidents", function(data, cb)
    local incident = data.incident
    TriggerServerEvent('mdt:server:searchIncidents', incident)
    cb(true)
end)

RegisterNUICallback("getIncidentData", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:getIncidentData', id)
    cb(true)
end)

RegisterNUICallback("incidentSearchPerson", function(data, cb)
    local name = data.name
    TriggerServerEvent('mdt:server:incidentSearchPerson', name )
    cb(true)
end)

RegisterNetEvent('mdt:client:getIncidents', function(sentData)
    SendNUIMessage({ type = "incidents", data = sentData })
end)

RegisterNetEvent('mdt:client:getIncidentData', function(sentData, sentConvictions)
    SendNUIMessage({ type = "incidentData", data = sentData, convictions = sentConvictions })
end)

RegisterNetEvent('mdt:client:incidentSearchPerson', function(sentData)
    SendNUIMessage({ type = "incidentSearchPerson", data = sentData })
end)

RegisterNUICallback("saveIncident", function(data, cb)
    TriggerServerEvent('mdt:server:saveIncident', data.ID, data.title, data.information, data.tags, data.officers, data.civilians, data.evidence, data.associated, data.time)
    cb(true)
end)

RegisterNetEvent('mdt:client:updateIncidentDbId', function(sentData)
    SendNUIMessage({ type = "updateIncidentDbId", data = tonumber(sentData) })
end)

RegisterNUICallback("removeIncidentCriminal", function(data, cb)
    TriggerServerEvent('mdt:server:removeIncidentCriminal', data.cid, data.incidentId)
    cb(true)
end)

RegisterNUICallback("getAllIncidents", function(data, cb)
    TriggerServerEvent('mdt:server:getAllIncidents')
    cb(true)
end)

RegisterNetEvent('mdt:client:getAllIncidents', function(sentData)
    SendNUIMessage({ type = "incidents", data = sentData })
end)

------------------------------------------
--               BOLO PAGE              --
------------------------------------------

RegisterNUICallback("searchBolos", function(data, cb)
    local searchVal = data.searchVal
    TriggerServerEvent('mdt:server:searchBolos', searchVal)
    cb(true)
end)

RegisterNUICallback("getAllBolos", function(data, cb)
    TriggerServerEvent('mdt:server:getAllBolos')
    cb(true)
end)

RegisterNUICallback("getBoloData", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:getBoloData', id)
    cb(true)
end)

RegisterNUICallback("newBolo", function(data, cb)
    local existing = data.existing
    local id = data.id
    local title = data.title
    local plate = data.plate
    local owner = data.owner
    local individual = data.individual
    local detail = data.detail
    local tags = data.tags
    local gallery = data.gallery
    local officers = data.officers
    local time = data.time
    TriggerServerEvent('mdt:server:newBolo', existing, id, title, plate, owner, individual, detail, tags, gallery, officers, time)
    cb(true)
end)

RegisterNUICallback("deleteBolo", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:deleteBolo', id)
    cb(true)
end)

RegisterNUICallback("deleteICU", function(data, cb)
    local id = data.id
    TriggerServerEvent('mdt:server:deleteICU', id)
    cb(true)
end)

RegisterNetEvent('mdt:client:getBolos', function(sentData)
    SendNUIMessage({ type = "bolos", data = sentData })
end)

RegisterNetEvent('mdt:client:getAllIncidents', function(sentData)
    SendNUIMessage({ type = "incidents", data = sentData })
end)

RegisterNetEvent('mdt:client:getAllBolos', function(sentData)
    SendNUIMessage({ type = "bolos", data = sentData })
end)

RegisterNetEvent('mdt:client:getBoloData', function(sentData)
    SendNUIMessage({ type = "boloData", data = sentData })
end)

RegisterNetEvent('mdt:client:boloComplete', function(sentData)
    SendNUIMessage({ type = "boloComplete", data = sentData })
end)