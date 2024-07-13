ESX = exports['es_extended']:getSharedObject()

-- Callback to get repair shops from the database
ESX.RegisterServerCallback('grave_pedrepair:getRepairShops', function(source, cb)
    MySQL.Async.fetchAll('SELECT * FROM repair_shops', {}, function(result)
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
    local mechanicsOnDuty = 0

    if xPlayer then
        local players = ESX.GetExtendedPlayers('job', jobName)
        mechanicsOnDuty = #players
    end

    cb(mechanicsOnDuty >= lsRequired)
end)

-- Callback to check if player can afford the repair cost
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

-- Function to add money to the society account
function addMoneyToSociety(amount)
    if Config.SharedAccount then
        TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society, function(account)
            account.addMoney(amount)
        end)
    end
end


RegisterServerEvent('grave_pedrepair:addRepairShop')
AddEventHandler('grave_pedrepair:addRepairShop', function(shopName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if xPlayer and xPlayer.groups and (xPlayer.groups['admin'] or xPlayer.groups['superadmin'] or xPlayer.groups['owner']) then
        MySQL.Async.execute('INSERT INTO repair_shops (name, repairSpotX, repairSpotY, repairSpotZ, pedSpawnX, pedSpawnY, pedSpawnZ) VALUES (@name, 0, 0, 0, 0, 0, 0)', {
            ['@name'] = shopName
        }, function(rowsAffected)
            if rowsAffected > 0 then
                print('New repair shop added by ' .. GetPlayerName(_source) .. ': ' .. shopName)
                TriggerClientEvent('grave_pedrepair:shopAdded', -1, shopName) -- Update all clients
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

    -- Ensure xPlayer exists and has group information
    if xPlayer and xPlayer.groups then
        -- Check if player is in admin, superadmin, or owner group
        if xPlayer.groups['admin'] or xPlayer.groups['superadmin'] or xPlayer.groups['owner'] then
            MySQL.Async.fetchAll('SELECT * FROM repair_shops WHERE name = @name', {
                ['@name'] = shopName
            }, function(result)
                if #result == 0 then
                    MySQL.Async.execute('INSERT INTO repair_shops (name, repairSpotX, repairSpotY, repairSpotZ, pedSpawnX, pedSpawnY, pedSpawnZ) VALUES (@name, @repairSpotX, @repairSpotY, @repairSpotZ, @pedSpawnX, @pedSpawnY, @pedSpawnZ)', {
                        ['@name'] = shopName,
                        ['@repairSpotX'] = (locationType == 'repairspot' and coords.x or 0),
                        ['@repairSpotY'] = (locationType == 'repairspot' and coords.y or 0),
                        ['@repairSpotZ'] = (locationType == 'repairspot' and coords.z or 0),
                        ['@pedSpawnX'] = (locationType == 'pedspawn' and coords.x or 0),
                        ['@pedSpawnY'] = (locationType == 'pedspawn' and coords.y or 0),
                        ['@pedSpawnZ'] = (locationType == 'pedspawn' and coords.z or 0)
                    })
                else
                    if locationType == 'repairspot' then
                        MySQL.Async.execute('UPDATE repair_shops SET repairSpotX = @repairSpotX, repairSpotY = @repairSpotY, repairSpotZ = @repairSpotZ WHERE name = @name', {
                            ['@repairSpotX'] = coords.x,
                            ['@repairSpotY'] = coords.y,
                            ['@repairSpotZ'] = coords.z,
                            ['@name'] = shopName
                        })
                    elseif locationType == 'pedspawn' then
                        MySQL.Async.execute('UPDATE repair_shops SET pedSpawnX = @pedSpawnX, pedSpawnY = @pedSpawnY, pedSpawnZ = @pedSpawnZ WHERE name = @name', {
                            ['@pedSpawnX'] = coords.x,
                            ['@pedSpawnY'] = coords.y,
                            ['@pedSpawnZ'] = coords.z,
                            ['@name'] = shopName
                        })
                    end
                end
            end)

            print('Location saved by ' .. GetPlayerName(_source) .. ' for ' .. shopName .. ' as ' .. locationType .. ': ' .. coords)
        else
            print('Player ' .. GetPlayerName(_source) .. ' tried to save location without permission')
        end
    else
        print('Failed to retrieve player data or player has no group information')
    end
end)

RegisterServerEvent('grave_pedrepair:deleteRepairShop')
AddEventHandler('grave_pedrepair:deleteRepairShop', function(shopName)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if xPlayer and xPlayer.groups and (xPlayer.groups['admin'] or xPlayer.groups['superadmin'] or xPlayer.groups['owner']) then
        MySQL.Async.execute('DELETE FROM repair_shops WHERE name = @name', {
            ['@name'] = shopName
        }, function(rowsAffected)
            if rowsAffected > 0 then
                print('Repair shop deleted by ' .. GetPlayerName(_source) .. ': ' .. shopName)
                TriggerClientEvent('grave_pedrepair:shopDeleted', -1, shopName) -- Update all clients
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

    if xPlayer and xPlayer.groups and (xPlayer.groups['admin'] or xPlayer.groups['superadmin'] or xPlayer.groups['owner']) then
        MySQL.Async.fetchAll('SELECT * FROM repair_shops WHERE name = @name', {
            ['@name'] = oldName
        }, function(result)
            if #result > 0 then
                MySQL.Async.execute('UPDATE repair_shops SET name = @newName WHERE name = @oldName', {
                    ['@newName'] = newName,
                    ['@oldName'] = oldName
                }, function(rowsAffected)
                    if rowsAffected > 0 then
                        print('Repair shop name changed from ' .. oldName .. ' to ' .. newName .. ' by ' .. GetPlayerName(_source))
                        TriggerClientEvent('grave_pedrepair:shopNameChanged', -1, oldName, newName) -- Update all clients
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
