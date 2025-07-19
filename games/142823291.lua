local Venyx = shared.Venyx.instance

if not Venyx then
    return
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localplayer = Players.LocalPlayer
local claimedCoins = {}
local lastMap = nil
local coinAutoCollect = false
local espEnabled = false
local espHighlights = {}

local shootOffset = 0.2
local offsetToPingMult = 1.05

local utility = {}
local themes = {}
local objects = {}

function utility:DraggingEnabled(frame, parent)
    parent = parent or frame
    local dragging = false
    local dragInput, mousePos, framePos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = parent.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            parent.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

function utility:DraggingEnded(callback)
    UserInputService.InputEnded:Connect(function(inputObj)
        if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
            callback()
        end
    end)
end

function utility:Find(tbl, value)
    for k, v in pairs(tbl) do
        if v == value then
            return k
        end
    end
    return nil
end

function utility:Create(instance, properties, children)
    local object = Instance.new(instance)

    for i, v in pairs(properties or {}) do
        object[i] = v

        if typeof(v) == "Color3" then
            local theme = utility:Find(themes, v)

            if theme then
                objects[theme] = objects[theme] or {}
                objects[theme][i] = objects[theme][i] or setmetatable({}, {__mode = "k"})

                table.insert(objects[theme][i], object)
            end
        end
    end

    for i, module in pairs(children or {}) do
        module.Parent = object
    end

    return object
end

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
		pcall(function()
			player = player.Character
			if not player.Character then Venyx("Venyx", "No player to predict position", 3) return end
		end)
		local playerHRP = player:FindFirstChild("UpperTorso")
		local playerHum = player:FindFirstChild("Humanoid")
		if not playerHRP or not playerHum then
			return Vector3.new(0,0,0), "Could not find the player's HumanoidRootPart."
		end

		local playerPosition = playerHRP.Position
		local velocity = Vector3.new()
		velocity = playerHRP.AssemblyLinearVelocity
		local playerMoveDirection = playerHum.MoveDirection
		local playerLookVec = playerHRP.CFrame.LookVector
		local yVelFactor = velocity.Y > 0 and -1 or 0.5
		local predictedPosition
		predictedPosition = playerHRP.Position + ((velocity * Vector3.new(0, 0.5, 0))) * (shootOffset / 15) +playerMoveDirection * shootOffset
		predictedPosition = predictedPosition * (((localplayer:GetNetworkPing() * 1000) * ((offsetToPingMult - 1) * 0.01)) + 1)

		return predictedPosition
	end

local function updatePlayerESP(player)
    local character = player.Character
    local highlight = espHighlights[player]

    if not character or not espEnabled then
        if highlight then
            highlight.Parent = nil
        end
        return
    end

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "Venyx_ESP_Highlight"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.OutlineTransparency = 0
        highlight.FillTransparency = 0.5
        espHighlights[player] = highlight
    end

    local role = getPlayerRole(player)
    if role == "Murderer" then
        highlight.FillColor = Color3.fromRGB(255, 25, 25)
        highlight.OutlineColor = Color3.fromRGB(255, 25, 25)
    elseif role == "Sheriff" then
        highlight.FillColor = Color3.fromRGB(25, 118, 210)
        highlight.OutlineColor = Color3.fromRGB(25, 118, 210)
    else
        highlight.FillColor = Color3.fromRGB(0, 200, 83)
        highlight.OutlineColor = Color3.fromRGB(0, 200, 83)
    end

    highlight.Parent = character
end

local activeTween = nil

task.spawn(function()
    while task.wait(0.05) do
        if not coinAutoCollect then 
            if activeTween then
                activeTween:Cancel()
                activeTween = nil
            end
            continue 
        end
        
        local currentMap = getMap()
        if currentMap then
            if lastMap ~= currentMap then
                lastMap = currentMap
                claimedCoins = {}
                if activeTween then
                    activeTween:Cancel()
                    activeTween = nil
                end
            end

            local coinContainer = currentMap:FindFirstChild("CoinContainer")
            if coinContainer and #coinContainer:GetChildren() > 1 then
                local character = localplayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                local closestCoin = getClosestModelToPlayer(localplayer, coinContainer:GetChildren())
                if closestCoin and not claimedCoins[closestCoin] then
                    local distance = (hrp.Position - closestCoin.Position).Magnitude
                    
                    if not activeTween or activeTween.PlaybackState == Enum.PlaybackState.Completed then
                        local tweenSpeed = math.max(distance * 0.02, 0.1)
                        activeTween = TweenService:Create(hrp, TweenInfo.new(
                            tweenSpeed,
                            Enum.EasingStyle.Quart,
                            Enum.EasingDirection.Out
                        ), {
                            CFrame = CFrame.new(closestCoin.Position)
                        })
                        
                        activeTween:Play()
                        
                        claimedCoins[closestCoin] = true
                        
                        activeTween.Completed:Connect(function()
                            if activeTween then
                                activeTween = nil
                            end
                        end)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if not espEnabled then continue end
        for _, player in ipairs(Players:GetPlayers()) do
            updatePlayerESP(player)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if espHighlights[player] then
        espHighlights[player]:Destroy()
        espHighlights[player] = nil
    end
end)

local mm2Tab = Venyx:addTab("Main")

local combatSection = mm2Tab:addSection("Combat")
local automationSection = mm2Tab:addSection("Automation")
local visualsSection = mm2Tab:addSection("Visuals")

combatSection:addButton("Shoot", function()
    local target
    local localRole = getPlayerRole(localplayer)

    if localRole == "Sheriff" then
        target = findRole("Murderer")
    elseif localRole == "Murderer" then
        target = findRole("Sheriff")
    else
        Venyx:Notify("Venyx", "You are not the Sheriff or Murderer.", 5)
        return
    end

    if not target then
        Venyx:Notify("Venyx", "No valid target found.", 5)
        return
    end

    if not localplayer.Character or not localplayer.Character:FindFirstChild("Gun") then
        local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
        local backpack = localplayer:FindFirstChildOfClass("Backpack")
        if hum and backpack and backpack:FindFirstChild("Gun") then
            hum:EquipTool(backpack:FindFirstChild("Gun"))
            task.wait(0.1)
        else
            Venyx:Notify("Venyx", "You don't have the gun.", 5)
            return
        end
    end

    local gun = localplayer.Character:FindFirstChild("Gun")
    if not gun or not gun:FindFirstChild("KnifeLocal") or not gun.KnifeLocal:FindFirstChild("CreateBeam") then
        Venyx:Notify("Venyx", "Gun structure not found.", 5)
        return
    end

    local targetHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then
        Venyx:Notify("Venyx", "Could not find the target's HumanoidRootPart.", 5)
        return
    end

    local predictedPosition = getPredictedPosition(target, shootOffset)

    pcall(function()
        gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, predictedPosition, "AH2")
    end)
end)

combatSection:addButton("Kill All (Murderer)", function()
    if getPlayerRole(localplayer) ~= "Murderer" then
        Venyx:Notify("Venyx", "You are not the Murderer.", 5)
        return
    end

    if not localplayer.Character or not localplayer.Character:FindFirstChild("Knife") then
        local hum = localplayer.Character and localplayer.Character:FindFirstChildOfClass("Humanoid")
        local backpack = localplayer:FindFirstChildOfClass("Backpack")
        if hum and backpack and backpack:FindFirstChild("Knife") then
            hum:EquipTool(backpack:FindFirstChild("Knife"))
            task.wait(0.1)
        else
            Venyx:Notify("Venyx", "You don't have the knife.", 5)
            return
        end
    end

    local knife = localplayer.Character:FindFirstChild("Knife")
    if not knife or not knife:FindFirstChild("Stab") then
        Venyx:Notify("Venyx", "Knife structure not found.", 5)
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
        Venyx:Notify("Venyx", "Coin collection enabled.", 3)
    else
        Venyx:Notify("Venyx", "Coin collection disabled.", 3)
    end
end)

visualsSection:addToggle("Player ESP", false, function(value)
    espEnabled = value
    if value then
        Venyx:Notify("Venyx", "ESP enabled.", 3)
        for _, player in ipairs(Players:GetPlayers()) do
            updatePlayerESP(player)
        end
    else
        Venyx:Notify("Venyx", "ESP disabled.", 3)
        for player, highlight in pairs(espHighlights) do
            if highlight then
                highlight:Destroy()
            end
        end
        espHighlights = {}
    end
end)