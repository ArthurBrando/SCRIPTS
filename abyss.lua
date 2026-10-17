--[[
    MM2 ULTIMATE HUB - V5
    Todas as funcionalidades em um único arquivo.
    Coloque no GitHub e use:
    loadstring(game:HttpGet("URL_RAW"))()
]]

-- ============================================================
-- SERVIÇOS E CONFIGURAÇÃO INICIAL
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Verifica se a Drawing API está disponível
local hasDrawing = false
pcall(function()
    local d = Drawing.new("Line")
    if d then hasDrawing = true; d:Remove() end
end)

-- Carrega a GUI Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================
-- ESTADO GLOBAL
-- ============================================================
local State = {
    -- ESP
    ESP = {
        Innocent = false, Murder = false, Sheriff = false,
        Line = false, Box = false, Skeleton = false, Name = false,
        Triangle = false, HeadDot = false, HealthBar = false, Distance = false,
        Hologram = false
    },
    -- Cores
    Colors = {
        Innocent = Color3.fromRGB(0, 255, 0),
        Murder   = Color3.fromRGB(255, 0, 0),
        Sheriff  = Color3.fromRGB(0, 100, 255),
        Gun      = Color3.fromRGB(255, 215, 0)
    },
    -- Teleporte
    TP = {
        AllLoop = false,
        CoinLoop = false,
        CoinSpeed = 50,
        CoinWait = 0.8,
        CoinLimit = 0,
        CoinCount = 0
    },
    -- Combate
    Combat = {
        KillAll = false,
        AutoShoot = false,
        SilentAim = false,
        Aimbot = false,
        AimbotSmooth = 0.15,
        FlingAll = false,
        AutoFlingMurder = false
    },
    -- Movimento
    Move = {
        WalkSpeed = 16,
        JumpPower = 50,
        InfiniteJump = false,
        Noclip = false,
        Fly = false,
        FlySpeed = 50,
        AntiFling = false
    },
    -- Farm
    Farm = {
        AutoGrabGun = false,
        AutoGrabKnife = false,
        AutoFarmCoins = false
    },
    -- Misc
    Misc = {
        Fullbright = false,
        AntiAFK = false,
        GodMode = false
    }
}

-- Cache de roles
local RoleCache = {}
local LastChar = {}

-- ============================================================
-- FUNÇÕES AUXILIARES
-- ============================================================

-- Verifica ferramentas em um container
local function checkTools(container)
    if not container then return nil end
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Tool") then
            if obj.Name == "Knife" then return "Murder" end
            if obj.Name == "Gun"   then return "Sheriff" end
        end
    end
    return nil
end

-- Atualiza o cache de roles
local function updateRoleCache()
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local bp   = player:FindFirstChild("Backpack")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if not char or not hum or hum.Health <= 0 then
            RoleCache[player] = nil
        end

        local role = checkTools(char) or checkTools(bp)
        if role then
            RoleCache[player] = role
        elseif not RoleCache[player] then
            RoleCache[player] = "Innocent"
        end
    end
end

-- Retorna a role de um jogador
local function getRole(player)
    return RoleCache[player] or "Innocent"
end

-- Retorna a cor da role
local function getRoleColor(role)
    if role == "Murder"  then return State.Colors.Murder  end
    if role == "Sheriff" then return State.Colors.Sheriff end
    return State.Colors.Innocent
end

-- Obtém o HumanoidRootPart do jogador local
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart"), char
end

-- Teleporte instantâneo
local function teleportTo(pos)
    local hrp = getHRP()
    if hrp and pos then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

-- Teleporte suave com Tween
local function smoothTeleport(pos, speed)
    local hrp = getHRP()
    if not hrp or not pos then return end
    speed = speed or 100
    local start = hrp.Position
    local dest  = pos + Vector3.new(0, 3, 0)
    local dist  = (dest - start).Magnitude
    if dist < 1 then return end
    local dur = math.clamp(dist / speed, 0.05, 8)
    local anchored = hrp.Anchored
    hrp.Anchored = true
    local tw = TweenService:Create(hrp,
        TweenInfo.new(dur, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(dest) })
    tw:Play()
    tw.Completed:Wait()
    if hrp and hrp.Parent then hrp.Anchored = anchored end
end

-- Verifica se uma ferramenta está equipada por alguém
local function isEquippedByAnyone(tool)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and plr.Character:FindFirstChild(tool.Name) == tool then
            return true
        end
    end
    return false
end

-- Encontra uma ferramenta caída
local function findDroppedTool(toolName)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") and obj.Name == toolName and not isEquippedByAnyone(obj) then
            return obj
        end
    end
    return nil
end

-- Encontra todas as moedas
local function findCoins()
    local coins = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("MeshPart") then
            local n = obj.Name:lower()
            if n:find("coin") or n:find("moeda") then
                table.insert(coins, obj)
            end
        end
    end
    return coins
end

-- Encontra um jogador por role
local function findPlayerByRole(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == role and p.Character then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then return p end
        end
    end
    return nil
end

-- Verifica se o jogador local tem a arma
local function hasGun()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Gun") then return true end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Gun") then return true end
    return false
end

-- Verifica se o jogador local tem a faca
local function hasKnife()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Knife") then return true end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Knife") then return true end
    return false
end

-- ============================================================
-- GUI - CRIAÇÃO DAS ABAS
-- ============================================================
local Window = Rayfield:CreateWindow({
    Name = "MM2 Ultimate Hub V5",
    LoadingTitle = "Carregando...",
    LoadingSubtitle = "V5",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local TabESP     = Window:CreateTab("ESP", 4483362458)
local TabMurder  = Window:CreateTab("Murder", 4483362458)
local TabSheriff = Window:CreateTab("Sheriff", 4483362458)
local TabTeleport= Window:CreateTab("Teleport", 4483362458)
local TabFarm    = Window:CreateTab("Farm", 4483362458)
local TabMisc    = Window:CreateTab("Misc", 4483362458)

-- ============================================================
-- ABA ESP
-- ============================================================
TabESP:CreateSection("ESP Base")
TabESP:CreateToggle({ Name="Inocentes (Verde)", CurrentValue=false, Flag="espInnocent", Callback=function(v) State.ESP.Innocent=v end })
TabESP:CreateToggle({ Name="Murder (Vermelho)", CurrentValue=false, Flag="espMurder",   Callback=function(v) State.ESP.Murder=v   end })
TabESP:CreateToggle({ Name="Sheriff (Azul)",    CurrentValue=false, Flag="espSheriff",  Callback=function(v) State.ESP.Sheriff=v  end })

TabESP:CreateSection("Estilos (Drawing API)")
if not hasDrawing then
    TabESP:CreateLabel("⚠ Seu executor não suporta Drawing API. Apenas Highlight funcionará.")
end
TabESP:CreateToggle({ Name="Linha (Tracer)", CurrentValue=false, Flag="espLine",     Callback=function(v) State.ESP.Line=v     end })
TabESP:CreateToggle({ Name="Box",            CurrentValue=false, Flag="espBox",      Callback=function(v) State.ESP.Box=v      end })
TabESP:CreateToggle({ Name="Skeleton",       CurrentValue=false, Flag="espSkeleton", Callback=function(v) State.ESP.Skeleton=v end })
TabESP:CreateToggle({ Name="Nome + Role",    CurrentValue=false, Flag="espName",     Callback=function(v) State.ESP.Name=v     end })
TabESP:CreateToggle({ Name="Triângulo",      CurrentValue=false, Flag="espTriangle", Callback=function(v) State.ESP.Triangle=v end })
TabESP:CreateToggle({ Name="Head Dot",       CurrentValue=false, Flag="espHeadDot",  Callback=function(v) State.ESP.HeadDot=v  end })
TabESP:CreateToggle({ Name="Health Bar",     CurrentValue=false, Flag="espHealth",   Callback=function(v) State.ESP.HealthBar=v end })
TabESP:CreateToggle({ Name="Distância",      CurrentValue=false, Flag="espDistance", Callback=function(v) State.ESP.Distance=v end })
TabESP:CreateToggle({ Name="Holograma RGB",  CurrentValue=false, Flag="espHologram", Callback=function(v) State.ESP.Hologram=v end })

TabESP:CreateSection("Cores")
TabESP:CreateColorPicker({ Name="Cor Inocente", Color=State.Colors.Innocent, Flag="colInnocent", Callback=function(c) State.Colors.Innocent=c end })
TabESP:CreateColorPicker({ Name="Cor Murder",   Color=State.Colors.Murder,   Flag="colMurder",   Callback=function(c) State.Colors.Murder=c   end })
TabESP:CreateColorPicker({ Name="Cor Sheriff",  Color=State.Colors.Sheriff,  Flag="colSheriff",  Callback=function(c) State.Colors.Sheriff=c  end })
TabESP:CreateColorPicker({ Name="Cor Gun",      Color=State.Colors.Gun,      Flag="colGun",      Callback=function(c) State.Colors.Gun=c      end })

-- ============================================================
-- ABA MURDER
-- ============================================================
TabMurder:CreateSection("Combate")
TabMurder:CreateToggle({
    Name = "Kill All (Teleporta e Mata)",
    CurrentValue = false, Flag = "killAll",
    Callback = function(v) State.Combat.KillAll = v end
})
TabMurder:CreateToggle({
    Name = "Auto Fling Murder",
    CurrentValue = false, Flag = "autoFling",
    Callback = function(v) State.Combat.AutoFlingMurder = v end
})

TabMurder:CreateSection("Teleporte")
TabMurder:CreateToggle({
    Name = "Teleportar para Todos (Loop)",
    CurrentValue = false, Flag = "tpAll",
    Callback = function(v) State.TP.AllLoop = v end
})

TabMurder:CreateSection("Farm de Coins")
TabMurder:CreateToggle({
    Name = "Flutuar pelas Moedas",
    CurrentValue = false, Flag = "coinFloat",
    Callback = function(v) State.TP.CoinLoop = v end
})
TabMurder:CreateSlider({
    Name = "Velocidade do Flutuar", Range = {20, 200}, Increment = 10, Suffix = " studs/s",
    CurrentValue = 50, Flag = "coinSpeed",
    Callback = function(v) State.TP.CoinSpeed = v end
})
TabMurder:CreateSlider({
    Name = "Pausa entre Moedas", Range = {0.2, 3}, Increment = 0.1, Suffix = " s",
    CurrentValue = 0.8, Flag = "coinWait",
    Callback = function(v) State.TP.CoinWait = v end
})
TabMurder:CreateInput({
    Name = "Limite de Coins (0 = infinito)",
    CurrentValue = "50", PlaceholderText = "Ex: 50",
    RemoveTextAfterFocusLost = false, Flag = "coinLimit",
    Callback = function(txt)
        local n = tonumber(txt)
        if n and n >= 0 then State.TP.CoinLimit = n end
    end
})

-- ============================================================
-- ABA SHERIFF
-- ============================================================
TabSheriff:CreateSection("Combate")
TabSheriff:CreateToggle({
    Name = "Auto Shoot (atira sozinho no Murder)",
    CurrentValue = false, Flag = "autoShoot",
    Callback = function(v) State.Combat.AutoShoot = v end
})
TabSheriff:CreateToggle({
    Name = "Aimbot (trava câmera no Murder)",
    CurrentValue = false, Flag = "aimbot",
    Callback = function(v) State.Combat.Aimbot = v end
})
TabSheriff:CreateSlider({
    Name = "Suavidade do Aimbot", Range = {0.02, 0.5}, Increment = 0.01, Suffix = "",
    CurrentValue = 0.15, Flag = "aimbotSmooth",
    Callback = function(v) State.Combat.AimbotSmooth = v end
})
TabSheriff:CreateToggle({
    Name = "Silent Aim (redireciona tiros)",
    CurrentValue = false, Flag = "silentAim",
    Callback = function(v) State.Combat.SilentAim = v end
})

TabSheriff:CreateSection("Arma Caída")
TabSheriff:CreateToggle({
    Name = "Auto Grab Gun",
    CurrentValue = false, Flag = "autoGrabGun",
    Callback = function(v) State.Farm.AutoGrabGun = v end
})
TabSheriff:CreateButton({
    Name = "Teleportar para Gun Caída",
    Callback = function()
        local gun = findDroppedTool("Gun")
        if gun and gun:FindFirstChild("Handle") then
            smoothTeleport(gun.Handle.Position, 120)
        else
            Rayfield:Notify({Title="Erro", Content="Gun não encontrada", Duration=3})
        end
    end
})

-- ============================================================
-- ABA TELEPORT
-- ============================================================
TabTeleport:CreateSection("Jogadores")
TabTeleport:CreateButton({
    Name = "Teleportar para Murder",
    Callback = function()
        local p = findPlayerByRole("Murder")
        if p and p.Character then
            smoothTeleport(p.Character.HumanoidRootPart.Position, 120)
        else
            Rayfield:Notify({Title="Aviso", Content="Nenhum Murder vivo", Duration=3})
        end
    end
})
TabTeleport:CreateButton({
    Name = "Teleportar para Sheriff",
    Callback = function()
        local p = findPlayerByRole("Sheriff")
        if p and p.Character then
            smoothTeleport(p.Character.HumanoidRootPart.Position, 120)
        else
            Rayfield:Notify({Title="Aviso", Content="Nenhum Sheriff vivo", Duration=3})
        end
    end
})
TabTeleport:CreateButton({
    Name = "Teleportar para Lobby",
    Callback = function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("lobby") then
                smoothTeleport(obj.Position, 120)
                return
            end
        end
        Rayfield:Notify({Title="Erro", Content="Lobby não encontrado", Duration=3})
    end
})

-- ============================================================
-- ABA FARM
-- ============================================================
TabFarm:CreateSection("Auto Grab")
TabFarm:CreateToggle({
    Name = "Auto Grab Gun",
    CurrentValue = false, Flag = "autoGrabGunFarm",
    Callback = function(v) State.Farm.AutoGrabGun = v end
})
TabFarm:CreateToggle({
    Name = "Auto Grab Knife",
    CurrentValue = false, Flag = "autoGrabKnife",
    Callback = function(v) State.Farm.AutoGrabKnife = v end
})
TabFarm:CreateToggle({
    Name = "Auto Farm Coins (Teleporte)",
    CurrentValue = false, Flag = "autoFarmCoins",
    Callback = function(v) State.Farm.AutoFarmCoins = v end
})

-- ============================================================
-- ABA MISC
-- ============================================================
TabMisc:CreateSection("Movimento")
TabMisc:CreateSlider({
    Name = "WalkSpeed", Range = {16, 200}, Increment = 1, Suffix = " studs/s",
    CurrentValue = 16, Flag = "ws",
    Callback = function(v) State.Move.WalkSpeed = v end
})
TabMisc:CreateSlider({
    Name = "JumpPower", Range = {50, 300}, Increment = 1, Suffix = "",
    CurrentValue = 50, Flag = "jp",
    Callback = function(v) State.Move.JumpPower = v end
})
TabMisc:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false, Flag = "infJump",
    Callback = function(v) State.Move.InfiniteJump = v end
})
TabMisc:CreateToggle({
    Name = "Noclip",
    CurrentValue = false, Flag = "noclip",
    Callback = function(v) State.Move.Noclip = v end
})
TabMisc:CreateToggle({
    Name = "Fly",
    CurrentValue = false, Flag = "fly",
    Callback = function(v)
        State.Move.Fly = v
        local hrp = getHRP()
        if hrp then
            if v then
                hrp.Anchored = true
            else
                hrp.Anchored = false
            end
        end
    end
})

TabMisc:CreateSection("Utilidades")
TabMisc:CreateToggle({
    Name = "Fullbright",
    CurrentValue = false, Flag = "fullbright",
    Callback = function(v)
        State.Misc.Fullbright = v
        if v then
            Lighting.Brightness = 3
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 2
            Lighting.GlobalShadows = true
        end
    end
})
TabMisc:CreateToggle({
    Name = "Anti-Fling",
    CurrentValue = false, Flag = "antiFling",
    Callback = function(v) State.Move.AntiFling = v end
})

-- ============================================================
-- SISTEMA DE HIGHLIGHT (ESP)
-- ============================================================
local Highlights = {} -- [player] = Highlight

local function removeHighlight(player)
    if Highlights[player] then
        pcall(function() Highlights[player]:Destroy() end)
        Highlights[player] = nil
    end
    -- Também limpa qualquer highlight órfão no personagem
    if player.Character then
        for _, obj in ipairs(player.Character:GetChildren()) do
            if obj:IsA("Highlight") and obj.Name == "MM2_ESP" then
                obj:Destroy()
            end
        end
    end
end

local function clearAllHighlights()
    for player, _ in pairs(Highlights) do
        removeHighlight(player)
    end
    Highlights = {}
end

-- Loop principal de ESP
RunService.RenderStepped:Connect(function()
    updateRoleCache()

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        -- Se o personagem mudou (respawn), limpa o highlight antigo
        if char and LastChar[player] and LastChar[player] ~= char then
            removeHighlight(player)
        end
        LastChar[player] = char

        -- Se não há personagem vivo, remove o ESP e continua
        if not char or not hum or hum.Health <= 0 then
            removeHighlight(player)
            continue
        end

        local role  = getRole(player)
        local color = getRoleColor(role)

        local shouldShow = (role == "Innocent" and State.ESP.Innocent)
                        or (role == "Murder"   and State.ESP.Murder)
                        or (role == "Sheriff"  and State.ESP.Sheriff)

        if shouldShow then
            local hl = Highlights[player]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.Name = "MM2_ESP"
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.OutlineTransparency = 0
                hl.Parent = char
                Highlights[player] = hl
            end
            hl.Adornee = char
            hl.Enabled = true

            if State.ESP.Hologram then
                local hue = (tick() * 0.4) % 1
                hl.FillColor    = Color3.fromHSV(hue, 1, 1)
                hl.OutlineColor = Color3.fromHSV((hue + 0.5) % 1, 1, 1)
                hl.FillTransparency = 0.2
            else
                hl.FillColor = color
                hl.OutlineColor = color
                hl.FillTransparency = 0.5
            end
        else
            removeHighlight(player)
        end
    end
end)

-- Limpa highlights quando um jogador sai
Players.PlayerRemoving:Connect(function(player)
    removeHighlight(player)
    LastChar[player] = nil
end)

-- ============================================================
-- LOOPS DE COMBATE E UTILIDADES
-- ============================================================

-- Kill All (teleporta e mata)
task.spawn(function()
    while true do
        task.wait(0.2)
        if State.Combat.KillAll and hasKnife() then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        -- Teleporta para o jogador
                        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            teleportTo(hrp.Position)
                            task.wait(0.1)
                            -- Tenta equipar a faca e atacar
                            local knife = LocalPlayer.Character:FindFirstChild("Knife")
                            if knife then
                                knife:Activate()
                            end
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
end)

-- Auto Shoot (atira sozinho no murder)
task.spawn(function()
    while true do
        task.wait(0.1)
        if State.Combat.AutoShoot and hasGun() then
            local murderer = findPlayerByRole("Murder")
            if murderer and murderer.Character then
                local head = murderer.Character:FindFirstChild("Head")
                if head then
                    -- Mira no murder
                    local myHRP = getHRP()
                    if myHRP then
                        Camera.CFrame = CFrame.new(myHRP.Position, head.Position)
                        -- Simula clique
                        VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,1)
                        task.wait(0.05)
                        VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,1)
                    end
                end
            end
        end
    end
end)

-- Aimbot (trava a câmera no murder)
RunService.RenderStepped:Connect(function()
    if State.Combat.Aimbot and hasGun() then
        local murderer = findPlayerByRole("Murder")
        if murderer and murderer.Character then
            local head = murderer.Character:FindFirstChild("Head")
            local myHRP = getHRP()
            if head and myHRP then
                local targetCF = CFrame.new(myHRP.Position, head.Position)
                Camera.CFrame = Camera.CFrame:Lerp(targetCF, State.Combat.AimbotSmooth)
            end
        end
    end
end)

-- Teleportar para Todos (Loop)
task.spawn(function()
    while true do
        task.wait(0.5)
        if State.TP.AllLoop then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        teleportTo(hrp.Position)
                        task.wait(0.4)
                    end
                end
            end
        end
    end
end)

-- Flutuar pelas Moedas
task.spawn(function()
    while true do
        task.wait(0.3)
        if State.TP.CoinLoop then
            if State.TP.CoinLimit > 0 and State.TP.CoinCount >= State.TP.CoinLimit then
                State.TP.CoinLoop = false
                Rayfield:Notify({Title="Coins", Content="Limite atingido!", Duration=4})
                continue
            end
            local coins = findCoins()
            for _, coin in ipairs(coins) do
                if not State.TP.CoinLoop then break end
                if coin and coin.Parent then
                    smoothTeleport(coin.Position, State.TP.CoinSpeed)
                    State.TP.CoinCount = State.TP.CoinCount + 1
                    task.wait(State.TP.CoinWait)
                end
            end
        end
    end
end)

-- Auto Grab Gun / Knife
task.spawn(function()
    while true do
        task.wait(0.5)
        if State.Farm.AutoGrabGun then
            local gun = findDroppedTool("Gun")
            if gun and gun:FindFirstChild("Handle") then
                smoothTeleport(gun.Handle.Position, 200)
            end
        end
        if State.Farm.AutoGrabKnife then
            local knife = findDroppedTool("Knife")
            if knife and knife:FindFirstChild("Handle") then
                smoothTeleport(knife.Handle.Position, 200)
            end
        end
    end
end)

-- Auto Farm Coins (modo teleporte)
task.spawn(function()
    while true do
        task.wait(0.2)
        if State.Farm.AutoFarmCoins then
            local coins = findCoins()
            for _, coin in ipairs(coins) do
                if coin and coin.Parent then
                    teleportTo(coin.Position)
                    task.wait(0.1)
                end
            end
        end
    end
end)

-- Movimento (WalkSpeed, JumpPower, Noclip, Fly)
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.WalkSpeed = State.Move.WalkSpeed
        hum.JumpPower = State.Move.JumpPower
    end

    if State.Move.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    if State.Move.Fly then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hum then
            hum.PlatformStand = true
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + moveDir * (State.Move.FlySpeed / 60)
            end
        end
    else
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if State.Move.InfiniteJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Anti-Fling
RunService.Heartbeat:Connect(function()
    if not State.Move.AntiFling then return end
    local hrp = getHRP()
    if hrp then
        hrp.AssemblyAngularVelocity = Vector3.new(0,0,0)
    end
end)

-- ============================================================
-- NOTIFICAÇÃO FINAL
-- ============================================================
Rayfield:Notify({
    Title = "MM2 Ultimate Hub V5",
    Content = "Carregado! " .. (hasDrawing and "Drawing API OK ✅" or "Drawing API indisponível ⚠"),
    Duration = 6
})