-- [[ Neverlose UI Matcha Loader/Test ]] --
-- This script demostrates how to use the ported Neverlose UI library in Matcha.

local function Get(url)
    return game:HttpGet(url)
end

loadstring(Get("https://raw.githubusercontent.com/Oracle228/NeverGoon/refs/heads/main/matcha_compat.lua"))()
local NeverLose = loadstring(Get("https://raw.githubusercontent.com/Oracle228/NeverGoon/refs/heads/main/matcha_neverlose.lua"))()

-- [[ Application Logic ]] --
local Window = NeverLose:CreateWindow({
    Name = "Neverlose",
    Content = "Matcha Edition",
    Size = UDim2.new(0, 640, 0, 480)
})

local MainTab = Window:AddTab({
    Name = "Main",
    Icon = "house"
})

local AimSection = MainTab:AddSection({
    Name = "Aimbot"
})

AimSection:AddToggle({
    Name = "Enabled",
    Default = true,
    Callback = function(v)
        print("Aimbot enabled:", v)
    end
})

AimSection:AddSlider({
    Name = "FOV",
    Min = 0,
    Max = 180,
    Default = 90,
    Callback = function(v)
        print("Aimbot FOV:", v)
    end
})

local VisualsTab = Window:AddTab({
    Name = "Visuals",
    Icon = "eye"
})

local ESPSection = VisualsTab:AddSection({
    Name = "ESP"
})

ESPSection:AddDropdown({
    Name = "Mode",
    Values = {"Boxes", "Chams", "Skeleton"},
    Default = "Boxes",
    Callback = function(v)
        print("ESP Mode:", v)
    end
})

ESPSection:AddButton({
    Name = "Reset Config",
    Callback = function()
        print("Config reset!")
    end
})

print("Neverlose UI Loaded successfully in Matcha!")
