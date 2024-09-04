ESX = exports['es_extended']:getSharedObject()

local settingLocation = false
local currentAction = nil
local currentShop = nil
local blips = {}  -- Initialize blips as an empty table

-- Constants for key bindings
local INTERACT_KEY = 38 -- E key
local BACKSPACE_KEY = 177

-- Register the Repair Shop Menu
local function registerRepairShopMenu()
    lib.registerMenu({
        id = 'repair_shop_menu',
        title = 'Manage Repair Shops',
        position = 'top-right',
        options = {}
    }, function(selected, scrollIndex, args)
        if args.action == 'add_new' then
            OpenNewShopDialog()
        else
            currentShop = args.shopName
            OpenShopActionsMenu(currentShop)
        end
    end, function()
        -- Close the menu when backspace is pressed in the main menu
        RefreshBlips()  -- Refresh blips when the menu is closed
        lib.hideMenu()
    end)
end

registerRepairShopMenu()

function OpenAdminMenu()
    ESX.TriggerServerCallback('grave_pedrepair:getRepairShops', function(repairShops)
        local elements = {
            {label = 'Add New Repair Shop', args = {action = 'add_new'}}
        }

        for name, _ in pairs(repairShops) do
            table.insert(elements, {label = name, args = {action = 'manage', shopName = name}})
        end

        lib.setMenuOptions('repair_shop_menu', elements)
        lib.showMenu('repair_shop_menu')
    end)
end

function OpenNewShopDialog()
    local input = lib.inputDialog('Enter New Shop Name', {
        {type = 'input', label = 'Shop Name', description = 'Name of the new repair shop', required = true}
    })

    if input then
        local shopName = input[1]
        if shopName == nil or shopName == '' then
            ESX.ShowNotification('Invalid name')
        else
            TriggerServerEvent('grave_pedrepair:addRepairShop', shopName)
            Citizen.Wait(500)  -- Re-open admin menu to refresh the list
            OpenAdminMenu()
        end
    end
end

function OpenShopActionsMenu(shopName)
    ESX.TriggerServerCallback('grave_pedrepair:getRepairShops', function(repairShops)
        local shop = repairShops[shopName]
        local elements = {
            {label = 'Set Repair Spot', args = {action = 'set_repair', shopName = shopName}},
            {label = 'Set Ped Spawn', args = {action = 'set_pedspawn', shopName = shopName}},
            {label = 'Change Shop Name', args = {action = 'change_name', shopName = shopName}},
            {label = 'Delete Repair Shop', args = {action = 'delete_shop', shopName = shopName}}
        }

        if shop.repairSpot and shop.repairSpot.x ~= 0 then
            table.insert(elements, 1, {label = 'Current Repair Spot: ' .. string.format('%.2f, %.2f, %.2f', shop.repairSpot.x, shop.repairSpot.y, shop.repairSpot.z), args = {action = 'info'}})
        end
        if shop.pedSpawn and shop.pedSpawn.x ~= 0 then
            table.insert(elements, 2, {label = 'Current Ped Spawn: ' .. string.format('%.2f, %.2f, %.2f', shop.pedSpawn.x, shop.pedSpawn.y, shop.pedSpawn.z), args = {action = 'info'}})
        end

        lib.registerMenu({
            id = 'shop_actions_menu',
            title = 'Actions for ' .. shopName,
            position = 'top-right',
            options = elements
        }, function(selected, scrollIndex, args)
            if args.action == 'set_repair' then
                settingLocation = true
                currentAction = 'repairspot'
                currentShop = shopName
                ESX.ShowNotification('Run to the location and press E to set the repair spot.')
            elseif args.action == 'set_pedspawn' then
                settingLocation = true
                currentAction = 'pedspawn'
                currentShop = shopName
                ESX.ShowNotification('Run to the location and press E to set the ped spawn spot.')
            elseif args.action == 'change_name' then
                OpenChangeShopNameDialog(shopName)
            elseif args.action == 'delete_shop' then
                TriggerServerEvent('grave_pedrepair:deleteRepairShop', shopName)
                ESX.ShowNotification('Deleted repair shop: ' .. shopName)
                OpenAdminMenu() -- Update menu after deletion
            end
        end, function()
            OpenAdminMenu()  -- Reopen the main menu
        end)

        lib.showMenu('shop_actions_menu')
    end)
end

function OpenChangeShopNameDialog(shopName)
    local input = lib.inputDialog('Enter New Shop Name', {
        {type = 'input', label = 'Shop Name', description = 'Name of the repair shop', value = shopName, required = true}
    })

    if input then
        local newShopName = input[1]
        if newShopName == nil or newShopName == '' or newShopName == shopName then
            ESX.ShowNotification('Invalid name or same as current name')
        else
            TriggerServerEvent('grave_pedrepair:changeRepairShopName', shopName, newShopName)
            Citizen.Wait(500)  -- Re-open admin menu to refresh the list
            OpenAdminMenu()
        end
    end
end

-- Event to update repair shop blips
RegisterNetEvent('grave_pedrepair:updateRepairShopBlips')
AddEventHandler('grave_pedrepair:updateRepairShopBlips', function()
    OpenAdminMenu() -- Re-open the repair shop menu to refresh blips
end)

function RefreshBlips()
    ESX.TriggerServerCallback('grave_pedrepair:getRepairShops', function(repairShops)
        clearOldBlips() -- Clear existing blips

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
                table.insert(blips, blip) -- Store blip handle in the table
            end
        end

        Config.RepairShops = repairShops
    end)
end

function clearOldBlips()
    for _, blipHandle in ipairs(blips) do
        RemoveBlip(blipHandle)
    end
    blips = {} -- Clear the table after removing all blips
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10)
        if settingLocation then
            ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to set the location.')
            if IsControlJustReleased(0, INTERACT_KEY) then
                local coords = GetEntityCoords(PlayerPedId())
                settingLocation = false

                if currentAction == 'repairspot' then
                    TriggerServerEvent('grave_pedrepair:saveLocation', 'repairspot', coords, currentShop)
                    ESX.ShowNotification('Repair spot set at: ' .. coords)
                    ESX.ShowNotification('Make sure to set the ped spawn location too.')
                elseif currentAction == 'pedspawn' then
                    TriggerServerEvent('grave_pedrepair:saveLocation', 'pedspawn', coords, currentShop)
                    ESX.ShowNotification('Ped spawn spot set at: ' .. coords)
                end

                -- Re-open shop actions menu after setting location
                Citizen.Wait(500)  -- Wait a bit for the server to update
                OpenShopActionsMenu(currentShop)

                currentAction = nil
                currentShop = nil

                -- Refresh blips after setting location
                RefreshBlips()
            end
        end

        -- Handle Backspace to go back to the main menu
        if IsControlJustReleased(0, BACKSPACE_KEY) then
            if lib.getOpenMenu() == 'shop_actions_menu' then
                OpenAdminMenu()  -- Reopen the main menu
            else
                RefreshBlips()  -- Refresh blips when the menu is closed
                lib.hideMenu()  -- Close the menu
            end
        end
    end
end)

RegisterNetEvent('grave_pedrepair:openAdminMenu')
AddEventHandler('grave_pedrepair:openAdminMenu', function()
    OpenAdminMenu()
end)
