-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
-- local Tunnel = module("vrp","lib/Tunnel")
-- local Proxy = module("vrp","lib/Proxy")
-- vRP = Proxy.getInterface("vRP")
-- vRPclient = Tunnel.getInterface("vRP")
-- vCLIENT = Tunnel.getInterface("player")
-----------------------------------------------------------------------------------------------------------------------------------------

-- local currentGarage = 1

local function doCarDamage(currentVehicle, veh)
	local smash = false
	local damageOutside = false
	local damageOutside2 = false
	local engine = veh.engine + 0.0
	local body = veh.body + 0.0

	if engine < 200.0 then engine = 200.0 end
    if engine  > 1000.0 then engine = 950.0 end
	if body < 150.0 then body = 150.0 end
	if body < 950.0 then smash = true end
	if body < 920.0 then damageOutside = true end
	if body < 920.0 then damageOutside2 = true end

    Citizen.Wait(100)
    SetVehicleEngineHealth(currentVehicle, engine)

	if smash then
		SmashVehicleWindow(currentVehicle, 0)
		SmashVehicleWindow(currentVehicle, 1)
		SmashVehicleWindow(currentVehicle, 2)
		SmashVehicleWindow(currentVehicle, 3)
		SmashVehicleWindow(currentVehicle, 4)
	end

	if damageOutside then
		SetVehicleDoorBroken(currentVehicle, 1, true)
		SetVehicleDoorBroken(currentVehicle, 6, true)
		SetVehicleDoorBroken(currentVehicle, 4, true)
	end

	if damageOutside2 then
		SetVehicleTyreBurst(currentVehicle, 1, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 2, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 3, false, 990.0)
		SetVehicleTyreBurst(currentVehicle, 4, false, 990.0)
	end

	if body < 1000 then
		SetVehicleBodyHealth(currentVehicle, 985.1)
	end
end

function QBCoreFunctionsSpawnVehicle(model, cb, coords, isnetworked)
    local model = GetHashKey(model)
    local ped = PlayerPedId()
    if coords then
        coords = type(coords) == 'table' and vec3(coords.x, coords.y, coords.z) or coords
    else
        coords = GetEntityCoords(ped)
    end
    local isnetworked = isnetworked or true
    if not IsModelInCdimage(model) then
        return
    end
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, isnetworked, false)
    local netid = NetworkGetNetworkIdFromEntity(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetNetworkIdCanMigrate(netid, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(model)
    if cb then
        cb(veh)
    end
end

local function TakeOutImpound(vehicle)
    local coords = Config.ImpoundLocations[currentGarage]
    if coords then
        QBCoreFunctionsSpawnVehicle(vehicle.vehicle, function(veh)
            SetVehicleNumberPlateText(veh, vehicle.plate)
            SetEntityHeading(veh, coords.w)
            doCarDamage(veh, vehicle)
            TriggerServerEvent('police:server:TakeOutImpound',vehicle.plate)
            SetVehicleEngineOn(veh, true, true)
        end, coords, true)
    end
end

RegisterNetEvent('nc-mdt:client:TakeOutImpound', function(data)
    local pos = GetEntityCoords(PlayerPedId())
    currentGarage = data.currentSelection
    local takeDist = Config.ImpoundLocations[data.currentSelection]
    takeDist = vector3(takeDist.x, takeDist.y,  takeDist.z)
    if #(pos - takeDist) <= 15.0 then
        local vehicle = data.vehicle
        TakeOutImpound(data)
    else
        QBCore.Functions.Notify("You are too far away from the impound location!")
    end
end)

RegisterNetEvent('police:client:TakeOutImpound', function(data)
    local pos = GetEntityCoords(PlayerPedId())
    local takeDist = Config.Locations['impound'][data.currentSelection]
    takeDist = vector3(takeDist.x, takeDist.y,  takeDist.z)
    if #(pos - takeDist) <= 1.5 then
        local vehicle = data.vehicle
        TakeOutImpound(vehicle)
    end
end)