ESX = nil
local repairInProgress = false
local mechanicPed = nil
local blips = {}

-- Constants for magic numbers
local INTERACT_KEY = 38 -- E key
local MARKER_TYPE = 36
local MARKER_DISTANCE = 35
local INTERACTION_DISTANCE = 2

-- Load repair shops from the server callback
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(10)
    end

    RefreshBlips()
end)

-- Function to clear all existing blips
function clearOldBlips()
    for _, blipHandle in ipairs(blips) do
        RemoveBlip(blipHandle)
    end
    blips = {} -- Clear the table after removing all blips
end

-- Function to refresh all blips
function RefreshBlips()
    ESX.TriggerServerCallback('grave_pedrepair:getRepairShops', function(repairShops)
        clearOldBlips() -- Clear existing blips before adding new ones

        -- Create new blips for repair shops
        for name, shop in pairs(repairShops) do
            if shop.repairSpot then
                local blip = AddBlipForCoord(shop.repairSpot.x, shop.repairSpot.y, shop.repairSpot.z)
                SetBlipSprite(blip, 225)
                SetBlipAsShortRange(blip, true)
                SetBlipScale(blip, 0.8)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(name)
                EndTextCommandSetBlipName(blip)

                -- Store blip handle in the table
                table.insert(blips, blip)
            end
        end
        Config.RepairShops = repairShops
    end)
end

-- Function to handle ped spawning and actions
function pedmodel(playerPed, vehicle, location)
    local pedModel = GetHashKey(Config.pedModel)
    if not HasModelLoaded(pedModel) then
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do
            Citizen.Wait(1)
        end
    end

    mechanicPed = CreatePed(1, pedModel, location.pedSpawn.x, location.pedSpawn.y, location.pedSpawn.z, 36.850395, false, true)
    SetBlockingOfNonTemporaryEvents(mechanicPed, true)

    local passengerDoor = GetOffsetFromEntityInWorldCoords(vehicle, 1)

    TaskGoToCoordAnyMeans(mechanicPed, passengerDoor.x, passengerDoor.y, passengerDoor.z, 1.0, 0, 0, 786603, 0xbf800000)
    Citizen.Wait(Config.WalkTime)

    if DoesEntityExist(mechanicPed) then
        ClearPedTasksImmediately(mechanicPed)
        TaskStartScenarioInPlace(mechanicPed, Config.Animation, 0, true)
        Citizen.Wait(Config.PedAnimationTime)
        ClearPedTasks(mechanicPed)
        TaskGoToCoordAnyMeans(mechanicPed, location.pedSpawn.x, location.pedSpawn.y, location.pedSpawn.z, 1.0, 0, 0, 786603, 0xbf800000)
        Citizen.Wait(Config.WalkTime)
        ShowAdvancedNotification(Config.PedPicture, Config.PedName, Config.PedSubject, Config.PedMessage)
        DeleteEntity(mechanicPed)
    end
end

local isNearShop = false
local lastNotification = false

-- Main loop to handle player interactions with repair shops and marker drawing
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        isNearShop = false

        for name, shop in pairs(Config.RepairShops) do
            if shop.repairSpot then
                local distance = #(coords - vector3(shop.repairSpot.x, shop.repairSpot.y, shop.repairSpot.z))

                -- Handle marker drawing and proximity interaction in a single loop
                if distance < MARKER_DISTANCE then
                    DrawMarker(MARKER_TYPE, shop.repairSpot.x, shop.repairSpot.y, shop.repairSpot.z, 0, 0, 0, 0, 0, 0, 2.4, 2.4, 2.4, 0, 255, 0, 155, false, false, 2, false, false, false, false)
                end

                if distance < INTERACTION_DISTANCE then
                    isNearShop = true

                    if not lastNotification then
                        ESX.ShowHelpNotification(Strings.HelpNotification)
                        lastNotification = true
                    end

                    if IsControlJustReleased(0, INTERACT_KEY) then
                        if IsPedOnFoot(playerPed) then
                            ESX.ShowNotification(Strings.OnFoot)
                        else
                            if not repairInProgress then
                                repairInProgress = true
                                if Config.RequireMechanicOnline then
                                    ESX.TriggerServerCallback('checkLS', function(lsRequired)
                                        if not lsRequired then
                                            handleRepair(playerPed, shop)
                                        else
                                            ESX.ShowNotification(Strings.MechanicsonDuty)
                                            repairInProgress = false
                                        end
                                    end, Config.LSJobName, Config.LSRequired)
                                else
                                    handleRepair(playerPed, shop)
                                end
                            end
                        end
                    end
                end
            end
        end

        if not isNearShop and lastNotification then
            lastNotification = false
        end

        Citizen.Wait(isNearShop and 10 or 500) -- Optimize wait time based on proximity
    end
end)

-- Function to handle repair logic
function handleRepair(playerPed, shop)
    if IsPedInAnyVehicle(playerPed) then
        ESX.TriggerServerCallback('canAfford', function(canAfford)
            if canAfford then
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                FreezeEntityPosition(vehicle, true)
                FreezeEntityPosition(playerPed, true)
                DisableAllControlActions(0)
                pedmodel(playerPed, vehicle, shop)
                Citizen.Wait(1000)
                SetVehicleFixed(vehicle)
                SetVehicleDeformationFixed(vehicle)
                SetVehicleEngineHealth(vehicle, 1000.0)
                FreezeEntityPosition(vehicle, false)
                FreezeEntityPosition(playerPed, false)
                EnableAllControlActions(0)
            else
                ESX.ShowNotification(Strings.NoMoney)
            end
            repairInProgress = false
        end, Config.Money)
    else
        ESX.ShowNotification(Strings.OnFoot)
        repairInProgress = false
    end
end

-- Utility function to show advanced notifications
function ShowAdvancedNotification(icon, sender, title, text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    SetNotificationMessage(icon, icon, true, 4, sender, title, text)
    DrawNotification(false, true)
end
