--[[
    Matcha Compatibility Layer (Fake Roblox API)
    Version: 2.3 (Final Fix)
]]

local Matcha = {}

-- [[ Enum Shim ]] --
getgenv().Enum = {
    Font = { UI = "UI", Bold = "Bold" },
    UserInputType = { MouseButton1 = "MouseButton1", MouseButton2 = "MouseButton2", Keyboard = "Keyboard", MouseMovement = "MouseMovement" },
    KeyCode = { W = "W", A = "A", S = "S", D = "D", Insert = "Insert", RightShift = "RightShift" },
    UserInputState = { Begin = "Begin", Change = "Change", End = "End" },
    EasingStyle = { Linear = "Linear", Quad = "Quad", Quint = "Quint" },
    ZIndexBehavior = { Global = "Global", Sibling = "Sibling" },
    TextXAlignment = { Left = "Left", Center = "Center", Right = "Right" }
}

-- [[ Data Types ]] --
Matcha.UDim2 = {}
Matcha.UDim2.__index = Matcha.UDim2
function Matcha.UDim2.new(sx, ox, sy, oy)
    return setmetatable({ X = { Scale = sx or 0, Offset = ox or 0 }, Y = { Scale = sy or 0, Offset = oy or 0 } }, Matcha.UDim2)
end
function Matcha.UDim2.fromOffset(x, y) return Matcha.UDim2.new(0, x, 0, y) end
function Matcha.UDim2.fromScale(x, y) return Matcha.UDim2.new(x, 0, y, 0) end
getgenv().UDim2 = Matcha.UDim2

-- [[ Visual Helpers ]] --
local function lerp(a, b, t) return a + (b - a) * t end
local function lerpColor(c1, c2, t)
    return Color3.new(lerp(c1.R, c2.R, t), lerp(c1.G, c2.G, t), lerp(c1.B, c2.B, t))
end

-- [[ Instance Emulation ]] --
local UI_OBJECTS = {}
local ACTIVE_TWEENS = {}
local BaseObject = {}
BaseObject.__index = BaseObject

function BaseObject.new(className, parent)
    local self = setmetatable({
        ClassName = className,
        _parent = nil,
        Children = {},
        Visible = true,
        Position = Matcha.UDim2.new(0,0,0,0),
        Size = Matcha.UDim2.new(0,0,0,0),
        AbsolutePosition = Vector2.new(0,0),
        AbsoluteSize = Vector2.new(0,0),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BackgroundTransparency = 0,
        Text = "",
        TextColor3 = Color3.fromRGB(255,255,255),
        TextTransparency = 0,
        InputBegan = { Connect = function(s, f) self._onInputBegan = f end },
        InputEnded = { Connect = function(s, f) self._onInputEnded = f end },
        MouseEnter = { Connect = function(s, f) self._onMouseEnter = f end },
        MouseLeave = { Connect = function(s, f) self._onMouseLeave = f end },
        MouseButton1Click = { Connect = function(s, f) self._onClick = f end },
    }, BaseObject)

    if className == "Frame" or className == "ScrollingFrame" then
        self._drawing = Drawing.new("Square")
        self._drawing.Filled = true
    elseif className:find("Text") then
        self._drawing = Drawing.new("Text")
        self._drawing.Size = 14
        self._drawing.Font = Drawing.Fonts.UI
    end

    table.insert(UI_OBJECTS, self)
    if parent then self.Parent = parent end
    return self
end

function BaseObject:__newindex(k, v)
    if k == "Parent" then self._parent = v; if v and v.Children then table.insert(v.Children, self) end
    else rawset(self, k, v) end
end

-- [[ Global Loop ]] --
task.spawn(function()
    local Players = game:GetService("Players")
    while not Players.LocalPlayer do task.wait() end
    local Mouse = Players.LocalPlayer:GetMouse()
    local lastM1 = false

    while true do
        task.wait()
        local now = tick()
        local mPos = Vector2.new(Mouse.X, Mouse.Y)
        local m1 = ismouse1pressed()
        
        for i = #ACTIVE_TWEENS, 1, -1 do
            local tween = ACTIVE_TWEENS[i]
            local alpha = math.clamp((now - tween.StartTime) / tween.Duration, 0, 1)
            for k, goal in pairs(tween.Goals) do
                local start = tween.StartValues[k]
                if typeof(goal) == "Color3" then tween.Object[k] = lerpColor(start, goal, alpha)
                elseif typeof(goal) == "number" then tween.Object[k] = lerp(start, goal, alpha) end
            end
            if alpha >= 1 then table.remove(ACTIVE_TWEENS, i) end
        end

        for _, obj in pairs(UI_OBJECTS) do
            if not obj._drawing then continue end
            local absPos = Vector2.new(obj.Position.X.Offset, obj.Position.Y.Offset)
            local absSize = Vector2.new(obj.Size.X.Offset, obj.Size.Y.Offset)
            if obj._parent and obj._parent.AbsolutePosition then absPos = obj._parent.AbsolutePosition + absPos end
            obj.AbsolutePosition, obj.AbsoluteSize = absPos, absSize

            obj._drawing.Visible = obj.Visible
            if obj._drawing.Text then
                obj._drawing.Position, obj._drawing.Text, obj._drawing.Color = absPos, obj.Text, obj.TextColor3
            else
                obj._drawing.Position, obj._drawing.Size, obj._drawing.Color = absPos, absSize, obj.BackgroundColor3
                obj._drawing.Transparency = 1 - obj.BackgroundTransparency
            end

            local over = mPos.X >= absPos.X and mPos.X <= absPos.X + absSize.X and mPos.Y >= absPos.Y and mPos.Y <= absPos.Y + absSize.Y
            if over and not obj._h then obj._h = true; if obj._onMouseEnter then obj._onMouseEnter() end
            elseif not over and obj._h then obj._h = false; if obj._onMouseLeave then obj._onMouseLeave() end end
            
            if over and m1 and not lastM1 then
                if obj._onInputBegan then obj._onInputBegan({UserInputType=Enum.UserInputType.MouseButton1}) end
                if obj._onClick then obj._onClick() end
            elseif lastM1 and not m1 then 
                if obj._onInputEnded then obj._onInputEnded({UserInputType=Enum.UserInputType.MouseButton1}) end
            end
        end
        lastM1 = m1
    end
end)

getgenv().Instance = { new = BaseObject.new }
getgenv().TweenService = { Create = function(s,o,i,p) return { Play = function() 
    local t = {Object=o, Duration=i.Time or 1, StartTime=tick(), Goals=p, StartValues={}}
    for k,v in pairs(p) do t.StartValues[k] = o[k] end
    table.insert(ACTIVE_TWEENS, t)
end } end }
getgenv().TweenInfo = { new = function(...) return {...} end }
getgenv().UserInputService = { InputChanged = { Connect = function() end }, InputBegan = { Connect = function() end } }
getgenv().Color3 = Color3
getgenv().Vector2 = Vector2
getgenv().MatchaCompat = Matcha
return Matcha
