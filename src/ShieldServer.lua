local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Load modules
local ShieldModules = script.Parent.ShieldModules
local ShieldConfig = require(ShieldModules.ShieldConfig)
local ShieldGeometry = require(ShieldModules.ShieldGeometry)
local ShieldRenderer = require(ShieldModules.ShieldRenderer)
local ShieldAnimation = require(ShieldModules.ShieldAnimation)
local ShieldCombat = require(ShieldModules.ShieldCombat)
local ShieldEvents = require(ShieldModules.ShieldEvents)
local ShieldRemote = ReplicatedStorage:WaitForChild("ShieldRemote")

-------------------------------------------------
-- PLAYER SHIELDS
-------------------------------------------------
local playerShields = {}

-------------------------------------------------
-- CREATE SHIELD
-------------------------------------------------
local function createShield(player, config)
	-- Destroy old shield
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

	-- Apply defaults and validate
	for key, value in pairs(ShieldConfig.Defaults) do
		if config[key] == nil then
			config[key] = value
		end
	end
	config = ShieldConfig.validate(config)

	-- Extract config values
	local baseShape = config.baseShape
	local radius = config.radius
	local subdivisionLevel = config.subdivisionLevel
	local shapeType = config.shapeType
	local cutoffY = config.cutoffY
	local thickness = config.triangleThickness
	local triangleColor = Color3.fromRGB(config.triangleR, config.triangleG, config.triangleB)
	local edgeColor = Color3.fromRGB(config.edgeR, config.edgeG, config.edgeB)
	local triangleTransparency = config.triangleTransparency
	local edgeTransparency = config.edgeTransparency
	local edgeThickness = config.edgeThickness
	local vertexSize = config.vertexSize
	local showTriangles = config.showTriangles == 1
	local showEdges = config.showEdges == 1
	local showVertices = config.showVertices == 1
	local material = config.glowMaterial == 1 and Enum.Material.Neon or Enum.Material.Glass
	local spawnPattern = config.spawnPattern
	local spawnDelay = config.spawnDelay
	local spawnBatch = config.spawnBatch
	local spawnAnim = config.spawnAnim
	local offsetY = config.offsetY
	local offsetZ = config.offsetZ

	-- Animation settings
	local useBreathing = config.breathing == 1
	local breathingIntensity = config.breathingIntensity
	local useMomentumLag = config.momentumLag == 1
	local useVelocityTilt = config.velocityTilt == 1
	local useShimmer = config.shimmer == 1
	local shimmerIntensity = config.shimmerIntensity
	local useEnergyWave = config.energyWave == 1
	local useEdgeGlow = config.edgeGlow == 1
	local useCoreGlowSync = config.coreGlowSync == 1
	local useTestMode = config.testMode == 1

	-- Combat settings
	local useHitRipple = config.hitRipple == 1
	local useBreakAnim = config.breakAnim == 1

	-- Capture initial Y rotation to convert world -> local
	local _, initialYRotation, _ = rootPart.CFrame:ToEulerAnglesYXZ()
	local inverseInitialRotation = CFrame.Angles(0, -initialYRotation + math.pi, 0)

	-- Calculate spawn center (in front of player)
	local centerPos = rootPart.Position + Vector3.new(0, offsetY, 0) + rootPart.CFrame.LookVector * offsetZ
	local fixedCenter = rootPart.Position + Vector3.new(0, offsetY, 0) + rootPart.CFrame.LookVector * 15

	-- Generate geometry (unrotated - on unit sphere)
	local vertices, faces = ShieldGeometry.getBaseGeometry(baseShape)
	vertices, faces = ShieldGeometry.subdivide(vertices, faces, subdivisionLevel)
	local filteredFaces = ShieldGeometry.filterFaces(faces, vertices, shapeType, cutoffY)

	-- Build face centers for sorting
	local facesWithCenters = {}
	for _, face in ipairs(filteredFaces) do
		local v1, v2, v3 = vertices[face[1]], vertices[face[2]], vertices[face[3]]
		table.insert(facesWithCenters, { face = face, center = (v1 + v2 + v3) / 3 })
	end

	local sortedFaces = ShieldGeometry.sortFacesByPattern(facesWithCenters, spawnPattern, config.diagonalStrength)

	-- Get edges and vertices
	local sortedFaceList = {}
	for _, item in ipairs(sortedFaces) do
		table.insert(sortedFaceList, item.face)
	end
	local edges = ShieldGeometry.getUniqueEdges(sortedFaceList)
	local usedVertices = ShieldGeometry.getUsedVertices(edges)

	-- Create model
	local model = Instance.new("Model")
	model.Name = player.Name .. "_Shield"
	model.Parent = workspace

	local triangleData = {}
	local edgeParts = {}
	local vertexParts = {}
	local triangleCount = #sortedFaces

	ShieldRemote:FireClient(player, "Progress", "Starting... " .. triangleCount .. " triangles")

	local initialSpawnCenter = useTestMode and fixedCenter or centerPos
	local shieldCenter = initialSpawnCenter
	local smoothCenter = centerPos
	local lastRootPos = rootPart.Position
	local playerVelocity = Vector3.new(0, 0, 0)

	-- Store shield data
	playerShields[player] = {
		model = model,
		triangles = triangleData,
		edges = edgeParts,
		vertices = vertexParts,
		connection = nil,
		config = config,
		radius = radius,
		ready = false,
		lastWaveTime = 0,
	}

	-- Animation loop
	local breathTime = 0
	local connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent or not rootPart.Parent then return end

		breathTime = breathTime + dt

		-- Calculate velocity
		local currentVel = (rootPart.Position - lastRootPos) / math.max(dt, 0.001)
		lastRootPos = rootPart.Position
		playerVelocity = playerVelocity:Lerp(currentVel, 0.2)

		-- Target center (in front of player)
		local targetCenter
		if useTestMode then
			targetCenter = fixedCenter
		else
			targetCenter = rootPart.Position + Vector3.new(0, offsetY, 0) + rootPart.CFrame.LookVector * offsetZ
		end

		-- Momentum lag
		if useMomentumLag then
			smoothCenter = ShieldAnimation.applyMomentumLag(smoothCenter, targetCenter, 0.12)
		else
			smoothCenter = targetCenter
		end

		-- Velocity tilt
		local tiltOffset = Vector3.new(0, 0, 0)
		if useVelocityTilt then
			tiltOffset = ShieldAnimation.getVelocityTilt(playerVelocity, 1.5)
		end

		local newCenter = smoothCenter + tiltOffset

		-- Get player's CURRENT Y rotation (this is all we need!)
		local _, currentYRotation, _ = rootPart.CFrame:ToEulerAnglesYXZ()
		local currentRotation = CFrame.Angles(0, currentYRotation + math.pi, 0)

		-- Breathing
		local breathScale = ShieldAnimation.getBreathScale(breathTime, breathingIntensity, useBreathing and playerShields[player].ready)

		-- Energy wave
		local waveProgress = -1
		if useEnergyWave and playerShields[player].ready then
			waveProgress = ShieldAnimation.updateEnergyWave(playerShields[player], breathTime)
		end

		-- Update triangles
		for _, tri in ipairs(triangleData) do
			if tri.part and tri.part.Parent then
				-- localOffset is in "shield space" where +Z = forward
				-- Rotate by player's current Y rotation to get world offset
				local rotatedOffset = currentRotation:VectorToWorldSpace(tri.localOffset)
				local scaledOffset = rotatedOffset * breathScale
				local newPos = newCenter + scaledOffset

				-- Apply position and rotation to triangle
				if tri.localCFrame then
					tri.part.CFrame = currentRotation * tri.localCFrame + newPos
				else
					tri.part.Position = newPos
				end

				local normalizedHeight = tri.localOffset.Unit.Y
				local baseTrans = triangleTransparency

				-- Edge glow
				if useEdgeGlow then
					baseTrans = ShieldAnimation.getEdgeGlowOffset(normalizedHeight, triangleTransparency)
				end

				-- Shimmer
				local shimmerOffset = 0
				if useShimmer and playerShields[player].ready then
					shimmerOffset = ShieldAnimation.getShimmerOffset(breathTime, tri.index, shimmerIntensity, true)
				end

				-- Energy wave
				local waveTransOffset, waveColorLerp = ShieldAnimation.getWaveEffect(waveProgress, normalizedHeight)

				if waveColorLerp > 0 then
					if not tri.waveColor then
						tri.waveColor = tri.part.Color
					end
					tri.part.Color = tri.waveColor:Lerp(Color3.new(1, 1, 1), waveColorLerp)
				else
					if tri.waveColor then
						tri.part.Color = tri.waveColor
					end
				end

				if not tri.spawning then
					tri.part.Transparency = math.clamp(baseTrans + shimmerOffset + waveTransOffset, 0, 0.95)
				end
			end
		end

		-- Update edges
		for _, edgeData in ipairs(edgeParts) do
			if edgeData.part and edgeData.part.Parent then
				local rotatedV1 = currentRotation:VectorToWorldSpace(edgeData.localV1)
				local rotatedV2 = currentRotation:VectorToWorldSpace(edgeData.localV2)
				local p1 = newCenter + rotatedV1 * radius * breathScale
				local p2 = newCenter + rotatedV2 * radius * breathScale
				edgeData.part.Size = Vector3.new(edgeThickness, edgeThickness, (p2 - p1).Magnitude)
				edgeData.part.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
			end
		end

		-- Update vertices
		for _, vertData in ipairs(vertexParts) do
			if vertData.part and vertData.part.Parent then
				local rotatedPos = currentRotation:VectorToWorldSpace(vertData.localPos)
				vertData.part.Position = newCenter + rotatedPos * radius * breathScale
			end
		end

		-- Update core
		local core = model:FindFirstChild("Core")
		if core then
			core.Position = newCenter

			if useCoreGlowSync and playerShields[player].ready then
				local light = core:FindFirstChildOfClass("PointLight")
				if light then
					ShieldAnimation.updateCoreGlow(light, breathTime, config.lightBrightness, config.lightRange)
				end
			end
		end

		shieldCenter = newCenter
	end)

	playerShields[player].connection = connection

	-- Spawn triangles
	task.spawn(function()
		if showTriangles then
			local batchCount = 0
			for i, item in ipairs(sortedFaces) do
				if not playerShields[player] or not model.Parent then return end

				local face = item.face
				local v1, v2, v3 = vertices[face[1]], vertices[face[2]], vertices[face[3]]

				-- Create triangle at world positions (using initial rotation)
				local initialRotation = CFrame.Angles(0, initialYRotation + math.pi, 0)
				local p1 = initialSpawnCenter + initialRotation:VectorToWorldSpace(v1 * radius)
				local p2 = initialSpawnCenter + initialRotation:VectorToWorldSpace(v2 * radius)
				local p3 = initialSpawnCenter + initialRotation:VectorToWorldSpace(v3 * radius)

				local triangle = ShieldRenderer.createTriangle(p1, p2, p3, thickness)
				if triangle then
					triangle.Name = "Tri_" .. i
					triangle.Color = triangleColor
					triangle.Material = material
					triangle:SetAttribute("TriangleIndex", i)
					triangle:SetAttribute("IsShieldTriangle", true)
					triangle:SetAttribute("HP", 100)
					triangle.Parent = model

					-- Convert world offset to LOCAL offset (shield space where +Z = forward)
					local worldOffset = triangle.Position - initialSpawnCenter
					local localOffset = inverseInitialRotation:VectorToWorldSpace(worldOffset)

					-- Convert world orientation to LOCAL orientation
					local worldCFrame = triangle.CFrame - triangle.CFrame.Position
					local localCFrame = inverseInitialRotation * worldCFrame

					local triData = {
						index = i,
						part = triangle,
						localOffset = localOffset,
						localCFrame = localCFrame,
						hp = 100,
						originalColor = triangleColor,
						spawning = true,
					}

					table.insert(triangleData, triData)

					ShieldRenderer.applySpawnAnimation(triangle, spawnAnim, triangleTransparency, triData)
				end

				batchCount = batchCount + 1
				if batchCount >= spawnBatch then
					batchCount = 0
					if spawnDelay > 0 then
						task.wait(spawnDelay)
					else
						task.wait()
					end
				end

				if i % 15 == 0 then
					ShieldRemote:FireClient(player, "Progress", string.format("%s: %d/%d", spawnPattern, i, triangleCount))
				end
			end
		end

		-- Create edges (store in local space)
		if showEdges then
			for _, edge in ipairs(edges) do
				local v1Unit, v2Unit = vertices[edge[1]], vertices[edge[2]]

				-- v1Unit and v2Unit are already in local space (unit sphere)
				local localV1 = v1Unit
				local localV2 = v2Unit

				-- Create at initial world position
				local initialRotation = CFrame.Angles(0, initialYRotation, 0)
				local p1 = shieldCenter + initialRotation:VectorToWorldSpace(v1Unit * radius)
				local p2 = shieldCenter + initialRotation:VectorToWorldSpace(v2Unit * radius)

				local part = ShieldRenderer.createEdge(p1, p2, edgeThickness, edgeColor, edgeTransparency)
				part.Parent = model

				table.insert(edgeParts, {
					part = part,
					localV1 = localV1,
					localV2 = localV2,
				})
			end
		end

		-- Create vertices (store in local space)
		if showVertices then
			for idx in pairs(usedVertices) do
				local unitPos = vertices[idx]

				-- unitPos is already in local space
				local localPos = unitPos

				-- Create at initial world position
				local initialRotation = CFrame.Angles(0, initialYRotation, 0)
				local pos = shieldCenter + initialRotation:VectorToWorldSpace(unitPos * radius)

				local part = ShieldRenderer.createVertex(pos, vertexSize, edgeColor, edgeTransparency)
				part.Parent = model

				table.insert(vertexParts, {
					part = part,
					localPos = localPos,
				})
			end
		end

		-- Create core
		local core = ShieldRenderer.createCore(shieldCenter, edgeColor, config.lightBrightness, config.lightRange)
		core.Parent = model

		-- Mark shield as ready
		playerShields[player].ready = true

		ShieldRemote:FireClient(player, "Created", {
			triangles = #triangleData,
			baseShape = baseShape,
			pattern = spawnPattern
		})

		ShieldEvents.fireShieldCreated(player, { triangles = #triangleData })
		ShieldEvents.fireShieldReady(player, #triangleData)
	end)
end

-------------------------------------------------
-- DESTROY SHIELD
-------------------------------------------------
local function destroyShield(player)
	if playerShields[player] then
		if playerShields[player].connection then
			playerShields[player].connection:Disconnect()
		end
		if playerShields[player].model then
			playerShields[player].model:Destroy()
		end
		playerShields[player] = nil
		ShieldRemote:FireClient(player, "Destroyed")
		ShieldEvents.fireShieldDestroyed(player)
	end
end

-------------------------------------------------
-- DAMAGE TRIANGLE
-------------------------------------------------
local function damageTriangle(player, index, damage)
	local shield = playerShields[player]
	if not shield then return end

	local useHitRipple = shield.config.hitRipple == 1
	local useBreakAnim = shield.config.breakAnim == 1

	local destroyed = ShieldCombat.damageTriangle(shield, index, damage, useHitRipple, useBreakAnim)

	-- Find triangle to get HP
	for _, tri in ipairs(shield.triangles) do
		if tri.index == index then
			if destroyed then
				ShieldEvents.fireTriangleDestroyed(player, index)
			else
				ShieldEvents.fireTriangleDamaged(player, index, tri.hp)
			end
			break
		end
	end
end

-------------------------------------------------
-- REPAIR TRIANGLE
-------------------------------------------------
local function repairTriangle(player, index, amount)
	local shield = playerShields[player]
	if not shield then return end

	local repaired = ShieldCombat.repairTriangle(shield, index, amount)

	if repaired then
		for _, tri in ipairs(shield.triangles) do
			if tri.index == index then
				ShieldEvents.fireTriangleRepaired(player, index, tri.hp)
				break
			end
		end
	end
end

-------------------------------------------------
-- TEST PROJECTILE
-------------------------------------------------
local function fireTestProjectile(player)
	local shield = playerShields[player]
	if shield then
		ShieldCombat.fireTestProjectile(player, shield, damageTriangle)
	end
end

-------------------------------------------------
-- EVENTS
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
	elseif action == "TestProjectile" then
		fireTestProjectile(player)
	end
end)

Players.PlayerRemoving:Connect(destroyShield)
