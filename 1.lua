local Genv = getgenv()

Genv.Connections = Genv.Connections or {}
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

local Workspace = GetService(game, "Workspace")
local RunService = GetService(game, "RunService")
local Players = GetService(game, "Players")

local LocalPlayer = Players.LocalPlayer
local XRayState = Genv.XRayState

local XRay = {}
local Utility = {}
local Connection = {}

local TeamColors = {
    Murderer = Color3FromRGB(255, 0, 0),
    Sheriff = Color3FromRGB(0, 0, 255)
}

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

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

    local WorldSection = VisualsTab:CreateSection("地图透视")
    VisualsTab:CreateToggle({
        Name = "全图X光",
        CurrentValue = false,
        Flag = "Visuals/World/XRay",
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
    local Cons = Genv.Connections

    function Connection:Add(Name, Signal, Callback)
        if Cons[Name] then Cons[Name]:Disconnect() end
        Cons[Name] = Signal:Connect(Callback)
    end

    function Connection:Clear()
        for Name, Conn in Cons do
            Conn:Disconnect() ; Cons[Name] = nil
        end
    end
end

do
    Connection:Clear()
    XRay:Reset()
end

do
    Connection:Add("Visuals/ESP/Players", RunService.Stepped, function()
        local ChamsESP = Flags["Visuals/ESP/Chams"]
        if not ChamsESP then return end
        local NameESP = Flags["Visuals/ESP/Name"]
        if not NameESP then return end
        Utility:PlayerESP(ChamsESP.CurrentValue, NameESP.CurrentValue)
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
end
