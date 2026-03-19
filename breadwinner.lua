loadstring(game:HttpGet('https://raw.githubusercontent.com/catowice/p/refs/heads/main/library.lua'))()

UILib:SetMenuTitle("Breadwinner")
UILib:CenterMenu()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- ESP State
local ESPEnabled = false
local ESPBox = true
local ESPDistance = true
local ESPLabel = true
local UPDATE_RATE = 0.01
local WORLD_RADIUS = 1.5
local espObjects = {}

-- Farm State
local FARMING = false
local COLLECT_WAIT = 2.0

local function getColorName(color)
    local r = color.R
    local g = color.G
    local b = color.B
    local diff = math.abs(r - g) + math.abs(g - b) + math.abs(r - b)
    if diff < 0.15 then
        if r < 0.2 then return "Black"
        elseif r > 0.8 then return "White"
        else return "Grey" end
    end
    if r > g and r > b then
        if g > 0.4 then return "Orange" end
        if b > 0.4 then return "Pink" end
        return "Red"
    elseif g > r and g > b then
        if r > 0.4 then return "Yellow" end
        if b > 0.4 then return "Cyan" end
        return "Green"
    elseif b > r and b > g then
        if r > 0.4 then return "Purple" end
        if g > 0.4 then return "Teal" end
        return "Blue"
    elseif r > 0.5 and g > 0.5 then return "Yellow"
    elseif r > 0.5 and b > 0.5 then return "Magenta"
    elseif g > 0.5 and b > 0.5 then return "Cyan"
    end
    return "Unknown"
end

local function getDistance(pos)
    local character = LocalPlayer.Character
    if not character then return 0 end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    local rpos = root.Position
    if not rpos then return 0 end
    local dx = rpos.X - pos.X
    local dy = rpos.Y - pos.Y
    local dz = rpos.Z - pos.Z
    return math.floor(math.sqrt(dx^2 + dy^2 + dz^2))
end

local function isPhysicalPart(className)
    return className == "Part"
        or className == "MeshPart"
        or className == "UnionOperation"
        or className == "WedgePart"
        or className == "CornerWedgePart"
        or className == "TrussPart"
end

local function getRepPart(obj)
    if isPhysicalPart(obj.ClassName) then return obj end
    if obj.ClassName == "Model" and obj.PrimaryPart then return obj.PrimaryPart end
    for _, child in ipairs(obj:GetDescendants()) do
        if isPhysicalPart(child.ClassName) then return child end
    end
    return nil
end

local function getPartColor(part)
    if not part or not part.Color then return Color3.fromRGB(0, 255, 0) end
    return part.Color
end

local function getDrawColor(color)
    if color.R < 0.2 and color.G < 0.2 and color.B < 0.2 then
        return Color3.fromRGB(180, 180, 180)
    end
    if color.B > color.R and color.B > color.G then
        return Color3.fromRGB(150, 200, 255)
    end
    return color
end

local function getScaledBox(part)
    local pos = part.Position
    if not pos then return nil end
    local centerScreen, centerOn = WorldToScreen(pos)
    if not centerOn then return nil end
    local topScreen = WorldToScreen(Vector3.new(pos.X, pos.Y + WORLD_RADIUS, pos.Z))
    local rightScreen = WorldToScreen(Vector3.new(pos.X + WORLD_RADIUS, pos.Y, pos.Z))
    local halfH = math.abs(centerScreen.Y - topScreen.Y)
    local halfW = math.abs(centerScreen.X - rightScreen.X)
    local half = math.max(math.max(halfH, halfW), 4)
    return centerScreen.X - half, centerScreen.Y - half, half * 2
end

local function createESP(obj)
    local box = Drawing.new("Square")
    box.Color = Color3.fromRGB(0, 255, 0)
    box.Thickness = 1
    box.Filled = false
    box.Visible = false
    local label = Drawing.new("Text")
    label.Color = Color3.fromRGB(0, 255, 0)
    label.Size = 13
    label.Font = Drawing.Fonts.SystemBold
    label.Outline = true
    label.Visible = false
    return { box = box, label = label, obj = obj }
end

local function removeESP(esp)
    if esp.box then esp.box:Remove() end
    if esp.label then esp.label:Remove() end
end

local function clearAllESP()
    for _, esp in pairs(espObjects) do removeESP(esp) end
    espObjects = {}
end

local function getMonadPositions()
    local positions = {}
    local monadFolder = Workspace:FindFirstChild("Monads")
    if not monadFolder then return positions end
    for _, obj in ipairs(monadFolder:GetChildren()) do
        if obj.Parent then
            local part = getRepPart(obj)
            if part then
                local ok, pos = pcall(function() return part.Position end)
                if ok and pos then
                    table.insert(positions, pos)
                end
            end
        end
    end
    return positions
end

local function goToMonad(pos)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local tx = pos.X
    local ty = pos.Y + 5
    local tz = pos.Z

    pcall(function()
        hrp.Position = Vector3.new(tx, ty, tz)
    end)
    task.wait(0.5)

    local holdStart = os.clock()
    keypress(0x45)
    while os.clock() - holdStart < COLLECT_WAIT do
        if not FARMING then break end
        char = LocalPlayer.Character
        if not char then break end
        hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then break end
        pcall(function()
            hrp.Position = Vector3.new(tx, ty, tz)
        end)
        task.wait(0.5)
    end
    keyrelease(0x45)
    task.wait(0.3)
end

-- ESP Loop
task.spawn(function()
    local monadFolder = nil
    while not monadFolder do
        monadFolder = Workspace:FindFirstChild("Monads")
        task.wait(1)
    end

    while true do
        task.wait(UPDATE_RATE)

        monadFolder = Workspace:FindFirstChild("Monads")
        if not monadFolder then clearAllESP() continue end

        local children = monadFolder:GetChildren()

        if #children ~= #espObjects then
            clearAllESP()
            for i, obj in ipairs(children) do
                espObjects[i] = createESP(obj)
            end
        end

        for i, obj in ipairs(children) do
            local esp = espObjects[i]
            if not esp then continue end
            esp.obj = obj

            if not ESPEnabled then
                esp.box.Visible = false
                esp.label.Visible = false
                continue
            end

            if not obj or not obj.Parent then
                esp.box.Visible = false
                esp.label.Visible = false
                continue
            end

            local part = getRepPart(obj)
            if not part or not part.Parent then
                esp.box.Visible = false
                esp.label.Visible = false
                continue
            end

            local x, y, size = getScaledBox(part)
            if not x then
                esp.box.Visible = false
                esp.label.Visible = false
                continue
            end

            local rawColor = getPartColor(part)
            local drawColor = getDrawColor(rawColor)
            local colorName = getColorName(rawColor)
            local dist = getDistance(part.Position)

            esp.box.Position = Vector2.new(x, y)
            esp.box.Size = Vector2.new(size, size)
            esp.box.Color = drawColor
            esp.box.Visible = ESPBox

            local labelText = ""
            if ESPLabel then
                labelText = "Pearl | " .. colorName
            end
            if ESPDistance then
                if labelText ~= "" then
                    labelText = labelText .. " [" .. dist .. " studs]"
                else
                    labelText = "[" .. dist .. " studs]"
                end
            end

            esp.label.Text = labelText
            esp.label.Position = Vector2.new(x, y - 18)
            esp.label.Color = drawColor
            esp.label.Visible = (ESPLabel or ESPDistance) and labelText ~= ""
        end
    end
end)

-- Farm Loop
task.spawn(function()
    while true do
        task.wait(0.1)
        if not FARMING then task.wait(0.5) continue end

        local positions = getMonadPositions()
        if #positions == 0 then
            task.wait(2)
            continue
        end

        for _, pos in ipairs(positions) do
            if not FARMING then break end
            goToMonad(pos)
        end

        task.wait(1)
    end
end)

-- Build Menu
local farmTab = UILib:Tab("Pearl Farm")
local farmSection = farmTab:Section("Monads")

farmSection:Toggle("Farm Enabled", false, function(value)
    FARMING = value
    notify(value and "Pearl Farm: ON" or "Pearl Farm: OFF", "Breadwinner", 2)
end)

farmSection:Slider("Collect Hold", 2, 1, 1, 5, "s", function(value)
    COLLECT_WAIT = value
end)

local espTab = UILib:Tab("ESP")
local espSection = espTab:Section("Pearls")

espSection:Toggle("Pearl ESP", false, function(value)
    ESPEnabled = value
    if not value then clearAllESP() end
end)

espSection:Toggle("Box", true, function(value)
    ESPBox = value
end)

espSection:Toggle("Label", true, function(value)
    ESPLabel = value
end)

espSection:Toggle("Distance", true, function(value)
    ESPDistance = value
end)

local _, menuSettings = UILib:CreateSettingsTab()
local shouldDie = false
menuSettings:Button("Unload", function()
    shouldDie = true
    clearAllESP()
    FARMING = false
end)

UILib:Notification("Breadwinner loaded! Press F1 to toggle menu.", 5)

while not shouldDie do
    task.wait()
    UILib:Step()
end

UILib:Unload()