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
local TWEEN_SPEED = 62

-- TweenService
local resolvers = {
    vector3 = function(target)
        return target
    end,

    instance = function(target)
        if target:IsA("BasePart") then
            return target.Position
        end
    end,
}

local math_util = {
    distance = function(a, b)
        local diff = a - b
        return math.sqrt(diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z)
    end,

    lerp = function(a, b, alpha)
        return Vector3.new(
            a.X + (b.X - a.X) * alpha,
            a.Y + (b.Y - a.Y) * alpha,
            a.Z + (b.Z - a.Z) * alpha
        )
    end,

    easing = {
        linear = function(alpha)
            return alpha
        end,

        smoothstep = function(alpha)
            return alpha * alpha * (3 - 2 * alpha)
        end,

        ease_in_quad = function(alpha)
            return alpha * alpha
        end,

        ease_out_quad = function(alpha)
            return alpha * (2 - alpha)
        end,

        ease_in_out_quad = function(alpha)
            if alpha < 0.5 then
                return 2 * alpha * alpha
            else
                return -1 + (4 - 2 * alpha) * alpha
            end
        end,
    }
}

local function tween_to(local_player, target, speed, easing_style)
    local result = {completed = false}

    if not (local_player and target and speed > 0) then
        result.completed = true
        return result
    end

    local char = local_player.Character
    if not char then
        result.completed = true
        return result
    end

    local hrp = char:WaitForChild("HumanoidRootPart")
    local resolve = resolvers[typeof(target):lower()]
    local target_position = resolve and resolve(target)
    if not target_position then
        result.completed = true
        return result
    end

    local start_position = hrp.Position
    local distance = math_util.distance(start_position, target_position)
    local duration = distance / speed
    if duration <= 0 then
        result.completed = true
        return result
    end

    local easing_func = math_util.easing[easing_style] or math_util.easing.linear

    task.spawn(function()
        local elapsed = 0
        local dt = 1 / 240
        while elapsed < duration do
            elapsed = elapsed + dt
            local alpha = math.clamp(elapsed / duration, 0, 1)
            local eased_alpha = easing_func(alpha)
            hrp.Position = math_util.lerp(start_position, target_position, eased_alpha)
            task.wait(dt)
        end
        hrp.Position = target_position
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        result.completed = true
    end)

    return result
end

-- ESP Functions
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
    local targetPos = Vector3.new(pos.X, pos.Y - 50, pos.Z)

    local tween = tween_to(LocalPlayer, targetPos, TWEEN_SPEED, "ease_in_quad")
    while not tween.completed do
        task.wait()
    end

    keypress(0x45)
    task.wait(COLLECT_WAIT)
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

farmSection:Slider("Tween Speed", 62, 1, 1, 125, "spd", function(value)
    TWEEN_SPEED = value
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
