-- Ragdoll MMA Phantom God Hub v22 [PHYSICS FLY + HITBOX FIX + KEYPRESS SIM]
-- СВОБОДНЫЙ ПОЛЕТ + ИСПРАВЛЕННАЯ РЕГИСТРАЦИЯ УДАРОВ + ANTI-GRAB + СИМУЛЯЦИЯ Q/E

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager") -- Сервис для нажатия клавиш

local LocalPlayer = Players.LocalPlayer
local GUI_NAME = "MMAPhantomHubV22"

-- ============================================================================
-- НАСТРОЙКИ СЕКРЕТОВ И ПЛЕЙСА (КЛЮЧ: NittyOnTop)
-- ============================================================================
local SECRET_KEY = "NittyOnTop"                       
local DISCORD_LINK = "https://discord.gg"    
local TARGET_PLACE_ID = 76205942520539

local function InitializeMainScript()
    -- ГОРЯЧИЕ КЛАВИШИ
    local KILL_KEY = Enum.KeyCode.X      -- Зажми X для полета и аннигиляции целей
    local MENU_TOGGLE_KEY = Enum.KeyCode.RightShift 
    local UNLOAD_KEY = Enum.KeyCode.K     
    local REJOIN_KEY = Enum.KeyCode.R     

    -- НАСТРОЙКИ БЕЗОПАСНОГО УБОЯ И ПОЛЕТА
    local MAX_KILL_DISTANCE = 150         
    local INSTA_KO_FORCE = 380            -- Сила физического удара ноги вниз
    local JITTER_RADIUS = 0.8             
    local FLY_SPEED = 45                  -- Скорость перемещения в полете

    -- СОСТОЯНИЯ
    local autoAntiFall = true
    local isKillActive = false
    local menuVisible = true
    local connections = {}
    local killThread = nil               

    local combatLegs = {"LeftFoot", "RightFoot"}

    local oldGui = CoreGui:FindFirstChild(GUI_NAME) or LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild(GUI_NAME)
    if oldGui then oldGui:Destroy() end

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
        if not myRoot then return nil end
        
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

    -- РЕЖИМ СВОБОДНОГО ФИЗИЧЕСКОГО ПОЛЕТА И ИСПРАВЛЕННОЙ АТАКЫ
    local function startPhantomKill()
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character or not hrp or isKillActive then return end
        isKillActive = true

        -- Включаем режим полета для Humanoid
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Physics) end

        -- Создаем физические силы для левитации и полета
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
            while isKillActive do
                -- Считываем управление игрока (W, S, A, D) для полета в сторону камеры
                local moveVector = Vector3.zero
                local camera = workspace.CurrentCamera
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVector = moveVector + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVector = moveVector - Vector3.new(0, 1, 0) end

                -- Прикладываем скорость к полету
                if moveVector.Magnitude > 0 then
                    linearVelocity.VectorVelocity = moveVector.Unit * FLY_SPEED
                else
                    linearVelocity.VectorVelocity = Vector3.zero
                end

                -- БОЕВАЯ ЧАСТЬ (ИСПРАВЛЕННЫЙ МИКРО-ЗАМАХ) + СИМУЛЯЦИЯ КЛАВИШ
                local targetRoot = getNearestTarget()
                local targetChar = targetRoot and targetRoot.Parent
                local targetHead = targetChar and targetChar:FindFirstChild("Head")

                if character and targetHead and targetChar:FindFirstChildOfClass("Humanoid").Health > 0 then
                    -- Полный Anti-Grab для всех частей тела, кроме бьющих ног
                    for _, part in ipairs(character:GetChildren()) do
                        if part:IsA("BasePart") then 
                            part.CanTouch = false 
                            if part.Name ~= "LeftFoot" and part.Name ~= "RightFoot" then
                                part.CanCollide = false 
                            end
                        end
                    end

                    for _, legName in ipairs(combatLegs) do
                        local leg = character:FindFirstChild(legName)
                        if leg and leg:IsA("BasePart") then
                            -- Включаем коллизию и тач-детект ногам в момент удара
                            leg.CanCollide = true
                            leg.CanTouch = true
                            
                            -- Создаем микро-замах: телепортируем ногу чуть выше головы врага с микро-вибрацией
                            local jitter = Vector3.new(
                                math.random(-100, 100) / 100 * JITTER_RADIUS,
                                math.random(-100, 100) / 100 * JITTER_RADIUS,
                                math.random(-100, 100) / 100 * JITTER_RADIUS
                            )
                            leg.CFrame = targetHead.CFrame * CFrame.new(0, JITTER_RADIUS + 0.5, 0) * CFrame.new(jitter)
                            
                            -- Направляем физический импульс строго вниз сквозь хитбокс головы
                            leg.Velocity = Vector3.new(0, -INSTA_KO_FORCE, 0)

                            -- АВТОМАТИЧЕСКОЕ НАЖАТИЕ КЛАВИШ Q И E
                            task.spawn(function()
                                if legName == "LeftFoot" then
                                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
                                    task.wait(0.01)
                                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
                                elseif legName == "RightFoot" then
                                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                                    task.wait(0.01)
                                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                                end
                            end)
                        end
                    end
                end
                -- Оптимальная пауза между ударами
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
        
        -- Удаляем физику полета
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
        
        -- Возвращаем коллизии назад
        if character then
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then 
                    part.CanCollide = true 
                    part.CanTouch = true
                end
            end
        end
    end

    -- СТАБИЛИЗАЦИЯ И АНТИ-ПАДЕНИЕ ТВОЕГО ТЕЛА
    connections.mainLoop = RunService.Heartbeat:Connect(function()
        local character = LocalPlayer.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
local hrp = character and character:FindFirstChild("HumanoidRootPart")
if hrp and humanoid and not isKillActive then
hrp.RotVelocity = Vector3.zero
if autoAntiFall and (humanoid:GetState() == Enum.HumanoidStateType.Ragdoll or hrp.Velocity.Y < -6) then
hrp.Velocity = Vector3.new(hrp.Velocity.X, 1, hrp.Velocity.Z)
humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end
end
end)
-- ОБРАБОТКА КЛАВИШ
connections.inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
if gameProcessed then return end
if input.KeyCode == KILL_KEY then
startPhantomKill()
elseif input.KeyCode == MENU_TOGGLE_KEY then
menuVisible = not menuVisible
local mainFrame = CoreGui:FindFirstChild(GUI_NAME) and CoreGui[GUI_NAME]:FindFirstChild("MainFrame")
if mainFrame then mainFrame.Visible = menuVisible end
elseif input.KeyCode == REJOIN_KEY then
pcall(function() TeleportService:Teleport(TARGET_PLACE_ID, LocalPlayer) end)
elseif input.KeyCode == UNLOAD_KEY then
stopPhantomKill()
autoAntiFall = false
for _, connection in pairs(connections) do if connection then connection:Disconnect() end end
connections = {}
if CoreGui:FindFirstChild(GUI_NAME) then CoreGui[GUI_NAME]:Destroy() end
print("Phantom Hub полностью выгружен.")
end
end)
connections.inputEnded = UserInputService.InputEnded:Connect(function(input)
if input.KeyCode == KILL_KEY then
stopPhantomKill()
end
end)
----------------------------------------------------------------
-- ИНТЕРФЕЙС GUI
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
local success, _ = pcall(function() ScreenGui.Parent = CoreGui end)
if not success or not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 230, 0, 235)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 42)
Title.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
Title.Text = "🦅 PHYSICS FLY V22 🦅"
Title.TextColor3 = Color3.fromRGB(0, 255, 128)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 11
Title.BorderSizePixel = 0
Title.Parent = MainFrame
local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = Title
local function createToggle(text, position, default_state, callback)
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 190, 0, 34)
btn.Position = position
btn.Font = Enum.Font.GothamSemibold
btn.TextSize = 11
btn.BorderSizePixel = 0
btn.Parent = MainFrame
local corner = Instance.new("UICorner")
corner.Parent = btn
local state = default_state
local function updateVisual()
btn.BackgroundColor3 = state and Color3.fromRGB(0, 255, 128) or Color3.fromRGB(45, 45, 55)
btn.Text = state and text..": АКТИВЕН" or text..": ВЫКЛЮЧЕН"
btn.TextColor3 = Color3.new(0, 0, 0)
end
updateVisual()
btn.MouseButton1Click:Connect(function()
state = not state
updateVisual()
callback(state)
end)
end
createToggle("🛡️ Анти-Регдолл", UDim2.new(0, 20, 0, 58), true, function(v) autoAntiFall = v end)
local function createBindLabel(text, position)
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(0, 190, 0, 22)
lbl.Position = position
lbl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
lbl.Font = Enum.Font.Gotham
lbl.TextSize = 9
lbl.BorderSizePixel = 0
lbl.Text = text
lbl.Parent = MainFrame
local corner = Instance.new("UICorner")
corner.Parent = lbl
end
createBindLabel("⚡ ЗАЖМИ X: Полёт + Удары ног (Q/E)", UDim2.new(0, 20, 0, 102))
createBindLabel("🔄 НАЖМИ R: Быстрый перезаход", UDim2.new(0, 20, 0, 130))
local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(0, 190, 0, 32)
UnloadBtn.Position = UDim2.new(0, 20, 0, 158)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 35)
UnloadBtn.Text = "🛑 ВЫГРУЗИТЬ СКРИПТ (K)"
UnloadBtn.TextColor3 = Color3.fromRGB(255, 75, 75)
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.TextSize = 10
UnloadBtn.BorderSizePixel = 0
UnloadBtn.Parent = MainFrame
local UnloadCorner = Instance.new("UICorner")
UnloadCorner.Parent = UnloadBtn
UnloadBtn.MouseButton1Click:Connect(function()
stopPhantomKill()
autoAntiFall = false
for _, connection in pairs(connections) do if connection then connection:Disconnect() end end
connections = {}
ScreenGui:Destroy()
end)
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, 0, 0, 20)
Footer.Position = UDim2.new(0, 0, 1, -20)
Footer.BackgroundTransparency = 1
Footer.Text = "[Правый Shift] — Скрыть / Открыть меню"
Footer.TextColor3 = Color3.fromRGB(130, 130, 140)
Footer.Font = Enum.Font.Gotham
Footer.TextSize = 9
Footer.Parent = MainFrame
print("Phantom God Hub v22 успешно загружен!")
end
-- ============================================================================
-- СИСТЕМА КЛЮЧЕЙ
-- ============================================================================
local KeySystemGui = Instance.new("ScreenGui")
KeySystemGui.Name = "PhantomKeyLoader"
KeySystemGui.ResetOnSpawn = false
local keySuccess, _ = pcall(function() KeySystemGui.Parent = CoreGui end)
if not keySuccess or not KeySystemGui.Parent then KeySystemGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
local KeyFrame = Instance.new("Frame")
KeyFrame.Size = UDim2.new(0, 300, 0, 175)
KeyFrame.Position = UDim2.new(0.5, -150, 0.4, -87)
KeyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
KeyFrame.BorderSizePixel = 0
KeyFrame.Active = true
KeyFrame.Draggable = true
KeyFrame.Parent = KeySystemGui
local KeyCorner = Instance.new("UICorner")
KeyCorner.CornerRadius = UDim.new(0, 10)
KeyCorner.Parent = KeyFrame
local KeyTitle = Instance.new("TextLabel")
KeyTitle.Size = UDim2.new(1, 0, 0, 42)
KeyTitle.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
KeyTitle.Text = "🦅 PHANTOM HUB — АВТОРИЗАЦИЯ 🦅"
KeyTitle.TextColor3 = Color3.fromRGB(0, 255, 128)
KeyTitle.Font = Enum.Font.GothamBold
KeyTitle.TextSize = 11
KeyTitle.BorderSizePixel = 0
KeyTitle.Parent = KeyFrame
local TitleCorner2 = Instance.new("UICorner")
TitleCorner2.CornerRadius = UDim.new(0, 10)
TitleCorner2.Parent = KeyTitle
local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(0, 260, 0, 36)
TextBox.Position = UDim2.new(0, 20, 0, 56)
TextBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.Text = ""
TextBox.PlaceholderText = "Введите ключ доступа..."
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 11
TextBox.BorderSizePixel = 0
TextBox.Parent = KeyFrame
local TextCorner = Instance.new("UICorner")
TextCorner.Parent = TextBox
local VerifyBtn = Instance.new("TextButton")
VerifyBtn.Size = UDim2.new(0, 125, 0, 34)
VerifyBtn.Position = UDim2.new(0, 20, 0, 104)
VerifyBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 128)
VerifyBtn.Text = "Проверить ключ"
VerifyBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
VerifyBtn.Font = Enum.Font.GothamBold
VerifyBtn.TextSize = 11
VerifyBtn.BorderSizePixel = 0
VerifyBtn.Parent = KeyFrame
local VerifyCorner = Instance.new("UICorner")
VerifyCorner.Parent = VerifyBtn
local GetKeyBtn = Instance.new("TextButton")
GetKeyBtn.Size = UDim2.new(0, 125, 0, 34)
GetKeyBtn.Position = UDim2.new(0, 155, 0, 104)
GetKeyBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
GetKeyBtn.Text = "Получить ключ"
GetKeyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
GetKeyBtn.Font = Enum.Font.GothamBold
GetKeyBtn.TextSize = 11
GetKeyBtn.BorderSizePixel = 0
GetKeyBtn.Parent = KeyFrame
local GetCorner = Instance.new("UICorner")
GetCorner.Parent = GetKeyBtn
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1, 0, 0, 20)
StatusLbl.Position = UDim2.new(0, 0, 1, -24)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "Введите секретный ключ для разблокировки хаба"
StatusLbl.TextColor3 = Color3.fromRGB(140, 140, 150)
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 9
StatusLbl.Parent = KeyFrame
GetKeyBtn.MouseButton1Click:Connect(function()
if setclipboard then
setclipboard(DISCORD_LINK)
StatusLbl.Text = "Ссылка на Discord скопирована!"
StatusLbl.TextColor3 = Color3.fromRGB(52, 152, 219)
else
StatusLbl.Text = "Ссылка в консоли (F9)"
print("[Phantom Hub] Ссылка: ", DISCORD_LINK)
end
end)
VerifyBtn.MouseButton1Click:Connect(function()
if TextBox.Text == SECRET_KEY then
StatusLbl.Text = "Успешно! Запуск!"
StatusLbl.TextColor3 = Color3.fromRGB(46, 204, 113)
task.wait(0.5)
KeySystemGui:Destroy()
InitializeMainScript()
else
StatusLbl.Text = "Неверный секретный ключ!"
StatusLbl.TextColor3 = Color3.fromRGB(231, 76, 60)
end
end)
