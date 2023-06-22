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
    else
        TriggerEvent("Notify", "erro", "Sem permissao para abrir o tablet")
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

RegisterNetEvent('mdt:client:getCallResponses', function(sentData, sentCallId)
    SendNUIMessage({ type = "getCallResponses", data = sentData, callid = sentCallId })
end)

RegisterNetEvent('mdt:client:sendCallResponse', function(message, time, callid, name)
    SendNUIMessage({ type = "sendCallResponse", message = message, time = time, callid = callid, name = name })
end)