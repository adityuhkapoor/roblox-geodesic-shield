-- ServerScriptService/ShieldServer (Script)
-- GEODESIC SHIELD WITH SPAWN PATTERNS
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShieldRemote = ReplicatedStorage:WaitForChild("ShieldRemote")


-------------------------------------------------
-- MATH
-------------------------------------------------
local PHI = 0.5 + math.sqrt(5) / 2

local function getVertices()
	local verts = {
		Vector3.new(-1, PHI, 0), Vector3.new(1, PHI, 0),
		Vector3.new(-1, -PHI, 0), Vector3.new(1, -PHI, 0),
		Vector3.new(0, -1, PHI), Vector3.new(0, 1, PHI),
		Vector3.new(0, -1, -PHI), Vector3.new(0, 1, -PHI),
		Vector3.new(PHI, 0, -1), Vector3.new(PHI, 0, 1),
		Vector3.new(-PHI, 0, -1), Vector3.new(-PHI, 0, 1),
	}
	for i, v in ipairs(verts) do verts[i] = v.Unit end
	return verts
end

local function getFaces()
	return {
		{1, 12, 6}, {1, 6, 2}, {1, 2, 8}, {1, 8, 11}, {1, 11, 12},
		{2, 6, 10}, {6, 12, 5}, {12, 11, 3}, {11, 8, 7}, {8, 2, 9},
		{4, 10, 5}, {4, 5, 3}, {4, 3, 7}, {4, 7, 9}, {4, 9, 10},
		{5, 10, 6}, {3, 5, 12}, {7, 3, 11}, {9, 7, 8}, {10, 9, 2},
	}
end

local function subdivide(vertices, faces, level)
	if level == 0 then return vertices, faces end

	local newFaces = {}
	local midpointCache = {}

	local function getMidpoint(i1, i2)
		local key = math.min(i1, i2) .. "-" .. math.max(i1, i2)
		if midpointCache[key] then return midpointCache[key] end
		local mid = ((vertices[i1] + vertices[i2]) / 2).Unit
		table.insert(vertices, mid)
		midpointCache[key] = #vertices
		return #vertices
	end

	for _, face in ipairs(faces) do
		local a, b, c = face[1], face[2], face[3]
		local ab = getMidpoint(a, b)
		local bc = getMidpoint(b, c)
		local ca = getMidpoint(c, a)
		table.insert(newFaces, {a, ab, ca})
		table.insert(newFaces, {b, bc, ab})
		table.insert(newFaces, {c, ca, bc})
		table.insert(newFaces, {ab, bc, ca})
	end

	return subdivide(vertices, newFaces, level - 1)
end

local function getUniqueEdges(faces)
	local edgeSet = {}
	local edges = {}

	for _, face in ipairs(faces) do
		for _, pair in ipairs({{face[1], face[2]}, {face[2], face[3]}, {face[3], face[1]}}) do
			local key = math.min(pair[1], pair[2]) .. "-" .. math.max(pair[1], pair[2])
			if not edgeSet[key] then
				edgeSet[key] = true
				table.insert(edges, {pair[1], pair[2]})
			end
		end
	end

	return edges
end

-------------------------------------------------
-- SPAWN PATTERN SORTING
-------------------------------------------------
local function sortFacesByPattern(facesWithCenters, pattern)
	-- facesWithCenters = { {face = {1,2,3}, center = Vector3}, ... }

	local sorted = {}
	for _, item in ipairs(facesWithCenters) do
		table.insert(sorted, item)
	end

	if pattern == "default" then
		-- Keep original order
		return sorted

	elseif pattern == "bottom_to_top" then
		table.sort(sorted, function(a, b)
			return a.center.Y < b.center.Y
		end)

	elseif pattern == "top_to_bottom" then
		table.sort(sorted, function(a, b)
			return a.center.Y > b.center.Y
		end)

	elseif pattern == "left_to_right" then
		table.sort(sorted, function(a, b)
			return a.center.X < b.center.X
		end)

	elseif pattern == "right_to_left" then
		table.sort(sorted, function(a, b)
			return a.center.X > b.center.X
		end)

	elseif pattern == "front_to_back" then
		table.sort(sorted, function(a, b)
			return a.center.Z > b.center.Z
		end)

	elseif pattern == "back_to_front" then
		table.sort(sorted, function(a, b)
			return a.center.Z < b.center.Z
		end)

	elseif pattern == "center_out" then
		table.sort(sorted, function(a, b)
			return a.center.Magnitude < b.center.Magnitude
		end)

	elseif pattern == "outside_in" then
		table.sort(sorted, function(a, b)
			return a.center.Magnitude > b.center.Magnitude
		end)

	elseif pattern == "diagonal_bl_tr" then
		-- Bottom-left to top-right: sort by (-X + Y)
		table.sort(sorted, function(a, b)
			local scoreA = -a.center.X + a.center.Y
			local scoreB = -b.center.X + b.center.Y
			return scoreA < scoreB
		end)

	elseif pattern == "diagonal_tr_bl" then
		-- Top-right to bottom-left
		table.sort(sorted, function(a, b)
			local scoreA = -a.center.X + a.center.Y
			local scoreB = -b.center.X + b.center.Y
			return scoreA > scoreB
		end)

	elseif pattern == "diagonal_br_tl" then
		-- Bottom-right to top-left: sort by (X + Y)
		table.sort(sorted, function(a, b)
			local scoreA = a.center.X + a.center.Y
			local scoreB = b.center.X + b.center.Y
			return scoreA < scoreB
		end)

	elseif pattern == "diagonal_tl_br" then
		-- Top-left to bottom-right
		table.sort(sorted, function(a, b)
			local scoreA = a.center.X + a.center.Y
			local scoreB = b.center.X + b.center.Y
			return scoreA > scoreB
		end)

	elseif pattern == "spiral_cw" then
		-- Clockwise spiral from top (by angle around Y axis)
		table.sort(sorted, function(a, b)
			local angleA = math.atan2(a.center.X, a.center.Z)
			local angleB = math.atan2(b.center.X, b.center.Z)
			-- Add Y component for spiral effect
			local scoreA = angleA + a.center.Y * 0.5
			local scoreB = angleB + b.center.Y * 0.5
			return scoreA < scoreB
		end)

	elseif pattern == "spiral_ccw" then
		-- Counter-clockwise spiral
		table.sort(sorted, function(a, b)
			local angleA = math.atan2(a.center.X, a.center.Z)
			local angleB = math.atan2(b.center.X, b.center.Z)
			local scoreA = angleA + a.center.Y * 0.5
			local scoreB = angleB + b.center.Y * 0.5
			return scoreA > scoreB
		end)

	elseif pattern == "ring_top_down" then
		-- Rings from top to bottom (sorted by Y, then angle)
		table.sort(sorted, function(a, b)
			-- Round Y to create "rings"
			local ringA = math.floor(a.center.Y * 5) / 5
			local ringB = math.floor(b.center.Y * 5) / 5
			if ringA ~= ringB then
				return ringA > ringB -- Top first
			end
			-- Within same ring, sort by angle
			local angleA = math.atan2(a.center.X, a.center.Z)
			local angleB = math.atan2(b.center.X, b.center.Z)
			return angleA < angleB
		end)

	elseif pattern == "ring_bottom_up" then
		-- Rings from bottom to top
		table.sort(sorted, function(a, b)
			local ringA = math.floor(a.center.Y * 5) / 5
			local ringB = math.floor(b.center.Y * 5) / 5
			if ringA ~= ringB then
				return ringA < ringB -- Bottom first
			end
			local angleA = math.atan2(a.center.X, a.center.Z)
			local angleB = math.atan2(b.center.X, b.center.Z)
			return angleA < angleB
		end)

	elseif pattern == "random" then
		-- Shuffle randomly
		for i = #sorted, 2, -1 do
			local j = math.random(1, i)
			sorted[i], sorted[j] = sorted[j], sorted[i]
		end

	elseif pattern == "wave_horizontal" then
		-- Wave pattern (sine wave based on X)
		table.sort(sorted, function(a, b)
			local waveA = a.center.Y + math.sin(a.center.X * 2) * 0.3
			local waveB = b.center.Y + math.sin(b.center.X * 2) * 0.3
			return waveA < waveB
		end)

	elseif pattern == "checkerboard" then
		-- Alternating pattern
		table.sort(sorted, function(a, b)
			local gridA = math.floor(a.center.X * 3) + math.floor(a.center.Y * 3) * 10
			local gridB = math.floor(b.center.X * 3) + math.floor(b.center.Y * 3) * 10
			local checkA = (math.floor(a.center.X * 3) + math.floor(a.center.Y * 3)) % 2
			local checkB = (math.floor(b.center.X * 3) + math.floor(b.center.Y * 3)) % 2
			if checkA ~= checkB then
				return checkA < checkB
			end
			return gridA < gridB
		end)
	end

	return sorted
end

-------------------------------------------------
-- CREATE TRIANGLE (UnionAsync)
-------------------------------------------------
local function createTriangle(A, B, C, thickness)
	local AB, AC, BC = B - A, C - A, C - B

	local XVector = AC:Cross(AB)
	if XVector.Magnitude < 0.001 then return nil end
	XVector = XVector.Unit

	local YVector = BC:Cross(XVector).Unit
	local ZVector = BC.Unit

	local height = math.abs(AB:Dot(YVector))
	if height < 0.001 then return nil end

	local WedgePart1 = Instance.new("WedgePart")
	WedgePart1.BottomSurface = Enum.SurfaceType.Smooth
	WedgePart1.Size = Vector3.new(thickness, height, math.max(0.01, math.abs(AB:Dot(ZVector))))
	WedgePart1.CFrame = CFrame.fromMatrix((A + B) / 2, XVector, YVector, ZVector)
	WedgePart1.Anchored = true
	WedgePart1.CanCollide = false

	local WedgePart2 = Instance.new("WedgePart")
	WedgePart2.BottomSurface = Enum.SurfaceType.Smooth
	WedgePart2.Size = Vector3.new(thickness, height, math.max(0.01, math.abs(AC:Dot(ZVector))))
	WedgePart2.CFrame = CFrame.fromMatrix((A + C) / 2, -XVector, YVector, -ZVector)
	WedgePart2.Anchored = true
	WedgePart2.CanCollide = false

	WedgePart1.Parent = workspace
	WedgePart2.Parent = workspace

	local success, triangle = pcall(function()
		return WedgePart1:UnionAsync({WedgePart2})
	end)

	WedgePart1:Destroy()
	WedgePart2:Destroy()

	if success and triangle then
		triangle.Anchored = true
		triangle.CanCollide = false
		triangle.CastShadow = false
		triangle.UsePartColor = true
		return triangle
	end

	return nil
end

-------------------------------------------------
-- FILTER FACES BY SHAPE TYPE
-------------------------------------------------
local function filterFaces(faces, vertices, shapeType, cutoffY)
	local filtered = {}

	for _, face in ipairs(faces) do
		local v1, v2, v3 = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		local center = (v1 + v2 + v3) / 3
		local maxY = math.max(v1.Y, v2.Y, v3.Y)
		local minY = math.min(v1.Y, v2.Y, v3.Y)

		local include = false

		if shapeType == "full" then
			include = true
		elseif shapeType == "dome_top" then
			include = maxY >= cutoffY
		elseif shapeType == "dome_bottom" then
			include = minY <= -cutoffY
		elseif shapeType == "front" then
			include = center.Z >= cutoffY
		elseif shapeType == "back" then
			include = center.Z <= -cutoffY
		elseif shapeType == "left" then
			include = center.X <= -cutoffY
		elseif shapeType == "right" then
			include = center.X >= cutoffY
		elseif shapeType == "quarter_front_top" then
			include = maxY >= cutoffY and center.Z >= 0
		elseif shapeType == "band" then
			include = math.abs(center.Y) <= (1 - cutoffY)
		elseif shapeType == "cap" then
			include = minY >= cutoffY
		else
			include = maxY >= cutoffY
		end

		if include then
			table.insert(filtered, face)
		end
	end

	return filtered
end

-------------------------------------------------
-- PLAYER SHIELDS
-------------------------------------------------
local playerShields = {}

-------------------------------------------------
-- CREATE SHIELD
-------------------------------------------------
local function createShield(player, config)
	-- Destroy old
	if playerShields[player] then
		if playerShields[player].model then
			playerShields[player].model:Destroy()
		end
		if playerShields[player].connection then
			playerShields[player].connection:Disconnect()
		end
		playerShields[player] = nil
	end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Config values
	local radius = config.radius or 10
	local subdivisionLevel = math.clamp(config.subdivisionLevel or 1, 0, 3)
	local shapeType = config.shapeType or "dome_top"
	local cutoffY = config.cutoffY or 0
	local thickness = config.triangleThickness or 0.1
	local triangleColor = Color3.fromRGB(config.triangleR or 80, config.triangleG or 150, config.triangleB or 220)
	local edgeColor = Color3.fromRGB(config.edgeR or 100, config.edgeG or 200, config.edgeB or 255)
	local triangleTransparency = config.triangleTransparency or 0.5
	local edgeTransparency = config.edgeTransparency or 0.1
	local edgeThickness = config.edgeThickness or 0.1
	local vertexSize = config.vertexSize or 0.25
	local showTriangles = config.showTriangles ~= 0
	local showEdges = config.showEdges ~= 0
	local showVertices = config.showVertices ~= 0
	local material = config.glowMaterial and Enum.Material.Neon or Enum.Material.Glass

	-- Spawn pattern settings
	local spawnPattern = config.spawnPattern or "default"
	local spawnDelay = config.spawnDelay or 0
	local spawnBatch = math.max(1, config.spawnBatch or 5)

	-- Position offset
	local offsetY = config.offsetY or 1
	local offsetZ = config.offsetZ or 0
	local centerPos = rootPart.Position + Vector3.new(0, offsetY, offsetZ)

	-- Generate geometry
	local vertices = getVertices()
	local faces = getFaces()
	vertices, faces = subdivide(vertices, faces, subdivisionLevel)

	-- Filter by shape
	local filteredFaces = filterFaces(faces, vertices, shapeType, cutoffY)

	-- Calculate centers and prepare for sorting
	local facesWithCenters = {}
	for _, face in ipairs(filteredFaces) do
		local v1, v2, v3 = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		local center = (v1 + v2 + v3) / 3 -- Unit sphere center
		table.insert(facesWithCenters, {
			face = face,
			center = center,
		})
	end

	-- Sort by spawn pattern
	local sortedFaces = sortFacesByPattern(facesWithCenters, spawnPattern)

	-- Get edges from sorted faces (for consistent edge creation)
	local sortedFaceList = {}
	for _, item in ipairs(sortedFaces) do
		table.insert(sortedFaceList, item.face)
	end
	local edges = getUniqueEdges(sortedFaceList)

	local usedVertices = {}
	for _, edge in ipairs(edges) do
		usedVertices[edge[1]] = true
		usedVertices[edge[2]] = true
	end

	local model = Instance.new("Model")
	model.Name = player.Name .. "_Shield"
	model.Parent = workspace

	local triangleData = {}
	local totalParts = 0

	local triangleCount = #sortedFaces
	ShieldRemote:FireClient(player, "Progress", "Starting... " .. triangleCount .. " triangles")

	-- Store shield early for position tracking
	local shieldCenter = centerPos
	playerShields[player] = {
		model = model,
		triangles = triangleData,
		connection = nil,
		config = config,
	}

	-- Follow player connection
	local connection = RunService.Heartbeat:Connect(function()
		if not model.Parent or not rootPart.Parent then return end

		local newCenter = rootPart.Position + Vector3.new(0, offsetY, offsetZ)
		local offset = newCenter - shieldCenter

		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CFrame = part.CFrame + offset
			end
		end

		for _, tri in ipairs(triangleData) do
			tri.center = tri.center + offset
		end

		shieldCenter = newCenter
	end)

	playerShields[player].connection = connection

	-- Create triangles with spawn pattern
	task.spawn(function()
		if showTriangles then
			local batchCount = 0

			for i, item in ipairs(sortedFaces) do
				-- Check if shield still exists
				if not playerShields[player] or not model.Parent then
					return
				end

				local face = item.face
				local v1, v2, v3 = vertices[face[1]], vertices[face[2]], vertices[face[3]]
				local p1 = shieldCenter + v1 * radius
				local p2 = shieldCenter + v2 * radius
				local p3 = shieldCenter + v3 * radius

				local triangle = createTriangle(p1, p2, p3, thickness)

				if triangle then
					triangle.Name = "Tri_" .. i
					triangle.Color = triangleColor
					triangle.Material = material
					triangle.Transparency = triangleTransparency
					triangle:SetAttribute("TriangleIndex", i)
					triangle:SetAttribute("IsShieldTriangle", true)
					triangle:SetAttribute("HP", 100)
					triangle.Parent = model
					totalParts = totalParts + 1

					table.insert(triangleData, {
						index = i,
						part = triangle,
						center = (p1 + p2 + p3) / 3,
						hp = 100,
						originalColor = triangleColor,
					})
				end

				batchCount = batchCount + 1

				-- Apply spawn delay
				if spawnDelay > 0 and batchCount >= spawnBatch then
					batchCount = 0
					task.wait(spawnDelay)
				elseif batchCount >= 5 then
					batchCount = 0
					task.wait() -- Minimum yield to prevent freezing
				end

				-- Progress update
				if i % 15 == 0 then
					ShieldRemote:FireClient(player, "Progress", string.format("%s: %d/%d", spawnPattern, i, triangleCount))
				end
			end
		end

		-- Create edges
		if showEdges then
			for _, edge in ipairs(edges) do
				local v1, v2 = vertices[edge[1]], vertices[edge[2]]
				local p1 = shieldCenter + v1 * radius
				local p2 = shieldCenter + v2 * radius

				local part = Instance.new("Part")
				part.Name = "Edge"
				part.Size = Vector3.new(edgeThickness, edgeThickness, (p2 - p1).Magnitude)
				part.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
				part.Anchored = true
				part.CanCollide = false
				part.CastShadow = false
				part.Material = Enum.Material.Neon
				part.Color = edgeColor
				part.Transparency = edgeTransparency
				part.Parent = model
				totalParts = totalParts + 1
			end
		end

		-- Create vertices
		if showVertices then
			for idx in pairs(usedVertices) do
				local pos = shieldCenter + vertices[idx] * radius
				local part = Instance.new("Part")
				part.Name = "Vertex"
				part.Shape = Enum.PartType.Ball
				part.Size = Vector3.new(vertexSize, vertexSize, vertexSize)
				part.Position = pos
				part.Anchored = true
				part.CanCollide = false
				part.CastShadow = false
				part.Material = Enum.Material.Neon
				part.Color = edgeColor
				part.Transparency = edgeTransparency
				part.Parent = model
				totalParts = totalParts + 1
			end
		end

		-- Core light
		local core = Instance.new("Part")
		core.Name = "Core"
		core.Shape = Enum.PartType.Ball
		core.Size = Vector3.new(0.5, 0.5, 0.5)
		core.Position = shieldCenter
		core.Anchored = true
		core.CanCollide = false
		core.Transparency = 1
		core.Parent = model

		local light = Instance.new("PointLight")
		light.Color = edgeColor
		light.Brightness = config.lightBrightness or 2
		light.Range = config.lightRange or 25
		light.Parent = core

		ShieldRemote:FireClient(player, "Created", {
			triangles = #triangleData,
			parts = totalParts,
			shape = shapeType,
			pattern = spawnPattern,
		})
	end)
end

-------------------------------------------------
-- DESTROY SHIELD
-------------------------------------------------
local function destroyShield(player)
	if playerShields[player] then
		if playerShields[player].model then
			playerShields[player].model:Destroy()
		end
		if playerShields[player].connection then
			playerShields[player].connection:Disconnect()
		end
		playerShields[player] = nil
		ShieldRemote:FireClient(player, "Destroyed")
	end
end

-------------------------------------------------
-- DAMAGE / REPAIR
-------------------------------------------------
local function damageTriangle(player, index, damage)
	if not playerShields[player] then return end

	for _, tri in ipairs(playerShields[player].triangles) do
		if tri.index == index and tri.part and tri.part.Parent then
			tri.hp = math.max(0, tri.hp - damage)
			tri.part:SetAttribute("HP", tri.hp)

			local original = tri.originalColor
			tri.part.Color = Color3.new(1, 1, 1)

			task.delay(0.1, function()
				if tri.part and tri.part.Parent then
					local dmgPct = 1 - (tri.hp / 100)
					tri.part.Color = Color3.new(
						original.R + (1 - original.R) * dmgPct,
						original.G * (1 - dmgPct),
						original.B * (1 - dmgPct)
					)
				end
			end)

			if tri.hp <= 0 then
				tri.part:Destroy()
			end
			return
		end
	end
end

local function repairTriangle(player, index, amount)
	if not playerShields[player] then return end

	for _, tri in ipairs(playerShields[player].triangles) do
		if tri.index == index and tri.part and tri.part.Parent and tri.hp < 100 then
			tri.hp = math.min(100, tri.hp + amount)
			tri.part:SetAttribute("HP", tri.hp)

			tri.part.Color = Color3.fromRGB(100, 255, 100)
			task.delay(0.2, function()
				if tri.part and tri.part.Parent then
					local dmgPct = 1 - (tri.hp / 100)
					local original = tri.originalColor
					tri.part.Color = Color3.new(
						original.R + (1 - original.R) * dmgPct,
						original.G * (1 - dmgPct),
						original.B * (1 - dmgPct)
					)
				end
			end)
			return
		end
	end
end

-------------------------------------------------
-- HANDLE EVENTS
-------------------------------------------------
ShieldRemote.OnServerEvent:Connect(function(player, action, ...)
	if action == "Create" then
		createShield(player, ... or {})
	elseif action == "Destroy" then
		destroyShield(player)
	elseif action == "Damage" then
		damageTriangle(player, ...)
	elseif action == "Repair" then
		repairTriangle(player, ...)
	end
end)

Players.PlayerRemoving:Connect(destroyShield)
