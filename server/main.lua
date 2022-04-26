-- Variables
QBCore = exports['qb-core']:GetCoreObject()
local SoundScriptName = 'interact-sound'
local SoundPath = '/client/html/sounds'
local IsFrozen = {}
local permissions = { -- What should each permission be able to do
    ['kill'] = 'god',
    ['revive'] = 'god',
    ['freeze'] = 'admin',
    ['spectate'] = 'admin',
    ['goto'] = 'admin',
    ['bring'] = 'admin',
    ['intovehicle'] = 'admin',
    ['kick'] = 'admin',
    ['ban'] = 'god',
    ['setPermissions'] = 'god',
    ['cloth'] = 'admin',
    ['spawnVehicle'] = 'admin',
    ['savecar'] = 'god',
    ['playsound'] = 'god',
    ['usemenu'] = 'admin',
}
local PermissionOrder = { -- Permission hierarchy order from top to bottom
    'god',
    'admin',
    'user'
}

-- Functions
local function PermOrder(permission)
    for i = 1, #PermissionOrder do
        if PermissionOrder[i] == permission then
            return i
        end
    end
end

local function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('dir "'..directory..'" /b'):lines() do
        i = i + 1
        t[i] = filename:match("(.+)%..+$")
    end
    return t
end

-- Events
RegisterNetEvent('qb-admin:server:GetPlayersForBlips', function()
    local src = source
    local players = {}
    for k, v in pairs(QBCore.Functions.GetPlayers()) do
        local targetped = GetPlayerPed(v)
        local ped = QBCore.Functions.GetPlayer(v)
        players[#players+1] = {
            name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname .. ' | ' .. GetPlayerName(v),
            id = v,
            coords = GetEntityCoords(targetped),
            cid = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
            citizenid = ped.PlayerData.citizenid,
            sources = GetPlayerPed(ped.PlayerData.source),
            sourceplayer= ped.PlayerData.source
        }
    end
    TriggerClientEvent('qb-admin:client:Show', src, players)
end)

RegisterNetEvent('qb-admin:server:kill', function(player)
    local src = source
    local target = player.id

    if not (QBCore.Functions.HasPermission(src, permissions['kill']) or IsPlayerAceAllowed(src, 'command')) then return end
    if PermOrder(QBCore.Functions.GetPermission(src)) > PermOrder(QBCore.Functions.GetPermission(target)) then return end

    TriggerClientEvent('hospital:client:KillPlayer', target)
end)

RegisterNetEvent('qb-admin:server:revive', function(player)
    local src = source

    if not (QBCore.Functions.HasPermission(src, permissions['revive']) or IsPlayerAceAllowed(src, 'command')) then return end
    
    TriggerClientEvent('hospital:client:Revive', player.id)
end)

RegisterNetEvent('qb-admin:server:freeze', function(player)
    local src = source
    local target = GetPlayerPed(player.id)
    
    if not (QBCore.Functions.HasPermission(src, permissions['freeze']) or IsPlayerAceAllowed(src, 'command')) then return end
    if PermOrder(QBCore.Functions.GetPermission(src)) > PermOrder(QBCore.Functions.GetPermission(player.id)) then return end
    if IsFrozen[target] == nil then IsFrozen[target] = false end

    if IsFrozen[target] then
        FreezeEntityPosition(target, false)
        IsFrozen[target] = false
    else
        FreezeEntityPosition(target, true)
        IsFrozen[target] = true
    end
end)

RegisterNetEvent('qb-admin:server:spectate', function(player)
    local src = source
    local targetped = GetPlayerPed(player.id)
    local coords = GetEntityCoords(targetped)

    if not (QBCore.Functions.HasPermission(src, permissions['spectate']) or IsPlayerAceAllowed(src, 'command')) then return end
    
    TriggerClientEvent('qb-admin:client:spectate', src, player.id, coords)
end)

RegisterNetEvent('qb-admin:server:goto', function(player)
    local src = source
    local admin = GetPlayerPed(src)
    local coords = GetEntityCoords(GetPlayerPed(player.id))
    
    if not (QBCore.Functions.HasPermission(src, permissions['goto']) or IsPlayerAceAllowed(src, 'command')) then return end

    SetEntityCoords(admin, coords)
end)

RegisterNetEvent('qb-admin:server:bring', function(player)
    local src = source
    local admin = GetPlayerPed(src)
    local coords = GetEntityCoords(admin)
    local target = GetPlayerPed(player.id)
    
    if not (QBCore.Functions.HasPermission(src, permissions['bring']) or IsPlayerAceAllowed(src, 'command')) then return end
    
    SetEntityCoords(target, coords)
end)

RegisterNetEvent('qb-admin:server:intovehicle', function(player)
    local src = source
    local admin = GetPlayerPed(src)
    local targetPed = GetPlayerPed(player.id)
    local vehicle = GetVehiclePedIsIn(targetPed, false)
    local seat = -1
    
    if not (QBCore.Functions.HasPermission(src, permissions['intovehicle']) or IsPlayerAceAllowed(src, 'command')) then return end
    if vehicle == 0 then TriggerClientEvent('QBCore:Notify', src, Lang:t("error.player_no_vehicle"), 'error', 4000) return end
    for i = 0, 8, 1 do if GetPedInVehicleSeat(vehicle, i) == 0 then seat = i break end end
    if seat == -1 then TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_free_seats"), 'error', 4000) return end
    
    SetPedIntoVehicle(admin, vehicle, seat)
    TriggerClientEvent('QBCore:Notify', src, Lang:t("success.entered_vehicle"), 'success', 5000)
end)

RegisterNetEvent('qb-admin:server:kick', function(player, reason)
    local src = source
    local target = player.id
    
    if not (QBCore.Functions.HasPermission(src, permissions['kick']) or IsPlayerAceAllowed(src, 'command')) then return end
    if PermOrder(QBCore.Functions.GetPermission(src)) > PermOrder(QBCore.Functions.GetPermission(target)) then return end
    
    TriggerEvent('qb-log:server:CreateLog', 'bans', 'Player Kicked', 'red', string.format('%s was kicked by %s for %s', GetPlayerName(target), GetPlayerName(src), reason), true)
    DropPlayer(target, Lang:t("info.kicked_server") .. ':\n' .. reason .. '\n\n' .. Lang:t("info.check_discord") .. QBCore.Config.Server.discord)
end)

RegisterNetEvent('qb-admin:server:ban', function(player, time, reason)
    local src = source
    local target = player.id
    local banTime = tonumber(os.time() + tonumber(time))
    if banTime > 2147483647 then banTime = 2147483647 end
    local timeTable = os.date('*t', banTime)
    
    if not (QBCore.Functions.HasPermission(src, permissions['ban']) or IsPlayerAceAllowed(src, 'command')) then return end
    if PermOrder(QBCore.Functions.GetPermission(src)) > PermOrder(QBCore.Functions.GetPermission(target)) then return end

    MySQL.Async.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        GetPlayerName(target),
        QBCore.Functions.GetIdentifier(target, 'license'),
        QBCore.Functions.GetIdentifier(target, 'discord'),
        QBCore.Functions.GetIdentifier(target, 'ip'),
        reason,
        banTime,
        GetPlayerName(src)
    })
    TriggerClientEvent('chat:addMessage', -1, {
        template = "<div class=chat-message server'><strong>ANNOUNCEMENT | {0} has been banned:</strong> {1}</div>",
        args = {GetPlayerName(target), reason}
    })
    TriggerEvent('qb-log:server:CreateLog', 'bans', 'Player Banned', 'red', string.format('%s was banned by %s for %s', GetPlayerName(target), GetPlayerName(src), reason), true)
    if banTime >= 2147483647 then
        DropPlayer(target, Lang:t("info.banned") .. '\n' .. reason .. Lang:t("info.ban_perm") .. QBCore.Config.Server.discord)
    else
        DropPlayer(target, Lang:t("info.banned") .. '\n' .. reason .. Lang:t("info.ban_expires") .. timeTable['day'] .. '/' .. timeTable['month'] .. '/' .. timeTable['year'] .. ' ' .. timeTable['hour'] .. ':' .. timeTable['min'] .. '\n🔸 Check our Discord for more information: ' .. QBCore.Config.Server.discord)
    end
end)

RegisterNetEvent('qb-admin:server:setPermissions', function(targetId, group)
    local src = source

    if not (QBCore.Functions.HasPermission(src, permissions['setPermissions']) or IsPlayerAceAllowed(src, 'command')) then return end
    if PermOrder(QBCore.Functions.GetPermission(src)) > PermOrder(group[1].rank) then return end

    QBCore.Functions.AddPermission(targetId, group[1].rank)
    TriggerClientEvent('QBCore:Notify', targetId, Lang:t("info.rank_level")..group[1].label)
    TriggerClientEvent('QBCore:Notify', src, Lang:t("success.changed_perm")..' : '..group[1].label)
end)

RegisterNetEvent('qb-admin:server:cloth', function(player)
    local src = source

    if not (QBCore.Functions.HasPermission(src, permissions['cloth']) or IsPlayerAceAllowed(src, 'command')) then return end

    TriggerClientEvent('qb-clothing:client:openMenu', player.id)
end)

RegisterNetEvent('qb-admin:server:spawnVehicle', function(model)
    local src = source
    local hash = GetHashKey(model)
    local player = GetPlayerPed(src)
    local coords = GetEntityCoords(player)
    local heading = GetEntityHeading(player)
    local vehicle = GetVehiclePedIsIn(player, false)

    if not (QBCore.Functions.HasPermission(src, permissions['spawnVehicle']) or IsPlayerAceAllowed(src, 'command')) then return end
    if vehicle ~= 0 then DeleteEntity(vehicle) end

    local vehicle = CreateVehicle(hash, coords, true, true)
    while not DoesEntityExist(vehicle) do
        Wait(100)
    end
    SetEntityHeading(vehicle, heading)
    TaskWarpPedIntoVehicle(player, vehicle, -1)
    TriggerClientEvent('vehiclekeys:client:SetOwner', src, GetVehicleNumberPlateText(vehicle))
end)

RegisterNetEvent('qb-admin:server:SaveCar', function(mods, vehicle, hash, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local result = MySQL.Sync.fetchAll('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
    
    if result[1] ~= nil then TriggerClientEvent('QBCore:Notify', src, Lang:t("error.failed_vehicle_owner"), 'error', 3000) return end
    if not (QBCore.Functions.HasPermission(src, permissions['savecar']) or IsPlayerAceAllowed(src, 'command')) then return end
    
    MySQL.Async.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        vehicle.model,
        vehicle.hash,
        json.encode(mods),
        plate,
        0
    })
    TriggerClientEvent('QBCore:Notify', src, Lang:t("success.success_vehicle_owner"), 'success', 5000)
end)

RegisterNetEvent('qb-admin:server:getsounds', function()
    local src = source
    local path = GetResourcePath(SoundScriptName)
    path = path:gsub('//', '/')..SoundPath
    local Files = scandir(path)
    
    if not (QBCore.Functions.HasPermission(src, permissions['savecar']) or IsPlayerAceAllowed(src, 'command')) then return end
    
    TriggerClientEvent('qb-admin:client:getsounds', src, Files)
end)

RegisterNetEvent('qb-admin:server:SendReport', function(name, targetSrc, msg)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
        if QBCore.Functions.IsOptin(src) then
            TriggerClientEvent('chat:addMessage', src, {
                color = {255, 0, 0},
                multiline = true,
                args = {Lang:t("info.admin_report")..name..' ('..targetSrc..')', msg}
            })
        end
    end
end)

RegisterNetEvent('qb-admin:server:Staffchat:addMessage', function(name, msg)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
        if QBCore.Functions.IsOptin(src) then
            TriggerClientEvent('chat:addMessage', src, Lang:t("info.staffchat")..name, 'error', msg)
        end
    end
end)

RegisterNetEvent('qb-admin:server:playsound', function(target, soundname, soundvolume, soundradius)
    local src = source

    if not (QBCore.Functions.HasPermission(src, permissions['playsound']) or IsPlayerAceAllowed(src, 'command')) then return end

    TriggerClientEvent('qb-admin:client:playsound', target, soundname, soundvolume, soundradius)
end)

RegisterNetEvent('qb-admin:server:playsound', function(target, soundname, soundvolume, soundradius)
    local src = source

    if not (QBCore.Functions.HasPermission(src, permissions['usemenu']) or IsPlayerAceAllowed(src, 'command')) then return end

    DropPlayer(src, Lang:t("info.dropped"))
end)

QBCore.Functions.CreateCallback('qb-adminmenu:callback:getdealers', function(source, cb)
    cb(exports['qb-drugs']:GetDealers())
end)

QBCore.Functions.CreateCallback('qb-adminmenu:callback:getplayers', function(source, cb)
    local players = {}
    for k, v in pairs(QBCore.Functions.GetPlayers()) do
        local targetped = GetPlayerPed(v)
        local ped = QBCore.Functions.GetPlayer(v)
        players[#players+1] = {
            name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname .. ' | (' .. GetPlayerName(v) .. ')',
            id = v,
            coords = GetEntityCoords(targetped),
            cid = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
            citizenid = ped.PlayerData.citizenid,
            sources = GetPlayerPed(ped.PlayerData.source),
            sourceplayer= ped.PlayerData.source

        }
    end
        -- Sort players list by source ID (1,2,3,4,5, etc) --
        table.sort(players, function(a, b)
            return a.id < b.id
        end)
        ------
    cb(players)
end)

QBCore.Functions.CreateCallback('qb-adminmenu:callback:haspermission', function(source, cb)
    local src = source
    if QBCore.Functions.HasPermission(src, 'admin') or IsPlayerAceAllowed(src, 'command') then
        cb(true)
    else
        cb(false)
    end
end)
