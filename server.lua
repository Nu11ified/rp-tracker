local json = {
  encode = function(tbl) return json.encode(tbl) end,
  decode = function(str) return json.decode(str) end
}

local activeRPs = {}
local rpQueue = {}
local cooldowns = {}
local nextRPID = 1

local Config = Config or {}

-- Load data from JSON
local function loadData()
    local file = io.open(Config.DataFile, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local data = json.decode(content)
        if data then
            rpQueue = data.rpQueue or {}
            activeRPs = data.activeRPs or {}
            cooldowns = data.cooldowns or {}
            nextRPID = data.nextRPID or 1
        end
    else
        -- File does not exist, create empty
        saveData()
    end
end

-- Save data to JSON
function saveData()
    local data = {
        rpQueue = rpQueue,
        activeRPs = activeRPs,
        cooldowns = cooldowns,
        nextRPID = nextRPID
    }
    local file = io.open(Config.DataFile, "w+")
    if file then
        file:write(json.encode(data))
        file:close()
    else
        print("[RPQueue] Could not save data to file.")
    end
end

local function getPlayerIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)
    for _,id in pairs(identifiers) do
        if string.sub(id, 1, string.len("license:")) == "license:" then
            return id
        end
    end
    return nil
end

local function isOnCooldown(identifier)
    local now = os.time()
    local ends = cooldowns[identifier]
    if ends and now < ends then
        return true, ends - now
    end
    return false, 0
end

local function setCooldownForParticipants(participants)
    local ends = os.time() + Config.CooldownTime
    for _,ident in ipairs(participants) do
        cooldowns[ident] = ends
    end
    saveData()
end

local function sendChatMessage(source, msg)
    TriggerClientEvent('chat:addMessage', source, {color={255,255,0}, multiline=true, args={"RP Queue", msg}})
end

local function canStartNewRP()
    return #activeRPs < Config.MaxActiveRPs
end

local function findRPInQueueById(rpID)
    for i, rp in ipairs(rpQueue) do
        if rp.id == rpID then
            return i, rp
        end
    end
    return nil, nil
end

local function findActiveRPById(rpID)
    for i, rp in ipairs(activeRPs) do
        if rp.id == rpID then
            return i, rp
        end
    end
    return nil, nil
end

local function regionIsValid(region)
    for _,r in ipairs(Config.AllowedRegions) do
        if r:lower() == region:lower() then
            return true
        end
    end
    return false
end

-- Command: Request an RP
RegisterCommand("requestRP", function(source, args)
    if #args < 3 then
        sendChatMessage(source, "Usage: /requestRP <title> <description> <region>")
        return
    end

    local identifier = getPlayerIdentifier(source)
    if not identifier then
        sendChatMessage(source, "Identifier not found. Cannot request RP.")
        return
    end

    local onCD, secsLeft = isOnCooldown(identifier)
    if onCD then
        sendChatMessage(source, string.format("You are on cooldown for another %d seconds.", secsLeft))
        return
    end

    local title = args[1]
    local desc = args[2]
    local region = args[3]

    if #title > Config.MaxTitleLength then
        sendChatMessage(source, "Title is too long.")
        return
    end

    if #desc > Config.MaxDescriptionLength then
        sendChatMessage(source, "Description is too long.")
        return
    end

    if not regionIsValid(region) then
        sendChatMessage(source, "Invalid region. Allowed regions: " .. table.concat(Config.AllowedRegions, ", "))
        return
    end

    local newRP = {
        id = nextRPID,
        requestor = identifier,
        title = title,
        desc = desc,
        region = region,
        participants = {identifier},
        requestorSrc = source
    }

    table.insert(rpQueue, newRP)
    nextRPID = nextRPID + 1
    saveData()

    sendChatMessage(source, string.format("Your RP request has been submitted with ID %d.", newRP.id))
end, false)

-- Command: Join an RP from the queue
RegisterCommand("joinRP", function(source, args)
    if #args < 1 then
        sendChatMessage(source, "Usage: /joinRP <RP_ID>")
        return
    end

    local rpID = tonumber(args[1])
    if not rpID then
        sendChatMessage(source, "Invalid RP ID.")
        return
    end

    local identifier = getPlayerIdentifier(source)
    if not identifier then
        sendChatMessage(source, "Identifier not found. Cannot join RP.")
        return
    end

    local onCD, secsLeft = isOnCooldown(identifier)
    if onCD then
        sendChatMessage(source, string.format("You are on cooldown for another %d seconds.", secsLeft))
        return
    end

    local idx, rp = findRPInQueueById(rpID)
    if not rp then
        sendChatMessage(source, "No such RP request in the queue.")
        return
    end

    -- Check if already in participants
    for _, part in ipairs(rp.participants) do
        if part == identifier then
            sendChatMessage(source, "You are already part of this RP request.")
            return
        end
    end

    table.insert(rp.participants, identifier)
    saveData()
    sendChatMessage(source, string.format("You joined RP request %d successfully.", rpID))
end, false)

-- Management commands (require ace perms)
RegisterCommand("rpQueue", function(source, args)
    if not IsPlayerAceAllowed(source, Config.ManageQueueAce) then
        sendChatMessage(source, "You do not have permission to manage the RP queue.")
        return
    end

    sendChatMessage(source, "----- RP Queue -----")
    if #rpQueue == 0 then
        sendChatMessage(source, "No RPs in queue.")
    else
        for _,rp in ipairs(rpQueue) do
            sendChatMessage(source, string.format("ID: %d | Title: %s | Region: %s | Participants: %d", rp.id, rp.title, rp.region, #rp.participants))
        end
    end

    sendChatMessage(source, "----- Active RPs -----")
    if #activeRPs == 0 then
        sendChatMessage(source, "No active RPs.")
    else
        for _,rp in ipairs(activeRPs) do
            local activeTime = os.time() - (rp.startTime or os.time())
            sendChatMessage(source, string.format("ID: %d | Title: %s | Region: %s | Participants: %d | Active for %d sec", rp.id, rp.title, rp.region, #rp.participants, activeTime))
        end
    end
end, false)

RegisterCommand("startRP", function(source, args)
    if not IsPlayerAceAllowed(source, Config.ManageQueueAce) then
        sendChatMessage(source, "You do not have permission to start an RP.")
        return
    end

    if #args < 1 then
        sendChatMessage(source, "Usage: /startRP <RP_ID>")
        return
    end

    local rpID = tonumber(args[1])
    if not rpID then
        sendChatMessage(source, "Invalid RP ID.")
        return
    end

    if not canStartNewRP() then
        sendChatMessage(source, "Maximum number of active RPs already running.")
        return
    end

    local idx, rp = findRPInQueueById(rpID)
    if not rp then
        sendChatMessage(source, "No such RP in the queue.")
        return
    end

    -- Move from queue to active
    table.remove(rpQueue, idx)
    local activeEntry = {
        id = rp.id,
        title = rp.title,
        desc = rp.desc,
        region = rp.region,
        participants = rp.participants,
        startTime = os.time()
    }
    table.insert(activeRPs, activeEntry)
    saveData()

    -- Notify all participants that their RP has started
    for _,ident in ipairs(rp.participants) do
        for _, playerId in ipairs(GetPlayers()) do
            local pid = getPlayerIdentifier(playerId)
            if pid == ident then
                sendChatMessage(playerId, string.format("Your RP (ID: %d) titled '%s' is starting now!", rp.id, rp.title))
            end
        end
    end

    sendChatMessage(source, string.format("RP %d has started.", rp.id))
end, false)

RegisterCommand("endRP", function(source, args)
    if not IsPlayerAceAllowed(source, Config.ManageQueueAce) then
        sendChatMessage(source, "You do not have permission to end an RP.")
        return
    end

    if #args < 1 then
        sendChatMessage(source, "Usage: /endRP <RP_ID>")
        return
    end

    local rpID = tonumber(args[1])
    if not rpID then
        sendChatMessage(source, "Invalid RP ID.")
        return
    end

    local idx, rp = findActiveRPById(rpID)
    if not rp then
        sendChatMessage(source, "No such active RP.")
        return
    end

    -- Set cooldown for all participants
    setCooldownForParticipants(rp.participants)

    -- Notify participants that RP has ended
    for _,ident in ipairs(rp.participants) do
        for _, playerId in ipairs(GetPlayers()) do
            local pid = getPlayerIdentifier(playerId)
            if pid == ident then
                sendChatMessage(playerId, string.format("RP %d has ended. You are now on cooldown.", rpID))
            end
        end
    end

    table.remove(activeRPs, idx)
    saveData()
    sendChatMessage(source, string.format("RP %d has been ended and participants placed on cooldown.", rpID))
end, false)

-- Command: Reset all cooldowns (for admins)
RegisterCommand("rpResetCooldowns", function(source, args)
    if not IsPlayerAceAllowed(source, Config.ManageQueueAce) then
        sendChatMessage(source, "You do not have permission.")
        return
    end
    cooldowns = {}
    saveData()
    sendChatMessage(source, "All cooldowns have been reset.")
end, false)

-- Command: Reload Data
RegisterCommand("rpReloadData", function(source, args)
    if not IsPlayerAceAllowed(source, Config.ManageQueueAce) then
        sendChatMessage(source, "You do not have permission.")
        return
    end
    loadData()
    sendChatMessage(source, "Data reloaded from file.")
end, false)

-- Command: Open UI (for admins)
RegisterCommand("rpui", function(source, args)
    if not IsPlayerAceAllowed(source, Config.ManageQueueAce) then
        sendChatMessage(source, "You do not have permission.")
        return
    end
    TriggerClientEvent("rpQueue:openUI", source)
end, false)

-- NUI Callbacks
RegisterNetEvent("rpQueue:requestData")
AddEventHandler("rpQueue:requestData", function()
    local src = source
    if not IsPlayerAceAllowed(src, Config.ManageQueueAce) then
        TriggerClientEvent("rpQueue:noPermission", src)
        return
    end

    TriggerClientEvent("rpQueue:updateData", src, rpQueue, activeRPs)
end)

RegisterNetEvent("rpQueue:startRP")
AddEventHandler("rpQueue:startRP", function(rpID)
    local src = source
    if not IsPlayerAceAllowed(src, Config.ManageQueueAce) then
        return
    end

    if not canStartNewRP() then
        TriggerClientEvent("rpQueue:notify", src, "Maximum active RPs reached.")
        return
    end

    local idx, rp = findRPInQueueById(rpID)
    if not rp then
        TriggerClientEvent("rpQueue:notify", src, "No such RP in queue.")
        return
    end

    table.remove(rpQueue, idx)
    local activeEntry = {
        id = rp.id,
        title = rp.title,
        desc = rp.desc,
        region = rp.region,
        participants = rp.participants,
        startTime = os.time()
    }
    table.insert(activeRPs, activeEntry)
    saveData()

    for _,ident in ipairs(rp.participants) do
        for _, playerId in ipairs(GetPlayers()) do
            local pid = getPlayerIdentifier(playerId)
            if pid == ident then
                sendChatMessage(playerId, string.format("Your RP (ID: %d, '%s') is starting now!", rp.id, rp.title))
            end
        end
    end

    TriggerClientEvent("rpQueue:updateData", src, rpQueue, activeRPs)
    TriggerClientEvent("rpQueue:notify", src, "RP started.")
end)

RegisterNetEvent("rpQueue:endRP")
AddEventHandler("rpQueue:endRP", function(rpID)
    local src = source
    if not IsPlayerAceAllowed(src, Config.ManageQueueAce) then
        return
    end

    local idx, rp = findActiveRPById(rpID)
    if not rp then
        TriggerClientEvent("rpQueue:notify", src, "No such active RP.")
        return
    end

    setCooldownForParticipants(rp.participants)

    for _,ident in ipairs(rp.participants) do
        for _, playerId in ipairs(GetPlayers()) do
            local pid = getPlayerIdentifier(playerId)
            if pid == ident then
                sendChatMessage(playerId, string.format("RP %d ended. You are now on cooldown.", rpID))
            end
        end
    end

    table.remove(activeRPs, idx)
    saveData()

    TriggerClientEvent("rpQueue:updateData", src, rpQueue, activeRPs)
    TriggerClientEvent("rpQueue:notify", src, "RP ended and participants on cooldown.")
end)

-- On resource start, load data
CreateThread(function()
    loadData()
    print("[RPQueue] Data loaded.")
end)
