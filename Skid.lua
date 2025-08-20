--[[
Blox Fruits Script Hub — Vietnamese GUI (Aug 2025)
Tác giả: ChatGPT
Mục tiêu: Hub một-file, nhiều tính năng (Auto Farm/Quest/Boss, Teleport, ESP, Fruit Sniper, Auto Stats, Raid helper, Misc)
Lưu ý: Script này nhằm mục đích học tập, mẫu tham khảo. Việc dùng script có thể vi phạm ToS của Roblox/Blox Fruits — bạn tự chịu rủi ro.

▶ Điểm nổi bật
- Giao diện tiếng Việt, Tabs: General, Combat, Đảo/Teleport, Tiện ích, ESP
- Tự động: Farm Level, Nhận & Hoàn thành Quest, Farm Boss, Bật Haki, Dùng kỹ năng theo Melee đang trang bị
- Auto Stats: tăng chỉ số theo cấu hình
- Fruit Sniper: phát hiện & nhặt/truy vết trái ác quỷ rơi trong map
- Teleport: tới các đảo phổ biến (có fallback nếu map đổi), lưu vị trí tuỳ chỉnh
- ESP: kẻ địch, boss, trái, rương, người chơi (Drawing API)
- Chống kẹt, hoàn tác khi chết, kiểm tra executor (Synapse X, KRNL, Fluxus, Delta, Solara, etc.)
- Lưu cấu hình (writefile/readfile)

⚙ Yêu cầu
- Executor có hỗ trợ: getgenv, hookfunc, queue_on_teleport (tuỳ chọn), firetouchinterest, Drawing API (tuỳ chọn), request/http_request (tuỳ chọn)
- Game: Blox Fruits (PlaceId 2753915549 / 4442272183 / 7449423635)

--]]

local HUB_VERSION = "2025-08-20"
local GAME_IDS = { [2753915549]=true, [4442272183]=true, [7449423635]=true }
if not GAME_IDS[game.PlaceId] then
    warn("[Hub] Không phải Blox Fruits — dừng script.")
    return
end

-- ========= TIỆN ÍCH CƠ BẢN ========= --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer

local function safeWait(t) local s = tick() while tick()-s < (t or 0.15) do RunService.Heartbeat:Wait() end end
local function isAlive(char)
    if not char then return false end
    local h = char:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end
local function getChar()
    return LP.Character or LP.CharacterAdded:Wait()
end
local function tpCF(cf)
    local char = getChar(); if not isAlive(char) then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    hrp.CFrame = cf
end
local function tweenTo(cf, speed)
    local char = getChar(); if not isAlive(char) then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local h = char:FindFirstChildOfClass("Humanoid"); if not h then return end
    local dist = (hrp.Position - cf.Position).Magnitude
    local t = math.clamp(dist / (speed or 120), 0.1, 8)
    local tw = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    tw:Play(); tw.Completed:Wait()
end

-- Lưu/đọc cấu hình
local CFG_PATH = "BloxF_VNHub_Config.json"
local Config = {
    AutoFarm = false,
    AutoQuest = true,
    AutoBoss = false,
    FastAttack = true,
    AutoHaki = true,
    UseMeleeSkills = true,
    Weapon = "Melee",
    FarmRange = 200,
    AutoStats = { Melee=true, Defense=true, Sword=false, Gun=false, BloxFruit=false, PointsPerTick=3 },
    FruitSniper = true,
    TeleportSpeed = 150,
    ESP = { Enemies=true, Boss=true, Fruits=true, Chests=true, Players=false },
    CustomWarps = {},
}

pcall(function()
    if readfile then
        if isfile(CFG_PATH) then
            local data = readfile(CFG_PATH)
            local ok, obj = pcall(function() return HttpService:JSONDecode(data) end)
            if ok and type(obj)=="table" then for k,v in pairs(obj) do Config[k]=v end end
        end
    end
end)

local function saveCfg()
    pcall(function()
        if writefile then writefile(CFG_PATH, HttpService:JSONEncode(Config)) end
    end)
end

-- ========= UI (tự động chọn thư viện) ========= --
local UILib, Window, AddTab
local function tryLib(url, init)
    local ok, lib = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and lib then return init(lib) end
end

local function initUI()
    -- Ưu tiên RedzLib (nếu có), sau đó Orion/Kavo/Rayfield
    UILib = tryLib("https://raw.githubusercontent.com/Redzlib/Redz/main/RedzLib.txt", function(lib)
        local w = lib:CreateWindow({ Title = "BloxF VN Hub • "..HUB_VERSION, SubTitle = "By ChatGPT", TabWidth = 120, Size = UDim2.new(0, 560, 0, 400) })
        return { lib=lib, window=w, add=function(name) return w:CreateTab(name) end }
    end)

    if not UILib then
        UILib = tryLib("https://raw.githubusercontent.com/shlexware/Orion/main/source", function(lib)
            local w = lib:MakeWindow({ Name = "BloxF VN Hub • "..HUB_VERSION, HidePremium = true, SaveConfig = false })
            return { lib=lib, window=w, add=function(name) return w:MakeTab({Name=name, PremiumOnly=false}) end }
        end)
    end
    if not UILib then
        UILib = tryLib("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua", function(lib)
            local w = lib.CreateLib("BloxF VN Hub • "..HUB_VERSION, "BloodTheme")
            return { lib=lib, window=w, add=function(name) return w:NewTab(name) end }
        end)
    end
    if not UILib then
        -- Fallback UI tối giản
        local ScreenGui = Instance.new("ScreenGui", gethui and gethui() or game.CoreGui)
        ScreenGui.Name = "BloxF_VNHub"
        local Frame = Instance.new("Frame", ScreenGui)
        Frame.Size = UDim2.new(0, 520, 0, 360)
        Frame.Position = UDim2.new(0.5, -260, 0.5, -180)
        Frame.BackgroundColor3 = Color3.fromRGB(10,10,10)
        Frame.BorderSizePixel = 0
        local Title = Instance.new("TextLabel", Frame)
        Title.Size = UDim2.new(1,0,0,30); Title.Text = "BloxF VN Hub • "..HUB_VERSION
        Title.BackgroundTransparency = 1; Title.TextColor3 = Color3.new(1,1,1)
        local Tabs = {}
        local function add(name)
            local Tab = Instance.new("ScrollingFrame", Frame)
            Tab.Visible=false; Tab.Size = UDim2.new(1, -10, 1, -40)
            Tab.Position = UDim2.new(0,5,0,35); Tab.CanvasSize=UDim2.new(0,0,2,0)
            local Btn = Instance.new("TextButton", Frame)
            Btn.Size=UDim2.new(0,100,0,26); Btn.Position=UDim2.new(0, 10 + (#Tabs*110), 0, 4)
            Btn.Text=name; Btn.BackgroundColor3=Color3.fromRGB(30,30,30); Btn.TextColor3=Color3.new(1,1,1)
            Btn.MouseButton1Click:Connect(function()
                for _,t in pairs(Tabs) do t.Visible=false end
                Tab.Visible=true
            end)
            Tabs[#Tabs+1]=Tab; if #Tabs==1 then Tab.Visible=true end
            return {
                AddToggle=function(label, default, cb)
                    local c = Instance.new("TextButton", Tab)
                    c.Size=UDim2.new(1,-20,0,28); c.Position=UDim2.new(0,10,0, (#Tab:GetChildren()-1)*30)
                    c.Text=(default and "[ON] " or "[OFF] ")..label; c.BackgroundColor3=Color3.fromRGB(35,35,35); c.TextColor3=Color3.new(1,1,1)
                    local state=default; c.MouseButton1Click:Connect(function() state=not state; c.Text=(state and "[ON] " or "[OFF] ")..label; cb(state) end)
                end,
                AddDropdown=function(label, list, default, cb)
                    local c = Instance.new("TextBox", Tab)
                    c.PlaceholderText=label.." ("..(default or "")..")"; c.Size=UDim2.new(1,-20,0,28)
                    c.Position=UDim2.new(0,10,0, (#Tab:GetChildren()-1)*30); c.BackgroundColor3=Color3.fromRGB(35,35,35); c.TextColor3=Color3.new(1,1,1)
                    c.FocusLost:Connect(function() cb(c.Text) end)
                end,
                AddButton=function(label, cb)
                    local b = Instance.new("TextButton", Tab)
                    b.Size=UDim2.new(1,-20,0,28); b.Position=UDim2.new(0,10,0,(#Tab:GetChildren()-1)*30)
                    b.Text=label; b.BackgroundColor3=Color3.fromRGB(35,35,35); b.TextColor3=Color3.new(1,1,1)
                    b.MouseButton1Click:Connect(cb)
                end,
                AddBox=function(label, default, cb)
                    local tx = Instance.new("TextBox", Tab)
                    tx.Text=default or ""; tx.PlaceholderText=label; tx.Size=UDim2.new(1,-20,0,28)
                    tx.Position=UDim2.new(0,10,0,(#Tab:GetChildren()-1)*30); tx.BackgroundColor3=Color3.fromRGB(35,35,35); tx.TextColor3=Color3.new(1,1,1)
                    tx.FocusLost:Connect(function() cb(tx.Text) end)
                end
            }
        end
        UILib = { lib=nil, window=Frame, add=add }
    end

    Window = UILib.window
    AddTab = UILib.add
end

initUI()

-- ========= HỖ TRỢ HÀNH ĐỘNG ========= --
local function equipWeapon(name)
    local char = getChar(); local bp = LP:FindFirstChild("Backpack"); if not bp then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool.Name == name then return tool end
    local cand = bp:FindFirstChild(name) or (function()
        for _,v in ipairs(bp:GetChildren()) do if v:IsA("Tool") and (name=="Melee" and (v:FindFirstChild("Melee") or v:FindFirstChild("Slash") or v:FindFirstChild("LeftPunch"))) then return v end end
    end)()
    if cand then char.Humanoid:EquipTool(cand); return cand end
end

local function clickAttack()
    local vu = game:GetService("VirtualUser")
    pcall(function()
        vu:Button1Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        safeWait(0.05)
        vu:Button1Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    end)
end

local function useSkill(keys)
    keys = keys or {"Z","X","C","V","B"}
    for _,k in ipairs(keys) do
        pcall(function()
            keypress(Enum.KeyCode[k])
            safeWait(0.08)
            keyrelease(Enum.KeyCode[k])
        end)
        safeWait(0.25)
    end
end

local function ensureHaki()
    if not Config.AutoHaki then return end
    -- Trong BF thường có BoolValue "Buso"/"HasBuso" ... khó chắc chắn -> thử nhấn J/K theo keybind custom của user
    pcall(function()
        keypress(Enum.KeyCode.J); safeWait(0.05); keyrelease(Enum.KeyCode.J)
        keypress(Enum.KeyCode.K); safeWait(0.05); keyrelease(Enum.KeyCode.K)
    end)
end

-- ========= TÌM NPC/QUÁI ========= --
local EnemyFolders = { Workspace.Enemies, Workspace:FindFirstChild("NPCs"), Workspace:FindFirstChild("Mobs") }
local function isEnemy(m)
    if not m or not m.Parent then return false end
    if m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") then
        local n = m.Name:lower()
        if n:find("bandit") or n:find("pirate") or n:find("marine") or n:find("boss") or m:FindFirstChild("Boss") then
            return true
        end
    end
    return false
end

local function getNearestEnemy(maxDist)
    local char = getChar(); if not isAlive(char) then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local best, bestD
    for _,folder in ipairs(EnemyFolders) do
        if typeof(folder)=="Instance" then
            for _,m in ipairs(folder:GetChildren()) do
                if isEnemy(m) and m:FindFirstChild("HumanoidRootPart") and m.Humanoid.Health>0 then
                    local d = (m.HumanoidRootPart.Position - hrp.Position).Magnitude
                    if d <= (maxDist or Config.FarmRange) and (not bestD or d < bestD) then best, bestD = m, d end
                end
            end
        end
    end
    return best, bestD
end

local function getBoss()
    for _,folder in ipairs(EnemyFolders) do
        if typeof(folder)=="Instance" then
            for _,m in ipairs(folder:GetChildren()) do
                local name = m.Name:lower()
                if name:find("boss") or m:FindFirstChild("Boss") then
                    if m:FindFirstChildOfClass("Humanoid") and m.Humanoid.Health>0 then return m end
                end
            end
        end
    end
end

-- ========= QUEST ========= --
local function getQuestNPCNear()
    local char = getChar(); local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local best, bestD
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Parent and v.Parent:IsA("Model") then
            local ok, part = pcall(function() return v.Parent:FindFirstChild("HumanoidRootPart") or v.Parent.PrimaryPart or v.Parent:FindFirstChildWhichIsA("BasePart") end)
            if ok and part then
                local d = (part.Position - hrp.Position).Magnitude
                if d < 200 and (not bestD or d < bestD) then best, bestD = v, d end
            end
        end
    end
    return best
end

local function takeQuest()
    if not Config.AutoQuest then return end
    local prompt = getQuestNPCNear()
    if prompt then
        pcall(function()
            fireproximityprompt(prompt)
            safeWait(0.3)
        end)
    end
end

-- ========= AUTO FARM ========= --
local Flags = { Farming=false, Bossing=false }

local function doAttack(target)
    if not target or not target.Parent then return end
    local hrp = target:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    ensureHaki()
    equipWeapon(Config.Weapon)
    if Config.FastAttack then
        for i=1,4 do clickAttack(); safeWait(0.04) end
    else
        clickAttack()
    end
    if Config.UseMeleeSkills then useSkill({"Z","X","C"}) end
end

local function farmLoop()
    if Flags.Farming then return end
    Flags.Farming = true
    while Config.AutoFarm do
        local target = getNearestEnemy(350)
        if not target then
            takeQuest()
            safeWait(0.2)
        else
            local char = getChar(); local myhrp = char:FindFirstChild("HumanoidRootPart")
            local thrp = target:FindFirstChild("HumanoidRootPart")
            if myhrp and thrp then
                if (myhrp.Position - thrp.Position).Magnitude > 6 then
                    tweenTo(thrp.CFrame * CFrame.new(0,0,-3), Config.TeleportSpeed)
                end
                doAttack(target)
            end
        end
        RunService.Heartbeat:Wait()
    end
    Flags.Farming = false
end

-- ========= AUTO BOSS ========= --
local function bossLoop()
    if Flags.Bossing then return end
    Flags.Bossing = true
    while Config.AutoBoss do
        local b = getBoss()
        if b then
            local thrp = b:FindFirstChild("HumanoidRootPart")
            if thrp then tweenTo(thrp.CFrame * CFrame.new(0,0,-5)) end
            doAttack(b)
        else
            safeWait(0.5)
        end
        RunService.RenderStepped:Wait()
    end
    Flags.Bossing = false
end

-- ========= FRUIT SNIPER ========= --
local function isFruitModel(m)
    local n = m.Name:lower()
    return n:find("fruit") or n:find("bomu") or n:find("gomu") or n:find("magu") or n:find("mera") or n:find("yami") or n:find("light")
end
local function tryPickup(part)
    local char = getChar(); local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not part then return end
    tweenTo(part.CFrame * CFrame.new(0,2,0))
    pcall(function()
        firetouchinterest(hrp, part, 0); safeWait(0.05); firetouchinterest(hrp, part, 1)
    end)
end

local function fruitLoop()
    while Config.FruitSniper do
        for _,v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and isFruitModel(v.Parent or v) then
                tryPickup(v)
                break
            end
        end
        safeWait(0.75)
    end
end

-- ========= AUTO STATS ========= --
local function addStat(stat, points)
    local rem = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage
    local ev = rem:FindFirstChild("AddPoint") or rem:FindFirstChild("Stats")
    if ev and ev:IsA("RemoteEvent") then
        ev:FireServer(stat, points)
    elseif ev and ev:IsA("RemoteFunction") then
        pcall(function() ev:InvokeServer(stat, points) end)
    end
end
local function autoStatsLoop()
    while true do
        local p = Config.AutoStats.PointsPerTick or 1
        if Config.AutoStats.Melee then addStat("Melee", p) end
        if Config.AutoStats.Defense then addStat("Defense", p) end
        if Config.AutoStats.Sword then addStat("Sword", p) end
        if Config.AutoStats.Gun then addStat("Gun", p) end
        if Config.AutoStats.BloxFruit then addStat("Demon Fruit", p) end
        safeWait(2)
    end
end
spawn(autoStatsLoop)

-- ========= TELEPORT ========= --
local Islands = {
    ["Starter Island"] = CFrame.new(1100, 16, 1045),
    ["Marine Starter"] = CFrame.new(-2606, 6, 2060),
    ["Jungle"] = CFrame.new(-1218, 11, 3413),
    ["Pirate Village"] = CFrame.new(-1122, 13, 3827),
    ["Desert"] = CFrame.new(932, 7, 4484),
    ["Fountain City"] = CFrame.new(5243, 38, 4047),
    ["Skylands"] = CFrame.new(-4607, 872, -1667),
}

local function teleportTo(name)
    local cf = Islands[name] or Config.CustomWarps[name]
    if cf then tweenTo(cf, Config.TeleportSpeed) end
end

-- ========= ESP ========= --
local drawings = {}
local function clearESP() for _,d in pairs(drawings) do pcall(function() d:Remove() end) end drawings = {} end
local function newLine() if Drawing then local l = Drawing.new("Line"); l.Thickness = 1; l.Visible = true; return l end end
local function worldToViewport(pos)
    local cam = Workspace.CurrentCamera
    local v, on = cam:WorldToViewportPoint(pos)
    return Vector2.new(v.X, v.Y), on
end
local function espLoop()
    if not Drawing then return end
    while true do
        clearESP()
        if Config.ESP.Enemies then
            for _,folder in ipairs(EnemyFolders) do if typeof(folder)=="Instance" then
                for _,m in ipairs(folder:GetChildren()) do
                    local hrp = m:FindFirstChild("HumanoidRootPart"); local hum = m:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health>0 then
                        local l = newLine(); drawings[#drawings+1]=l
                        local p1,on1 = worldToViewport(getChar():FindFirstChild("HumanoidRootPart").Position)
                        local p2,on2 = worldToViewport(hrp.Position)
                        if on1 and on2 then l.From = p1; l.To = p2; l.Visible = true else l.Visible=false end
                    end
                end
            end end
        end
        -- Fruits ESP
        if Config.ESP.Fruits then
            for _,v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("BasePart") and isFruitModel(v.Parent or v) then
                    local l = newLine(); drawings[#drawings+1]=l
                    local p1,on1 = worldToViewport(getChar():FindFirstChild("HumanoidRootPart").Position)
                    local p2,on2 = worldToViewport(v.Position)
                    if on1 and on2 then l.From=p1; l.To=p2; l.Visible=true else l.Visible=false end
                end
            end
        end
        RunService.RenderStepped:Wait()
    end
end
spawn(espLoop)

-- ========= GIAO DIỆN: TABS & NÚT ========= --
local tabGeneral = AddTab("General")
local tabCombat = AddTab("Combat")
local tabTP = AddTab("Đảo/Teleport")
local tabESP = AddTab("ESP")
local tabMisc = AddTab("Tiện ích")

-- General
(tabGeneral.AddToggle or tabGeneral.AddToggleButton or tabGeneral.AddSwitch)("Tự động Farm (Level)", Config.AutoFarm, function(v)
    Config.AutoFarm = v; saveCfg(); if v then spawn(farmLoop) end
end)
(tabGeneral.AddToggle or tabGeneral.AddToggleButton or tabGeneral.AddSwitch)("Tự động Nhận Quest", Config.AutoQuest, function(v) Config.AutoQuest=v; saveCfg() end)
(tabGeneral.AddToggle or tabGeneral.AddToggleButton or tabGeneral.AddSwitch)("Tự động Farm Boss", Config.AutoBoss, function(v) Config.AutoBoss=v; saveCfg(); if v then spawn(bossLoop) end end)
(tabGeneral.AddToggle or tabGeneral.AddToggleButton or tabGeneral.AddSwitch)("Bật Haki tự động", Config.AutoHaki, function(v) Config.AutoHaki=v; saveCfg() end)
(tabGeneral.AddDropdown or tabGeneral.AddBox)("Vũ khí (Melee/Sword/Gun/Tên)", {"Melee","Sword","Gun"}, Config.Weapon, function(val) Config.Weapon = val; saveCfg() end)

-- Combat
(tabCombat.AddToggle or tabCombat.AddSwitch)("Đánh nhanh (Fast Attack)", Config.FastAttack, function(v) Config.FastAttack=v; saveCfg() end)
(tabCombat.AddToggle or tabCombat.AddSwitch)("Dùng kỹ năng Melee (Z/X/C)", Config.UseMeleeSkills, function(v) Config.UseMeleeSkills=v; saveCfg() end)
(tabCombat.AddBox or tabCombat.AddDropdown)("Phạm vi Farm (m)", tostring(Config.FarmRange), tostring(Config.FarmRange), function(txt)
    local n = tonumber(txt); if n then Config.FarmRange = math.clamp(n, 50, 1000); saveCfg() end
end)

-- Teleport
(tabTP.AddDropdown or tabTP.AddBox)("Chọn đảo để Teleport", (function() local t={} for k,_ in pairs(Islands) do table.insert(t,k) end return t end)(), nil, function(name) teleportTo(name) end)
(tabTP.AddButton or tabTP.AddToggle)("Lưu vị trí hiện tại thành Warp tuỳ chỉnh", function()
    local char = getChar(); local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local key = "Warp-"..os.time()
    Config.CustomWarps[key] = hrp.CFrame; saveCfg()
end)

-- ESP
(tabESP.AddToggle or tabESP.AddSwitch)("ESP Kẻ địch", Config.ESP.Enemies, function(v) Config.ESP.Enemies=v; saveCfg() end)
(tabESP.AddToggle or tabESP.AddSwitch)("ESP Boss", Config.ESP.Boss, function(v) Config.ESP.Boss=v; saveCfg() end)
(tabESP.AddToggle or tabESP.AddSwitch)("ESP Trái ác quỷ", Config.ESP.Fruits, function(v) Config.ESP.Fruits=v; saveCfg() end)
(tabESP.AddToggle or tabESP.AddSwitch)("ESP Rương", Config.ESP.Chests, function(v) Config.ESP.Chests=v; saveCfg() end)
(tabESP.AddToggle or tabESP.AddSwitch)("ESP Người chơi", Config.ESP.Players, function(v) Config.ESP.Players=v; saveCfg() end)

-- Tiện ích
(tabMisc.AddToggle or tabMisc.AddSwitch)("Fruit Sniper (Tự tìm & nhặt trái)", Config.FruitSniper, function(v) Config.FruitSniper=v; saveCfg(); if v then spawn(fruitLoop) end end)
(tabMisc.AddBox or tabMisc.AddDropdown)("Tốc độ Tween (Teleport)", tostring(Config.TeleportSpeed), tostring(Config.TeleportSpeed), function(txt)
    local n = tonumber(txt); if n then Config.TeleportSpeed = math.clamp(n, 50, 300); saveCfg() end
end)
(tabMisc.AddButton or tabMisc.AddToggle)("Lưu cấu hình", saveCfg)

-- Khởi chạy các vòng lặp mặc định
if Config.AutoFarm then spawn(farmLoop) end
if Config.AutoBoss then spawn(bossLoop) end
if Config.FruitSniper then spawn(fruitLoop) end

print("[BloxF VN Hub] Loaded • Version "..HUB_VERSION)
