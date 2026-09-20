--[[
    ===================================================================
    🔥 Steal An Egg - Webhook Tracker & Monitor (WindUI Edition)
    GitHub Repo: https://github.com/kongsprb-lgtm/monitoring
    ===================================================================
    Execute via Loadstring:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/kongsprb-lgtm/monitoring/main/steal_an_egg.lua"))()
    ===================================================================
]]--

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- // Anti-AFK Protection (Supaya joki tidak disconnect 20 menit)
if LocalPlayer then
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
    print("[Monitor] Anti-AFK aktif.")
end

-- // HTTP Request function
local req = http_request or request or HttpPost or (syn and syn.request) or (fluxus and fluxus.request)
if not req then
    warn("[Error] Executor tidak mendukung fungsi http request!")
    return
end

-- // DATABASE & RARITY INITIALIZER (Biar mandiri dan tidak error jika DB nil)
local DB = {
    Pets = {},
    RarityDict = {},
    AvailableRarities = {}
}

pcall(function()
    local Assets = require(ReplicatedStorage.Data.Assets)
    if Assets and Assets.Directory then
        for id, data in pairs(Assets.Directory) do
            local rarity = data.Rarity or (data.Egg and data.Egg.Rarity) or "Common"
            DB.Pets[id] = {
                Rarity = rarity,
                DisplayName = data.DisplayName or data.Name or id,
                EarnRate = data.EarnRate or 0
            }
            if not table.find(DB.AvailableRarities, rarity) then
                table.insert(DB.AvailableRarities, rarity)
            end
        end
    end
end)

if #DB.AvailableRarities == 0 then
    DB.AvailableRarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Eternal", "Divine"}
end

local defaultColors = {
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

for i, r in ipairs(DB.AvailableRarities) do
    DB.RarityDict[r] = {
        Number = i,
        Color = defaultColors[r] or Color3.fromRGB(255, 255, 255)
    }
end

-- // Element Registry & Config Storage
local ElementRegistry = {}
local function Reg(key, el)
    ElementRegistry[key] = el
    return el
end

local ConfigFile = "StealAnEgg_WindUI_Config.json"
local SavedConfig = {
    WebhookURL = "",
    WebhookPingID = "",
    WebhookRarities = {},
    WHS_Spawn = false,
    WHS_Steal = true,
    WHS_Hatch = true
}

if isfile and readfile and isfile(ConfigFile) then
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(ConfigFile))
        for k, v in pairs(decoded) do
            SavedConfig[k] = v
        end
    end)
end

local function SaveSettings()
    if writefile then
        pcall(function()
            SavedConfig.WebhookURL = getgenv().WebhookURL or ""
            SavedConfig.WebhookPingID = getgenv().WebhookPingID or ""
            SavedConfig.WebhookRarities = getgenv().WebhookRarities or {}
            SavedConfig.WHS_Spawn = getgenv().WHS_Spawn or false
            SavedConfig.WHS_Steal = getgenv().WHS_Steal or false
            SavedConfig.WHS_Hatch = getgenv().WHS_Hatch or false
            writefile(ConfigFile, HttpService:JSONEncode(SavedConfig))
        end)
    end
end

-- Set environment globals dari saved config
getgenv().WebhookURL = SavedConfig.WebhookURL or ""
getgenv().WebhookPingID = SavedConfig.WebhookPingID or ""
getgenv().WebhookRarities = SavedConfig.WebhookRarities or {}
getgenv().WHS_Spawn = SavedConfig.WHS_Spawn or false
getgenv().WHS_Steal = SavedConfig.WHS_Steal or false
getgenv().WHS_Hatch = SavedConfig.WHS_Hatch or false

-- // Load WindUI Library
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Steal An Egg - Monitor",
    Icon = "egg",
    Author = "by kongsprb-lgtm",
    Folder = "StealAnEggMonitor",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 170,
    HasOutline = true
})

-- ====================================================================
-- TAB WEBHOOK
-- ====================================================================
do
    local webhookTab = Window:Tab({ Title = "Webhook", Icon = "webhook", Locked = false })
    local whSec = webhookTab:Section({ Title = "Discord Webhook Setup", TextSize = 20 })

    local function FormatNumber(value)
        if type(value) ~= "number" then return "0" end
        if value >= 1e18 then return string.format("%.2f Qi", value / 1e18):gsub("%.00", "")
        elseif value >= 1e15 then return string.format("%.2f Q", value / 1e15):gsub("%.00", "")
        elseif value >= 1e12 then return string.format("%.2f T", value / 1e12):gsub("%.00", "")
        elseif value >= 1e9 then return string.format("%.2f B", value / 1e9):gsub("%.00", "")
        elseif value >= 1e6 then return string.format("%.2f M", value / 1e6):gsub("%.00", "")
        elseif value >= 1e3 then return string.format("%.1f K", value / 1e3):gsub("%.0", "")
        else return tostring(math.floor(value)) end
    end

    -- Helper Mutasi
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

    Reg("wh_url", whSec:Input({
        Title = "Webhook URL",
        Value = getgenv().WebhookURL,
        Placeholder = "https://discord.com/api/webhooks/...",
        Icon = "link",
        Callback = function(text)
            getgenv().WebhookURL = text
            SaveSettings()
        end
    }))

    Reg("wh_ping", whSec:Input({
        Title = "Discord User ID (For Mention)",
        Value = getgenv().WebhookPingID,
        Placeholder = "123456789012345678 (Opsional)",
        Icon = "at-sign",
        Callback = function(text)
            getgenv().WebhookPingID = text
            SaveSettings()
        end
    }))

    Reg("wh_rarity_filter", whSec:Dropdown({
        Title = "Filter Rarity To Webhook",
        Multi = true,
        AllowNone = true,
        Values = DB.AvailableRarities,
        Value = getgenv().WebhookRarities,
        Callback = function(val)
            getgenv().WebhookRarities = val
            SaveSettings()
        end
    }))

    whSec:Divider()

    Reg("wh_tgl_spawn", whSec:Toggle({
        Title = "Webhook On Egg Spawn (Grouped)",
        Value = getgenv().WHS_Spawn,
        Callback = function(s)
            getgenv().WHS_Spawn = s
            SaveSettings()
        end
    }))

    Reg("wh_tgl_steal", whSec:Toggle({
        Title = "Webhook On Steal (To Backpack)",
        Value = getgenv().WHS_Steal,
        Callback = function(s)
            getgenv().WHS_Steal = s
            SaveSettings()
        end
    }))

    Reg("wh_tgl_hatch", whSec:Toggle({
        Title = "Webhook On Hatch (Pet Result)",
        Value = getgenv().WHS_Hatch,
        Callback = function(s)
            getgenv().WHS_Hatch = s
            SaveSettings()
        end
    }))

    -- ============================================================
    -- 🔄 UPDATER DROPDOWN RARITY WEBHOOK
    -- ============================================================
    task.spawn(function()
        local lastRarCount = 0
        while task.wait(2) do
            pcall(function()
                if DB and DB.AvailableRarities and #DB.AvailableRarities > lastRarCount then
                    lastRarCount = #DB.AvailableRarities
                    if ElementRegistry["wh_rarity_filter"] and ElementRegistry["wh_rarity_filter"].Refresh then
                        pcall(function()
                            if setthreadidentity then setthreadidentity(8) elseif setidentity then setidentity(8) end
                            ElementRegistry["wh_rarity_filter"]:Refresh(DB.AvailableRarities)
                        end)
                    end
                end
            end)
        end
    end)

    -- ============================================================
    -- 👤 FUNGSI PENGIRIMAN WEBHOOK PERSONAL
    -- ============================================================
    getgenv().SendDiscordWebhook = function(actionType, petId, valueInfo, forceBypassFilter)
        local personalUrl = getgenv().WebhookURL
        if not req or not personalUrl or personalUrl == "" then return end

        local playerName = LocalPlayer and LocalPlayer.Name or "Unknown Player"
        local rarityName = "Unknown"
        local displayName = petId
        local earnRate = 0
        
        if actionType ~= "SpawnBatch" then
            rarityName = DB.Pets[petId] and DB.Pets[petId].Rarity or "Unknown"
            displayName = DB.Pets[petId] and DB.Pets[petId].DisplayName or petId
            earnRate = DB.Pets[petId] and DB.Pets[petId].EarnRate or 0
        end

        local allowed = getgenv().WebhookRarities or {}
        if actionType ~= "SpawnBatch" and not forceBypassFilter and #allowed > 0 and not table.find(allowed, rarityName) then 
            return 
        end

        local embedFields = {}
        local embedTitle, titleIcon = "", ""
        local colorDecimal = 16777215
        local targetPetIdForImage = petId 

        if actionType == "SpawnBatch" then
            local batchData = valueInfo 
            local groupedByRarity = {}
            local highestRarityNum = -1
            local bestPetColor = 16777215

            for _, egg in ipairs(batchData) do
                local pId = egg.id
                local scale = tonumber(egg.scale) or 1
                local dName = DB.Pets[pId] and DB.Pets[pId].DisplayName or pId
                local mutStr = GetMutationsString(egg.itemData)
                
                local eRate = DB.Pets[pId] and DB.Pets[pId].EarnRate or 0
                pcall(function()
                    local bRate = require(ReplicatedStorage.Shared.Util.AssetEarnings).MutationOnlyRatePerSecond({Category = pId, Scale = scale, Mutations = {}, BaseMutation = ""})
                    if type(bRate) == "number" and bRate > 0 then eRate = bRate end
                end)

                local rName = DB.Pets[pId] and DB.Pets[pId].Rarity or "Unknown"
                local rNum = DB.RarityDict[rName] and DB.RarityDict[rName].Number or 0
                
                if forceBypassFilter or #allowed == 0 or table.find(allowed, rName) then
                    if not groupedByRarity[rName] then groupedByRarity[rName] = { items = {}, order = rNum } end
                    local formattedScale = string.format("%.2f", scale)
                    local lineStr = string.format("> 🐾 **%s** | ⚖️ `%sx` | 💸 `$%s/s` | 🧬 `%s`", dName, formattedScale, FormatNumber(eRate), mutStr)
                    table.insert(groupedByRarity[rName].items, lineStr)
                    
                    if rNum > highestRarityNum then
                        highestRarityNum = rNum
                        targetPetIdForImage = pId
                        local c = DB.RarityDict[rName] and DB.RarityDict[rName].Color or Color3.new(1,1,1)
                        bestPetColor = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)
                    end
                end
            end

            if highestRarityNum == -1 then return end
            titleIcon = "📡"
            embedTitle = "Area Egg Scanner - Spawns Detected!"
            colorDecimal = bestPetColor
            table.insert(embedFields, { ["name"] = "👤 Player", ["value"] = "```" .. playerName .. "```", ["inline"] = false })

            local sortedGroups = {}
            for k, v in pairs(groupedByRarity) do table.insert(sortedGroups, { name = k, data = v }) end
            table.sort(sortedGroups, function(a,b) return a.data.order > b.data.order end)

            for _, g in ipairs(sortedGroups) do
                local textBlock = table.concat(g.data.items, "\n")
                if string.len(textBlock) > 1024 then textBlock = string.sub(textBlock, 1, 1020) .. "..." end
                table.insert(embedFields, { ["name"] = "💎 " .. g.name, ["value"] = textBlock, ["inline"] = false })
            end
        else
            local safeScale = 1
            if type(valueInfo) == "table" then
                safeScale = tonumber(valueInfo.AssetScale) or tonumber(valueInfo.Scale) or 1
            else
                safeScale = tonumber(valueInfo) or 1
            end

            pcall(function()
                local itemData = (type(valueInfo) == "table") and valueInfo or { Category = petId, Scale = safeScale, Mutations = {}, BaseMutation = "" }
                local bRate = require(ReplicatedStorage.Shared.Util.AssetEarnings).MutationOnlyRatePerSecond(itemData)
                if type(bRate) == "number" and bRate > 0 then earnRate = bRate end
            end)
            
            local c = DB.RarityDict[rarityName] and DB.RarityDict[rarityName].Color or Color3.new(1,1,1)
            colorDecimal = math.floor(c.R * 255) * 65536 + math.floor(c.G * 255) * 256 + math.floor(c.B * 255)
            
            local valueLabel, valueField = "", ""
            local mutationsStr = GetMutationsString(valueInfo)
            local formattedScale = string.format("%.2f", safeScale)

            if actionType == "Steal" then
                titleIcon = "🕵️"
                embedTitle = "Egg Successfully Stolen!"
                valueLabel = "Multiplier Scale" 
                valueField = "```" .. formattedScale .. "x```"
            elseif actionType == "Hatch" then
                titleIcon = "✨"
                embedTitle = "Pet Successfully Hatched!"
                valueLabel = "Pet Weight"
                local displayWeight = "0 Kg"
                pcall(function() displayWeight = require(ReplicatedStorage.Shared.Util.AssetItems).WeightLabel(valueInfo) end)
                valueField = "```" .. tostring(displayWeight) .. "```"
            end

            table.insert(embedFields, { ["name"] = "👤 Player", ["value"] = "```" .. playerName .. "```", ["inline"] = false })
            table.insert(embedFields, { ["name"] = "🐾 Species", ["value"] = "```" .. displayName .. "```", ["inline"] = true })
            table.insert(embedFields, { ["name"] = "💎 Rarity", ["value"] = "```" .. rarityName .. "```", ["inline"] = true })
            table.insert(embedFields, { ["name"] = "💸 Earn Rate", ["value"] = "```$" .. FormatNumber(earnRate) .. "/s```", ["inline"] = true })
            table.insert(embedFields, { ["name"] = "📊 " .. valueLabel, ["value"] = valueField, ["inline"] = true })
            table.insert(embedFields, { ["name"] = "🧬 Mutations", ["value"] = "```" .. mutationsStr .. "```", ["inline"] = true })
        end

        local imageUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png"
        
        pcall(function() 
            local imgData = require(ReplicatedStorage.Data.Assets).Directory[targetPetIdForImage] or {}
            local rawIcon = imgData.Egg and imgData.Egg.Icon or imgData.Icon or ""
            local iconId = rawIcon:match("%d+")
            
            if iconId then
                local res1 = req({ Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. iconId .. "&returnPolicy=PlaceHolder&size=420x420&format=Png", Method = "GET" })
                local data1 = HttpService:JSONDecode(res1.Body)
                if data1 and data1.data and data1.data[1] then
                    local img = data1.data[1].imageUrl
                    if img and not string.find(img, "e5bef3") and not string.find(img, "unapproved") then imageUrl = img end
                end
            end
        end)

        local ping = getgenv().WebhookPingID
        local mentionStr = (ping and ping ~= "") and ("<@" .. ping .. ">") or ""
        local payload = {
            ["content"] = mentionStr ~= "" and mentionStr or nil,
            ["embeds"] = {{
                ["author"] = { ["name"] = "Steal An Egg Tracker", ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=150&height=150&format=png" },
                ["title"] = titleIcon .. " " .. embedTitle,
                ["color"] = colorDecimal,
                ["thumbnail"] = { ["url"] = imageUrl },
                ["fields"] = embedFields,
                ["footer"] = { ["text"] = "Monitoring • Auto-Tracker" },
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }}
        }
        task.spawn(function()
            pcall(function()
                req({
                    Url = personalUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(payload)
                })
            end)
        end)
    end

    -- ============================================================
    -- TEST BUTTONS
    -- ============================================================
    whSec:Button({
        Title = "Test Spawn Batch Format",
        Icon = "layout-list",
        Color = Color3.fromRGB(0, 255, 127),
        Callback = function()
            if not getgenv().WebhookURL or getgenv().WebhookURL == "" then
                WindUI:Notify({ Title = "Error", Content = "Isi Webhook URL dulu!", Duration = 3 })
                return
            end
            local dummyBatch = { 
                {id = "Whale Shark", scale = 1.25123, itemData = {BaseMutation = "Shiny"}}, 
                {id = "Snowy Owl", scale = 2.509, itemData = {Mutations = {"Giant", "Radiant"}}}, 
                {id = "DesertLark", scale = 1.05, itemData = {}} 
            }
            getgenv().SendDiscordWebhook("SpawnBatch", "Batch", dummyBatch, true)
            WindUI:Notify({ Title = "Sent", Content = "Test Batch Webhook terkirim!", Duration = 3 })
        end
    })

    whSec:Button({
        Title = "Test Hatch Format",
        Icon = "send",
        Color = Color3.fromRGB(0, 170, 255),
        Callback = function()
            if not getgenv().WebhookURL or getgenv().WebhookURL == "" then
                WindUI:Notify({ Title = "Error", Content = "Isi Webhook URL dulu!", Duration = 3 })
                return
            end
            local dummyItem = { Category = "Whale Shark", Scale = 1.25, HasBeenFirstPlaced = true, BaseMutation = "Rainbow", Mutations = {"Shiny", "Giant"}, Personality = "Normal" }
            getgenv().SendDiscordWebhook("Hatch", "Whale Shark", dummyItem, true)
            WindUI:Notify({ Title = "Sent", Content = "Test Hatch Webhook terkirim!", Duration = 3 })
        end
    })

    -- ============================================================
    -- 🌀 TRACKER ENGINE (SPAWN, STEAL, HATCH)
    -- ============================================================
    local spawnBuffer = {}
    local spawnTimer = nil
    local knownFieldEggs = {}

    -- Tracker Spawns
    task.spawn(function()
        while task.wait(1.5) do
            if not getgenv().WHS_Spawn then continue end
            pcall(function()
                local eggStateMod = ReplicatedStorage:FindFirstChild("Client") and ReplicatedStorage.Client:FindFirstChild("EggState")
                if not eggStateMod then return end

                local fieldData = require(eggStateMod).ReadFieldEggs()
                local fieldRecords = fieldData and fieldData.Records or {}
                local newlySpawned, currentUids = {}, {}

                for _, rec in ipairs(fieldRecords) do
                    currentUids[rec.Uid] = true
                    if not knownFieldEggs[rec.Uid] then
                        knownFieldEggs[rec.Uid] = true
                        if rec.AssetCategory then
                            table.insert(newlySpawned, {id = rec.AssetCategory, scale = rec.AssetScale or 1, itemData = rec})
                            table.insert(spawnBuffer, {id = rec.AssetCategory, scale = rec.AssetScale or 1, itemData = rec})
                        end
                    end
                end

                for uid, _ in pairs(knownFieldEggs) do
                    if not currentUids[uid] then knownFieldEggs[uid] = nil end
                end

                if #newlySpawned > 0 then
                    if spawnTimer then task.cancel(spawnTimer) end
                    spawnTimer = task.delay(3, function()
                        local batchToSend = spawnBuffer
                        spawnBuffer = {} 
                        if #batchToSend > 0 then
                            getgenv().SendDiscordWebhook("SpawnBatch", "Batch", batchToSend)
                        end
                    end)
                end
            end)
        end
    end)

    -- Tracker Steal & Hatch
    local knownSteal = {}
    local knownHatch = {}
    local firstScan = true

    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                local saveMod = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Save")
                if not saveMod then return end

                local sData = require(saveMod).Get()
                local eggRecords = sData.EggInventory or {} 
                
                if firstScan then
                    for uid, _ in pairs(eggRecords) do knownSteal[uid] = true end
                    if sData.Inventory then for uid, _ in pairs(sData.Inventory) do knownHatch[uid] = true end end
                    firstScan = false
                    return
                end

                -- Deteksi Steal (Egg masuk backpack)
                for uid, rec in pairs(eggRecords) do
                    if not knownSteal[uid] then
                        knownSteal[uid] = true
                        if rec.Placement == nil then 
                            local cat = rec.AssetCategory or "Unknown"
                            if getgenv().WHS_Steal then
                                getgenv().SendDiscordWebhook("Steal", cat, rec)
                            end
                        end
                    end
                end

                -- Deteksi Hatch
                if getgenv().WHS_Hatch and sData.Inventory then
                    local AssetItems = require(ReplicatedStorage.Shared.Util.AssetItems)
                    for uid, serialized in pairs(sData.Inventory) do
                        if not knownHatch[uid] then
                            knownHatch[uid] = true
                            if not eggRecords[uid] then
                                local s_item, item = pcall(AssetItems.Decode, serialized)
                                if s_item and type(item) == "table" and (item.Category or item.AssetCategory) then
                                    getgenv().SendDiscordWebhook("Hatch", item.Category or item.AssetCategory, item)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
end

WindUI:Notify({
    Title = "Steal An Egg - Monitor",
    Content = "Menu Webhook berhasil dimuat!",
    Duration = 4
})
