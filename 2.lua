local Genv = getgenv()

Genv.Connections = Genv.Connections or {}
Genv.Desync = Genv.Desync or {}
Genv.XRayState = Genv.XRayState or {
    isProcessing = false,
    currentState = nil,
    batchConnection = nil
}

local GetService = game.GetService
local FindFirstChild = game.FindFirstChild
local FindFirstChildOfClass = game.FindFirstChildOfClass
local InstanceNew = Instance.new
local Color3FromRGB = Color3.fromRGB
local Vector3New = Vector3.new
local Vector2New = Vector2.new
local UDim2New = UDim2.new
local Destroy = game.Destroy
local CFrameNew = CFrame.new
local GetDescendants = game.GetDescendants

local Workspace = GetService(game, "Workspace")
local RunService = GetService(game, "RunService")
local Players = GetService(game, "Players")

local LocalPlayer = Players.LocalPlayer
local Desync = Genv.Desync
local XRayState = Genv.XRayState

local XRay = {}
local Utility = {}
local Connection = {}
local Desyncing = {}

local TeamColors = {
    Murderer = Color3FromRGB(255, 0, 0),
    Sheriff = Color3FromRGB(0, 0, 255)
}

local RayfieldLoaded, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not RayfieldLoaded or not Rayfield then
    warn("Rayfield加载失败，尝试备用源")
    RayfieldLoaded, Rayfield = pcall(function()
        return loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()
    end)
end

if not RayfieldLoaded or not Rayfield then
    warn("Rayfield加载失败:", Rayfield)
    return
end

local Window = Rayfield:CreateWindow({
   Name = "MM2",
   Icon = 0,
   LoadingTitle = "...",
   LoadingSubtitle = "MM2",
   ShowText = "MM2",
   Theme = "Default",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "Hub"
   },
})

local Flags = Rayfield.Flags

do
    local VisualsTab = Window:CreateTab("透视", "rewind")

    local PlayerESPSection = VisualsTab:CreateSection("人物透视")
    VisualsTab:CreateToggle({
        Name = "人物上色",
        CurrentValue = false,
        Flag = "Visuals/ESP/Chams",
        Callback = function(Value) end,
    })
    VisualsTab:CreateToggle({
        Name = "名字透视",
        CurrentValue = false,
        Flag = "Visuals/ESP/Name",
        Callback = function(Value) end,
    })

    local CoinsESPSection = VisualsTab:CreateSection("金币透视")
    VisualsTab:CreateToggle({
        Name = "金币透视",
        CurrentValue = false,
        Flag = "Visuals/ESP/Coins",
        Callback = function(Value) end,
    })

    local WorldSection = VisualsTab:CreateSection("地图透视")
    VisualsTab:CreateToggle({
        Name = "全图X光",
        CurrentValue = false,
        Flag = "Visuals/World/XRay",
        Callback = function(Value) end,
    })

    local MiscTab = Window:CreateTab("杂项", "rewind")

    local MovementSection = MiscTab:CreateSection("移动")
    MiscTab:CreateToggle({
        Name = "反甩飞",
        CurrentValue = false,
        Flag = "Misc/AntiFling",
        Callback = function(Value) end,
    })
    MiscTab:CreateToggle({
        Name = "自动触摸金币",
        CurrentValue = false,
        Flag = "Misc/AutoCoins",
        Callback = function(Value) end,
    })
    MiscTab:CreateToggle({
        Name = "隐身 (半无敌)",
        CurrentValue = false,
        Flag = "Misc/VoidHide",
        Callback = function(Value) end,
    })

    local CombatSection = MiscTab:CreateSection("战斗")
    MiscTab:CreateToggle({
        Name = "自动射击杀手",
        CurrentValue = false,
        Flag = "Combat/AutoShoot",
        Callback = function(Value) end,
    })
    MiscTab:CreateToggle({
        Name = "自动击杀光环",
        CurrentValue = false,
        Flag = "Combat/KillAura",
        Callback = function(Value) end,
    })
    MiscTab:CreateToggle({
        Name = "全图击杀",
        CurrentValue = false,
        Flag = "Combat/KillAll",
        Callback = function(Value) end,
    })
    MiscTab:CreateToggle({
        Name = "静默击杀",
        CurrentValue = false,
        Flag = "Combat/SilentAura",
        Callback = function(Value) end,
    })
    MiscTab:CreateSlider({
        Name = "光环范围",
        Range = {3, 20},
        Increment = 1,
        CurrentValue = 10,
        Flag = "Combat/AuraRange",
        Callback = function(Value) end,
    })
end

do
    function Utility:Create(ClassName, Properties)
        local Object = InstanceNew(ClassName)
        local Parent = Properties.Parent
        for Index, Property in Properties do
            if Index == "Parent" then continue end
            Object[Index] = Property
        end
        if Parent then Object.Parent = Parent end
        return Object
    end

    function Utility:AntiFling(State)
        for _, Player in Players:GetPlayers() do
            if Player == LocalPlayer then continue end
            local Character = Player.Character
            if not Character then continue end
            for _, BodyPart in Character:GetDescendants() do
                if BodyPart:IsA("BasePart") then BodyPart.CanCollide = not State end
            end
        end
    end

    function Utility:GetRootPart()
        if not LocalPlayer then return end
        local Character = LocalPlayer.Character
        if not Character then return end
        local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
        if not Humanoid then return end
        if Humanoid.Health <= 0 then return end
        local RootPart = Humanoid.RootPart
        if not RootPart then return end
        return RootPart
    end

    function Utility:GetTeam(Player)
        if not Player then return end
        local Backpack = FindFirstChildOfClass(Player, "Backpack")
        if not Backpack then return end
        local Character = Player.Character
        if not Character then return end
        local Knife = FindFirstChild(Backpack, "Knife") or FindFirstChild(Character, "Knife")
        if Knife then return "Murderer" end
        local Gun = FindFirstChild(Backpack, "Gun") or FindFirstChild(Character, "Gun")
        if Gun then return "Sheriff" end
        return
    end

    function Utility:GetNearestMurderer()
        local nearestPlayer = nil
        local nearestDistance = math.huge
        local localRoot = Utility:GetRootPart()
        if not localRoot then return nil end
        for _, Player in Players:GetPlayers() do
            if Player == LocalPlayer then continue end
            local Team = Utility:GetTeam(Player)
            if Team ~= "Murderer" then continue end
            local Character = Player.Character
            if not Character then continue end
            local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
            if not Humanoid or Humanoid.Health <= 0 then continue end
            local RootPart = Humanoid.RootPart
            if not RootPart then continue end
            local distance = (RootPart.Position - localRoot.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = Player
            end
        end
        return nearestPlayer
    end

    function Utility:GetCoinContainer()
        for _, Instance in GetDescendants(Workspace) do
            if not Instance:IsA("Model") then continue end
            if Instance.Name ~= "CoinContainer" then continue end
            return Instance
        end
    end

    function Utility:ClaimAllCoins()
        local CoinContainer = Utility:GetCoinContainer()
        if not CoinContainer then return end
        local RootPart = Utility:GetRootPart()
        if not RootPart then return end
        for _, Coin in CoinContainer:GetChildren() do
            if not Coin then continue end
            firetouchinterest(RootPart, Coin, 0)
            firetouchinterest(RootPart, Coin, 1)
        end
    end
end

do
    local BATCH_SIZE = 100

    local function processBatch(instances, processor)
        if XRayState.batchConnection then
            XRayState.batchConnection:Disconnect()
            XRayState.batchConnection = nil
        end

        local total = #instances
        local index = 1

        XRayState.batchConnection = RunService.Heartbeat:Connect(function()
            local batchEnd = math.min(index + BATCH_SIZE - 1, total)
            for i = index, batchEnd do
                processor(instances[i])
            end
            index = batchEnd + 1
            if index > total then
                XRayState.batchConnection:Disconnect()
                XRayState.batchConnection = nil
                XRayState.isProcessing = false
            end
        end)
    end

    function XRay:Init()
        if XRayState.isProcessing or XRayState.currentState == true then return end
        XRayState.isProcessing = true
        XRayState.currentState = true

        local targets = {}
        for _, inst in Workspace:GetDescendants() do
            if inst:IsA("BasePart") and inst.Transparency < 0.5 then
                targets[#targets + 1] = inst
            end
        end
        processBatch(targets, function(inst)
            if inst and inst.Parent then
                inst.LocalTransparencyModifier = 0.5
            end
        end)
    end

    function XRay:Remove()
        if XRayState.isProcessing or XRayState.currentState == false then return end
        XRayState.isProcessing = true
        XRayState.currentState = false

        local targets = {}
        for _, inst in Workspace:GetDescendants() do
            if inst:IsA("BasePart") then
                targets[#targets + 1] = inst
            end
        end
        processBatch(targets, function(inst)
            if inst and inst.Parent then
                inst.LocalTransparencyModifier = 0
            end
        end)
    end

    function XRay:Reset()
        if XRayState.batchConnection then
            XRayState.batchConnection:Disconnect()
            XRayState.batchConnection = nil
        end
        XRayState.isProcessing = false
        XRayState.currentState = nil
    end
end

do
    function Utility:CoinsESP(State)
        local CoinContainer = Utility:GetCoinContainer()
        if not CoinContainer then return end
        for _, Coin in CoinContainer:GetChildren() do
            if not Coin then continue end
            local CoinVisual = FindFirstChild(Coin, "CoinVisual")
            if not CoinVisual then continue end
            local MainCoin = FindFirstChildOfClass(CoinVisual, "MeshPart")
            if not MainCoin then continue end
            local OldHighlight = FindFirstChildOfClass(MainCoin, "Highlight")
            if OldHighlight and State then
                OldHighlight.FillColor = Color3FromRGB(255, 255, 0)
                continue
            elseif OldHighlight and not State then
                Destroy(OldHighlight)
                continue
            end
            if State then InstanceNew("Highlight", MainCoin) end
        end
    end

    local BillboardTemplate = Utility:Create("BillboardGui", {
        Name = "@",
        Size = UDim2New(0, 100, 0, 40),
        AlwaysOnTop = true,
        StudsOffset = Vector3New(0, 3, 0),
        SizeOffset = Vector2New(0, 0),
        ClipsDescendants = false,
        ResetOnSpawn = false,
    })

    local LabelTemplate = Utility:Create("TextLabel", {
        Size = UDim2New(1, 0, 1, 0),
        BackgroundTransparency = 1,
        TextSize = 12,
        TextStrokeTransparency = 0,
        ZIndex = 10,
        Parent = BillboardTemplate,
    })

    function Utility:PlayerESP(State, NameEnabled)
        for _, Player in Players:GetPlayers() do
            if Player == LocalPlayer then continue end
            local PlayerTeamName = Utility:GetTeam(Player)
            local Character = Player.Character
            if not Character then continue end
            local Head = FindFirstChild(Character, "Head")
            if not Head then continue end
            local OldHighlight = FindFirstChildOfClass(Character, "Highlight")
            local OldBillboard = FindFirstChild(Head, "@")

            if OldHighlight and State then
                OldHighlight.FillColor = TeamColors[PlayerTeamName] or Color3FromRGB(0, 255, 0)
                if OldBillboard then
                    local Label = OldBillboard:FindFirstChildOfClass("TextLabel")
                    if Label then
                        Label.Visible = NameEnabled
                        Label.TextColor3 = TeamColors[PlayerTeamName] or Color3FromRGB(0, 255, 0)
                    end
                end
                continue
            elseif OldHighlight and not State then
                Destroy(OldHighlight)
                if OldBillboard then Destroy(OldBillboard) end
                continue
            end

            if State and Head then
                InstanceNew("Highlight", Character)
                local Billboard = BillboardTemplate:Clone()
                Billboard.Parent = Head
                local Label = Billboard:FindFirstChildOfClass("TextLabel")
                Label.Text = Player.Name
                Label.Visible = NameEnabled
                Label.TextColor3 = TeamColors[PlayerTeamName] or Color3FromRGB(0, 255, 0)
            end
        end
    end
end

do
    local Cons = Genv.Connections

    function Connection:Add(Name, Signal, Callback)
        if Cons[Name] then Cons[Name]:Disconnect() end
        Cons[Name] = Signal:Connect(Callback)
    end

    function Connection:Remove(Name)
        if Cons[Name] then Cons[Name]:Disconnect() ; Cons[Name] = nil end
    end

    function Connection:Clear()
        for Name, Conn in Cons do
            Conn:Disconnect() ; Cons[Name] = nil
        end
    end
end

do
    function Desync:Resume()
        local RootPart = Utility:GetRootPart()
        if not RootPart then return end
        if not Desync.LastCFrame then return end
        RootPart.CFrame = Desync.LastCFrame
    end

    function Desync:Teleport()
        local RootPart = Utility:GetRootPart()
        if not RootPart then return end
        Desync.LastCFrame = RootPart.CFrame
        if not Desync.LastCFrame then return end
        RootPart.CFrame = CFrameNew(0/0, 0/0, 0/0)
    end

    function Desync:Stop()
        local RootPart = Utility:GetRootPart()
        if not RootPart then return end
        if Desync.LastCFrame then RootPart.CFrame = Desync.LastCFrame end
        Desync.LastCFrame = nil
    end

    function Desync:Init()
        local RootPart = Utility:GetRootPart()
        if not RootPart then return end
        if Desync.LastCFrame then RootPart.CFrame = Desync.LastCFrame end
        Desync.LastCFrame = RootPart.CFrame
    end
end

do
    Connection:Clear()
    XRay:Reset()
    RunService:UnbindFromRenderStep("DESYNCING")
    Desync:Init()
end

do
    RunService:BindToRenderStep("DESYNCING", 0, function()
        Desync:Resume()
    end)

    Connection:Add("Misc/VoidHide", RunService.Heartbeat, function()
        local Flag = Flags["Misc/VoidHide"]
        if not Flag then return end
        if Flag.CurrentValue then
            Desync:Teleport()
        elseif Desync.LastCFrame then
            Desync:Stop()
        end
    end)

    Connection:Add("Misc/AntiFling", RunService.Stepped, function()
        local Flag = Flags["Misc/AntiFling"]
        if not Flag then return end
        Utility:AntiFling(Flag.CurrentValue)
    end)

    Connection:Add("Visuals/ESP/Players", RunService.Stepped, function()
        local ChamsESP = Flags["Visuals/ESP/Chams"]
        if not ChamsESP then return end
        local NameESP = Flags["Visuals/ESP/Name"]
        if not NameESP then return end
        Utility:PlayerESP(ChamsESP.CurrentValue, NameESP.CurrentValue)
    end)

    Connection:Add("Visuals/ESP/Coins", RunService.Stepped, function()
        local Flag = Flags["Visuals/ESP/Coins"]
        if not Flag then return end
        Utility:CoinsESP(Flag.CurrentValue)
    end)

    Connection:Add("Misc/AutoCoins", RunService.Stepped, function()
        local Flag = Flags["Misc/AutoCoins"]
        if not Flag then return end
        if not Flag.CurrentValue then return end
        Utility:ClaimAllCoins()
    end)

    Connection:Add("Visuals/World/XRay", RunService.Stepped, function()
        local Flag = Flags["Visuals/World/XRay"]
        if not Flag then return end
        if Flag.CurrentValue then
            XRay:Init()
        else
            XRay:Remove()
        end
    end)

    local lastShootTime = 0
    local shootCooldown = 0.12

    Connection:Add("Combat/AutoShoot", RunService.Heartbeat, function()
        local Flag = Flags["Combat/AutoShoot"]
        if not Flag or not Flag.CurrentValue then return end
        local localTeam = Utility:GetTeam(LocalPlayer)
        if localTeam ~= "Sheriff" then return end
        local Character = LocalPlayer.Character
        if not Character then return end
        local Gun = FindFirstChild(Character, "Gun")
        if not Gun then return end
        local GunAttachment = FindFirstChild(Character.HumanoidRootPart, "GunRaycastAttachment")
        if not GunAttachment then return end
        local Target = Utility:GetNearestMurderer()
        if not Target then return end
        local TargetCharacter = Target.Character
        if not TargetCharacter then return end
        local TargetHead = FindFirstChild(TargetCharacter, "Head")
        if not TargetHead then return end
        local currentTime = os.clock()
        if currentTime - lastShootTime < shootCooldown then return end
        lastShootTime = currentTime
        Gun.Shoot:FireServer(GunAttachment.WorldCFrame, CFrameNew(TargetHead.Position))
    end)

    Connection:Add("Combat/KillAura", RunService.Heartbeat, function()
        local auraFlag = Flags["Combat/KillAura"]
        local killAllFlag = Flags["Combat/KillAll"]
        local silentFlag = Flags["Combat/SilentAura"]
        local rangeFlag = Flags["Combat/AuraRange"]
        if not (auraFlag and killAllFlag and silentFlag and rangeFlag) then return end
        local auraEnabled = auraFlag.CurrentValue
        local killAllEnabled = killAllFlag.CurrentValue
        local silentEnabled = silentFlag.CurrentValue
        local range = rangeFlag.CurrentValue
        if not (auraEnabled or killAllEnabled) then return end
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        local handle = tool and tool:FindFirstChild("Handle")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not (tool and handle and hrp) then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local enemy = plr.Character
                local eHRP = enemy.HumanoidRootPart
                local eHum = enemy:FindFirstChildOfClass("Humanoid")
                if eHum and eHum.Health > 0 then
                    local dist = (hrp.Position - eHRP.Position).Magnitude
                    if (auraEnabled and dist <= range) or killAllEnabled then
                        if not silentEnabled then tool:Activate() end
                        for _, part in pairs(enemy:GetChildren()) do
                            if part:IsA("BasePart") then
                                firetouchinterest(handle, part, 0)
                                firetouchinterest(handle, part, 1)
                            end
                        end
                    end
                end
            end
        end
    end)
end
