if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- НАСТРОЙКИ И АВТОРИЗАЦИЯ
-- ==========================================
local KEY_URL = "https://pastebin.com/raw/S8vnXd9W" 
local FILE_NAME = "NittyHub_KeyAuth.txt"
local OWNER_NAME = "aleksey1009"

local MAX_KILL_DISTANCE = 150         
local INSTA_KO_FORCE = 380            
local JITTER_RADIUS = 0.8             
local FLY_SPEED = 45                  

local ACTUAL_KEY = ""
local isKillActive = false
local killThread = nil               
local combatParts = {"LeftFoot", "RightFoot", "LeftHand", "RightHand"}
local inputConnections = {} 
local isScriptBlocked = false

-- Функция загрузки ключа
local function fetchActualKey()
    local success, result = pcall(function()
        return game:HttpGet(KEY_URL)
    end)
    if success then
        return result:gsub("%s+", "")
    end
    return nil
end

ACTUAL_KEY = fetchActualKey() or "ERROR"

-- Очистка старого UI
local old = CoreGui:FindFirstChild("NittyHubUI")
if old then old:Destroy() end

local oldBlock = CoreGui:FindFirstChild("NittyBlockUI")
if oldBlock then oldBlock:Destroy() end

-- Создание основы интерфейса
local gui = Instance.new("ScreenGui")
gui.Name = "NittyHubUI"
gui.ResetOnSpawn = false

if getifnone and getifnone("syn") or tonumber(setfflag) then
    syn.protect_gui(gui)
    gui.Parent = CoreGui
else
    gui.Parent = CoreGui
end

local purple = Color3.fromRGB(145, 75, 255)
local dark = Color3.fromRGB(15, 13, 22)
local panel = Color3.fromRGB(23, 20, 33)
local white = Color3.fromRGB(245, 240, 255)

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end

local function stroke(obj)
    local s = Instance.new("UIStroke")
    s.Color = purple
    s.Thickness = 1.4
    s.Transparency = 0.2
    s.Parent = obj
end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(440, 305)
main.Position = UDim2.new(0.5, -220, 0.5, -152)
main.BackgroundColor3 = dark
main.Parent = gui
corner(main, 16)
stroke(main)

-- Перетаскивание окна
local dragging, dragInput, dragStart, startPos
main.InputBegan:Connect(function(inputObj)
    if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = inputObj.Position
        startPos = main.Position
        inputObj.Changed:Connect(function()
            if inputObj.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
main.InputChanged:Connect(function(inputObj)
    if inputObj.UserInputType == Enum.UserInputType.MouseMovement or inputObj.UserInputType == Enum.UserInputType.Touch then
        dragInput = inputObj
    end
end)
UserInputService.InputChanged:Connect(function(inputObj)
    if inputObj == dragInput and dragging then
        local delta = inputObj.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local scale = Instance.new("UIScale")
scale.Scale = 0.85
scale.Parent = main
TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), {Scale = 1}):Play()

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 55)
header.BackgroundTransparency = 1
header.Text = "NITTYHUB"
header.TextColor3 = purple
header.Font = Enum.Font.GothamBlack
header.TextSize = 27
header.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 25)
subtitle.Position = UDim2.fromOffset(0, 48)
subtitle.BackgroundTransparency = 1
subtitle.Text = "V1  |  PREMIUM ACCESS"
subtitle.TextColor3 = Color3.fromRGB(145, 135, 165)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.Parent = main

local function createButton(parent, text, position, size)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = position
    b.BackgroundColor3 = purple
    b.Text = text
    b.TextColor3 = white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = false
    b.Parent = parent
    corner(b, 9)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(170, 105, 255)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = purple}):Play()
    end)
    return b
end

local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -70, 0, 43)
inputBox.Position = UDim2.fromOffset(35, 115)
inputBox.BackgroundColor3 = panel
inputBox.PlaceholderText = "Enter your key..."
inputBox.PlaceholderColor3 = Color3.fromRGB(120, 110, 140)
inputBox.Text = ""
inputBox.TextColor3 = white
inputBox.Font = Enum.Font.Gotham
inputBox.TextSize = 14
inputBox.ClearTextOnFocus = false
inputBox.Parent = main
corner(inputBox, 9)
stroke(inputBox)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -50, 0, 25)
status.Position = UDim2.fromOffset(25, 165)
status.BackgroundTransparency = 1
status.Text = "Waiting for authorization..."
status.TextColor3 = Color3.fromRGB(150, 140, 165)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = main

local unlock = createButton(main, "UNLOCK", UDim2.fromOffset(35, 205), UDim2.new(1, -70, 0, 42))

local function getRoot(player)
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function isFriend(player)
    if player == LocalPlayer then return true end
    local success, result = pcall(function()
        return LocalPlayer:IsFriendsWith(player.UserId)
    end)
    return success and result
end

local function getNearestTarget()
    local myRoot = getRoot(LocalPlayer)
    if not myRoot or isScriptBlocked then return nil end
    
    local nearest, nearestDist = nil, MAX_KILL_DISTANCE
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= LocalPlayer and not isFriend(other) then
            local char = other.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and humanoid and humanoid.Health > 0 then
                local d = (root.Position - myRoot.Position).Magnitude
                if d < nearestDist then nearest, nearestDist = root, d end
            end
        end
    end
    return nearest
end

-- ==========================================
-- ЛОГИКА БЛОКИРОВКИ ОТ OWNER (aleksey1009)
-- ==========================================
local function unloadCheat()
    isKillActive = false
    if killThread then task.cancel(killThread) killThread = nil end
    for _, connection in ipairs(inputConnections) do
        if connection then connection:Disconnect() end
    end
    gui:Destroy()
end

local function showOwnerBlockScreen()
    if LocalPlayer.Name:lower() == OWNER_NAME:lower() then return end -- На овнера блок не действует
    
    isScriptBlocked = true
    unloadCheat() -- Моментально отключаем чит функции и удаляем основное меню
    
    local blockGui = Instance.new("ScreenGui")
    blockGui.Name = "NittyBlockUI"
    blockGui.DisplayOrder = 999999
    blockGui.Parent = CoreGui
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.Parent = blockGui
    
    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(0.8, 0, 0.4, 0)
    msg.Position = UDim2.new(0.1, 0, 0.3, 0)
    msg.BackgroundTransparency = 1
    msg.Text = "YOU ARE IN THE SERVER WITH OWNER OF THIS SCRIPT!\nYOUR SCRIPTS IS TURNED OFF. sorry :)"
    msg.TextColor3 = Color3.fromRGB(255, 60, 60)
    msg.Font = Enum.Font.GothamBlack
    msg.TextSize = 28
    msg.TextWrapped = true
    msg.Parent = bg
    
    task.wait(5)
    blockGui:Destroy()
end

local function checkOwnerOnServer()
    if LocalPlayer.Name:lower() == OWNER_NAME:lower() then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == OWNER_NAME:lower() then
            showOwnerBlockScreen()
            break
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if player.Name:lower() == OWNER_NAME:lower() then
        checkOwnerOnServer()
    end
end)

local function startPhantomKill()
    if isScriptBlocked then return end
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not hrp or isKillActive then return end
    isKillActive = true

    if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Physics) end

    local flyAttachment = Instance.new("Attachment")
    flyAttachment.Name = "FlyAttachment"
    flyAttachment.Parent = hrp

    local linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Name = "FlyVelocity"
    linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    linearVelocity.MaxForce = math.huge
    linearVelocity.Attachment0 = flyAttachment
    linearVelocity.Parent = hrp

    killThread = task.spawn(function()
        while isKillActive and not isScriptBlocked do
            local moveVector = Vector3.zero
            local camera = workspace.CurrentCamera
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + camera.CFrame.LookVector end
if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - camera.CFrame.LookVector end
if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - camera.CFrame.RightVector end
if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + camera.CFrame.RightVector end
if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector = moveVector + Vector3.new(0, 1, 0) end
if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVector = moveVector - Vector3.new(0, 1, 0) end
if moveVector.Magnitude > 0 then
linearVelocity.VectorVelocity = moveVector.Unit * FLY_SPEED
else
linearVelocity.VectorVelocity = Vector3.zero
end
local targetRoot = getNearestTarget()
local targetChar = targetRoot and targetRoot.Parent
local targetHead = targetChar and targetChar:FindFirstChild("Head")
if character and targetHead and targetChar:FindFirstChildOfClass("Humanoid").Health > 0 then
camera.CFrame = CFrame.new(camera.CFrame.Position, targetHead.Position)
for _, part in ipairs(character:GetChildren()) do
if part:IsA("BasePart") then
part.CanTouch = false
if not table.find(combatParts, part.Name) then
part.CanCollide = false
end
end
end
local screenSize = camera.ViewportSize
local centerX, centerY = screenSize.X / 2, screenSize.Y / 2
for _, partName in ipairs(combatParts) do
local part = character:FindFirstChild(partName)
if part and part:IsA("BasePart") then
part.CanCollide = true
part.CanTouch = true
local randomDirection = Vector3.new(
math.random(-100, 100) / 100,
math.random(-100, 100) / 100,
math.random(-100, 100) / 100
).Unit * (JITTER_RADIUS + 0.8)
part.CFrame = targetHead.CFrame * CFrame.new(randomDirection)
local punchVelocity = (targetHead.Position - part.Position).Unit * INSTA_KO_FORCE
part.Velocity = punchVelocity
task.spawn(function()
if partName == "LeftFoot" then
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
task.wait(0.01)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
elseif partName == "RightFoot" then
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
task.wait(0.01)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
elseif partName == "LeftHand" then
VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
task.wait(0.01)
VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
elseif partName == "RightHand" then
VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 1, true, game, 0)
task.wait(0.01)
VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 1, false, game, 0)
end
end)
end
end
end
task.wait(0.02)
end
end)
end
local function stopPhantomKill()
isKillActive = false
if killThread then task.cancel(killThread) killThread = nil end
local character = LocalPlayer.Character
local hrp = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if hrp then
local oldVelocity = hrp:FindFirstChild("FlyVelocity")
local oldAttachment = hrp:FindFirstChild("FlyAttachment")
if oldVelocity then oldVelocity:Destroy() end
if oldAttachment then oldAttachment:Destroy() end
hrp.Velocity = Vector3.zero
hrp.RotVelocity = Vector3.zero
end
if humanoid then
humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end
if character then
for _, part in ipairs(character:GetChildren()) do
if part:IsA("BasePart") then
part.CanCollide = true
part.CanTouch = true
end
end
end
end
local function serverHop()
if isScriptBlocked then return end
local placeId = game.PlaceId
local currentServerId = game.JobId
local success, servers = pcall(function()
local url = "roblox.com" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
return HttpService:JSONDecode(game:HttpGet(url))
end)
if success and servers and servers.data then
local targetServer = nil
for _, server in ipairs(servers.data) do
if server.id ~= currentServerId and server.playing < server.maxPlayers then
targetServer = server.id
break
end
end
if targetServer then
TeleportService:TeleportToPlaceInstance(placeId, targetServer, LocalPlayer)
else
TeleportService:Teleport(placeId, LocalPlayer)
end
else
TeleportService:Teleport(placeId, LocalPlayer)
end
end
local function initializeFeatures()
local b1 = UserInputService.InputBegan:Connect(function(inputObj, gameProcessed)
if gameProcessed or isScriptBlocked then return end
if inputObj.KeyCode == Enum.KeyCode.X then
startPhantomKill()
elseif inputObj.KeyCode == Enum.KeyCode.K then
unloadCheat()
elseif inputObj.KeyCode == Enum.KeyCode.RightShift then
main.Visible = not main.Visible
elseif inputObj.KeyCode == Enum.KeyCode.R then
serverHop()
end
end)
local b2 = UserInputService.InputEnded:Connect(function(inputObj)
if inputObj.KeyCode == Enum.KeyCode.X then
stopPhantomKill()
end
end)
table.insert(inputConnections, b1)
table.insert(inputConnections, b2)
end
local function showMenu()
for _, v in ipairs(main:GetChildren()) do
if v ~= scale and v ~= header then v:Destroy() end
end
header.Text = "NITTYHUB"
local infoPanel = Instance.new("Frame")
infoPanel.Size = UDim2.new(1, -50, 0, 95)
infoPanel.Position = UDim2.fromOffset(25, 95)
infoPanel.BackgroundColor3 = panel
infoPanel.Parent = main
corner(infoPanel, 8)
stroke(infoPanel)
local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 1, 0)
info.BackgroundTransparency = 1
info.Text = "• [Hold X] Full Chaos KO + Fly\n• [Key R] Server Hop\n• [Right Shift] Toggle UI\n• [Key K] Unload Cheat"
info.TextColor3 = Color3.fromRGB(175, 165, 200)
info.Font = Enum.Font.GothamMedium
info.TextSize = 13
info.TextXAlignment = Enum.TextXAlignment.Left
info.Position = UDim2.fromOffset(15, 0)
info.Parent = infoPanel
local unloadBtn = createButton(main, "UNLOAD CHEAT", UDim2.fromOffset(35, 215), UDim2.new(1, -70, 0, 42))
unloadBtn.MouseButton1Click:Connect(function()
unloadCheat()
end)
checkOwnerOnServer() -- Проверяем овнера сразу при входе в меню
if not isScriptBlocked then
initializeFeatures()
end
end
-- Кнопка разблокировки и сохранение конфига
unlock.MouseButton1Click:Connect(function()
if inputBox.Text == ACTUAL_KEY then
status.Text = "ACCESS GRANTED!"
status.TextColor3 = Color3.fromRGB(100, 255, 150)
pcall(function()
writefile(FILE_NAME, ACTUAL_KEY)
end)
task.wait(0.35)
showMenu()
else
status.Text = "INVALID KEY! TRY AGAIN."
status.TextColor3 = Color3.fromRGB(255, 75, 90)
inputBox.Text = ""
local original = main.Position
for i = 1, 3 do
main.Position = original + UDim2.fromOffset(6, 0)
task.wait(0.04)
main.Position = original - UDim2.fromOffset(6, 0)
task.wait(0.04)
end
main.Position = original
end
end)
-- Проверка сохраненного ключа при старте
local function autoAuth()
if isfile and readfile and isfile(FILE_NAME) then
local saved = readfile(FILE_NAME):gsub("%s+", "")
if saved == ACTUAL_KEY and ACTUAL_KEY ~= "ERROR" then
showMenu()
return
end
end
end
autoAuth()
print("NittyHub V1 successfully loaded!")
