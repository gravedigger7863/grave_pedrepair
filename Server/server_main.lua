ESX = exports['es_extended']:getSharedObject()

-- Helper function to check permissions
local function hasAdminPermissions(xPlayer)
    return xPlayer and xPlayer.groups and (xPlayer.groups['admin'] or xPlayer.groups['superadmin'] or xPlayer.groups['owner'])
end

-- Helper function to handle SQL update/insert execution
local function executeSqlQuery(query, params, callback)
    MySQL.Async.execute(query, params, function(rowsAffected)
        if callback then
            callback(rowsAffected)
        end
    end)
end

-- Helper function to fetch data from the database
local function fetchSqlQuery(query, params, callback)
    MySQL.Async.fetchAll(query, params, function(result)
        if callback then
            callback(result)
        end
    end)
end

-- Function to add money to the society account
local function addMoneyToSociety(amount)
    if Config.SharedAccount then
        TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society, function(account)
            account.addMoney(amount)
        end)
    end
end

-- Callback to get repair shops from the database
ESX.RegisterServerCallback('grave_pedrepair:getRepairShops', function(source, cb)
    fetchSqlQuery('SELECT * FROM repair_shops', {}, function(result)
        local repairShops = {}

        for i = 1, #result, 1 do
            repairShops[result[i].name] = {
                repairSpot = {x = result[i].repairSpotX, y = result[i].repairSpotY, z = result[i].repairSpotZ},
                pedSpawn = {x = result[i].pedSpawnX, y = result[i].pedSpawnY, z = result[i].pedSpawnZ}
            }
        end

        cb(repairShops)
    end)
end)

-- Callback to check if a mechanic is required
ESX.RegisterServerCallback('checkLS', function(source, cb, jobName, lsRequired)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local players = ESX.GetExtendedPlayers('job', jobName)
        cb(#players >= lsRequired)
    else
        cb(false)
    end
end)

-- Callback to check if the player can afford the repair cost
ESX.RegisterServerCallback('canAfford', function(source, cb, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getMoney() >= amount then
        xPlayer.removeMoney(amount)
        addMoneyToSociety(amount)
        cb(true)
    else
        cb(false)
    end
end)

-- Event to add a new repair shop
RegisterServerEvent('grave_pedrepair:addRepairShop')
AddEventHandler('grave_pedrepair:addRepairShop', function(shopName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if hasAdminPermissions(xPlayer) then
        executeSqlQuery('INSERT INTO repair_shops (name, repairSpotX, repairSpotY, repairSpotZ, pedSpawnX, pedSpawnY, pedSpawnZ) VALUES (@name, 0, 0, 0, 0, 0, 0)', {
            ['@name'] = shopName
        }, function(rowsAffected)
            if rowsAffected > 0 then
                print('New repair shop added by ' .. GetPlayerName(_source) .. ': ' .. shopName)
                TriggerClientEvent('grave_pedrepair:shopAdded', -1, shopName)
            else
                print('Failed to add new repair shop for ' .. GetPlayerName(_source) .. ': ' .. shopName)
                TriggerClientEvent('grave_pedrepair:addShopFailed', _source, 'Failed to add new repair shop.')
            end
        end)
    else
        print('Player ' .. GetPlayerName(_source) .. ' tried to add a repair shop without permission')
        TriggerClientEvent('grave_pedrepair:addShopFailed', _source, 'You do not have permission to add a repair shop.')
    end
end)

-- Event to save repair shop locations
RegisterServerEvent('grave_pedrepair:saveLocation')
AddEventHandler('grave_pedrepair:saveLocation', function(locationType, coords, shopName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if hasAdminPermissions(xPlayer) then
        fetchSqlQuery('SELECT * FROM repair_shops WHERE name = @name', {
            ['@name'] = shopName
        }, function(result)
            if #result == 0 then
                executeSqlQuery('INSERT INTO repair_shops (name, repairSpotX, repairSpotY, repairSpotZ, pedSpawnX, pedSpawnY, pedSpawnZ) VALUES (@name, @repairSpotX, @repairSpotY, @repairSpotZ, @pedSpawnX, @pedSpawnY, @pedSpawnZ)', {
                    ['@name'] = shopName,
                    ['@repairSpotX'] = (locationType == 'repairspot' and coords.x or 0),
                    ['@repairSpotY'] = (locationType == 'repairspot' and coords.y or 0),
                    ['@repairSpotZ'] = (locationType == 'repairspot' and coords.z or 0),
                    ['@pedSpawnX'] = (locationType == 'pedspawn' and coords.x or 0),
                    ['@pedSpawnY'] = (locationType == 'pedspawn' and coords.y or 0),
                    ['@pedSpawnZ'] = (locationType == 'pedspawn' and coords.z or 0)
                })
            else
                local query, params
                if locationType == 'repairspot' then
                    query = 'UPDATE repair_shops SET repairSpotX = @repairSpotX, repairSpotY = @repairSpotY, repairSpotZ = @repairSpotZ WHERE name = @name'
                    params = {['@repairSpotX'] = coords.x, ['@repairSpotY'] = coords.y, ['@repairSpotZ'] = coords.z, ['@name'] = shopName}
                elseif locationType == 'pedspawn' then
                    query = 'UPDATE repair_shops SET pedSpawnX = @pedSpawnX, pedSpawnY = @pedSpawnY, pedSpawnZ = @pedSpawnZ WHERE name = @name'
                    params = {['@pedSpawnX'] = coords.x, ['@pedSpawnY'] = coords.y, ['@pedSpawnZ'] = coords.z, ['@name'] = shopName}
                end
                executeSqlQuery(query, params)
            end
            print('Location saved by ' .. GetPlayerName(_source) .. ' for ' .. shopName .. ' as ' .. locationType .. ': ' .. coords)
        end)
    else
        print('Player ' .. GetPlayerName(_source) .. ' tried to save location without permission')
    end
end)

-- Event to delete a repair shop
RegisterServerEvent('grave_pedrepair:deleteRepairShop')
AddEventHandler('grave_pedrepair:deleteRepairShop', function(shopName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if hasAdminPermissions(xPlayer) then
        executeSqlQuery('DELETE FROM repair_shops WHERE name = @name', {['@name'] = shopName}, function(rowsAffected)
            if rowsAffected > 0 then
                print('Repair shop deleted by ' .. GetPlayerName(_source) .. ': ' .. shopName)
                TriggerClientEvent('grave_pedrepair:shopDeleted', -1, shopName)
            else
                print('Failed to delete repair shop ' .. shopName)
            end
        end)
    else
        print('Player ' .. GetPlayerName(_source) .. ' tried to delete a repair shop without permission')
    end
end)

-- Event to change repair shop name
RegisterServerEvent('grave_pedrepair:changeRepairShopName')
AddEventHandler('grave_pedrepair:changeRepairShopName', function(oldName, newName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if hasAdminPermissions(xPlayer) then
        fetchSqlQuery('SELECT * FROM repair_shops WHERE name = @name', {['@name'] = oldName}, function(result)
            if #result > 0 then
                executeSqlQuery('UPDATE repair_shops SET name = @newName WHERE name = @oldName', {['@newName'] = newName, ['@oldName'] = oldName}, function(rowsAffected)
                    if rowsAffected > 0 then
                        print('Repair shop name changed from ' .. oldName .. ' to ' .. newName .. ' by ' .. GetPlayerName(_source))
                        TriggerClientEvent('grave_pedrepair:shopNameChanged', -1, oldName, newName)
                    else
                        print('Failed to change repair shop name from ' .. oldName .. ' to ' .. newName)
                        TriggerClientEvent('grave_pedrepair:changeShopNameFailed', _source, 'Failed to change repair shop name.')
                    end
                end)
            else
                print('Repair shop with name ' .. oldName .. ' does not exist.')
                TriggerClientEvent('grave_pedrepair:changeShopNameFailed', _source, 'Repair shop with the specified name does not exist.')
            end
        end)
    else
        print('Player ' .. GetPlayerName(_source) .. ' tried to change repair shop name without permission')
        TriggerClientEvent('grave_pedrepair:changeShopNameFailed', _source, 'You do not have permission to change the repair shop name.')
    end
end)

-- Register server-side command to manage repair shops
RegisterCommand('managerepairshops', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if hasAdminPermissions(xPlayer) then
        TriggerClientEvent('grave_pedrepair:openAdminMenu', source)
    else
        TriggerClientEvent('esx:showNotification', source, 'You do not have permission to use this command.')
    end
end, false)
