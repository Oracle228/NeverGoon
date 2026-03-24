--[[
    Matcha Compatibility Layer (Fake Roblox API)
    Designed for porting Neverlose UI to Matcha Drawing API.
]]

local Matcha = {}

-- [[ Enum Shim ]] --
getgenv().Enum = {
    Font = { UI = "UI", Bold = "Bold" },
    UserInputType = { MouseButton1 = "MouseButton1", MouseButton2 = "MouseButton2", Keyboard = "Keyboard" },
    KeyCode = { W = "W", A = "A", S = "S", D = "D" }, -- Add more as needed
    EasingStyle = { Linear = function(t) return t end, Quad = function(t) return t*t end, Quint = function(t) return t^5 end },
    ZIndexBehavior = { Global = "Global", Sibling = "Sibling" }
}

-- [[ Data Types ]] --
Matcha.UDim2 = {}
Matcha.UDim2.__index = Matcha.UDim2

function Matcha.UDim2.new(sx, ox, sy, oy)
    return setmetatable({
        X = { Scale = sx or 0, Offset = ox or 0 },
        Y = { Scale = sy or 0, Offset = oy or 0 }
    }, Matcha.UDim2)
end

function Matcha.UDim2.fromOffset(x, y)
    return Matcha.UDim2.new(0, x, 0, y)
end

function Matcha.UDim2.fromScale(x, y)
    return Matcha.UDim2.new(x, 0, y, 0)
end

-- [[ Icons Table ]] --
local icons = {
    ["dropdown"] = ">",
    ["check"] = "•",
    ["arrow"] = ">",
    ["plus"] = "+",
    ["minus"] = "-",
    ["gear"] = "*",
    ["cross"] = "x",
}

-- [[ Instance Emulation ]] --
local UI_ROOT = {
    AbsolutePosition = Vector2.new(0, 0),
    AbsoluteSize = Vector2.new(1920, 1080), -- Default screen size
    Visible = true,
    Children = {}
}

local UI_OBJECTS = {}
local ACTIVE_TWEENS = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return Color3.new(
        lerp(c1.R, c2.R, t),
        lerp(c1.G, c2.G, t),
        lerp(c1.B, c2.B, t)
    )
end

local Easing = {
    QuadOut = function(t)
        return -t * (t - 2)
    end
}

-- [[ Base Class ]] --
local BaseObject = {}
BaseObject.__index = BaseObject

function BaseObject.new(className, parent)
    local self = setmetatable({
        ClassName = className,
        Name = className,
        _parent = nil,
        Children = {},
        Visible = true,
        ZIndex = 1,
        Position = Matcha.UDim2.new(0, 0, 0, 0),
        Size = Matcha.UDim2.new(0, 0, 0, 0),
        AbsolutePosition = Vector2.new(0, 0),
        AbsoluteSize = Vector2.new(0, 0),
        Transparency = 1,
        Color = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255), -- Map to Color for Frames
        BackgroundTransparency = 0,
        Text = "",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextTransparency = 0,
        _dirty = true,
        _drawing = nil,
        _hovered = false,
        _pressed = false,
        InputBegan = { Connect = function(s, f) self._onInputBegan = f end },
        InputEnded = { Connect = function(s, f) self._onInputEnded = f end },
        MouseEnter = { Connect = function(s, f) self._onMouseEnter = f end },
        MouseLeave = { Connect = function(s, f) self._onMouseLeave = f end },
    }, BaseObject)

    if className == "Frame" or className == "ScrollingFrame" or className == "ImageLabel" then
        self._drawing = Drawing.new("Square")
        self._drawing.Filled = true
    elseif className == "TextLabel" or className == "TextButton" then
        self._drawing = Drawing.new("Text")
        self._drawing.Size = 14
        self._drawing.Font = Drawing.Fonts.UI
    end

    table.insert(UI_OBJECTS, self)
    if parent then self.Parent = parent end
    return self
end

function BaseObject:__newindex(k, v)
    if k == "Parent" then
        if self._parent then
            for i, child in ipairs(self._parent.Children) do
                if child == self then table.remove(self._parent.Children, i) break end
            end
        end
        self._parent = v
        if v and v.Children then table.insert(v.Children, self) end
        self._dirty = true
    elseif k == "Position" or k == "Size" or k == "Visible" or k == "Transparency" or k == "Color" or k == "ZIndex" then
        rawset(self, k, v)
        self._dirty = true
    elseif k == "BackgroundColor3" then
        rawset(self, k, v)
        self.Color = v
        self._dirty = true
    elseif k == "BackgroundTransparency" then
        rawset(self, k, v)
        self.Transparency = 1 - v
        self._dirty = true
    elseif k == "Text" or k == "TextColor3" or k == "TextTransparency" then
        rawset(self, k, v)
        if self._drawing and self.ClassName:find("Text") then
            if k == "Text" then self._drawing.Text = v
            elseif k == "TextColor3" then self._drawing.Color = v
            elseif k == "TextTransparency" then self._drawing.Transparency = 1 - v end
        end
    else
        rawset(self, k, v)
    end
end

function BaseObject:GetChildren()
    return self.Children
end

function BaseObject:FindFirstChild(name)
    for _, child in ipairs(self.Children) do
        if child.Name == name then return child end
    end
end

function BaseObject:UpdateAbsolute()
    if not self._dirty then return end
    
    local parentPos = self._parent and self._parent.AbsolutePosition or UI_ROOT.AbsolutePosition
    local parentSize = self._parent and self._parent.AbsoluteSize or UI_ROOT.AbsoluteSize
    
    self.AbsoluteSize = Vector2.new(
        parentSize.X * self.Size.X.Scale + self.Size.X.Offset,
        parentSize.Y * self.Size.Y.Scale + self.Size.Y.Offset
    )
    
    self.AbsolutePosition = Vector2.new(
        parentPos.X + (parentSize.X * self.Position.X.Scale) + self.Position.X.Offset,
        parentPos.Y + (parentSize.Y * self.Position.Y.Scale) + self.Position.Y.Offset
    )

    if self._drawing then
        self._drawing.Position = self.AbsolutePosition
        if self.ClassName:find("Text") then
            -- Text handling
        else
            self._drawing.Size = self.AbsoluteSize
        end
        self._drawing.Visible = self.Visible and (not self._parent or self._parent.Visible)
        self._drawing.Transparency = self.Transparency
        self._drawing.Color = self.Color
        self._drawing.ZIndex = self.ZIndex
    end

    self._dirty = false
    for _, child in ipairs(self.Children) do
        child._dirty = true
        child:UpdateAbsolute()
    end
end

function BaseObject:Destroy()
    if self._drawing then self._drawing:Remove() end
    for i, obj in ipairs(UI_OBJECTS) do
        if obj == self then
            table.remove(UI_OBJECTS, i)
            break
        end
    end
end

-- [[ Tween Manager ]] --
local TweenService = {}

function TweenService:Create(object, info, goals)
    local tween = {
        Object = object,
        Duration = info.Time or 1,
        EasingStyle = info.EasingStyle or Easing.QuadOut,
        StartTime = tick(),
        Goals = goals,
        StartValues = {},
        Completed = false
    }

    for k, v in pairs(goals) do
        tween.StartValues[k] = object[k]
    end

    table.insert(ACTIVE_TWEENS, tween)
    return {
        Play = function() tween.StartTime = tick() end,
        Cancel = function() tween.Completed = true end
    }
end

-- [[ UserInputService ]] --
local UserInputService = {
    InputBegan = { Connect = function() end }, -- Stubs for now
    InputEnded = { Connect = function() end },
    InputChanged = { Connect = function() end }
}

-- [[ Global Loop ]] --
task.spawn(function()
    local lastMousePos = Vector2.new(0, 0)
    local lastM1 = false

    while true do
        local dt = task.wait()
        local now = tick()
        local mousePos = Vector2.new(Mouse.X, Mouse.Y)
        local m1 = ismouse1pressed()

        -- Update Tweens
        for i = #ACTIVE_TWEENS, 1, -1 do
            local tween = ACTIVE_TWEENS[i]
            local elapsed = now - tween.StartTime
            local alpha = math.clamp(elapsed / tween.Duration, 0, 1)
            local t = tween.EasingStyle(alpha)

            for k, goal in pairs(tween.Goals) do
                local start = tween.StartValues[k]
                if typeof(goal) == "Color3" then
                    tween.Object[k] = lerpColor(start, goal, t)
                elseif typeof(goal) == "number" then
                    tween.Object[k] = lerp(start, goal, t)
                elseif typeof(goal) == "UDim2" then
                    tween.Object[k] = Matcha.UDim2.new(
                        lerp(start.X.Scale, goal.X.Scale, t),
                        lerp(start.X.Offset, goal.X.Offset, t),
                        lerp(start.Y.Scale, goal.Y.Scale, t),
                        lerp(start.Y.Offset, goal.Y.Offset, t)
                    )
                end
                tween.Object._dirty = true
            end

            if alpha >= 1 then
                table.remove(ACTIVE_TWEENS, i)
            end
        end

            end
        end
        
        lastM1 = m1
        lastMousePos = mousePos
    end
end)

-- [[ Global Exports ]] --
getgenv().Instance = {
    new = function(className, parent)
        return BaseObject.new(className, parent)
    end
}
getgenv().UDim2 = Matcha.UDim2
getgenv().TweenInfo = { new = function(...) return {...} end }
getgenv().TweenService = TweenService
getgenv().UserInputService = UserInputService
getgenv().Color3 = Color3 -- Matcha already has it
getgenv().Vector2 = Vector2
getgenv().notify = notify

getgenv().MatchaCompat = Matcha
return Matcha
