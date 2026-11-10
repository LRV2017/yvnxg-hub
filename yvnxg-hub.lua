--[[
    ██╗   ██╗██╗   ██╗███╗   ██╗██╗  ██╗ ██████╗     ██╗  ██╗██╗   ██╗██████╗
    ╚██╗ ██╔╝██║   ██║████╗  ██║╚██╗██╔╝██╔════╝     ██║  ██║██║   ██║██╔══██╗
     ╚████╔╝ ██║   ██║██╔██╗ ██║ ╚███╔╝ ██║  ███╗    ███████║██║   ██║██████╔╝
      ╚██╔╝  ██║   ██║██║╚██╗██║ ██╔██╗ ██║   ██║    ██╔══██║██║   ██║██╔══██╗
       ██║   ╚██████╔╝██║ ╚████║██╔╝ ██╗╚██████╔╝    ██║  ██║╚██████╔╝██████╔╝
       ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝

    yvnxg-hub — single-file Roblox hub for the Xeno executor
    GitHub : github.com/LRV2017/yvnxg-hub
    Toggle : RightShift

    Structure:
      • Theme / config
      • Helpers (Instance.new wrappers, HTTP, clipboard, toasts)
      • Script Loader  (ScriptBlox + RoScripts)
      • Avatar Changer (HumanoidDescription)
      • Utilities      (Movement / Visuals / Teleport / Utility)
--]]

--=====================================================================
-- SERVICES
--=====================================================================
local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local Lighting           = game:GetService("Lighting")
local HttpService        = game:GetService("HttpService")
local TeleportService    = game:GetService("TeleportService")
local VirtualUser        = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

--=====================================================================
-- THEME / CONFIG  (edit freely — colors, font, toggle key)
--=====================================================================
local Theme = {
    Background = Color3.fromRGB(0x1E, 0x1E, 0x1E), -- #1E1E1E
    Surface    = Color3.fromRGB(0x26, 0x26, 0x26),
    SurfaceAlt = Color3.fromRGB(0x2D, 0x2D, 0x2D),
    Stroke     = Color3.fromRGB(0x3C, 0x3C, 0x3C),
    Text       = Color3.fromRGB(0xFF, 0xFF, 0xFF), -- #FFFFFF
    TextDim    = Color3.fromRGB(0xA0, 0xA0, 0xA0),
    Accent     = Color3.fromRGB(0x4A, 0x90, 0xD9), -- #4A90D9
    Good       = Color3.fromRGB(0x50, 0xC8, 0x78),
    Bad        = Color3.fromRGB(0xDC, 0x50, 0x50),
    Font       = Enum.Font.Gotham,
    FontBold   = Enum.Font.GothamBold,
}

local TOGGLE_KEY = Enum.KeyCode.RightShift

--=====================================================================
-- HELPERS
--=====================================================================
local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        pcall(function() o[k] = v end)
    end
    if parent then o.Parent = parent end
    return o
end

local function corner(parent, r)
    return make("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function stroke(parent, color, thickness)
    return make("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function padding(parent, all)
    return make("UIPadding", {
        PaddingTop    = UDim.new(0, all),
        PaddingBottom = UDim.new(0, all),
        PaddingLeft   = UDim.new(0, all),
        PaddingRight  = UDim.new(0, all),
    }, parent)
end

local function urlEncode(s)
    return (s:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

-- Safe HTTP GET — tries game:HttpGet first, then request / syn.request
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(res) == "string" and #res > 0 then return res end
    local req = (syn and syn.request) or (http and http.request) or request
    if req then
        local ok2, res2 = pcall(req, { Url = url, Method = "GET" })
        if ok2 and type(res2) == "table" and res2.Body then return res2.Body end
    end
    return nil
end

local function copyToClipboard(text)
    local fn = setclipboard or toclipboard
             or (syn and syn.setclipboard) or (syn and syn.write_clipboard)
    if fn then pcall(fn, text) end
end

local function jsonDecode(str)
    local ok, data = pcall(function() return HttpService:JSONDecode(str) end)
    if ok then return data end
    return nil
end

local function jsonEncode(tbl)
    local ok, data = pcall(function() return HttpService:JSONEncode(tbl) end)
    if ok then return data end
    return nil
end

--=====================================================================
-- TOAST NOTIFICATIONS  (in-UI, bottom-right of the window)
--=====================================================================
local notifyGui, NotifyContainer

local function ensureNotifyGui()
    if notifyGui then return end
    notifyGui = make("ScreenGui", {
        Name = "yvnxg-hub-notify",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    if gethui then notifyGui.Parent = gethui() else notifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    NotifyContainer = make("Frame", {
        Size = UDim2.new(0, 300, 0, 0),
        Position = UDim2.new(1, -316, 1, -16),
        AnchorPoint = Vector2.new(0, 1),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = notifyGui,
    })
    make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
    }, NotifyContainer)
end

local function notify(title, text, duration)
    ensureNotifyGui()
    duration = duration or 4
    local frame = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.SurfaceAlt,
        BorderSizePixel = 0,
        Parent = NotifyContainer,
    })
    corner(frame, 6)
    stroke(frame, Theme.Accent, 1)
    padding(frame, 8)
    make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
    make("TextLabel", {
        Text = title, Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16), Parent = frame,
    })
    if text and text ~= "" then
        make("TextLabel", {
            Text = text, Font = Theme.Font, TextSize = 12, TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, Parent = frame,
        })
    end
    task.delay(duration, function()
        if frame and frame.Parent then
            pcall(function()
                TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
            end)
            task.wait(0.3)
            if frame and frame.Parent then frame:Destroy() end
        end
    end)
end

--=====================================================================
-- MAIN WINDOW
--=====================================================================
local hub = make("ScreenGui", {
    Name = "yvnxg-hub",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
if gethui then hub.Parent = gethui() else hub.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local main = make("Frame", {
    Size = UDim2.new(0, 620, 0, 440),
    Position = UDim2.new(0.5, -310, 0.5, -220),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    Active = true,
    Parent = hub,
})
corner(main, 12)
stroke(main, Theme.Stroke, 1)

--====== Draggable header ======--
local header = make("Frame", {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0,
    Active = true,
    Parent = main,
})
corner(header, 12)
-- hide bottom rounding of the header
make("Frame", {
    Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, Parent = header,
})

make("TextLabel", {
    Text = "yvnxg-hub", Font = Theme.FontBold, TextSize = 16, TextColor3 = Theme.Text,
    BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0),
    Size = UDim2.new(0, 240, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
make("TextLabel", {
    Text = "github.com/LRV2017/yvnxg-hub", Font = Theme.Font, TextSize = 11,
    TextColor3 = Theme.TextDim, BackgroundTransparency = 1,
    Position = UDim2.new(0, 120, 0, 0), Size = UDim2.new(0, 300, 1, 0),
    TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})

local closeBtn = make("TextButton", {
    Text = "×", Font = Theme.FontBold, TextSize = 22, TextColor3 = Theme.TextDim,
    BackgroundTransparency = 1, Size = UDim2.new(0, 40, 1, 0),
    Position = UDim2.new(1, -40, 0, 0), Parent = header,
})
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

-- Drag behaviour
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                  startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

--====== Tab bar ======--
local tabBar = make("Frame", {
    Size = UDim2.new(1, 0, 0, 36),
    Position = UDim2.new(0, 0, 0, 42),
    BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = main,
})
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    VerticalAlignment = Enum.VerticalAlignment.Center,
}, tabBar)
padding(tabBar, 6)

local contentArea = make("Frame", {
    Size = UDim2.new(1, -24, 1, -90),
    Position = UDim2.new(0, 12, 0, 84),
    BackgroundTransparency = 1, Parent = main,
})

local tabs = {}
local function addTab(name)
    local btn = make("TextButton", {
        Text = name, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.TextDim,
        BackgroundColor3 = Theme.SurfaceAlt, BackgroundTransparency = 1,
        AutoButtonColor = false, Size = UDim2.new(0, 118, 0, 24), Parent = tabBar,
    })
    corner(btn, 6)
    local page = make("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Visible = false, Parent = contentArea,
    })
    local t = { btn = btn, page = page }
    table.insert(tabs, t)
    btn.MouseButton1Click:Connect(function()
        for _, other in ipairs(tabs) do
            local active = (other == t)
            other.page.Visible             = active
            other.btn.TextColor3           = active and Theme.Text or Theme.TextDim
            other.btn.BackgroundTransparency = active and 0 or 1
        end
    end)
    return t
end

local function newScroll(parent)
    local s = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Stroke,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = parent,
    })
    make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, s)
    return s
end

local tabLoader = addTab("Script Loader")
local tabAvatar = addTab("Avatar")
local tabUtils  = addTab("Utilities")
-- activate the first tab
for _, t in ipairs(tabs) do
    t.page.Visible = (t == tabLoader)
    t.btn.TextColor3 = (t == tabLoader) and Theme.Text or Theme.TextDim
    t.btn.BackgroundTransparency = (t == tabLoader) and 0 or 1
end

--=====================================================================
-- ██ SCRIPT LOADER
--=====================================================================
-- Endpoints (edit here if the providers change their API shape)
local APIS = {
    ScriptBlox = {
        search = "https://scriptblox.com/api/script/search?q=%s&page=1&max=20&mode=free&key=0",
        raw    = "https://scriptblox.com/raw/%s",
    },
    RoScripts = {
        search = "https://api.roscripts.io/v1/scripts/search?query=%s&free=true&page=1&key=0",
        raw    = "https://api.roscripts.io/v1/scripts/%s/raw",
    },
}

-- Search bar
local searchRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = tabLoader.page,
})
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    VerticalAlignment = Enum.VerticalAlignment.Center,
}, searchRow)

local searchBox = make("TextBox", {
    Size = UDim2.new(1, -80, 1, 0), BackgroundColor3 = Theme.Surface,
    PlaceholderText = "Search game name... (Enter)", PlaceholderColor3 = Theme.TextDim,
    Text = "", ClearTextOnFocus = false,
    Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = searchRow,
})
corner(searchBox, 6); stroke(searchBox, Theme.Stroke, 1)

local searchBtn = make("TextButton", {
    Size = UDim2.new(0, 74, 1, 0), BackgroundColor3 = Theme.Accent,
    Text = "Search", Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
    Parent = searchRow,
})
corner(searchBtn, 6)

-- Results
local resultsList = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -38), Position = UDim2.new(0, 0, 0, 38),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Stroke,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0), Parent = tabLoader.page,
})
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, resultsList)

local function clearResults()
    for _, c in ipairs(resultsList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function addResult(source, title, gameName, rawUrl)
    local row = make("Frame", {
        Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0, Parent = resultsList,
    })
    corner(row, 6); stroke(row, Theme.Stroke, 1); padding(row, 6)

    make("TextLabel", {
        Text = title, Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        BackgroundTransparency = 1, Size = UDim2.new(1, -86, 0, 16), Parent = row,
    })
    make("TextLabel", {
        Text = "[" .. source .. "] " .. (gameName or ""),
        Font = Theme.Font, TextSize = 11, TextColor3 = Theme.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        BackgroundTransparency = 1, Size = UDim2.new(1, -86, 0, 14),
        Position = UDim2.new(0, 0, 0, 18), Parent = row,
    })

    local loadBtn = make("TextButton", {
        Text = "Load", Font = Theme.FontBold, TextSize = 12, TextColor3 = Theme.Text,
        BackgroundColor3 = Theme.Accent, Size = UDim2.new(0, 68, 0, 26),
        Position = UDim2.new(1, -68, 0.5, -13), Parent = row,
    })
    corner(loadBtn, 5)

    loadBtn.MouseButton1Click:Connect(function()
        if not rawUrl or rawUrl == "" then
            notify("Load failed", "No raw script URL available.", 4)
            return
        end
        loadBtn.Text = "..."
        loadBtn.BackgroundColor3 = Theme.SurfaceAlt
        task.spawn(function()
            local code = httpGet(rawUrl)
            if not code then
                loadBtn.Text = "Load"; loadBtn.BackgroundColor3 = Theme.Accent
                notify("Load failed", "Could not fetch script body.", 4)
                return
            end
            local fn, err = loadstring(code)
            if not fn then
                loadBtn.Text = "Load"; loadBtn.BackgroundColor3 = Theme.Accent
                notify("Compile error", tostring(err), 5)
                return
            end
            local ok, execErr = pcall(fn)
            if not ok then
                notify("Script error", tostring(execErr), 5)
            else
                notify("Loaded", title, 3)
            end
            loadBtn.Text = "Load"; loadBtn.BackgroundColor3 = Theme.Accent
        end)
    end)
end

-- -- Provider parsers --------------------------------------------------
local function searchScriptBlox(q)
    local out = {}
    local body = httpGet(string.format(APIS.ScriptBlox.search, urlEncode(q)))
    if not body then return out end
    local data = jsonDecode(body)
    if type(data) ~= "table" then return out end
    local list = (data.result and data.result.scripts) or data.scripts or {}
    for _, s in ipairs(list) do
        local rawUrl = s.rawUrl
        if not rawUrl and s.slug then rawUrl = string.format(APIS.ScriptBlox.raw, s.slug) end
        if rawUrl then
            table.insert(out, {
                source = "ScriptBlox",
                title  = s.title or s.name or "Untitled",
                game   = (s.game and s.game.name) or s.gameName or "",
                raw    = rawUrl,
            })
        end
    end
    return out
end

local function searchRoScripts(q)
    local out = {}
    local body = httpGet(string.format(APIS.RoScripts.search, urlEncode(q)))
    if not body then return out end
    local data = jsonDecode(body)
    if type(data) ~= "table" then return out end
    local list = data.data or data.results or data.scripts or {}
    for _, s in ipairs(list) do
        local rawUrl = s.rawUrl or s.raw_url or s.script_url or s.download_url
        if not rawUrl and s.id then rawUrl = string.format(APIS.RoScripts.raw, s.id) end
        if rawUrl then
            table.insert(out, {
                source = "RoScripts",
                title  = s.title or s.name or "Untitled",
                game   = (s.game and s.game.name) or s.gameName or "",
                raw    = rawUrl,
            })
        end
    end
    return out
end

local function doSearch()
    local q = searchBox.Text
    if q == "" then return end
    clearResults()
    searchBtn.Text = "Searching..."
    searchBtn.BackgroundColor3 = Theme.SurfaceAlt
    task.spawn(function()
        local sb = searchScriptBlox(q)
        local rs = searchRoScripts(q)
        clearResults()
        local total = 0
        for _, r in ipairs(sb) do addResult(r.source, r.title, r.game, r.raw); total += 1 end
        for _, r in ipairs(rs) do addResult(r.source, r.title, r.game, r.raw); total += 1 end
        if total == 0 then notify("No results", "Nothing found for '" .. q .. "'.", 4) end
        searchBtn.Text = "Search"
        searchBtn.BackgroundColor3 = Theme.Accent
    end)
end

searchBtn.MouseButton1Click:Connect(doSearch)
searchBox.FocusLost:Connect(function(enter)
    if enter then doSearch() end
end)

--=====================================================================
-- ██ AVATAR CHANGER
--=====================================================================
local avatarScroll = newScroll(tabAvatar.page)

-- Helper text
make("TextLabel", {
    Text = "Paste a UserId or HumanoidDescription JSON, then click Apply.",
    Font = Theme.Font, TextSize = 12, TextColor3 = Theme.TextDim,
    TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = avatarScroll,
})

-- Input wrapper (padded frame -> cleaner than TextBox padding)
local avWrap = make("Frame", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = Theme.Surface,
    BorderSizePixel = 0, Parent = avatarScroll,
})
corner(avWrap, 6); stroke(avWrap, Theme.Stroke, 1); padding(avWrap, 6)

local avInput = make("TextBox", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    PlaceholderText = "123456789  |  or  {\"Head\":0, \"Torso\":0, ...}",
    PlaceholderColor3 = Theme.TextDim, MultiLine = true, ClearTextOnFocus = false,
    Text = "", TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Font = Theme.Font, TextSize = 12, TextColor3 = Theme.Text, Parent = avWrap,
})

local avBtnRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = avatarScroll,
})
make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    VerticalAlignment = Enum.VerticalAlignment.Center,
}, avBtnRow)

local applyAvBtn = make("TextButton", {
    Size = UDim2.new(0.5, -3, 1, 0), BackgroundColor3 = Theme.Accent,
    Text = "Apply Avatar", Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
    Parent = avBtnRow,
})
corner(applyAvBtn, 6)

local copyAvBtn = make("TextButton", {
    Size = UDim2.new(0.5, -3, 1, 0), BackgroundColor3 = Theme.SurfaceAlt,
    Text = "Copy My Avatar", Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Text,
    Parent = avBtnRow,
})
corner(copyAvBtn, 6); stroke(copyAvBtn, Theme.Stroke, 1)

-- Properties that make up a HumanoidDescription JSON
local DESC_PROPS = {
    "Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg",
    "HeadColor","TorsoColor","LeftArmColor","RightArmColor","LeftLegColor","RightLegColor",
    "Shirt","Pants","Face","HairAccessory","HatAccessory","FaceAccessory",
    "NeckAccessory","ShouldersAccessory","FrontAccessory","BackAccessory","WaistAccessory",
    "BodyTypeScale","HeadScale","HeightScale","WidthScale","DepthScale","ProportionScale",
    "WalkAnimation","RunAnimation","JumpAnimation","FallAnimation","IdleAnimation",
    "ClimbAnimation","SwimAnimation","AccessoryBlob","AnimationsBlob",
}

local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

applyAvBtn.MouseButton1Click:Connect(function()
    local txt = avInput.Text
    if txt == "" then notify("Avatar", "Enter a UserId or JSON first."); return end
    local hum = getHumanoid()
    if not hum then notify("Avatar", "No Humanoid found (spawn first)."); return end

    task.spawn(function()
        local desc
        local numeric = tonumber(txt)
        if numeric then
            local ok, d = pcall(function() return Players:GetHumanoidDescriptionFromUserId(numeric) end)
            if ok and d then desc = d end
        else
            local data = jsonDecode(txt)
            if type(data) == "table" then
                local d = Instance.new("HumanoidDescription")
                for k, v in pairs(data) do
                    pcall(function() d[k] = v end)
                end
                desc = d
            end
        end
        if not desc then
            notify("Avatar", "Invalid UserId or JSON.", 4); return
        end
        local ok, err = pcall(function() hum:ApplyDescription(desc) end)
        if ok then
            notify("Avatar", "Applied successfully.", 3)
        else
            notify("Avatar", "Failed: " .. tostring(err), 4)
        end
    end)
end)

copyAvBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local ok, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
        end)
        if not ok or not desc then notify("Copy", "Could not read your description."); return end
        local out = {}
        for _, prop in ipairs(DESC_PROPS) do
            local pok, val = pcall(function() return desc[prop] end)
            if pok then out[prop] = val end
        end
        local json = jsonEncode(out)
        if json then
            copyToClipboard(json)
            notify("Copy", "Avatar JSON copied to clipboard.", 3)
        else
            notify("Copy", "JSON encoding failed.")
        end
    end)
end)

--=====================================================================
-- ██ UTILITIES  (movement / visuals / teleport / utility)
--=====================================================================
local utilsScroll = newScroll(tabUtils.page)

--====== Reusable widget builders ======--
local function section(parent, title)
    local sec = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface, BorderSizePixel = 0, Parent = parent,
    })
    corner(sec, 8); stroke(sec, Theme.Stroke, 1); padding(sec, 8)
    make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sec)
    make("TextLabel", {
        Text = title, Font = Theme.FontBold, TextSize = 13, TextColor3 = Theme.Accent,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = sec,
    })
    return sec
end

local function toggleRow(parent, label, default, callback)
    local r = make("Frame", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = parent,
    })
    make("TextLabel", {
        Text = label, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        BackgroundTransparency = 1, Size = UDim2.new(1, -50, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = r,
    })
    local btn = make("TextButton", {
        Text = "OFF", Font = Theme.FontBold, TextSize = 12, TextColor3 = Theme.TextDim,
        BackgroundColor3 = Theme.SurfaceAlt, Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -44, 0.5, -11), Parent = r,
    })
    corner(btn, 11)
    local state = default or false
    local function render()
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Theme.Accent or Theme.SurfaceAlt
        btn.TextColor3 = state and Theme.Text or Theme.TextDim
    end
    render()
    btn.MouseButton1Click:Connect(function()
        state = not state
        render()
        if callback then pcall(callback, state) end
    end)
    return {
        get = function() return state end,
        set = function(v) state = v; render(); if callback then pcall(callback, v) end end,
    }
end

local function sliderRow(parent, label, min, max, default, callback)
    local r = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = parent,
    })
    make("TextLabel", {
        Text = label, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left, Parent = r,
    })
    local valLbl = make("TextLabel", {
        Text = tostring(default), Font = Theme.FontBold, TextSize = 12,
        TextColor3 = Theme.Accent, BackgroundTransparency = 1,
        Size = UDim2.new(0, 60, 0, 16), Position = UDim2.new(1, -60, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Parent = r,
    })
    local bar = make("Frame", {
        Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 24),
        BackgroundColor3 = Theme.SurfaceAlt, BorderSizePixel = 0, Parent = r,
    })
    corner(bar, 4)
    local fill = make("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = bar,
    })
    corner(fill, 4)
    local knob = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0),
        BackgroundColor3 = Theme.Text, BorderSizePixel = 0, Parent = bar,
    })
    corner(knob, 7)

    local value = default
    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        value = math.floor(min + (max - min) * rel + 0.5)
        local p = (value - min) / (max - min)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, 0, 0.5, 0)
        valLbl.Text = tostring(value)
        if callback then pcall(callback, value) end
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        get = function() return value end,
        set = function(v)
            value = math.clamp(v, min, max)
            local p = (value - min) / (max - min)
            fill.Size = UDim2.new(p, 0, 1, 0)
            knob.Position = UDim2.new(p, 0, 0.5, 0)
            valLbl.Text = tostring(value)
            if callback then pcall(callback, value) end
        end,
    }
end

local function buttonRow(parent, label, callback)
    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.SurfaceAlt,
        Text = label, Font = Theme.Font, TextSize = 13, TextColor3 = Theme.Text,
        Parent = parent,
    })
    corner(btn, 6); stroke(btn, Theme.Stroke, 1)
    btn.MouseButton1Click:Connect(function() if callback then pcall(callback) end end)
    return btn
end

--====== Shared feature state ======--
local state = {
    walk = false, jump = false, infJump = false, fly = false, noclip = false,
    spin = false, fullbright = false, esp = false, clickTP = false,
    antiAFK = false, freecam = false,
}

-----------------------------------------------------------------
-- MOVEMENT
-----------------------------------------------------------------
local moveSection = section(utilsScroll, "Movement")

local WALK_DEFAULT = 16
local walkValue = 30

local walkToggle
local function applyWalk(on)
    state.walk = on
    local hum = getHumanoid()
    if not hum then return end
    pcall(function() hum.WalkSpeed = on and walkValue or WALK_DEFAULT end)
end
walkToggle = toggleRow(moveSection, "WalkSpeed", false, applyWalk)
sliderRow(moveSection, "WalkSpeed value", 16, 500, walkValue, function(v)
    walkValue = v
    if state.walk then applyWalk(true) end
end)

local JUMP_DEFAULT = 50
local jumpValue = 80
local function applyJump(on)
    state.jump = on
    local hum = getHumanoid()
    if not hum then return end
    pcall(function()
        if on then
            hum.UseJumpPower = true
            hum.JumpPower = jumpValue
        else
            hum.JumpPower = JUMP_DEFAULT
        end
    end)
end
toggleRow(moveSection, "JumpPower", false, applyJump)
sliderRow(moveSection, "JumpPower value", 50, 500, jumpValue, function(v)
    jumpValue = v
    if state.jump then applyJump(true) end
end)

toggleRow(moveSection, "Infinite Jump", false, function(on) state.infJump = on end)

-- Fly
local flyBV, flyBG
local flySpeed = 60
local function startFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5); flyBV.Velocity = Vector3.zero; flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5); flyBG.P = 1000; flyBG.Parent = hrp
    hum.PlatformStand = true
end
local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local hum = getHumanoid()
    if hum then pcall(function() hum.PlatformStand = false end) end
end
toggleRow(moveSection, "Fly (WASD / Space / Shift)", false, function(on)
    state.fly = on
    if on then startFly() else stopFly() end
end)
sliderRow(moveSection, "Fly speed", 10, 300, flySpeed, function(v) flySpeed = v end)

toggleRow(moveSection, "NoClip", false, function(on) state.noclip = on end)

-- Spin Bot
local spinSpeed = 20
toggleRow(moveSection, "Spin Bot", false, function(on) state.spin = on end)
sliderRow(moveSection, "Spin speed (deg/sec)", 5, 360, spinSpeed, function(v) spinSpeed = v end)

-----------------------------------------------------------------
-- VISUALS
-----------------------------------------------------------------
local visualSection = section(utilsScroll, "Visuals")

-- Fullbright
local lightingBackup
local function applyFullbright(on, brightness)
    state.fullbright = on
    if on then
        if not lightingBackup then
            lightingBackup = {
                Brightness      = Lighting.Brightness,
                ClockTime       = Lighting.ClockTime,
                FogEnd          = Lighting.FogEnd,
                FogStart        = Lighting.FogStart,
                Ambient         = Lighting.Ambient,
                OutdoorAmbient  = Lighting.OutdoorAmbient,
                GlobalShadows   = Lighting.GlobalShadows,
            }
        end
        pcall(function()
            Lighting.Brightness     = brightness or 3
            Lighting.ClockTime      = 12
            Lighting.FogEnd         = 1e6
            Lighting.FogStart       = 0
            Lighting.Ambient        = Color3.fromRGB(200, 200, 200)
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
            Lighting.GlobalShadows  = false
        end)
    elseif lightingBackup then
        pcall(function()
            Lighting.Brightness     = lightingBackup.Brightness
            Lighting.ClockTime      = lightingBackup.ClockTime
            Lighting.FogEnd         = lightingBackup.FogEnd
            Lighting.FogStart       = lightingBackup.FogStart
            Lighting.Ambient        = lightingBackup.Ambient
            Lighting.OutdoorAmbient = lightingBackup.OutdoorAmbient
            Lighting.GlobalShadows  = lightingBackup.GlobalShadows
        end)
        lightingBackup = nil
    end
end
local fbBrightness = 3
toggleRow(visualSection, "Fullbright", false, function(on) applyFullbright(on, fbBrightness) end)
sliderRow(visualSection, "Brightness", 1, 10, fbBrightness, function(v)
    fbBrightness = v
    if state.fullbright then applyFullbright(true, v) end
end)

-- ESP
local espObjects = {}
local function createESPFor(player)
    if player == LocalPlayer then return end
    local function attach(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hl = Instance.new("Highlight")
        hl.Adornee = char
        hl.FillColor = Theme.Accent
        hl.FillTransparency = 0.6
        hl.OutlineColor = Theme.Accent
        hl.Parent = char

        local bb = Instance.new("BillboardGui")
        bb.Adornee = hrp
        bb.Size = UDim2.new(0, 200, 0, 30)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Parent = hrp

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0, 14)
        nameLbl.BackgroundTransparency = 1
        nameLbl.TextColor3 = Color3.new(1, 1, 1)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 13
        nameLbl.TextStrokeTransparency = 0
        nameLbl.Text = player.Name
        nameLbl.Parent = bb

        local distLbl = Instance.new("TextLabel")
        distLbl.Size = UDim2.new(1, 0, 0, 12)
        distLbl.Position = UDim2.new(0, 0, 0, 14)
        distLbl.BackgroundTransparency = 1
        distLbl.TextColor3 = Color3.new(1, 1, 1)
        distLbl.Font = Enum.Font.Gotham
        distLbl.TextSize = 11
        distLbl.TextStrokeTransparency = 0
        distLbl.Parent = bb

        espObjects[player] = { hl = hl, bb = bb, distLbl = distLbl, char = char }
    end

    if player.Character then attach(player.Character) end
    player.CharacterAdded:Connect(function(c)
        if not state.esp then return end
        task.wait(0.5)
        attach(c)
    end)
end

toggleRow(visualSection, "Player ESP", false, function(on)
    state.esp = on
    if on then
        for _, p in ipairs(Players:GetPlayers()) do createESPFor(p) end
        Players.PlayerAdded:Connect(function(p)
            if state.esp then createESPFor(p) end
        end)
    else
        for _, obj in pairs(espObjects) do
            if obj.hl then obj.hl:Destroy() end
            if obj.bb then obj.bb:Destroy() end
        end
        espObjects = {}
    end
end)

-- FOV
local fovValue = 70
sliderRow(visualSection, "Camera FOV", 30, 120, fovValue, function(v)
    fovValue = v
    pcall(function() workspace.CurrentCamera.FieldOfView = v end)
end)

-----------------------------------------------------------------
-- TELEPORT
-----------------------------------------------------------------
local tpSection = section(utilsScroll, "Teleport")

toggleRow(tpSection, "Click Teleport", false, function(on) state.clickTP = on end)

buttonRow(tpSection, "Teleport to Spawn", function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
    if hrp and spawn then
        pcall(function() hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0) end)
        notify("Teleport", "Teleported to spawn.", 2)
    end
end)

-- Player dropdown
make("TextLabel", {
    Text = "Teleport to Player:", Font = Theme.Font, TextSize = 12,
    TextColor3 = Theme.TextDim, BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
    Parent = tpSection,
})
local playerListFrame = make("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, Parent = tpSection,
})
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, playerListFrame)

local function rebuildPlayerList()
    for _, c in ipairs(playerListFrame:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local btn = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Theme.SurfaceAlt,
                Text = "TP  " .. p.Name, Font = Theme.Font, TextSize = 12,
                TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
                Parent = playerListFrame,
            })
            corner(btn, 5); stroke(btn, Theme.Stroke, 1)
            make("UIPadding", { PaddingLeft = UDim.new(0, 6) }, btn)
            btn.MouseButton1Click:Connect(function()
                local char = LocalPlayer.Character
                local other = p.Character
                if char and other then
                    local hrp  = char:FindFirstChild("HumanoidRootPart")
                    local thrp = other:FindFirstChild("HumanoidRootPart")
                    if hrp and thrp then
                        pcall(function() hrp.CFrame = thrp.CFrame + Vector3.new(0, 3, 0) end)
                    end
                end
            end)
        end
    end
end
rebuildPlayerList()
Players.PlayerAdded:Connect(rebuildPlayerList)
Players.PlayerRemoving:Connect(function() task.defer(rebuildPlayerList) end)

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------
local utilSection = section(utilsScroll, "Utility")

toggleRow(utilSection, "Anti-AFK", false, function(on) state.antiAFK = on end)

buttonRow(utilSection, "Rejoin Server", function()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end)

buttonRow(utilSection, "Server Hop", function()
    task.spawn(function()
        local body = httpGet("https://games.roblox.com/v1/games/" ..
            tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
        if not body then notify("Server Hop", "Failed to fetch servers.", 4); return end
        local data = jsonDecode(body)
        if type(data) == "table" and data.data then
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    end)
                    return
                end
            end
        end
        notify("Server Hop", "No available servers.", 4)
    end)
end)

buttonRow(utilSection, "Reset Player", function()
    local hum = getHumanoid()
    if hum then pcall(function() hum.Health = 0 end) end
end)

-- Freecam
local freecamSpeed = 50
local freecamCFrame, freecamConn
local function startFreecam()
    local cam = workspace.CurrentCamera
    freecamCFrame = cam.CFrame
    cam.CameraType = Enum.CameraType.Scriptable
    freecamConn = RunService.RenderStepped:Connect(function(dt)
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W)         then move += cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S)         then move -= cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A)         then move -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D)         then move += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then move += Vector3.new(0, 1, 0)  end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0, 1, 0)  end
        if move.Magnitude > 0 then
            freecamCFrame = freecamCFrame + move.Unit * freecamSpeed * dt
        end
        cam.CFrame = freecamCFrame
    end)
end
local function stopFreecam()
    if freecamConn then freecamConn:Disconnect(); freecamConn = nil end
    local cam = workspace.CurrentCamera
    pcall(function()
        cam.CameraType = Enum.CameraType.Custom
        local hum = getHumanoid()
        if hum then cam.CameraSubject = hum end
    end)
end
toggleRow(utilSection, "Freecam", false, function(on)
    state.freecam = on
    if on then startFreecam() else stopFreecam() end
end)
sliderRow(utilSection, "Freecam speed", 10, 300, freecamSpeed, function(v) freecamSpeed = v end)

--=====================================================================
-- RUNTIME LOOPS  (all feature updates)
--=====================================================================
-- Fly
RunService.RenderStepped:Connect(function()
    if not state.fly then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera
    if not hrp or not flyBV or not flyBG then return end
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W)         then dir += cam.CFrame.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.S)         then dir -= cam.CFrame.LookVector  end
    if UserInputService:IsKeyDown(Enum.KeyCode.A)         then dir -= cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D)         then dir += cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir += Vector3.new(0, 1, 0)  end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0)  end
    flyBV.Velocity = (dir.Magnitude > 0) and (dir.Unit * flySpeed) or Vector3.zero
    flyBG.CFrame = cam.CFrame
end)

-- Noclip
RunService.Stepped:Connect(function()
    if not state.noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
end)

-- Spin Bot
RunService.RenderStepped:Connect(function(dt)
    if not state.spin then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(spinSpeed) * dt, 0)
    end
end)

-- Infinite jump
UserInputService.JumpRequest:Connect(function()
    if not state.infJump then return end
    local hum = getHumanoid()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if not state.antiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- Click TP
Mouse.Button1Down:Connect(function()
    if not state.clickTP then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local target = Mouse.Hit
    if target then
        pcall(function() hrp.CFrame = target + Vector3.new(0, 3, 0) end)
    end
end)

-- ESP distance + HP colour
RunService.Heartbeat:Connect(function()
    if not state.esp then return end
    local char = LocalPlayer.Character
    if not char then return end
    local myHrp = char:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    for _, obj in pairs(espObjects) do
        if obj.char and obj.char.Parent and obj.distLbl then
            local otherHrp = obj.char:FindFirstChild("HumanoidRootPart")
            if otherHrp then
                obj.distLbl.Text = math.floor((myHrp.Position - otherHrp.Position).Magnitude) .. " studs"
            end
            local hum = obj.char:FindFirstChildOfClass("Humanoid")
            if hum and obj.hl then
                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                obj.hl.FillColor = Color3.fromRGB(220 * (1 - pct), 200 * pct, 80 * pct)
            end
        end
    end
end)

-- Re-apply persistent features on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if state.walk then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.WalkSpeed = walkValue end) end
    end
    if state.jump then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.UseJumpPower = true; hum.JumpPower = jumpValue end) end
    end
    if state.fly then
        task.wait(0.4)
        startFly()
    end
end)

--=====================================================================
-- UI TOGGLE (RightShift)
--=====================================================================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == TOGGLE_KEY then
        main.Visible = not main.Visible
    end
end)

-- Initial toast
task.defer(function()
    notify("yvnxg-hub loaded", "Press " .. TOGGLE_KEY.Name .. " to toggle the UI.", 4)
end)
