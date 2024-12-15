RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("startRP", function(data, cb)
    local rpID = data.rpID
    TriggerServerEvent("rpQueue:startRP", rpID) -- Inform the server to start the RP
    cb("ok")
end)

RegisterNUICallback("endRP", function(data, cb)
    local rpID = data.rpID
    TriggerServerEvent("rpQueue:endRP", rpID) -- Inform the server to end the RP
    cb("ok")
end)

RegisterNetEvent("rpQueue:openUI")
AddEventHandler("rpQueue:openUI", function()
    SetNuiFocus(true, true)
    SendNUIMessage({action = "show"})
    TriggerServerEvent("rpQueue:requestData")
end)

RegisterNetEvent("rpQueue:updateData")
AddEventHandler("rpQueue:updateData", function(queue, active)
    SendNUIMessage({
        action = "update",
        queue = queue,
        active = active
    })
end)

RegisterNetEvent("rpQueue:noPermission")
AddEventHandler("rpQueue:noPermission", function()
    SendNUIMessage({
        action = "noPermission"
    })
end)

RegisterNetEvent("rpQueue:notify")
AddEventHandler("rpQueue:notify", function(msg)
    TriggerEvent('chat:addMessage', {color={0,255,0}, args={"RP Queue", msg}})
end)
