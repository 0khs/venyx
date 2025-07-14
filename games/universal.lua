local Venyx = shared.Venyx.instance

local HomeTab = Venyx:addTab("Home", "5037236979")
local WelcomeSection = HomeTab:addSection("Welcome")

WelcomeSection:addLabel("Welcome to the universal script!")
WelcomeSection:addLabel("This GUI is powered by Venyx.")

WelcomeSection:addButton("Show Notification", function()
    Venyx:Notify("Hello!", "This is a test notification.", 5)
end)

local SettingsTab = Venyx:addTab("Settings", "5037238985")
local ThemeSection = SettingsTab:addSection("Theme Customization")

local defaultThemes = {
	Background = Color3.fromRGB(24, 24, 24),
	Glow = Color3.fromRGB(0, 0, 0),
	Accent = Color3.fromRGB(10, 10, 10),
	LightContrast = Color3.fromRGB(20, 20, 20),
	DarkContrast = Color3.fromRGB(14, 14, 14),
	TextColor = Color3.fromRGB(255, 255, 255)
}

ThemeSection:addColorPicker("Background", defaultThemes.Background, function(color)
    Venyx:setTheme("Background", color)
end)

ThemeSection:addColorPicker("Glow Effect", defaultThemes.Glow, function(color)
    Venyx:setTheme("Glow", color)
end)

ThemeSection:addColorPicker("Accent", defaultThemes.Accent, function(color)
    Venyx:setTheme("Accent", color)
end)

ThemeSection:addColorPicker("Light Contrast", defaultThemes.LightContrast, function(color)
    Venyx:setTheme("LightContrast", color)
end)

ThemeSection:addColorPicker("Dark Contrast", defaultThemes.DarkContrast, function(color)
    Venyx:setTheme("DarkContrast", color)
end)

ThemeSection:addColorPicker("Text Color", defaultThemes.TextColor, function(color)
    Venyx:setTheme("TextColor", color)
end)
