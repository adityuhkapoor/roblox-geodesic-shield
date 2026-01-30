-- StarterPlayerScripts/ShieldClient (LocalScript)
-- SHIELD PLAYGROUND WITH ANIMATIONS

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ShieldRemote = ReplicatedStorage:WaitForChild("ShieldRemote")

local playgroundEnabled = false
local isCreating = false

local config = {
	baseShape = "icosahedron",
	radius = 10,
	subdivisionLevel = 1,
	shapeType = "dome_top",
	cutoffY = 0,
	offsetY = 1,
	offsetZ = 0,
	spawnPattern = "default",
	spawnDelay = 0.02,
	spawnBatch = 3,
	showTriangles = 1,
	triangleThickness = 0.1,
	triangleTransparency = 0.5,
	triangleR = 80,
	triangleG = 150,
	triangleB = 220,
	glowMaterial = 0,
	showEdges = 1,
	edgeThickness = 0.1,
	edgeTransparency = 0.1,
	edgeR = 100,
	edgeG = 200,
	edgeB = 255,
	showVertices = 1,
	vertexSize = 0.25,
	lightBrightness = 2,
	lightRange = 25,

	-- Animation
	breathing = 1,
	breathingIntensity = 0.03,
	spawnAnim = "none",
	diagonalStrength = 0.3,
	momentumLag = 0,
	velocityTilt = 0,
	hitRipple = 1,
	breakAnim = 1,
	shimmer = 1,
	shimmerIntensity = 0.5,
	energyWave = 1,
	edgeGlow = 1,
	coreGlowSync = 1,
	testMode = 0,
}

local baseShapes = {"tetrahedron", "octahedron", "icosahedron"}
local shapeTypes = {"dome_top", "dome_bottom", "full", "front", "back", "left", "right", "band", "cap"}
local spawnPatterns = {"default", "bottom_to_top", "top_to_bottom", "left_to_right", "right_to_left", "front_to_back", "back_to_front", "center_out", "outside_in", "spiral_cw", "spiral_ccw", "ring_top_down", "ring_bottom_up", "random", "stroke_bl_tr", "stroke_br_tl"}
local spawnAnims = {"none", "fade_in", "scale_in"}

local currentBaseShapeIndex = 3
local currentShapeIndex = 1
local currentPatternIndex = 1
local currentSpawnAnimIndex = 1

local triangleCounts = {
	tetrahedron = {4, 16, 64, 256, 1024},
	octahedron = {8, 32, 128, 512, 2048},
	icosahedron = {20, 80, 320, 1280, 5120},
}

local function getHoveredTriangle()
	local mouse = player:GetMouse()
	local target = mouse.Target
	if target and target:GetAttribute("IsShieldTriangle") then return target:GetAttribute("TriangleIndex") end
	return nil
end

local function getTriangleCount()
	local base, level = config.baseShape, config.subdivisionLevel
	if triangleCounts[base] then return triangleCounts[base][level + 1] or "?" end
	return "?"
end

-- UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShieldPlayground"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 150, 0, 40)
toggleBtn.Position = UDim2.new(1, -160, 0, 60)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 150)
toggleBtn.Text = "🛡️ SHIELD: OFF"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = screenGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 320, 0, 700)
panel.Position = UDim2.new(0, 10, 0.5, -350)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
panel.Visible = false
panel.ClipsDescendants = true
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, 2100)
scroll.Parent = panel

local yOffset = 10

local function createLabel(text, size, bold)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 0, size or 18)
	label.Position = UDim2.new(0, 10, 0, yOffset)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = bold and 14 or 10
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = scroll
	yOffset = yOffset + (size or 18) + 2
	return label
end

local function createHeader(text)
	yOffset = yOffset + 5
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 0, 18)
	label.Position = UDim2.new(0, 10, 0, yOffset)
	label.BackgroundTransparency = 1
	label.Text = "── " .. text .. " ──"
	label.TextColor3 = Color3.fromRGB(100, 200, 255)
	label.TextSize = 10
	label.Font = Enum.Font.GothamBold
	label.Parent = scroll
	yOffset = yOffset + 20
end

local function createSlider(name, min, max, label, decimals)
	local value = config[name]
	decimals = decimals or 1
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -20, 0, 30)
	container.Position = UDim2.new(0, 10, 0, yOffset)
	container.BackgroundTransparency = 1
	container.Parent = scroll

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 12)
	lbl.BackgroundTransparency = 1
	lbl.Text = label .. ": " .. tostring(value)
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextSize = 10
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = container

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 0, 10)
	bg.Position = UDim2.new(0, 0, 0, 14)
	bg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	bg.BorderSizePixel = 0
	bg.Parent = container
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(math.clamp((value - min) / (max - min), 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	yOffset = yOffset + 32

	local dragging = false
	bg.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
	bg.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

	RunService.RenderStepped:Connect(function()
		if dragging then
			local mousePos = UserInputService:GetMouseLocation()
			local pct = math.clamp((mousePos.X - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
			fill.Size = UDim2.new(pct, 0, 1, 0)
			local newVal = min + (max - min) * pct
			if decimals == 0 then newVal = math.floor(newVal + 0.5) else newVal = math.floor(newVal * 10^decimals + 0.5) / 10^decimals end
			config[name] = newVal
			lbl.Text = label .. ": " .. tostring(newVal)
		end
	end)
end

local function createToggle(name, label)
	local value = config[name]
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -20, 0, 26)
	container.Position = UDim2.new(0, 10, 0, yOffset)
	container.BackgroundTransparency = 1
	container.Parent = scroll

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 45, 0, 20)
	btn.BackgroundColor3 = value >= 0.5 and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(100, 50, 50)
	btn.Text = value >= 0.5 and "ON" or "OFF"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 10
	btn.Font = Enum.Font.GothamBold
	btn.Parent = container
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -55, 0, 20)
	lbl.Position = UDim2.new(0, 55, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextSize = 10
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = container

	btn.MouseButton1Click:Connect(function()
		config[name] = config[name] >= 0.5 and 0 or 1
		btn.BackgroundColor3 = config[name] >= 0.5 and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(100, 50, 50)
		btn.Text = config[name] >= 0.5 and "ON" or "OFF"
	end)

	yOffset = yOffset + 28
end

local function createSelector(label, options, currentIndex, onChange)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -20, 0, 55)
	container.Position = UDim2.new(0, 10, 0, yOffset)
	container.BackgroundTransparency = 1
	container.Parent = scroll

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 15)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	lbl.TextSize = 10
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = container

	local display = Instance.new("TextLabel")
	display.Size = UDim2.new(1, -100, 0, 25)
	display.Position = UDim2.new(0, 50, 0, 18)
	display.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	display.Text = options[currentIndex]
	display.TextColor3 = Color3.fromRGB(255, 255, 100)
	display.TextSize = 11
	display.Font = Enum.Font.GothamBold
	display.Parent = container
	Instance.new("UICorner", display).CornerRadius = UDim.new(0, 4)

	local prevBtn = Instance.new("TextButton")
	prevBtn.Size = UDim2.new(0, 40, 0, 25)
	prevBtn.Position = UDim2.new(0, 0, 0, 18)
	prevBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	prevBtn.Text = "◄"
	prevBtn.TextColor3 = Color3.new(1, 1, 1)
	prevBtn.TextSize = 12
	prevBtn.Font = Enum.Font.GothamBold
	prevBtn.Parent = container
	Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 4)

	local nextBtn = Instance.new("TextButton")
	nextBtn.Size = UDim2.new(0, 40, 0, 25)
	nextBtn.Position = UDim2.new(1, -40, 0, 18)
	nextBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	nextBtn.Text = "►"
	nextBtn.TextColor3 = Color3.new(1, 1, 1)
	nextBtn.TextSize = 12
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.Parent = container
	Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 4)

	yOffset = yOffset + 50

	local index = currentIndex
	local function update() display.Text = options[index] onChange(index, options[index]) end
	prevBtn.MouseButton1Click:Connect(function() index = index - 1 if index < 1 then index = #options end update() end)
	nextBtn.MouseButton1Click:Connect(function() index = index + 1 if index > #options then index = 1 end update() end)
	return function(newIndex) index = newIndex display.Text = options[index] end
end

-- BUILD UI
createLabel("🛡️ SHIELD PLAYGROUND", 25, true)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 25)
statusLabel.Position = UDim2.new(0, 10, 0, yOffset)
statusLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
statusLabel.Text = "Ready"
statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Parent = scroll
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 4)
yOffset = yOffset + 30

createLabel("Q: Create | C: Destroy | R: Rebuild", 14)
createLabel("- =: Base | T: Damage | Y: Heal | G: Fire", 14)

createHeader("BASE SHAPE")
local triangleInfoLabel = Instance.new("TextLabel")
triangleInfoLabel.Size = UDim2.new(1, -20, 0, 20)
triangleInfoLabel.Position = UDim2.new(0, 10, 0, yOffset)
triangleInfoLabel.BackgroundTransparency = 1
triangleInfoLabel.Text = "Triangles: " .. getTriangleCount()
triangleInfoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
triangleInfoLabel.TextSize = 11
triangleInfoLabel.Font = Enum.Font.GothamBold
triangleInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
triangleInfoLabel.Parent = scroll
yOffset = yOffset + 22

local updateBaseShapeDisplay = createSelector("Base Geometry", baseShapes, currentBaseShapeIndex, function(idx, val)
	currentBaseShapeIndex = idx
	config.baseShape = val
	triangleInfoLabel.Text = "Triangles: " .. getTriangleCount()
end)

createHeader("SHAPE TYPE")
local updateShapeDisplay = createSelector("Shape", shapeTypes, currentShapeIndex, function(idx, val)
	currentShapeIndex = idx
	config.shapeType = val
end)

createHeader("SPAWN PATTERN")
local updatePatternDisplay = createSelector("Pattern", spawnPatterns, currentPatternIndex, function(idx, val)
	currentPatternIndex = idx
	config.spawnPattern = val
end)
createSlider("diagonalStrength", 0.1, 0.8, "Diagonal Strength", 2)

createHeader("SPAWN TIMING")
createSlider("spawnDelay", 0, 0.2, "Delay (seconds)", 3)
createSlider("spawnBatch", 1, 20, "Batch Size", 0)

createHeader("SIZE & DETAIL")
createSlider("radius", 3, 25, "Radius", 1)
createSlider("subdivisionLevel", 0, 4, "Subdivision Level", 0)
createSlider("cutoffY", -1, 1, "Cutoff", 2)
createSlider("offsetY", -5, 10, "Offset Y", 1)
createSlider("offsetZ", -10, 10, "Offset Z", 1)

createHeader("ANIMATION")
createToggle("breathing", "Breathing (pulse)")
createSlider("breathingIntensity", 0.01, 0.15, "Breath Intensity", 2)
local updateSpawnAnimDisplay = createSelector("Spawn Animation", spawnAnims, currentSpawnAnimIndex, function(idx, val)
	currentSpawnAnimIndex = idx
	config.spawnAnim = val
end)
createToggle("momentumLag", "Momentum Lag")
createToggle("velocityTilt", "Velocity Tilt")
createToggle("hitRipple", "Hit Ripple")
createToggle("breakAnim", "Break Animation")

createHeader("MAGIC EFFECTS")
createToggle("shimmer", "Shimmer")
createSlider("shimmerIntensity", 0.1, 1.0, "Shimmer Intensity", 2)
createToggle("energyWave", "Energy Wave")
createToggle("edgeGlow", "Edge Glow")
createToggle("coreGlowSync", "Core Glow Sync")

createHeader("TESTING")
createToggle("testMode", "Test Mode (Fixed Position)")

createHeader("TRIANGLES")
createToggle("showTriangles", "Show Triangles")
createSlider("triangleThickness", 0.02, 0.3, "Thickness", 2)
createSlider("triangleTransparency", 0, 0.95, "Transparency", 2)
createSlider("triangleR", 0, 255, "Red", 0)
createSlider("triangleG", 0, 255, "Green", 0)
createSlider("triangleB", 0, 255, "Blue", 0)
createToggle("glowMaterial", "Glow (Neon)")

createHeader("EDGES")
createToggle("showEdges", "Show Edges")
createSlider("edgeThickness", 0.02, 0.3, "Thickness", 2)
createSlider("edgeTransparency", 0, 0.9, "Transparency", 2)
createSlider("edgeR", 0, 255, "Red", 0)
createSlider("edgeG", 0, 255, "Green", 0)
createSlider("edgeB", 0, 255, "Blue", 0)

createHeader("VERTICES")
createToggle("showVertices", "Show Vertices")
createSlider("vertexSize", 0.1, 0.8, "Size", 2)

createHeader("COLOR PRESETS")
local presets = {
	{name = "Blu", tR = 80, tG = 150, tB = 220, eR = 100, eG = 200, eB = 255},
	{name = "Gld", tR = 220, tG = 180, tB = 50, eR = 255, eG = 215, eB = 80},
	{name = "Red", tR = 200, tG = 50, tB = 50, eR = 255, eG = 80, eB = 80},
	{name = "Grn", tR = 50, tG = 180, tB = 80, eR = 80, eG = 255, eB = 120},
	{name = "Pur", tR = 150, tG = 50, tB = 200, eR = 180, eG = 100, eB = 255},
	{name = "Wht", tR = 220, tG = 220, tB = 230, eR = 255, eG = 255, eB = 255},
}

local presetContainer = Instance.new("Frame")
presetContainer.Size = UDim2.new(1, -20, 0, 30)
presetContainer.Position = UDim2.new(0, 10, 0, yOffset)
presetContainer.BackgroundTransparency = 1
presetContainer.Parent = scroll

for i, p in ipairs(presets) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 45, 0, 25)
	btn.Position = UDim2.new(0, (i-1) * 48, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(p.tR, p.tG, p.tB)
	btn.Text = p.name
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 9
	btn.Font = Enum.Font.GothamBold
	btn.Parent = presetContainer
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
	btn.MouseButton1Click:Connect(function()
		config.triangleR, config.triangleG, config.triangleB = p.tR, p.tG, p.tB
		config.edgeR, config.edgeG, config.edgeB = p.eR, p.eG, p.eB
	end)
end
yOffset = yOffset + 35

createHeader("TRIANGLE COUNTS")
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 90)
infoLabel.Position = UDim2.new(0, 10, 0, yOffset)
infoLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
infoLabel.Text = "        Lvl0  Lvl1  Lvl2  Lvl3  Lvl4\nTetra:    4    16    64   256  1024\nOcta:     8    32   128   512  2048\nIcosa:   20    80   320  1280  5120"
infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
infoLabel.TextSize = 10
infoLabel.Font = Enum.Font.Code
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = scroll
Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0, 4)
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingTop = UDim.new(0, 8)
pad.Parent = infoLabel

local function updateStatus(text, color)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or Color3.new(1, 1, 1)
end

local function toggle()
	playgroundEnabled = not playgroundEnabled
	panel.Visible = playgroundEnabled
	toggleBtn.Text = playgroundEnabled and "🛡️ SHIELD: ON" or "🛡️ SHIELD: OFF"
	toggleBtn.BackgroundColor3 = playgroundEnabled and Color3.fromRGB(30, 150, 80) or Color3.fromRGB(30, 80, 150)
end

local function createShield()
	if isCreating then return end
	isCreating = true
	updateStatus("Creating...", Color3.fromRGB(255, 200, 100))
	ShieldRemote:FireServer("Create", config)
end

local function destroyShield()
	ShieldRemote:FireServer("Destroy")
	updateStatus("Ready", Color3.fromRGB(100, 255, 100))
end

toggleBtn.MouseButton1Click:Connect(toggle)

ShieldRemote.OnClientEvent:Connect(function(action, data)
	if action == "Created" then
		isCreating = false
		if type(data) == "table" then
			updateStatus(string.format("%s | %s: %d", data.baseShape or "?", data.pattern, data.triangles), Color3.fromRGB(100, 255, 100))
		else
			updateStatus("Active", Color3.fromRGB(100, 255, 100))
		end
	elseif action == "Destroyed" then
		isCreating = false
		updateStatus("Ready", Color3.fromRGB(100, 255, 100))
	elseif action == "Progress" then
		updateStatus(tostring(data), Color3.fromRGB(255, 200, 100))
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.Insert then toggle()
	elseif playgroundEnabled then
		if input.KeyCode == Enum.KeyCode.Q then createShield()
		elseif input.KeyCode == Enum.KeyCode.C then destroyShield()
		elseif input.KeyCode == Enum.KeyCode.R then destroyShield() task.wait(0.1) createShield()
		elseif input.KeyCode == Enum.KeyCode.T then
			local idx = getHoveredTriangle()
			if idx then ShieldRemote:FireServer("Damage", idx, 25) end
		elseif input.KeyCode == Enum.KeyCode.Y then
			local idx = getHoveredTriangle()
			if idx then ShieldRemote:FireServer("Repair", idx, 25) end
		elseif input.KeyCode == Enum.KeyCode.Minus then
			currentBaseShapeIndex = currentBaseShapeIndex - 1
			if currentBaseShapeIndex < 1 then currentBaseShapeIndex = #baseShapes end
			config.baseShape = baseShapes[currentBaseShapeIndex]
			updateBaseShapeDisplay(currentBaseShapeIndex)
			triangleInfoLabel.Text = "Triangles: " .. getTriangleCount()
		elseif input.KeyCode == Enum.KeyCode.Equals then
			currentBaseShapeIndex = currentBaseShapeIndex + 1
			if currentBaseShapeIndex > #baseShapes then currentBaseShapeIndex = 1 end
			config.baseShape = baseShapes[currentBaseShapeIndex]
			updateBaseShapeDisplay(currentBaseShapeIndex)
			triangleInfoLabel.Text = "Triangles: " .. getTriangleCount()
		elseif input.KeyCode == Enum.KeyCode.G then
			ShieldRemote:FireServer("TestProjectile")
		end
	end
end)
