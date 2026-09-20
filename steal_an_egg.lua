--[[
    ===================================================================
    🔥 Steal An Egg - Account Monitoring & Tracker Script
    GitHub Repo: https://github.com/kongsprb-lgtm/monitoring
    ===================================================================
    Loadstring Usage:
        getgenv().WebhookUrl = "https://discord.com/api/webhooks/YOUR_KEY"
        getgenv().Interval = 300 -- update setiap 300 detik (5 menit)
        getgenv().ServerUrl = "http://YOUR_SERVER:3000/api/update" -- Opsional jika pakai web server
        loadstring(game:HttpGet("https://raw.githubusercontent.com/kongsprb-lgtm/monitoring/main/steal_an_egg.lua"))()
    ===================================================================
]]--

-- Pastikan game sudah ter-load sempurna
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local StatsService = game:GetService("Stats")
local player = Players.LocalPlayer

-- // Konfigurasi Default (Bisa di-override lewat getgenv() sebelum loadstring)
local Config = {
    WebhookUrl = (getgenv and getgenv().WebhookUrl) or "",
    ServerUrl = (getgenv and getgenv().ServerUrl) or "",
    Interval = (getgenv and getgenv().Interval) or 300,
    EnableAntiAFK = true,
    ScriptStartTime = os.time()
}

-- Deteksi fungsi HTTP executor
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
if not httpRequest then
    warn("[Monitor Error] Executor kamu tidak mendukung HTTP request (request / http_request)!")
    return
end

-- // Fitur Anti-AFK Bawaan (Supaya akun tidak ter-kick roblox 20 menit)
if Config.EnableAntiAFK then
    player.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
            print("[Anti-AFK] Virtual input terkirim, mencegah idle kick.")
        end)
    end)
    print("[Monitor] Anti-AFK aktif.")
end

-- Helper format waktu durasi joki
local function formatDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d jam %02d menit %02d detik", hours, mins, secs)
end

-- Helper format angka (e.g. 1000000 -> 1M)
local function formatNumber(val)
    if type(val) == "number" then
        if val >= 1e15 then return string.format("%.2fQa", val / 1e15)
        elseif val >= 1e12 then return string.format("%.2fT", val / 1e12)
        elseif val >= 1e9 then return string.format("%.2fB", val / 1e9)
        elseif val >= 1e6 then return string.format("%.2fM", val / 1e6)
        elseif val >= 1e3 then return string.format("%.2fK", val / 1e3)
        else return tostring(val) end
    end
    return tostring(val)
end

-- // Fungsi Ekstraksi Statistik Game "Steal An Egg"
local function collectAccountStats()
    local result = {
        username = player.Name,
        displayName = player.DisplayName,
        userId = player.UserId,
        uptime = formatDuration(os.time() - Config.ScriptStartTime),
        statsList = {},
        rawValues = {}
    }

    -- 1. Scan leaderstats jika ada
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        for _, item in ipairs(leaderstats:GetChildren()) do
            if item:IsA("ValueBase") then
                local formattedVal = formatNumber(item.Value)
                table.insert(result.statsList, { name = item.Name, value = formattedVal })
                result.rawValues[item.Name] = item.Value
            end
        end
    end

    -- 2. Scan UI PlayerGui untuk menangkap teks Level, Koin/Uang, Kecepatan/Sepatu
    pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then return end

        for _, descendant in ipairs(playerGui:GetDescendants()) do
            if descendant:IsA("TextLabel") and descendant.Visible then
                local txt = descendant.Text
                
                -- Deteksi Level (contoh: "Level 11 > Level 12" atau "Level 11")
                if txt:find("Level") and not result.rawValues["Level"] then
                    local lvl = txt:match("Level%s*(%d+)")
                    if lvl then
                        result.rawValues["Level"] = "Level " .. lvl
                        table.insert(result.statsList, { name = "Level Info", value = txt })
                    end
                end

                -- Deteksi Uang / Cash (contoh: "$50qa" atau "$2.1B")
                if txt:find("%$") and not result.rawValues["Money"] then
                    local moneyMatch = txt:match("%$[%d%.]+%a*")
                    if moneyMatch then
                        result.rawValues["Money"] = moneyMatch
                        table.insert(result.statsList, { name = "Cash / Money", value = moneyMatch })
                    end
                end

                -- Deteksi Kecepatan / Sepatu (contoh: "2.1B" atau sejenisnya)
                if descendant.Name:lower():find("speed") or descendant.Name:lower():find("shoe") or descendant.Parent.Name:lower():find("shoe") then
                    if not result.rawValues["Speed"] and txt:match("[%d%.]+%a*") then
                        result.rawValues["Speed"] = txt
                        table.insert(result.statsList, { name = "Speed / Shoes", value = txt })
                    end
                end
            end
        end
    end)

    -- Ping server
    pcall(function()
        local pingVal = StatsService.Network.ServerStatsItem["Data Ping"]:GetValueString()
        local pingNum = pingVal:match("([%d%.]+)")
        result.ping = pingNum and (math.floor(tonumber(pingNum)) .. " ms") or "N/A"
    end)

    return result
end

-- // Pengiriman ke Discord Webhook
local function sendToDiscord(data)
    if not Config.WebhookUrl or Config.WebhookUrl == "" then return end

    local fields = {
        {
            name = "⏳ Durasi Joki (Uptime)",
            value = data.uptime,
            inline = true
        },
        {
            name = "📶 Ping Server",
            value = data.ping or "N/A",
            inline = true
        }
    }

    -- Masukkan stats ke fields embed
    if #data.statsList > 0 then
        local statSummary = ""
        for _, s in ipairs(data.statsList) do
            statSummary = statSummary .. string.format("• **%s**: `%s`\n", s.name, tostring(s.value))
        end
        table.insert(fields, {
            name = "📊 Perkembangan Akun",
            value = statSummary,
            inline = false
        })
    else
        table.insert(fields, {
            name = "📊 Perkembangan Akun",
            value = "Menunggu data stat ter-render di game...",
            inline = false
        })
    end

    local payload = {
        username = "Steal An Egg - Monitor",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. data.userId .. "&width=150&height=150&format=png",
        embeds = {{
            title = "🎮 Monitoring Joki: " .. data.displayName .. " (@" .. data.username .. ")",
            description = "Status: 🟢 **Sedang Berjalan (Farming/Anti-AFK)**\nGame: **Steal An Egg**",
            color = 3447003, -- Warna Biru Hex #3498db
            fields = fields,
            thumbnail = {
                url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. data.userId .. "&width=150&height=150&format=png"
            },
            footer = {
                text = "GitHub: kongsprb-lgtm/monitoring • Auto Update"
            },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }

    local success, err = pcall(function()
        httpRequest({
            Url = Config.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if success then
        print("[Monitor] Update terkirim ke Discord Webhook.")
    else
        warn("[Monitor] Gagal kirim ke Discord: " .. tostring(err))
    end
end

-- // Pengiriman ke Web Server Dashboard Pribadi (Opsional)
local function sendToWebServer(data)
    if not Config.ServerUrl or Config.ServerUrl == "" then return end

    local payload = {
        username = data.username,
        displayName = data.displayName,
        userId = data.userId,
        uptime = data.uptime,
        ping = data.ping or "N/A",
        stats = data.statsList,
        timestamp = os.time()
    }

    local success, err = pcall(function()
        httpRequest({
            Url = Config.ServerUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    if success then
        print("[Monitor] Update terkirim ke Web Dashboard.")
    else
        warn("[Monitor] Gagal kirim ke Web Server: " .. tostring(err))
    end
end

-- // Loop Utama Tracker
local function runMonitoringCycle()
    local data = collectAccountStats()
    sendToDiscord(data)
    sendToWebServer(data)
end

-- Kirim notifikasi pertama kali saat script di-load
task.spawn(function()
    task.wait(3) -- Tunggu sebentar agar UI in-game muncul
    runMonitoringCycle()

    -- Jalankan pengiriman berkala
    while task.wait(Config.Interval) do
        runMonitoringCycle()
    end
end)

print(string.format("[Steal An Egg Monitor] Aktif! Update setiap %d detik.", Config.Interval))
