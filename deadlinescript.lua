--[[
    VoidStar Enhanced ESP System
    Author: Venduli
    Version: 1.0
    

]]

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local workspace = game:GetService("Workspace")

-- Variables
local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer
local ESP = {}
local connections = {}

-- ESP Settings (defaults)
local ESPSettings = {
    Enabled = true,
    
    -- Box ESP
    BoxEnabled = true,
    BoxColor = Color3.fromRGB(255, 255, 255),
    BoxThickness = 1,
    BoxTransparency = 1,
    BoxFilled = false,
    
    -- Name ESP
    NameEnabled = true,
    NameColor = Color3.fromRGB(255, 255, 255),
    NameSize = 14,
    ShowDistance = true,
    
    -- Health Bar
    HealthBarEnabled = true,
    HealthBarColor = Color3.fromRGB(0, 255, 0),
    HealthBarBackground = Color3.fromRGB(255, 0, 0),
    
    -- Tracers
    TracersEnabled = true,
    TracersColor = Color3.fromRGB(255, 255, 255),
    TracersThickness = 1,
    TracersTransparency = 1,
    TracerPosition = "Bottom", -- "Top", "Middle", "Bottom"
    
    -- Skeleton
    SkeletonEnabled = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    SkeletonThickness = 1,
    
    -- Team Colors
    UseTeamColor = true,
    TeamCheck = true, -- Don't show ESP for teammates
    
    -- Look Direction
    LookDirectionEnabled = false,
    LookDirectionColor = Color3.fromRGB(255, 255, 0),
    LookDirectionLength = 3,
    
    -- Performance
    MaxDistance = 500, -- Max distance to show ESP
    UpdateRate = 0.05, -- Update delay (lower = more performance intensive)
}

-- Utility Functions
local function WorldToViewportPoint(position)
    local screenPos, onScreen = camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function GetTeamColor(model)
    local player = Players:GetPlayerFromCharacter(model)
    if player and player.Team then
        return player.Team.TeamColor.Color
    end
    return ESPSettings.BoxColor
end

local function IsTeammate(model)
    if not ESPSettings.TeamCheck then return false end
    
    local player = Players:GetPlayerFromCharacter(model)
    if player and localPlayer.Team and player.Team == localPlayer.Team then
        return true
    end
    return false
end

local function GetCharacterName(model)
    local player = Players:GetPlayerFromCharacter(model)
    if player then
        return player.Name
    end
    return model.Name
end

local function GetHealth(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth
    end
    return 100, 100
end

local function GetDistance(position)
    return math.floor((camera.CFrame.Position - position).Magnitude)
end

-- ESP Creation Functions
local function CreateDrawing(drawingType, properties)
    local drawing = Drawing.new(drawingType)
    for prop, value in pairs(properties) do
        pcall(function()
            drawing[prop] = value
        end)
    end
    return drawing
end

local function CreateESP(model)
    if not model or not model.Parent then return end
    if ESP[model] then return end
    if IsTeammate(model) then return end
    
    local drawings = {
        -- Box ESP
        box = CreateDrawing("Square", {
            Thickness = ESPSettings.BoxThickness,
            Color = ESPSettings.BoxColor,
            Transparency = ESPSettings.BoxTransparency,
            Filled = ESPSettings.BoxFilled,
            Visible = false
        }),
        
        -- Name ESP
        nameText = CreateDrawing("Text", {
            Text = GetCharacterName(model),
            Size = ESPSettings.NameSize,
            Color = ESPSettings.NameColor,
            Center = true,
            Outline = true,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Visible = false
        }),
        
        -- Distance Text
        distanceText = CreateDrawing("Text", {
            Text = "",
            Size = 12,
            Color = Color3.fromRGB(200, 200, 200),
            Center = true,
            Outline = true,
            OutlineColor = Color3.fromRGB(0, 0, 0),
            Visible = false
        }),
        
        -- Health Bar
        healthBarBackground = CreateDrawing("Square", {
            Thickness = 1,
            Color = ESPSettings.HealthBarBackground,
            Transparency = 1,
            Filled = true,
            Visible = false
        }),
        
        healthBar = CreateDrawing("Square", {
            Thickness = 1,
            Color = ESPSettings.HealthBarColor,
            Transparency = 1,
            Filled = true,
            Visible = false
        }),
        
        -- Tracer
        tracer = CreateDrawing("Line", {
            Thickness = ESPSettings.TracersThickness,
            Color = ESPSettings.TracersColor,
            Transparency = ESPSettings.TracersTransparency,
            Visible = false
        }),
        
        -- Skeleton parts
        skeleton = {},
        
        -- Look direction
        lookDirection = CreateDrawing("Line", {
            Thickness = 2,
            Color = ESPSettings.LookDirectionColor,
            Transparency = 1,
            Visible = false
        })
    }
    
    ESP[model] = drawings
end

local function UpdateESP()
    if not ESPSettings.Enabled then return end
    
    for model, drawings in pairs(ESP) do
        if not model or not model.Parent then
            -- Cleanup if model is destroyed
            for _, drawing in pairs(drawings) do
                if typeof(drawing) == "Instance" or type(drawing) == "userdata" then
                    pcall(function() drawing:Remove() end)
                elseif type(drawing) == "table" then
                    for _, skelePart in pairs(drawing) do
                        pcall(function() skelePart:Remove() end)
                    end
                end
            end
            ESP[model] = nil
            continue
        end
        
        local rootPart = model:FindFirstChild("humanoid_root_part") or model:FindFirstChild("HumanoidRootPart")
        
        if not rootPart then
            -- Hide all drawings
            drawings.box.Visible = false
            drawings.nameText.Visible = false
            drawings.distanceText.Visible = false
            drawings.healthBarBackground.Visible = false
            drawings.healthBar.Visible = false
            drawings.tracer.Visible = false
            drawings.lookDirection.Visible = false
            continue
        end
        
        local rootPos = rootPart.Position
        local distance = GetDistance(rootPos)
        
        -- Check max distance
        if distance > ESPSettings.MaxDistance then
            drawings.box.Visible = false
            drawings.nameText.Visible = false
            drawings.distanceText.Visible = false
            drawings.healthBarBackground.Visible = false
            drawings.healthBar.Visible = false
            drawings.tracer.Visible = false
            drawings.lookDirection.Visible = false
            continue
        end
        
        local screenPos, onScreen = WorldToViewportPoint(rootPos)
        
        if onScreen then
            -- Determine color (team color or custom)
            local espColor = ESPSettings.UseTeamColor and GetTeamColor(model) or ESPSettings.BoxColor
            
            -- Calculate box size
            local rootCFrame = rootPart.CFrame
            local upVectorY = rootCFrame.UpVector.Y
            local offset = Vector3.new(0, 3 * math.abs(upVectorY), 0)
            local topPos = WorldToViewportPoint(rootPos + offset)
            local bottomPos = WorldToViewportPoint(rootPos - offset)
            local height = math.abs(topPos.Y - bottomPos.Y)
            local width = height * 0.6
            
            -- Update Box ESP
            if ESPSettings.BoxEnabled then
                drawings.box.Size = Vector2.new(width, height)
                drawings.box.Position = Vector2.new(screenPos.X - width/2, screenPos.Y - height/2)
                drawings.box.Color = espColor
                drawings.box.Thickness = ESPSettings.BoxThickness
                drawings.box.Transparency = ESPSettings.BoxTransparency
                drawings.box.Filled = ESPSettings.BoxFilled
                drawings.box.Visible = true
            else
                drawings.box.Visible = false
            end
            
            -- Update Name ESP
            if ESPSettings.NameEnabled then
                drawings.nameText.Position = Vector2.new(screenPos.X, screenPos.Y - height/2 - 18)
                drawings.nameText.Color = espColor
                drawings.nameText.Size = ESPSettings.NameSize
                drawings.nameText.Visible = true
                
                if ESPSettings.ShowDistance then
                    drawings.distanceText.Text = tostring(distance) .. "m"
                    drawings.distanceText.Position = Vector2.new(screenPos.X, screenPos.Y - height/2 - 32)
                    drawings.distanceText.Visible = true
                else
                    drawings.distanceText.Visible = false
                end
            else
                drawings.nameText.Visible = false
                drawings.distanceText.Visible = false
            end
            
            -- Update Health Bar
            if ESPSettings.HealthBarEnabled then
                local health, maxHealth = GetHealth(model)
                local healthPercent = health / maxHealth
                
                local barWidth = 3
                local barHeight = height
                
                drawings.healthBarBackground.Size = Vector2.new(barWidth, barHeight)
                drawings.healthBarBackground.Position = Vector2.new(screenPos.X - width/2 - 6, screenPos.Y - height/2)
                drawings.healthBarBackground.Visible = true
                
                drawings.healthBar.Size = Vector2.new(barWidth, barHeight * healthPercent)
                drawings.healthBar.Position = Vector2.new(screenPos.X - width/2 - 6, screenPos.Y - height/2 + (barHeight * (1 - healthPercent)))
                drawings.healthBar.Color = Color3.fromRGB(
                    255 * (1 - healthPercent),
                    255 * healthPercent,
                    0
                )
                drawings.healthBar.Visible = true
            else
                drawings.healthBarBackground.Visible = false
                drawings.healthBar.Visible = false
            end
            
            -- Update Tracers
            if ESPSettings.TracersEnabled then
                local tracerStart
                if ESPSettings.TracerPosition == "Top" then
                    tracerStart = Vector2.new(camera.ViewportSize.X / 2, 0)
                elseif ESPSettings.TracerPosition == "Middle" then
                    tracerStart = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                else -- Bottom
                    tracerStart = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                end
                
                drawings.tracer.From = tracerStart
                drawings.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                drawings.tracer.Color = espColor
                drawings.tracer.Thickness = ESPSettings.TracersThickness
                drawings.tracer.Transparency = ESPSettings.TracersTransparency
                drawings.tracer.Visible = true
            else
                drawings.tracer.Visible = false
            end
            
            -- Update Look Direction
            if ESPSettings.LookDirectionEnabled then
                local lookVector = rootCFrame.LookVector * ESPSettings.LookDirectionLength
                local lookPos = WorldToViewportPoint(rootPos + lookVector)
                
                drawings.lookDirection.From = Vector2.new(screenPos.X, screenPos.Y)
                drawings.lookDirection.To = Vector2.new(lookPos.X, lookPos.Y)
                drawings.lookDirection.Color = ESPSettings.LookDirectionColor
                drawings.lookDirection.Visible = true
            else
                drawings.lookDirection.Visible = false
            end
            
        else
            -- Not on screen
            drawings.box.Visible = false
            drawings.nameText.Visible = false
            drawings.distanceText.Visible = false
            drawings.healthBarBackground.Visible = false
            drawings.healthBar.Visible = false
            drawings.tracer.Visible = false
            drawings.lookDirection.Visible = false
        end
    end
end

-- Main Update Loop
local lastUpdate = 0
connections.update = RunService.PreRender:Connect(function()
    local now = tick()
    if now - lastUpdate >= ESPSettings.UpdateRate then
        lastUpdate = now
        pcall(UpdateESP)
    end
end)

-- Character Detection
local function SetupCharacterDetection()
    local characters = workspace:FindFirstChild("characters")
    
    if characters then
        -- Add existing characters
        for _, model in ipairs(characters:GetChildren()) do
            task.spawn(function()
                task.wait(0.1)
                CreateESP(model)
            end)
        end
        
        -- Watch for new characters
        connections.characterAdded = characters.ChildAdded:Connect(function(model)
            task.wait(0.5)
            task.spawn(function()
                CreateESP(model)
            end)
        end)
        
        -- Cleanup removed characters
        connections.characterRemoved = characters.ChildRemoved:Connect(function(model)
            if ESP[model] then
                for _, drawing in pairs(ESP[model]) do
                    if typeof(drawing) == "Instance" or type(drawing) == "userdata" then
                        pcall(function() drawing:Remove() end)
                    elseif type(drawing) == "table" then
                        for _, skelePart in pairs(drawing) do
                            pcall(function() skelePart:Remove() end)
                        end
                    end
                end
                ESP[model] = nil
            end
        end)
    end
end

-- Cleanup Function
local function CleanupESP()
    -- Disconnect all connections
    for name, connection in pairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    connections = {}
    
    -- Remove all drawings
    for model, drawings in pairs(ESP) do
        for _, drawing in pairs(drawings) do
            if typeof(drawing) == "Instance" or type(drawing) == "userdata" then
                pcall(function() drawing:Remove() end)
            elseif type(drawing) == "table" then
                for _, skelePart in pairs(drawing) do
                    pcall(function() skelePart:Remove() end)
                end
            end
        end
    end
    ESP = {}
end

-- Rayfield UI Integration
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "VoidStar ESP System",
    Icon = "eye",
    LoadingTitle = "VoidStar ESP",
    LoadingSubtitle = "by Venduli",
    Theme = "DarkBlue",
    
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "VoidStar",
        FileName = "ESP_Config"
    },
    
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true
})

-- Main Tab
local MainTab = Window:CreateTab("ESP Settings", "eye")

-- Master Controls
MainTab:CreateSection("Master Controls")

local MasterToggle = MainTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = ESPSettings.Enabled,
    Flag = "ESP_Master",
    Callback = function(value)
        ESPSettings.Enabled = value
        if not value then
            for _, drawings in pairs(ESP) do
                for _, drawing in pairs(drawings) do
                    if typeof(drawing) == "Instance" or type(drawing) == "userdata" then
                        pcall(function() drawing.Visible = false end)
                    end
                end
            end
        end
    end
})

-- Box ESP Section
MainTab:CreateSection("Box ESP")

MainTab:CreateToggle({
    Name = "Enable Boxes",
    CurrentValue = ESPSettings.BoxEnabled,
    Flag = "ESP_Box",
    Callback = function(value)
        ESPSettings.BoxEnabled = value
    end
})

MainTab:CreateColorPicker({
    Name = "Box Color",
    Color = ESPSettings.BoxColor,
    Flag = "ESP_BoxColor",
    Callback = function(value)
        ESPSettings.BoxColor = value
    end
})

MainTab:CreateSlider({
    Name = "Box Thickness",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = ESPSettings.BoxThickness,
    Flag = "ESP_BoxThickness",
    Callback = function(value)
        ESPSettings.BoxThickness = value
    end
})

MainTab:CreateToggle({
    Name = "Filled Boxes",
    CurrentValue = ESPSettings.BoxFilled,
    Flag = "ESP_BoxFilled",
    Callback = function(value)
        ESPSettings.BoxFilled = value
    end
})

-- Name ESP Section
MainTab:CreateSection("Name ESP")

MainTab:CreateToggle({
    Name = "Show Names",
    CurrentValue = ESPSettings.NameEnabled,
    Flag = "ESP_Name",
    Callback = function(value)
        ESPSettings.NameEnabled = value
    end
})

MainTab:CreateToggle({
    Name = "Show Distance",
    CurrentValue = ESPSettings.ShowDistance,
    Flag = "ESP_Distance",
    Callback = function(value)
        ESPSettings.ShowDistance = value
    end
})

MainTab:CreateSlider({
    Name = "Name Size",
    Range = {10, 24},
    Increment = 1,
    CurrentValue = ESPSettings.NameSize,
    Flag = "ESP_NameSize",
    Callback = function(value)
        ESPSettings.NameSize = value
    end
})

-- Health Bar Section
MainTab:CreateSection("Health Bar")

MainTab:CreateToggle({
    Name = "Show Health Bar",
    CurrentValue = ESPSettings.HealthBarEnabled,
    Flag = "ESP_Health",
    Callback = function(value)
        ESPSettings.HealthBarEnabled = value
    end
})

-- Tracers Section
local TracersTab = Window:CreateTab("Tracers", "pointer")

TracersTab:CreateToggle({
    Name = "Enable Tracers",
    CurrentValue = ESPSettings.TracersEnabled,
    Flag = "ESP_Tracers",
    Callback = function(value)
        ESPSettings.TracersEnabled = value
    end
})

TracersTab:CreateColorPicker({
    Name = "Tracer Color",
    Color = ESPSettings.TracersColor,
    Flag = "ESP_TracerColor",
    Callback = function(value)
        ESPSettings.TracersColor = value
    end
})

TracersTab:CreateSlider({
    Name = "Tracer Thickness",
    Range = {1, 5},
    Increment = 1,
    CurrentValue = ESPSettings.TracersThickness,
    Flag = "ESP_TracerThickness",
    Callback = function(value)
        ESPSettings.TracersThickness = value
    end
})

TracersTab:CreateDropdown({
    Name = "Tracer Position",
    Options = {"Top", "Middle", "Bottom"},
    CurrentOption = {ESPSettings.TracerPosition},
    Flag = "ESP_TracerPos",
    Callback = function(value)
        ESPSettings.TracerPosition = value[1]
    end
})

-- Settings Tab
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("Team Options")

SettingsTab:CreateToggle({
    Name = "Use Team Colors",
    CurrentValue = ESPSettings.UseTeamColor,
    Flag = "ESP_TeamColor",
    Callback = function(value)
        ESPSettings.UseTeamColor = value
    end
})

SettingsTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = ESPSettings.TeamCheck,
    Flag = "ESP_TeamCheck",
    Callback = function(value)
        ESPSettings.TeamCheck = value
        -- Refresh ESP for all characters
        CleanupESP()
        SetupCharacterDetection()
    end
})

SettingsTab:CreateSection("Performance")

SettingsTab:CreateSlider({
    Name = "Max Distance",
    Range = {100, 1000},
    Increment = 50,
    Suffix = "studs",
    CurrentValue = ESPSettings.MaxDistance,
    Flag = "ESP_MaxDist",
    Callback = function(value)
        ESPSettings.MaxDistance = value
    end
})

SettingsTab:CreateSlider({
    Name = "Update Rate",
    Range = {0.01, 0.2},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = ESPSettings.UpdateRate,
    Flag = "ESP_UpdateRate",
    Callback = function(value)
        ESPSettings.UpdateRate = value
    end
})

SettingsTab:CreateSection("Actions")

SettingsTab:CreateButton({
    Name = "Reload ESP",
    Callback = function()
        CleanupESP()
        SetupCharacterDetection()
        Rayfield:Notify({
            Title = "ESP Reloaded",
            Content = "All ESP elements have been refreshed",
            Duration = 3,
            Image = "refresh-cw"
        })
    end
})

SettingsTab:CreateButton({
    Name = "Unload ESP",
    Callback = function()
        CleanupESP()
        Rayfield:Notify({
            Title = "ESP Unloaded",
            Content = "All ESP elements have been removed",
            Duration = 3,
            Image = "x-circle"
        })
    end
})

-- Initialize
SetupCharacterDetection()
Rayfield:LoadConfiguration()

-- Notify
Rayfield:Notify({
    Title = "VoidStar ESP",
    Content = "ESP System loaded successfully!",
    Duration = 5,
    Image = "check-circle"
})

print("VoidStar ESP System v1.0 loaded successfully!")
print("Author: Venduli")
print("Press K to toggle UI")

return {
    Cleanup = CleanupESP,
    Settings = ESPSettings,
    Reload = SetupCharacterDetection
}
