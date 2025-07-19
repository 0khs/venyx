local Venyx = shared.Venyx.instance

if not Venyx then
    return
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localplayer = Players.LocalPlayer
local claimedCoins = {}
local coinAutoCollect = false
local shootOffset = 0.2
local offsetToPingMult = 1.05

local function playerHasTool(player, toolName)
    if not player then return false end
    local character = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    return (backpack and backpack:FindFirstChild(toolName)) or (character and character:FindFirstChild(toolName))
end

local function getPlayerRole(player)
    if not player or not player.Character then return "Innocent" end
    if playerHasTool(player, "Knife") then
        return "Murderer"
    end
    if playerHasTool(player, "Gun") then
        return "Sheriff"
    end
    return "Innocent"
end

local function findRole(role)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localplayer and getPlayerRole(player) == role then
            return player
        end
    end
    return nil
end

local function getMap()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("CoinContainer") and obj:FindFirstChild("Spawns") then
            return obj
        end
    end
    return nil
end

local function getClosestModelToPlayer(player, models)
    local closestModel = nil
    local shortestDistance = math.huge
    local playerHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

    if not playerHRP then return nil end

    for _, model in ipairs(models) do
        if model:IsA("BasePart") and not claimedCoins[model] then
            local distance = (playerHRP.Position - model.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestModel = model
            end
        end
    end
    return closestModel
end

local function getPredictedPosition(player, shootOffset)
    local char = player.Character
    if not char then 
        Venyx:Notify("Error", "No character to predict position.", 5)
        return 
    end

    local playerHRP = char:FindFirstChild("UpperTorso")
    local playerHum = char:FindFirstChild("Humanoid")
    if not playerHRP or not playerHum then
        return Vector3.new(0,0,0)
    end

    local playerPosition = playerHRP.Position
    local velocity = playerHRP.AssemblyLinearVelocity
    local playerMoveDirection = playerHum.MoveDirection
    
    local predictedPosition = playerHRP.Position + ((velocity * Vector3.new(0, 0.5, 0))) * (shootOffset / 15) + playerMoveDirection * shootOffset
    predictedPosition = predictedPosition * (((localplayer:GetNetworkPing() * 1000) * ((offsetToPingMult - 1) * 0.01)) + 1)
    
    return predictedPosition
end

task.spawn(function()
    while task.wait(0.1) do
        if not coinAutoCollect then continue end
        local currentMap = getMap()
        if currentMap and currentMap:FindFirstChild("CoinContainer") and #currentMap:FindFirstChild("CoinContainer"):GetChildren() > 1 then
            local character = localplayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            
            local closestCoin = getClosestModelToPlayer(localplayer, currentMap:FindFirstChild("CoinContainer"):GetChildren())
            if closestCoin then
                local distance = (hrp.Position - closestCoin.Position).Magnitude
                local toclosestcoin = TweenService:Create(hrp, TweenInfo.new(distance * 0.05, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(closestCoin.Position)
                })
                toclosestcoin:Play()
                toclosestcoin.Completed:Wait()
                task.wait(0.1)
                claimedCoins[closestCoin] = true
            end
        end
    end
end)


local mm2Tab = Venyx:addTab("MM2")

local combatSection = mm2Tab:addSection("Combat")
local automationSection = mm2Tab:addSection("Automation")
local funSection = mm2Tab:addSection("Fun")

combatSection:addButton("Shoot Target", function()
    local target
    local localRole = getPlayerRole(localplayer)

    if localRole == "Sheriff" then
        target = findRole("Murderer")
    elseif localRole == "Murderer" then
        target = findRole("Sheriff")
    else
        Venyx:Notify("Info", "You are not the Sheriff or Murderer.", 5)
        return
    end

    if not target then
        Venyx:Notify("Info", "No valid target found.", 5)
        return
    end

    if not localplayer.Character or not localplayer.Character:FindFirstChild("Gun") then
        local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
        local backpack = localplayer:FindFirstChildOfClass("Backpack")
        if hum and backpack and backpack:FindFirstChild("Gun") then
            hum:EquipTool(backpack:FindFirstChild("Gun"))
            task.wait(0.1)
        else
            Venyx:Notify("Error", "You don't have the gun.", 5)
            return
        end
    end
    
    local gun = localplayer.Character:FindFirstChild("Gun")
    if not gun or not gun:FindFirstChild("KnifeLocal") or not gun.KnifeLocal:FindFirstChild("CreateBeam") then
        Venyx:Notify("Error", "Gun structure not found.", 5)
        return
    end

    local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then
        Venyx:Notify("Error", "Could not find the target's HumanoidRootPart.", 5)
        return
    end

    local predictedPosition = getPredictedPosition(target, shootOffset)
    
    pcall(function()
        gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, predictedPosition, "AH2")
    end)
end)

combatSection:addButton("Kill All (Murderer)", function()
    if getPlayerRole(localplayer) ~= "Murderer" then
        Venyx:Notify("Error", "You are not the Murderer.", 5)
        return
    end

    if not localplayer.Character or not localplayer.Character:FindFirstChild("Knife") then
        local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
        local backpack = localplayer:FindFirstChildOfClass("Backpack")
        if hum and backpack and backpack:FindFirstChild("Knife") then
            hum:EquipTool(backpack:FindFirstChild("Knife"))
            task.wait(0.1)
        else
            Venyx:Notify("Error", "You don't have the knife.", 5)
            return
        end
    end
    
    local knife = localplayer.Character:FindFirstChild("Knife")
    if not knife or not knife:FindFirstChild("Stab") then
        Venyx:Notify("Error", "Knife structure not found.", 5)
        return
    end

    local localHRP = localplayer.Character:FindFirstChild("HumanoidRootPart")
    if not localHRP then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localplayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP = player.Character.HumanoidRootPart
            targetHRP.Anchored = true
            targetHRP.CFrame = localHRP.CFrame + localHRP.CFrame.LookVector * 1
        end
    end
    
    task.wait(0.2)
    
    pcall(function()
        knife.Stab:FireServer("Slash")
    end)

    task.wait(0.5)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
             player.Character.HumanoidRootPart.Anchored = false
        end
    end
end)

automationSection:addToggle("Auto Collect Coins", false, function(value)
    coinAutoCollect = value
    if value then
        Venyx:Notify("Automation", "Coin collection enabled.", 3)
    else
        Venyx:Notify("Automation", "Coin collection disabled.", 3)
    end
end)
