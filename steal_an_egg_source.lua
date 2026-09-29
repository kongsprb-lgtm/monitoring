--[[
    ===================================================================
    🥚 Steal An Egg - Pure Account Monitoring & Webhook Tracker
    GitHub Repo: https://github.com/kongsprb-lgtm/monitoring
    ===================================================================
    Execute via Loadstring:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/kongsprb-lgtm/monitoring/main/steal_an_egg.lua"))()
    ===================================================================
]]--

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

-- // HTTP Request function
local req = http_request or request or HttpPost or (syn and syn.request) or (fluxus and fluxus.request)
if not req then
    warn("[Error] Executor kamu tidak mendukung fungsi http request!")
    return
end

-- // Helper Format Angka
local function FormatNumber(value)
    if type(value) ~= "number" then return tostring(value or "0") end
    if value >= 1e33 then return string.format("%.2f Dc", value / 1e33):gsub("%.00", "")
    elseif value >= 1e30 then return string.format("%.2f No", value / 1e30):gsub("%.00", "")
    elseif value >= 1e27 then return string.format("%.2f Oc", value / 1e27):gsub("%.00", "")
    elseif value >= 1e24 then return string.format("%.2f Sp", value / 1e24):gsub("%.00", "")
    elseif value >= 1e21 then return string.format("%.2f Sx", value / 1e21):gsub("%.00", "")
    elseif value >= 1e18 then return string.format("%.2f Qi", value / 1e18):gsub("%.00", "")
    elseif value >= 1e15 then return string.format("%.2f Qa", value / 1e15):gsub("%.00", "")
    elseif value >= 1e12 then return string.format("%.2f T", value / 1e12):gsub("%.00", "")
    elseif value >= 1e9 then return string.format("%.2f B", value / 1e9):gsub("%.00", "")
    elseif value >= 1e6 then return string.format("%.2f M", value / 1e6):gsub("%.00", "")
    elseif value >= 1e3 then return string.format("%.1f K", value / 1e3):gsub("%.0", "")
    else return tostring(math.floor(value)) end
end

local function formatDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d jam %02d menit %02d detik", hours, mins, secs)
end

-- // Config Storage (Simpan Pilihan User ke File Lokal Executor)
local ConfigFile = "StealAnEgg_MonitorConfig.json"
local Config = {
    WebhookURL = (getgenv and getgenv().WebhookURL) or "",
    WebhookPingID = (getgenv and getgenv().WebhookPingID) or "",
    IntervalMinutes = 5,
    AutoReport = true,

    -- Pilihan Monitoring yang Diinginkan User:
    Track_EggObtained = true,   -- Egg yang di dapet (Realtime saat mencuri telur)
    Track_EggBackpack = true,   -- Jumlah & rincian Egg di backpack
    Track_PetBackpack = true,   -- Jumlah & rincian Pet di backpack
    Track_PetKandang  = true,   -- Jumlah & rincian Pet di kandang / base
    Track_Money       = true,   -- Money sekarang ($...)
    Track_Speed       = true,   -- Speed sekarang
    Track_Hatch       = false,  -- Notifikasi saat telur menetas

    -- Web Dashboard Monitoring (p4kong.site/monitoringjoki):
    Track_WebMonitoring = true, -- Aktifkan pengiriman data ke Web Dashboard
    WebMonitoring_URL   = "https://www.p4kong.site/api/monitoringjoki",
    WebMonitoring_Steal = "https://www.p4kong.site/api/monitoringjoki"
}

-- Uptime Sesi: Dimulai saat script dieksekusi, jika script mati/re-execute waktu otomatis reset ke 0
local ScriptStartTime = os.time()

-- Load config jika ada
if isfile and readfile and isfile(ConfigFile) then
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(ConfigFile))
        for k, v in pairs(decoded) do
            if k ~= "StartTime" then
                Config[k] = v
            end
        end
    end)
end

local function SaveSettings()
    if writefile then
        pcall(function()
            writefile(ConfigFile, HttpService:JSONEncode(Config))
        end)
    end
end

-- Timer kontrol hitung mundur laporan berkala
local nextReportTimestamp = os.time() + (math.clamp(Config.IntervalMinutes, 1, 60) * 60)
local function resetReportTimer()
    nextReportTimestamp = os.time() + (math.clamp(Config.IntervalMinutes, 1, 60) * 60)
end

-- // Rarity Colors
local RarityColors = {
    Common = Color3.fromRGB(180, 180, 180),
    Uncommon = Color3.fromRGB(85, 255, 85),
    Rare = Color3.fromRGB(85, 85, 255),
    Epic = Color3.fromRGB(170, 0, 255),
    Legendary = Color3.fromRGB(255, 170, 0),
    Mythic = Color3.fromRGB(255, 85, 85),
    Secret = Color3.fromRGB(0, 255, 255),
    Eternal = Color3.fromRGB(255, 0, 128),
    Divine = Color3.fromRGB(255, 215, 0)
}

-- // Helper Mutasi
local function GetMutationsString(data)
    if type(data) ~= "table" then return "None" end
    local mutList = {}
    if data.BaseMutation and data.BaseMutation ~= "" then table.insert(mutList, data.BaseMutation) end
    if type(data.Mutations) == "table" then 
        for _, mut in ipairs(data.Mutations) do table.insert(mutList, mut) end 
    end
    if #mutList > 0 then return table.concat(mutList, ", ") end
    return "None"
end

-- ====================================================================
-- 📊 DATA COLLECTOR ENGINE (MULTI-SOURCE: sData + UI + LEADERSTATS)
-- ====================================================================

-- Helper membersihkan tag RichText dan whitespace
local function cleanGuiText(str)
    if type(str) ~= "string" then return "" end
    local s = str:gsub("<[^>]->", "")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

-- Helper mengekstrak nama pet murni dari teks label (menghilangkan income rate ($.../s), dsb)
local function extractPetNameFromText(rawText)
    local t = cleanGuiText(rawText)
    t = t:gsub("%b()", "") -- Hapus teks dalam tanda kurung seperti ($10.3B/s)
    t = t:gsub("%$[%d%.]+%a*/s", "")
    t = t:gsub("%$[%d%.]+%a*", "")
    t = t:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return t
end

-- Blacklist kata-kata yang BUKAN nama pet (rarity, multiplier, stats, UI)
local NonPetKeywords = {
    -- Rarities
    "common", "uncommon", "rare", "epic", "legendary", "mythic", 
    "secret", "eternal", "divine", "cosmic", "exclusive", "event", "godly",
    -- Multipliers & stats
    "speed", "cash", "money", "step", "boost", "jump", "walk", "power",
    -- UI & Actions
    "trail", "title", "badge", "rank", "unequip", "equip", "active", 
    "max", "level", "best", "items", "search", "backpack", "skip", "growth",
    "open", "steal", "hatch", "close", "buy", "shop"
}

local function isRealPetName(name)
    if type(name) ~= "string" or #name < 2 then return false end
    -- Tolak jika berupa angka atau simbol murni (misal "81", "19", "$50", dll)
    if tonumber(name) or name:match("^%d+$") or name:match("^[%d%s%p]+$") then return false end
    
    local nLow = name:lower()
    
    -- Tolak jika berawalan "x" diikuti angka (misal "x5", "x5 speed", "x10 cash")
    if nLow:match("^x%d+") then return false end
    -- Tolak jika berawalan "+" diikuti angka (misal "+3000", "+3,000/step")
    if nLow:match("^%+?%d+") then return false end

    for _, kw in ipairs(NonPetKeywords) do
        if nLow == kw or (kw:find("trail") and nLow:find("trail")) or (kw:find("speed") and nLow:find("speed")) or (kw:find("cash") and nLow:find("cash")) then
            return false
        end
    end
    return true
end

-- Blacklist kata-kata yang BUKAN nama telur (quest, action, UI prompts)
local NonEggKeywords = {
    "bring", "place", "charge", "open", "steal", "hold", "click", "press",
    "tap", "your", "the", "an", "buy", "sell", "use", "all items", "backpack",
    "search", "skip", "hatch", "equipped", "unequip", "level", "stats",
    "infested", "machine", "altar", "teleport"
}

local function isRealEggName(name)
    if type(name) ~= "string" or #name < 4 then return false end
    local nLow = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
    -- Tolak jika kata umum "Egg" atau "Eggs" saja
    if nLow == "egg" or nLow == "eggs" then return false end
    -- Tolak jika berupa angka
    if tonumber(name) or name:match("^%d+$") then return false end

    for _, kw in ipairs(NonEggKeywords) do
        if nLow:find("%f[%a]" .. kw .. "%f[%A]") then
            return false
        end
    end

    -- Wajib berakhiran atau mengandung kata "egg"
    if not nLow:find("egg") then return false end
    return true
end

-- 1. Ambil Money, Money/s & Speed Sekarang
local function getPlayerCurrencies()
    local data = {
        money = "N/A",
        moneyPerSecond = "N/A",
        speed = "N/A",
        level = "N/A",
        ping = "N/A"
    }

    -- Cek Ping
    pcall(function()
        local pingVal = StatsService.Network.ServerStatsItem["Data Ping"]:GetValueString()
        local pingNum = pingVal:match("([%d%.]+)")
        data.ping = pingNum and (math.floor(tonumber(pingNum)) .. " ms") or "N/A"
    end)

    -- 🔍 PRIORITAS SPEED 1: Leaderstats (Nilai Paling Akurat & Konsisten, misal 187770000000 -> "187.77 B")
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            local spdVal = ls:FindFirstChild("Speed") or ls:FindFirstChild("speed")
            if spdVal and type(spdVal.Value) == "number" and spdVal.Value > 0 then
                data.speed = FormatNumber(spdVal.Value)
            end
        end
    end)

    -- 🔍 PRIORITAS MONEY & SPEED UI (HUD Pojok Kiri Bawah: "$50.2Qa" / "$50Qa" & "187.7B")
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end

        local hudCashCandidates = {}
        local hudSpeedCandidate = nil

        for _, desc in ipairs(pg:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) and desc.Text ~= "" then
                -- HUD utama TIDAK PERNAH berada di dalam ScrollingFrame (kandang/backpack/shop ada di ScrollingFrame)
                if not desc:FindFirstAncestorOfClass("ScrollingFrame") then
                    local txt = cleanGuiText(desc.Text)
                    local pName = desc.Parent and desc.Parent.Name:lower() or ""
                    local dName = desc.Name:lower()

                    -- Deteksi Money/s HUD (misal "+$4.7Qa/s", "$4.7Qa/s", "4.7Qa/s")
                    if txt:find("/s") and not txt:lower():find("boost") and not txt:lower():find("speed") and not txt:lower():find("step") then
                        local mpsMatch = txt:match("[%+%$]?%s*([%d%,%.]+%s*[A-Za-z]*)%s*/%s*s")
                        if mpsMatch and mpsMatch ~= "" then
                            data.moneyPerSecond = "+$" .. mpsMatch:gsub("%s+", "") .. "/s"
                        end
                    end

                    -- Deteksi Cash HUD dengan $ (misal "$50.2Qa", "$ 50.2Qa", "$50Qa", "$49.8Qa")
                    if txt:find("%$") and not txt:find("/s") and not txt:lower():find("boost") and not txt:lower():find("friend") then
                        local cashNum = txt:match("%$%s*([%d%,%.]+%s*[A-Za-z]*)")
                        if cashNum and cashNum ~= "" and cashNum ~= "$" then
                            local formatted = "$" .. cashNum:gsub("%s+", "")
                            local prio = 5
                            local low = formatted:lower()
                            if low:find("qa") or low:find("qi") or low:find("sx") or low:find("sp") or low:find("oc") or low:find("no") or low:find("dc") then
                                prio = 10
                            elseif low:find("t") or low:find("b") or low:find("m") then
                                prio = 7
                            end
                            table.insert(hudCashCandidates, { text = formatted, priority = prio })
                        end
                    end

                    -- Deteksi Cash HUD tanpa $ (misal "50.2Qa", "50.1Qa", "50Qa")
                    local qaOnly = txt:match("^([%d%,%.]+%s*[QqSsNnOoDd][AaIiXxPpCcMm]*)$")
                    if qaOnly and not txt:lower():find("/s") and not txt:lower():find("step") then
                        table.insert(hudCashCandidates, { text = "$" .. qaOnly:gsub("%s+", ""), priority = 9 })
                    end

                    -- Deteksi Cash jika parent/nama objek bernama cash/money/currency/coin
                    if (pName:find("cash") or pName:find("money") or pName:find("currency") or pName:find("coin")
                        or dName:find("cash") or dName:find("money") or dName:find("currency") or dName:find("coin"))
                        and not txt:lower():find("/s") and not txt:lower():find("boost") then
                        local cMatch = txt:match("^%$?%s*([%d%,%.]+%s*[A-Za-z]+)$")
                        if cMatch then
                            table.insert(hudCashCandidates, { text = "$" .. cMatch:gsub("%s+", ""), priority = 8 })
                        end
                    end

                    -- Deteksi Speed HUD shoe icon (hanya jika label/parent ada 'shoe')
                    if (pName:find("shoe") or dName:find("shoe")) and not txt:find("%$") and not txt:lower():find("boost") then
                        local sMatch = txt:match("^([%d%,%.]+%s*[A-Za-z]+)$")
                        if sMatch then
                            hudSpeedCandidate = sMatch:gsub("%s+", "")
                        end
                    end

                    -- Deteksi Level
                    if txt:find("Level") then
                        local lvlMatch = txt:match("Level%s*[%d%.]+")
                        if lvlMatch then data.level = lvlMatch end
                    end
                end
            end
        end

        -- Pilih kandidat cash terbaik
        if #hudCashCandidates > 0 then
            table.sort(hudCashCandidates, function(a, b) return a.priority > b.priority end)
            data.money = hudCashCandidates[1].text
        end

        -- Gunakan HUD speed jika ada dan speed belum terisi
        if hudSpeedCandidate and data.speed == "N/A" then
            data.speed = hudSpeedCandidate
        end
    end)

    -- 🔍 FALLBACK 1: Baca Cash dari Save Data (sData) jika UI belum terbaca
    if data.money == "N/A" then
        pcall(function()
            local saveMod = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Save")
            if not saveMod then return end
            local sData = require(saveMod).Get()
            if not sData then return end

            local candidateKeys = {"cash", "money", "coins", "coin", "gold", "currency", "currencies", "stats", "balance"}
            local highestVal = nil

            for k, v in pairs(sData) do
                local kLow = tostring(k):lower()
                if type(v) == "number" and v > 0 then
                    for _, ck in ipairs(candidateKeys) do
                        if kLow == ck or kLow:find(ck) then
                            if not highestVal or v > highestVal then highestVal = v end
                        end
                    end
                elseif type(v) == "table" then
                    for subK, subV in pairs(v) do
                        local subKLow = tostring(subK):lower()
                        if type(subV) == "number" and subV > 0 then
                            for _, ck in ipairs(candidateKeys) do
                                if subKLow == ck or subKLow:find(ck) then
                                    if not highestVal or subV > highestVal then highestVal = subV end
                                end
                            end
                        end
                    end
                end
            end

            if highestVal then
                data.money = "$" .. FormatNumber(highestVal)
            end
        end)
    end

    -- 🔍 FALLBACK 2: Leaderstats
    pcall(function()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                local n = v.Name:lower()
                if (n:find("money") or n:find("cash") or n:find("coin")) and data.money == "N/A" then
                    data.money = "$" .. FormatNumber(v.Value)
                elseif (n:find("speed") or n:find("shoe")) and data.speed == "N/A" then
                    data.speed = FormatNumber(v.Value)
                elseif n:find("level") and data.level == "N/A" then
                    data.level = tostring(v.Value)
                end
            end
        end
    end)

    return data
end

-- 2. Ambil Data Inventory: Egg di Backpack, Pet di Backpack, Pet di Kandang (Placed)
local function getInventorySummary()
    local summary = {
        eggBackpackCount = 0,
        eggsInBackpack = {},
        eggMeta = {},
        petBackpackCount = 0,
        petsInBackpack = {},
        petKandangCount = 0,
        petsInKandang = {},
        petMeta = {},
        bestPet = nil,
        totalKandangEarnRate = 0
    }

    local uiEggsInBackpack = {}
    local uiEggCount = 0
    local uiPetCount = 0
    local uiActiveCount = 0
    local uiPetsInKandang = {}
    local unequipButtonCount = 0

    -- ================================================================
    -- 🔍 SUMBER 1: BACA DARI UI (PlayerGui) - SUMBER PALING AKURAT & REALTIME
    -- ================================================================
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end

        local seenCardFrames = {}

        for _, desc in ipairs(pg:GetDescendants()) do
            if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
                local txt = cleanGuiText(desc.Text)
                if txt ~= "" then
                    -- 1. Deteksi "Eggs: 80/115" di header Backpack
                    local eCount = txt:match("[Ee]ggs:%s*(%d+)%s*/%s*%d+")
                    if eCount then
                        local n = tonumber(eCount)
                        if n and n > uiEggCount then uiEggCount = n end
                    end

                    -- 2. Deteksi "Pets: 100/115" di header Backpack
                    local pCount = txt:match("[Pp]ets:%s*(%d+)%s*/%s*%d+")
                    if pCount then
                        local n = tonumber(pCount)
                        if n and n > uiPetCount then uiPetCount = n end
                    end

                    -- 3. Deteksi "19/19 Active" di header Pet Kandang
                    local act1 = txt:match("(%d+)%s*/%s*%d+%s*[Aa]ctive") or txt:match("(%d+)%s*[Aa]ctive")
                    if act1 then
                        local n = tonumber(act1)
                        if n and n > uiActiveCount then uiActiveCount = n end
                    end

                    -- 4. Deteksi kartu telur di grid Backpack, misal "Titan Temple Egg (65.225Ka)" atau "Cosmic Egg"
                    if txt:find("Egg") and not txt:find(":") and not txt:find("All Items") then
                        local cleanEgg = txt:gsub("%b()", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        local eggMatch = cleanEgg:match("([%a%s]+Egg)")
                        if eggMatch and isRealEggName(eggMatch) then
                            uiEggsInBackpack[eggMatch] = (uiEggsInBackpack[eggMatch] or 0) + 1
                        end
                    end
                end
            end

            -- 5. Deteksi Tombol "Unequip" & Frame Kartu Pet Aktif
            local isUnequipBtn = false
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                local tLow = cleanGuiText(desc.Text):lower()
                if tLow == "unequip" then
                    isUnequipBtn = true
                end
            end
            if not isUnequipBtn and (desc:IsA("ImageButton") or desc:IsA("TextButton")) then
                if desc.Name:lower():find("unequip") then
                    isUnequipBtn = true
                end
            end

            if isUnequipBtn then
                -- Temukan container baris kartu (parent yang merupakan anak dari ScrollingFrame/List)
                local cardRow = desc.Parent
                while cardRow and cardRow.Parent do
                    if cardRow.Parent:IsA("ScrollingFrame") or cardRow.Parent.Name:lower():find("list") or cardRow.Parent.Name:lower():find("container") or cardRow.Parent.Name:lower():find("grid") then
                        break
                    end
                    if cardRow:IsA("ScreenGui") then break end
                    cardRow = cardRow.Parent
                end

                local cardKey = cardRow or desc.Parent
                if not seenCardFrames[cardKey] then
                    seenCardFrames[cardKey] = true
                    unequipButtonCount = unequipButtonCount + 1

                    for _, lbl in ipairs(cardKey:GetDescendants()) do
                        if (lbl:IsA("TextLabel") or lbl:IsA("TextButton")) and lbl ~= desc then
                            local cleanName = extractPetNameFromText(lbl.Text)
                            if isRealPetName(cleanName) then
                                uiPetsInKandang[cleanName] = (uiPetsInKandang[cleanName] or 0) + 1
                                break
                            end
                        end
                    end
                end
            end
        end

        if unequipButtonCount > uiActiveCount and unequipButtonCount <= 19 then
            uiActiveCount = unequipButtonCount
        end
    end)

    -- ================================================================
    -- 🔍 SUMBER 2: BACA DARI SAVE DATA GAME (sData)
    -- ================================================================
    pcall(function()
        local saveMod = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Save")
        if not saveMod then return end
        local sData = require(saveMod).Get()
        if not sData then return end

        local Assets = nil
        pcall(function() Assets = require(ReplicatedStorage.Data.Assets) end)

        -- A1. Egg Inventory
        if sData.EggInventory then
            local sDataEggCount = 0
            for uid, rec in pairs(sData.EggInventory) do
                local isPlaced = (rec.Placement ~= nil) or (rec.Placed == true)
                if not isPlaced then
                    local cat = rec.AssetCategory or "Egg"
                    local eggDisplayName = nil
                    local rarityStr = nil
                    local iconAssetId = nil

                    if Assets and Assets.Directory and Assets.Directory[cat] then
                        local pData = Assets.Directory[cat]
                        if pData.Egg then
                            if type(pData.Egg) == "table" then
                                eggDisplayName = pData.Egg.Name or pData.Egg.DisplayName or pData.Egg.Title
                                local r = pData.Egg.Rarity
                                rarityStr = type(r) == "table" and (r.Title or r.Name or r.DisplayName) or (type(r) == "string" and r)
                                iconAssetId = pData.Egg.Icon or pData.Egg.Image or pData.Egg.Thumbnail
                            elseif type(pData.Egg) == "string" then
                                eggDisplayName = pData.Egg
                            end
                        end
                        if not eggDisplayName then
                            eggDisplayName = pData.EggName or pData.EggType
                        end
                        if not rarityStr then
                            local r = pData.Rarity or rec.Rarity
                            rarityStr = type(r) == "table" and (r.Title or r.Name or r.DisplayName) or (type(r) == "string" and r)
                        end
                        if not iconAssetId then
                            iconAssetId = pData.Icon or pData.Image or pData.Thumbnail or pData.AssetId or rec.Icon or rec.Image
                        end
                    end

                    if not eggDisplayName then
                        eggDisplayName = rec.EggType or rec.EggName or rec.Egg
                    end

                    if not eggDisplayName then
                        if cat:find("Egg") then
                            eggDisplayName = cat
                        else
                            eggDisplayName = cat .. " Egg"
                        end
                    elseif not eggDisplayName:find("Egg") then
                        eggDisplayName = eggDisplayName .. " Egg"
                    end

                    if isRealEggName(eggDisplayName) then
                        sDataEggCount = sDataEggCount + 1
                        local cleanIcon = iconAssetId and tostring(iconAssetId):match("%d+") or nil
                        summary.eggsInBackpack[eggDisplayName] = (summary.eggsInBackpack[eggDisplayName] or 0) + 1
                        if not summary.eggMeta[eggDisplayName] then
                            summary.eggMeta[eggDisplayName] = {
                                rarity = rarityStr,
                                icon = cleanIcon
                            }
                        end
                    end
                end
            end
            summary.eggBackpackCount = sDataEggCount
        end

        -- A2. Pet Inventory: Pisahkan Active/Placed vs Backpack & Hitung Best Pet + Total Earn/s
        local AssetItems = nil
        pcall(function() AssetItems = require(ReplicatedStorage.Shared.Util.AssetItems) end)
        local AssetEarnings = nil
        pcall(function() AssetEarnings = require(ReplicatedStorage.Shared.Util.AssetEarnings) end)

        local equippedUIDs = {}
        for key, val in pairs(sData) do
            local kLower = tostring(key):lower()
            if (kLower:find("equip") or kLower:find("active") or kLower:find("pen") or kLower:find("placed") or kLower:find("slot")) 
                and not kLower:find("trail") and not kLower:find("title") and type(val) == "table" then
                for subKey, subVal in pairs(val) do
                    if type(subVal) == "string" then
                        equippedUIDs[subVal] = true
                    elseif type(subKey) == "string" and (subVal == true or type(subVal) == "table") then
                        equippedUIDs[subKey] = true
                    elseif type(subVal) == "table" and (subVal.Uid or subVal.UID or subVal.Id) then
                        equippedUIDs[subVal.Uid or subVal.UID or subVal.Id] = true
                    end
                end
            end
        end

        if sData.Inventory and AssetItems then
            local sDataPetBpCount = 0
            local sDataKandangCount = 0
            local sDataPetsKandang = {}
            local totalEarnRate = 0
            local bestPet = nil
            local bestPetRate = -1

            for uid, serialized in pairs(sData.Inventory) do
                local s_item, item = pcall(AssetItems.Decode, serialized)
                if s_item and type(item) == "table" then
                    local cat = item.Category or item.AssetCategory or item.Name or "Pet"
                    if isRealPetName(cat) then
                        sDataPetBpCount = sDataPetBpCount + 1
                        local pData = Assets and Assets.Directory and Assets.Directory[cat]
                        local r = item.Rarity or (pData and pData.Rarity)
                        local rarityStr = type(r) == "table" and (r.Title or r.Name or r.DisplayName) or (type(r) == "string" and r)
                        local iconAssetId = item.Icon or item.Image or item.Thumbnail or (pData and (pData.Icon or pData.Image or pData.Thumbnail))
                        local cleanIcon = iconAssetId and tostring(iconAssetId):match("%d+") or nil

                        local scale = tonumber(item.AssetScale) or tonumber(item.Scale) or 1
                        local earnRate = 0
                        if pData and pData.EarnRate then earnRate = pData.EarnRate end
                        if AssetEarnings and AssetEarnings.MutationOnlyRatePerSecond then
                            local sRate, bRate = pcall(AssetEarnings.MutationOnlyRatePerSecond, {
                                Category = cat,
                                Scale = scale,
                                Mutations = item.Mutations or {},
                                BaseMutation = item.BaseMutation or ""
                            })
                            if sRate and type(bRate) == "number" and bRate > 0 then
                                earnRate = bRate
                            end
                        end

                        summary.petsInBackpack[cat] = (summary.petsInBackpack[cat] or 0) + 1
                        if not summary.petMeta[cat] then
                            summary.petMeta[cat] = {
                                rarity = rarityStr,
                                icon = cleanIcon
                            }
                        end

                        local isEquipped = (equippedUIDs[uid] == true) 
                            or (item.Placement ~= nil) 
                            or (item.Equipped == true) 
                            or (item.Placed == true) 
                            or (item.Active == true) 
                            or (item.InPen == true) 
                            or (item.PenId ~= nil) 
                            or (item.Slot ~= nil) 
                            or (item.EquipSlot ~= nil)

                        if isEquipped then
                            totalEarnRate = totalEarnRate + earnRate
                            if sDataKandangCount < 19 then
                                sDataKandangCount = sDataKandangCount + 1
                                sDataPetsKandang[cat] = (sDataPetsKandang[cat] or 0) + 1
                            end
                        end

                        if earnRate > bestPetRate then
                            bestPetRate = earnRate
                            bestPet = {
                                name = cat,
                                rarity = rarityStr or "Common",
                                earnRate = "$" .. FormatNumber(earnRate) .. "/s",
                                rawRate = earnRate,
                                scale = string.format("%.2f", scale) .. "x",
                                icon = cleanIcon
                            }
                        end
                    end
                end
            end
            summary.petBackpackCount = sDataPetBpCount
            if summary.petKandangCount == 0 and sDataKandangCount > 0 then
                summary.petKandangCount = sDataKandangCount
                summary.petsInKandang = sDataPetsKandang
            end
            summary.totalKandangEarnRate = totalEarnRate
            summary.bestPet = bestPet
        end
    end)

    -- ================================================================
    -- 🔄 SINKRONISASI AKHIR DENGAN PRIORITAS UI
    -- ================================================================

    -- 1. Sync Pet di Kandang (Active)
    if uiActiveCount > 0 then
        summary.petKandangCount = uiActiveCount
    elseif unequipButtonCount > 0 and unequipButtonCount <= 19 then
        summary.petKandangCount = unequipButtonCount
    end

    if summary.petKandangCount > 19 then
        summary.petKandangCount = 19
    end

    local totalUiKandang = 0
    for _, cnt in pairs(uiPetsInKandang) do totalUiKandang = totalUiKandang + cnt end
    if totalUiKandang > 0 then
        summary.petsInKandang = uiPetsInKandang
    end

    -- 2. Sync Egg di Backpack
    if uiEggCount > 0 then
        summary.eggBackpackCount = uiEggCount
    end

    local sDataEggTotal = 0
    for _, cnt in pairs(summary.eggsInBackpack) do sDataEggTotal = sDataEggTotal + cnt end

    -- Hanya gunakan uiEggsInBackpack sebagai cadangan jika sData.EggInventory kosong
    if sDataEggTotal == 0 then
        for eggName, cnt in pairs(uiEggsInBackpack) do
            if isRealEggName(eggName) then
                summary.eggsInBackpack[eggName] = cnt
            end
        end
    end

    -- 3. Sync Pet di Backpack
    if uiPetCount > 0 then
        summary.petBackpackCount = uiPetCount
    end

    -- 4. Fallback Best Pet jika sData.Inventory belum terisi
    if not summary.bestPet then
        for cat, meta in pairs(summary.petMeta) do
            local r = (meta and meta.rarity) or "Common"
            local rate = 0
            pcall(function()
                local Assets = require(ReplicatedStorage.Data.Assets)
                local pData = Assets and Assets.Directory and Assets.Directory[cat]
                if pData and pData.EarnRate then rate = pData.EarnRate end
            end)
            if not summary.bestPet or rate > (summary.bestPet.rawRate or 0) then
                summary.bestPet = {
                    name = cat,
                    rarity = r,
                    earnRate = rate > 0 and ("$" .. FormatNumber(rate) .. "/s") or "$0/s",
                    rawRate = rate,
                    scale = "1.00x",
                    icon = meta and meta.icon or nil
                }
            end
        end
    end

    return summary
end

-- ====================================================================
-- 🔮 PREDICTOR ENGINE (RNG & DROP TABLE SIMULATOR)
-- ====================================================================
local AreaData = {}
local AssetRarityMap = {}
local RarityList = {}
local RarityOrderMap = {}
local RarityColorMap = {}
local CachedPredictions = {}
local PredictorInitialized = false

-- Math & RNG Helpers
local RESET_PERIOD_SECONDS = 300
local function imul(a, b)
    local ah, al, bh, bl = bit32.rshift(a, 16), bit32.band(a, 0xFFFF), bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
    local val = (ah * bl + al * bh) % 65536
    val = bit32.lshift(val, 16)
    return bit32.band(val + (al * bl), 0xFFFFFFFF)
end

local function getPeriodIndex(t) return math.max(math.floor(t / RESET_PERIOD_SECONDS), 0) end
local function getPeriodStartsAt(idx) return idx * RESET_PERIOD_SECONDS end
local function getNextResetAt(t) return getPeriodStartsAt(getPeriodIndex(t) + 1) end
local function getTimeLeft(t) return math.max(0, getNextResetAt(t) - t) end
local function getNightDurationSeconds() return 10 end
local function isNight(t) return getTimeLeft(t) <= getNightDurationSeconds() end
local function getActivePeriodIndex(t) local v1 = getPeriodIndex(t) return isNight(t) and (v1 + 1) or v1 end
local function getNightStartsAt(t) return getNextResetAt(t) - getNightDurationSeconds() end

local function getSlotSeed(fullStr)
    local hash = 2166136261
    for i = 1, #fullStr do 
        hash = bit32.bxor(hash, string.byte(fullStr, i)) 
        hash = imul(hash, 16777619) 
    end
    return hash <= 0 and 1 or hash
end

local function getEggFull(t, fullSeedStr, areaData)
    if not areaData or not areaData.Drops or #areaData.Drops == 0 then return "Unknown" end
    local seed = getSlotSeed(fullSeedStr)
    local nightOffset = isNight(t) and 1000 or 0
    local rng = Random.new(seed + nightOffset)
    local roll = rng:NextNumber()
    local total, cum = areaData.TotalWeight, 0
    for _, entry in ipairs(areaData.Drops) do
        cum = cum + (entry[2] / total)
        if roll <= cum then return entry[1] end
    end
    return areaData.Drops[1][1]
end

-- Initialize Drop Tables
task.spawn(function()
    local rDir = ReplicatedStorage:FindFirstChild("Data")
    if not rDir then return end

    local tempRarityData = {}
    pcall(function()
        local rarityMod = rDir:WaitForChild("Rarity", 5)
        if rarityMod then
            local rarityDir = require(rarityMod).Rarities
            for rName, data in pairs(rarityDir) do
                local dName = data.DisplayName or rName
                tempRarityData[dName] = { Order = data.RarityNumber or 0, Color = data.Color or Color3.fromRGB(200, 200, 200) }
            end
        end
    end)

    pcall(function()
        local assetsMod = rDir:WaitForChild("Assets", 5)
        if assetsMod then
            local assetsDir = require(assetsMod).Directory
            for modName, data in pairs(assetsDir) do
                if type(data) == "table" and data.Rarity then
                    local rName = data.Rarity.DisplayName or data.Rarity.Name or "Unknown"
                    AssetRarityMap[modName] = rName
                end
            end
        end
    end)

    local activeRarities = {}
    pcall(function()
        local areasMod = rDir:WaitForChild("Areas", 5)
        if areasMod then
            local areasDir = require(areasMod).Directory
            for modName, data in pairs(areasDir) do
                if data and data.DropTable then
                    local totalWeight = 0
                    for _, drop in ipairs(data.DropTable) do
                        totalWeight = totalWeight + (drop[2] or 0)
                        local petRarity = AssetRarityMap[drop[1]] or "Unknown"
                        activeRarities[petRarity] = true
                    end
                    AreaData[modName] = { Drops = data.DropTable, TotalWeight = totalWeight }
                end
            end
        end
    end)

    for rName, _ in pairs(activeRarities) do
        if tempRarityData[rName] then
            RarityOrderMap[rName] = tempRarityData[rName].Order
            RarityColorMap[rName] = tempRarityData[rName].Color
            table.insert(RarityList, rName)
        end
    end

    table.sort(RarityList, function(a, b) return (RarityOrderMap[a] or 0) < (RarityOrderMap[b] or 0) end)
    PredictorInitialized = true
end)

-- Background Predictor Scanner (Scans up to 100 periods = ~8.3 hours ahead)
task.spawn(function()
    local slotSuffixes = {}
    local slots = {"Slot1", "Slot2", "Slot3"}
    local lastScannedIdx = -1

    while task.wait(3) do
        if not PredictorInitialized then continue end

        local now = workspace:GetServerTimeNow()
        local currentIdx = getPeriodIndex(now)

        if currentIdx == lastScannedIdx then 
            continue 
        end
        lastScannedIdx = currentIdx

        local tempCache, seenTracker = {}, {}

        if not slotSuffixes["Desert"] then 
            for areaName, _ in pairs(AreaData) do
                slotSuffixes[areaName] = {
                    Slot1 = ":" .. areaName .. ":Slot1",
                    Slot2 = ":" .. areaName .. ":Slot2",
                    Slot3 = ":" .. areaName .. ":Slot3"
                }
            end
        end

        for i = 1, 1500 do
            if i % 50 == 0 then task.wait() end -- Smooth yielding (zero lag)

            local p = currentIdx + i
            local pStart = getPeriodStartsAt(p)
            local nightStart = getNightStartsAt(pStart)
            
            local activeDay = getActivePeriodIndex(pStart)
            local activeNight = getActivePeriodIndex(nightStart)
            
            local dayPrefix = tostring(activeDay)
            local nightPrefix = tostring(activeNight)

            for areaName, aData in pairs(AreaData) do
                local sfx = slotSuffixes[areaName]
                if not sfx then continue end

                for _, slotName in ipairs(slots) do
                    local sfxStr = sfx[slotName]
                    
                    local function ProcessEgg(petName, timeAt, phase)
                        local rarity = AssetRarityMap[petName] or "Unknown"
                        local rLow = string.lower(tostring(rarity))
                        
                        -- STRICT: Hanya Divine dan Eternal!
                        if rLow ~= "divine" and rLow ~= "eternal" then
                            return
                        end

                        local canonRarity = (rLow == "divine") and "Divine" or "Eternal"
                        local uniqueKey = petName .. "_" .. areaName .. "_" .. tostring(timeAt)
                        
                        if not seenTracker[uniqueKey] then
                            seenTracker[uniqueKey] = true
                            if not tempCache[canonRarity] then tempCache[canonRarity] = {} end
                            table.insert(tempCache[canonRarity], {
                                Name = petName,
                                Rarity = canonRarity,
                                TimeAt = timeAt,
                                Area = areaName,
                                Phase = phase,
                                SortValue = timeAt - now
                            })
                        end
                    end
                    
                    local daySeedStr = dayPrefix .. sfxStr
                    ProcessEgg(getEggFull(pStart, daySeedStr, aData), pStart, "Day")
                    
                    local nightSeedStr = nightPrefix .. sfxStr
                    ProcessEgg(getEggFull(nightStart, nightSeedStr, aData), nightStart, "Night")
                end
            end
        end
        
        CachedPredictions = tempCache
    end
end)

local function getPredictionSummary()
    local result = {}
    local now = workspace:GetServerTimeNow()

    for rName, list in pairs(CachedPredictions) do
        local rLow = string.lower(tostring(rName))
        if rLow == "divine" or rLow == "eternal" then
            for _, pet in ipairs(list) do
                local timeDiff = pet.TimeAt - now
                if timeDiff > -10 then -- semua jadwal Divine dan Eternal ke depan
                    table.insert(result, {
                        name = pet.Name,
                        rarity = pet.Rarity or rName,
                        area = pet.Area,
                        phase = pet.Phase,
                        timeAt = math.floor(pet.TimeAt),
                        timeDiff = math.floor(timeDiff)
                    })
                end
            end
        end
    end
    table.sort(result, function(a, b) return a.timeAt < b.timeAt end)

    -- Trim to top 60 Divine & Eternal predictions
    if #result > 60 then
        local trimmed = {}
        for i = 1, 60 do table.insert(trimmed, result[i]) end
        return trimmed
    end
    return result
end

-- ====================================================================
-- 🌐 WEBHOOK SENDERS
-- ====================================================================

-- Kirim Laporan Statistik ke Web Dashboard (p4kong.site)
local function sendWebStatusReport()
    if not Config.Track_WebMonitoring or not Config.WebMonitoring_URL or Config.WebMonitoring_URL == "" then
        return false, "Web Monitoring tidak aktif"
    end

    local currencies = getPlayerCurrencies()
    local inv = getInventorySummary()
    local uptimeStr = formatDuration(os.time() - ScriptStartTime)

    local mps = currencies.moneyPerSecond
    if not mps or mps == "N/A" then
        if inv.totalKandangEarnRate and inv.totalKandangEarnRate > 0 then
            mps = "+$" .. FormatNumber(inv.totalKandangEarnRate) .. "/s"
        else
            mps = "$0/s"
        end
    end

    local payload = {
        action = "update",
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        userId = LocalPlayer.UserId,
        uptime = uptimeStr,
        ping = currencies.ping,
        money = currencies.money,
        moneyPerSecond = mps,
        speed = currencies.speed,
        level = currencies.level,
        bestPet = inv.bestPet,
        predictions = getPredictionSummary(),
        petKandangCount = inv.petKandangCount,
        petsInKandang = inv.petsInKandang,
        eggBackpackCount = inv.eggBackpackCount,
        eggsInBackpack = inv.eggsInBackpack,
        eggMeta = inv.eggMeta,
        petBackpackCount = inv.petBackpackCount,
        petsInBackpack = inv.petsInBackpack,
        petMeta = inv.petMeta
    }

    local success, err = pcall(function()
        req({
            Url = Config.WebMonitoring_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    return success, err
end

-- Kirim Laporan Berkala (Periodic Status Update)
local function sendPeriodicStatusReport()
    -- 1. Kirim ke Web Dashboard p4kong.site jika aktif
    if Config.Track_WebMonitoring then
        task.spawn(function()
            pcall(sendWebStatusReport)
        end)
    end

    -- 2. Kirim ke Discord Webhook jika ada URL
    if not Config.WebhookURL or Config.WebhookURL == "" then
        return Config.Track_WebMonitoring, (Config.Track_WebMonitoring and "Terkirim ke Web Dashboard" or "Webhook URL belum diisi!")
    end

    local currencies = getPlayerCurrencies()
    local inv = getInventorySummary()
    local uptimeStr = formatDuration(os.time() - ScriptStartTime)

    local embedFields = {}

    -- 1. Money Sekarang & Rate (Jika Dipilih)
    if Config.Track_Money then
        local mps = currencies.moneyPerSecond
        if not mps or mps == "N/A" then
            if inv.totalKandangEarnRate and inv.totalKandangEarnRate > 0 then
                mps = "+$" .. FormatNumber(inv.totalKandangEarnRate) .. "/s"
            else
                mps = "$0/s"
            end
        end

        table.insert(embedFields, {
            name = "💰 Money Sekarang",
            value = "```" .. tostring(currencies.money) .. "```",
            inline = true
        })

        table.insert(embedFields, {
            name = "💸 Money / Detik",
            value = "```" .. tostring(mps) .. "```",
            inline = true
        })
    end

    -- Best Pet (Jika Ditemukan)
    if inv.bestPet then
        table.insert(embedFields, {
            name = "👑 Best Pet",
            value = string.format("```%s (%s • %s)```", inv.bestPet.name, inv.bestPet.rarity, inv.bestPet.earnRate),
            inline = true
        })
    end

    -- 2. Speed Sekarang (Jika Dipilih)
    if Config.Track_Speed then
        table.insert(embedFields, {
            name = "⚡ Speed Sekarang",
            value = "```" .. tostring(currencies.speed) .. "```",
            inline = true
        })
    end

    -- 3. Level Info
    if currencies.level ~= "N/A" then
        table.insert(embedFields, {
            name = "🎖️ Level",
            value = "```" .. tostring(currencies.level) .. "```",
            inline = true
        })
    end

    -- 4. Pet di Kandang / Active (Jika Dipilih)
    if Config.Track_PetKandang then
        local kandangDetail = string.format("**Total:** `%d Pet Terpasang`", inv.petKandangCount)
        local items = {}
        for name, count in pairs(inv.petsInKandang) do
            local c = type(count) == "table" and (count.count or 1) or tonumber(count) or 1
            table.insert(items, string.format("• %s: `x%d`", name, c))
            if #items >= 15 then break end
        end
        if #items > 0 then
            kandangDetail = kandangDetail .. "\n" .. table.concat(items, "\n")
        end
        table.insert(embedFields, {
            name = "🏡 Pet di Kandang (Active)",
            value = kandangDetail,
            inline = false
        })
    end

    -- 5. Egg di Backpack (Jika Dipilih)
    if Config.Track_EggBackpack then
        local eggDetail = string.format("**Total:** `%d Telur`", inv.eggBackpackCount)
        local items = {}
        for name, count in pairs(inv.eggsInBackpack) do
            local c = type(count) == "table" and (count.count or 1) or tonumber(count) or 1
            table.insert(items, string.format("• %s: `x%d`", name, c))
            if #items >= 12 then break end
        end
        if #items > 0 then
            eggDetail = eggDetail .. "\n" .. table.concat(items, "\n")
        end
        table.insert(embedFields, {
            name = "🎒 Egg di Backpack",
            value = eggDetail,
            inline = false
        })
    end

    -- 6. Pet di Backpack (Jika Dipilih)
    if Config.Track_PetBackpack then
        local petDetail = string.format("**Total:** `%d Pet`", inv.petBackpackCount)
        local items = {}
        for name, count in pairs(inv.petsInBackpack) do
            local c = type(count) == "table" and (count.count or 1) or tonumber(count) or 1
            table.insert(items, string.format("• %s: `x%d`", name, c))
            if #items >= 12 then break end
        end
        if #items > 0 then
            petDetail = petDetail .. "\n" .. table.concat(items, "\n")
        end
        table.insert(embedFields, {
            name = "🐾 Pet di Backpack",
            value = petDetail,
            inline = false
        })
    end

    -- Field Info Server & Durasi
    table.insert(embedFields, {
        name = "⏳ Durasi Monitoring",
        value = uptimeStr,
        inline = true
    })
    table.insert(embedFields, {
        name = "📶 Ping",
        value = currencies.ping,
        inline = true
    })

    local ping = Config.WebhookPingID
    local mentionStr = (ping and ping ~= "") and ("<@" .. ping .. ">") or nil

    local payload = {
        content = mentionStr,
        username = "Steal An Egg Monitor",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png",
        embeds = {{
            title = "📊 Laporan Akun: " .. LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")",
            description = "Game: **Steal An Egg** • Status: 🟢 **Monitoring Aktif**",
            color = 3447003,
            fields = embedFields,
            thumbnail = {
                url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png"
            },
            footer = { text = "P4kong x SysHub Monitor • Auto Report" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    local success, err = pcall(function()
        req({
            Url = Config.WebhookURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)

    return success, err
end

-- Kirim Event Realtime (Saat Egg Ditemukan / Dicuri)
local function sendEggStealEvent(cat, rec)
    local scale = tonumber(rec.AssetScale) or 1
    local formattedScale = string.format("%.2f", scale)
    local mutationsStr = GetMutationsString(rec)

    local rarityName = "Unknown"
    local displayName = cat
    local earnRate = 0

    pcall(function()
        local Assets = require(ReplicatedStorage.Data.Assets)
        if Assets and Assets.Directory and Assets.Directory[cat] then
            local pData = Assets.Directory[cat]
            local r = pData.Rarity or (pData.Egg and pData.Egg.Rarity) or "Unknown"
            rarityName = type(r) == "table" and (r.Title or r.Name or "Unknown") or tostring(r)
            displayName = pData.DisplayName or pData.Name or cat
            earnRate = pData.EarnRate or 0
        end
    end)

    pcall(function()
        local bRate = require(ReplicatedStorage.Shared.Util.AssetEarnings).MutationOnlyRatePerSecond({Category = cat, Scale = scale, Mutations = {}, BaseMutation = ""})
        if type(bRate) == "number" and bRate > 0 then earnRate = bRate end
    end)

    -- 1. Kirim ke Web Dashboard p4kong.site jika aktif
    if Config.Track_WebMonitoring and Config.WebMonitoring_Steal and Config.WebMonitoring_Steal ~= "" then
        task.spawn(function()
            pcall(function()
                local webStealPayload = {
                    action = "steal",
                    username = LocalPlayer.Name,
                    displayName = LocalPlayer.DisplayName,
                    userId = LocalPlayer.UserId,
                    eggName = displayName,
                    rarity = rarityName,
                    earnRate = FormatNumber(earnRate),
                    scale = formattedScale,
                    mutations = mutationsStr,
                    timestamp = os.time() * 1000
                }
                req({
                    Url = Config.WebMonitoring_Steal,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(webStealPayload)
                })
            end)
        end)
    end

    -- 2. Kirim ke Discord Webhook jika ada
    if not Config.WebhookURL or Config.WebhookURL == "" or not Config.Track_EggObtained then return end

    local c = RarityColors[rarityName] or Color3.fromRGB(0, 255, 200)
    local colorDecimal = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)

    local ping = Config.WebhookPingID
    local mentionStr = (ping and ping ~= "") and ("<@" .. ping .. ">") or nil

    local payload = {
        content = mentionStr,
        embeds = {{
            author = {
                name = "Steal An Egg Tracker",
                icon_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png"
            },
            title = "🕵️ Telur Berhasil Dicuri ke Backpack!",
            color = colorDecimal,
            fields = {
                { name = "👤 Player", value = "```" .. LocalPlayer.Name .. "```", inline = false },
                { name = "🐾 Spesies", value = "```" .. displayName .. "```", inline = true },
                { name = "💎 Rarity", value = "```" .. rarityName .. "```", inline = true },
                { name = "💸 Earn Rate", value = "```$" .. FormatNumber(earnRate) .. "/s```", inline = true },
                { name = "📊 Multiplier Scale", value = "```" .. formattedScale .. "x```", inline = true },
                { name = "🧬 Mutasi", value = "```" .. mutationsStr .. "```", inline = true }
            },
            footer = { text = "Monitoring • Event Egg Didapat" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    task.spawn(function()
        pcall(function()
            req({
                Url = Config.WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end)
end

-- ====================================================================
-- 🖥️ WINDUI INTERFACE (CLEAN & USER CONFIGURABLE)
-- ====================================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- Hapus window lama jika ada agar tidak menumpuk saat re-execute
pcall(function()
    local coreGui = game:GetService("CoreGui")
    if coreGui then
        for _, g in ipairs(coreGui:GetChildren()) do
            if g.Name:find("WindUI") or g.Name:find("StealAnEgg") then
                pcall(function() g:Destroy() end)
            end
        end
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name:find("WindUI") or g.Name:find("StealAnEgg") then
                pcall(function() g:Destroy() end)
            end
        end
    end
end)

local Window = WindUI:CreateWindow({
    Title = "Steal An Egg - Monitor",
    Icon = "egg",
    Author = "P4kong x SysHub",
    Folder = "StealAnEggMonitor",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 170,
    HasOutline = true
})

-- TAB 1: WEB MONITORING (p4kong.site/monitoringjoki)
local TabWeb = Window:Tab({ Title = "Web Monitor", Icon = "globe", Locked = false })

TabWeb:Section({ Title = "🌐 Monitoring Online di p4kong.site", TextSize = 18 })

TabWeb:Toggle({
    Title = "Aktifkan Monitoring Web (p4kong.site)",
    Value = Config.Track_WebMonitoring,
    Callback = function(val)
        Config.Track_WebMonitoring = val
        SaveSettings()
        if val then
            task.spawn(sendWebStatusReport)
            WindUI:Notify({ Title = "Web Monitor", Content = "Monitoring web aktif! Data dikirim ke p4kong.site.", Duration = 3 })
        else
            WindUI:Notify({ Title = "Web Monitor", Content = "Monitoring web dinonaktifkan.", Duration = 2 })
        end
    end
})

TabWeb:Paragraph({
    Title = "Akses Dashboard Joki Online",
    Desc = "🌐 URL: https://p4kong.site/monitoringjoki\n🔑 PIN Akses: 1802\n\nBuka link di browser HP atau PC untuk memantau semua akun joki secara realtime."
})

TabWeb:Button({
    Title = "⚡ Kirim Update ke Web Sekarang",
    Icon = "send",
    Color = Color3.fromRGB(56, 189, 248),
    Callback = function()
        local success, err = sendWebStatusReport()
        if success then
            WindUI:Notify({ Title = "Terkirim", Content = "Statistik berhasil dikirim ke p4kong.site/monitoringjoki!", Duration = 3 })
        else
            WindUI:Notify({ Title = "Gagal", Content = tostring(err or "Gagal mengirim ke server."), Duration = 4 })
        end
    end
})

TabWeb:Button({
    Title = "📋 Salin Link Dashboard (p4kong.site)",
    Icon = "copy",
    Color = Color3.fromRGB(16, 185, 129),
    Callback = function()
        if setclipboard then
            setclipboard("https://p4kong.site/monitoringjoki")
            WindUI:Notify({ Title = "Disalin!", Content = "https://p4kong.site/monitoringjoki disalin ke clipboard! (PIN: 1802)", Duration = 3 })
        else
            WindUI:Notify({ Title = "Info", Content = "Buka: https://p4kong.site/monitoringjoki (PIN: 1802)", Duration = 4 })
        end
    end
})

-- TAB 2: WEBHOOK SETTINGS
local TabWebhook = Window:Tab({ Title = "Webhook", Icon = "webhook", Locked = false })

TabWebhook:Section({ Title = "Koneksi Webhook Discord", TextSize = 18 })

TabWebhook:Input({
    Title = "Webhook URL",
    Value = Config.WebhookURL,
    Placeholder = "https://discord.com/api/webhooks/...",
    Icon = "link",
    Callback = function(val)
        Config.WebhookURL = val
        SaveSettings()
    end
})

TabWebhook:Input({
    Title = "Discord User ID (For Mention)",
    Value = Config.WebhookPingID,
    Placeholder = "123456789012345678 (Opsional)",
    Icon = "at-sign",
    Callback = function(val)
        Config.WebhookPingID = val
        SaveSettings()
    end
})

TabWebhook:Divider()
TabWebhook:Section({ Title = "⏱️ Jadwal Update Statistik Akun", TextSize = 18 })

-- Dropdown Pilihan Menit Preset
TabWebhook:Dropdown({
    Title = "Pilih Interval Update Webhook",
    Values = {"1 Menit", "2 Menit", "3 Menit", "5 Menit", "10 Menit", "15 Menit", "30 Menit", "60 Menit"},
    Value = tostring(Config.IntervalMinutes) .. " Menit",
    Callback = function(selected)
        local num = tonumber(string.match(selected, "%d+"))
        if num then
            Config.IntervalMinutes = num
            resetReportTimer()
            SaveSettings()
            WindUI:Notify({
                Title = "Interval Disimpan",
                Content = "Statistik akan otomatis dikirim setiap " .. num .. " menit!",
                Duration = 3
            })
        end
    end
})

-- Slider untuk atur menit kustom
TabWebhook:Slider({
    Title = "Atur Menit Kustom (1 - 60 Menit)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 60,
        Default = Config.IntervalMinutes
    },
    Callback = function(val)
        Config.IntervalMinutes = tonumber(val) or 5
        resetReportTimer()
        SaveSettings()
    end
})

-- Tombol Aksi Update & Reset
TabWebhook:Button({
    Title = "⚡ Update & Kirim Statistik Sekarang",
    Icon = "send",
    Color = Color3.fromRGB(0, 255, 127),
    Callback = function()
        local success, err = sendPeriodicStatusReport()
        if success then
            resetReportTimer()
            WindUI:Notify({ Title = "Terkirim", Content = "Statistik akun berhasil dikirim ke Discord!", Duration = 3 })
        else
            WindUI:Notify({ Title = "Gagal", Content = tostring(err or "Periksa Webhook URL kamu!"), Duration = 4 })
        end
    end
})

TabWebhook:Button({
    Title = "🔄 Reset Timer Laporan Berkala",
    Icon = "timer",
    Color = Color3.fromRGB(56, 189, 248),
    Callback = function()
        resetReportTimer()
        WindUI:Notify({
            Title = "Timer Direset",
            Content = "Hitungan update berikutnya diatur ulang (" .. Config.IntervalMinutes .. " menit dari sekarang).",
            Duration = 3
        })
    end
})

TabWebhook:Divider()
TabWebhook:Section({ Title = "📊 Pilihan Data yang Dimasukkan ke Webhook", TextSize = 18 })

TabWebhook:Toggle({
    Title = "Egg yang di dapet (Realtime Saat Mencuri)",
    Value = Config.Track_EggObtained,
    Callback = function(val)
        Config.Track_EggObtained = val
        SaveSettings()
    end
})

TabWebhook:Toggle({
    Title = "Pet di Kandang (Active / Terpasang)",
    Value = Config.Track_PetKandang,
    Callback = function(val)
        Config.Track_PetKandang = val
        SaveSettings()
    end
})

TabWebhook:Toggle({
    Title = "Egg di Backpack (Jumlah & List)",
    Value = Config.Track_EggBackpack,
    Callback = function(val)
        Config.Track_EggBackpack = val
        SaveSettings()
    end
})

TabWebhook:Toggle({
    Title = "Pet di Backpack (Jumlah & List)",
    Value = Config.Track_PetBackpack,
    Callback = function(val)
        Config.Track_PetBackpack = val
        SaveSettings()
    end
})

TabWebhook:Toggle({
    Title = "Money Sekarang ($...)",
    Value = Config.Track_Money,
    Callback = function(val)
        Config.Track_Money = val
        SaveSettings()
    end
})

TabWebhook:Toggle({
    Title = "Speed Sekarang",
    Value = Config.Track_Speed,
    Callback = function(val)
        Config.Track_Speed = val
        SaveSettings()
    end
})

TabWebhook:Toggle({
    Title = "Kirim Laporan Berkala Otomatis",
    Value = Config.AutoReport,
    Callback = function(val)
        Config.AutoReport = val
        SaveSettings()
    end
})

-- TAB 2: LIVE STATS VIEWER
local TabStats = Window:Tab({ Title = "Live Stats", Icon = "activity", Locked = false })
TabStats:Section({ Title = "Statistik Akun Terkini", TextSize = 18 })

local StatParagraph = TabStats:Paragraph({
    Title = "Ringkasan Akun",
    Desc = "Memuat data dari game..."
})

local function refreshStatsUI()
    local cur = getPlayerCurrencies()
    local inv = getInventorySummary()
    local remaining = math.max(0, nextReportTimestamp - os.time())
    
    local petKandangStr = string.format("%d Pet Terpasang", inv.petKandangCount)
    local samplePets = {}
    for name, count in pairs(inv.petsInKandang) do
        local c = type(count) == "table" and (count.count or 1) or tonumber(count) or 1
        table.insert(samplePets, string.format("%s (x%d)", name, c))
        if #samplePets >= 4 then break end
    end
    if #samplePets > 0 then
        petKandangStr = petKandangStr .. " [" .. table.concat(samplePets, ", ") .. "]"
    end

    local mps = cur.moneyPerSecond
    if not mps or mps == "N/A" then
        if inv.totalKandangEarnRate and inv.totalKandangEarnRate > 0 then
            mps = "+$" .. FormatNumber(inv.totalKandangEarnRate) .. "/s"
        else
            mps = "$0/s"
        end
    end

    local bestPetStr = inv.bestPet and string.format("%s (%s • %s)", inv.bestPet.name, inv.bestPet.rarity, inv.bestPet.earnRate) or "N/A"

    local desc = string.format(
        "💰 Money: %s\n💸 Money/s: %s\n⚡ Speed: %s\n🎖️ Level: %s\n👑 Best Pet: %s\n\n🏡 Pet di Kandang: %s\n🎒 Telur di Backpack: %d\n🐾 Pet di Backpack: %d\n\n⏳ Uptime: %s\n📶 Ping: %s\n⏱️ Update Berikutnya: %d detik lagi",
        cur.money, mps, cur.speed, cur.level, bestPetStr,
        petKandangStr,
        inv.eggBackpackCount, inv.petBackpackCount,
        formatDuration(os.time() - ScriptStartTime), cur.ping,
        remaining
    )
    StatParagraph:SetDesc(desc)
end

TabStats:Button({
    Title = "Refresh Tampilan Stats",
    Icon = "refresh-cw",
    Callback = function()
        refreshStatsUI()
        WindUI:Notify({ Title = "Refreshed", Content = "Tampilan data berhasil diperbarui!", Duration = 2 })
    end
})

-- TAB 4: LIVE PREDICTOR (EGG SPAWN PREDICTION)
local TabPredict = Window:Tab({ Title = "Predictor", Icon = "clock", Locked = false })
TabPredict:Section({ Title = "🔮 Live Egg Spawn Predictor", TextSize = 18 })

TabPredict:Paragraph({
    Title = "SysHub x P4kong Prediction Engine",
    Desc = "Prediksi jadwal spawn telur berdasarkan algoritma RNG dan drop table map. Selalu otomatis di-update dan dikirim ke web dashboard & bot WA!"
})

local PredParagraph = TabPredict:Paragraph({
    Title = "Jadwal Spawn Terdekat (Divine & Eternal)",
    Desc = "Sedang memuat data prediksi..."
})

local function formatPredictCountdown(sec)
    if sec <= 0 then return "Now" end
    local days = math.floor(sec / 86400)
    local hours = math.floor((sec % 86400) / 3600)
    local mins = math.floor((sec % 3600) / 60)
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

local function refreshPredictorUI()
    local preds = getPredictionSummary()
    local now = workspace:GetServerTimeNow()

    local divineList = {}
    local eternalList = {}

    for _, p in ipairs(preds) do
        local rLow = string.lower(tostring(p.rarity or ""))
        local diff = p.timeAt - now
        local clockWib = os.date("!%H:%M", p.timeAt + 7 * 3600)
        local cdStr = formatPredictCountdown(diff)
        local line = string.format("%s - %s (%s) @ %s", p.name, clockWib, cdStr, p.area)

        if rLow == "divine" then
            table.insert(divineList, line)
        elseif rLow == "eternal" then
            table.insert(eternalList, line)
        end
    end

    local textParts = {}
    if #divineList > 0 then
        table.insert(textParts, "👑 DIVINE")
        for i = 1, math.min(#divineList, 15) do
            table.insert(textParts, divineList[i])
        end
    end

    if #eternalList > 0 then
        if #textParts > 0 then table.insert(textParts, "") end
        table.insert(textParts, "🔥 ETERNAL")
        for i = 1, math.min(#eternalList, 15) do
            table.insert(textParts, eternalList[i])
        end
    end

    if #textParts == 0 then
        PredParagraph:SetDesc("Belum ada jadwal spawn Divine / Eternal terdeteksi, atau scanner sedang berjalan...")
    else
        PredParagraph:SetDesc(table.concat(textParts, "\n"))
    end
end

TabPredict:Button({
    Title = "🔄 Refresh Prediksi In-Game",
    Icon = "refresh-cw",
    Callback = function()
        refreshPredictorUI()
        WindUI:Notify({ Title = "Predictor", Content = "Data prediksi in-game diperbarui!", Duration = 2 })
    end
})

TabPredict:Button({
    Title = "🌐 Buka Prediksi di Web",
    Icon = "globe",
    Color = Color3.fromRGB(56, 189, 248),
    Callback = function()
        if setclipboard then
            setclipboard("https://p4kong.site/monitoringjoki")
            WindUI:Notify({ Title = "Disalin!", Content = "Buka tab Predictor di p4kong.site/monitoringjoki", Duration = 3 })
        end
    end
})

-- ====================================================================
-- 🌀 BACKGROUND LISTENERS (REALTIME EGG DETECTOR & AUTO REPORT)
-- ====================================================================

-- 1. Realtime Steal Detector (Deteksi Egg Baru Masuk Backpack)
task.spawn(function()
    local knownSteal = {}
    local firstRun = true

    while task.wait(1.5) do
        pcall(function()
            local saveMod = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Save")
            if not saveMod then return end
            local sData = require(saveMod).Get()
            if not sData or not sData.EggInventory then return end

            if firstRun then
                for uid, _ in pairs(sData.EggInventory) do knownSteal[uid] = true end
                firstRun = false
                return
            end

            for uid, rec in pairs(sData.EggInventory) do
                if not knownSteal[uid] then
                    knownSteal[uid] = true
                    if rec.Placement == nil then
                        local cat = rec.AssetCategory or "Unknown"
                        sendEggStealEvent(cat, rec)
                    end
                end
            end
        end)
    end
end)

-- 2. Dedicated 5-Second Realtime Web Heartbeat (Menjaga Status Online & Uptime Terus Bergerak)
task.spawn(function()
    task.wait(2)
    while true do
        if Config.Track_WebMonitoring and Config.WebMonitoring_URL and Config.WebMonitoring_URL ~= "" then
            pcall(sendWebStatusReport)
        end
        task.wait(5)
    end
end)

-- 3. Auto Periodic Reporter Loop (Untuk Discord Webhook & In-Game UI Refresh)
task.spawn(function()
    task.wait(3)
    pcall(refreshStatsUI)

    while task.wait(1) do
        pcall(function()
            if os.time() % 3 == 0 then
                refreshStatsUI()
            end
        end)

        if Config.AutoReport and Config.WebhookURL and Config.WebhookURL ~= "" then
            if os.time() >= nextReportTimestamp then
                resetReportTimer()
                pcall(function()
                    sendPeriodicStatusReport()
                    refreshStatsUI()
                end)
            end
        end
    end
end)

WindUI:Notify({
    Title = "Steal An Egg Monitor",
    Content = "Script monitoring murni berhasil dimuat!",
    Duration = 4
})
