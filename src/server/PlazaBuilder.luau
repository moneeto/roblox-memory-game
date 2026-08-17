local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlazaConfig = require(Shared.PlazaConfig)

local PlazaBuilder = {}

local TAG = "MemoryTable"
local ANCHORS_FOLDER_NAME = "TableAnchors"

local function createPart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material,
	Transparency: number?,
	CanCollide: boolean?,
	Parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Anchored = true
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.Color = props.Color
	part.Material = props.Material
	part.Transparency = props.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function orientSeatToward(seat: Seat, target: Vector3)
	local position = seat.Position
	local lookAt = Vector3.new(target.X, position.Y, target.Z)
	seat.CFrame = CFrame.lookAt(position, lookAt)
end

local function createStatusIndicator(tableModel: Model, boardOrigin: BasePart)
	local adornee = tableModel:FindFirstChild("TableTop")
	if not (adornee and adornee:IsA("BasePart")) then
		adornee = boardOrigin
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatusIndicator"
	billboard.Size = UDim2.fromOffset(80, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = adornee :: BasePart
	billboard.Parent = tableModel

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	label.Text = "0/1"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(212, 175, 55)
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
end

local function createMemoryTable(
	parent: Instance,
	tableName: string,
	mode: "Solo" | "Versus",
	floorPosition: Vector3
): Model
	local tableModel = Instance.new("Model")
	tableModel.Name = tableName
	tableModel:SetAttribute("Mode", mode)

	local center = floorPosition + Vector3.new(0, 1.25, 0)
	local tableSize = if mode == "Solo" then Vector3.new(10, 0.5, 14) else Vector3.new(12, 0.5, 14)
	local tableCf = CFrame.new(center) * CFrame.Angles(0, PlazaConfig.TABLE_YAW, 0)

	local tableTop = createPart({
		Name = "TableTop",
		Size = tableSize,
		CFrame = tableCf,
		Color = Color3.fromRGB(110, 24, 45),
		Material = Enum.Material.SmoothPlastic,
		Parent = tableModel,
	})
	tableModel.PrimaryPart = tableTop

	local boardOrigin = createPart({
		Name = "BoardOrigin",
		Size = Vector3.new(1, 0.05, 1),
		CFrame = tableCf * CFrame.new(0, 0.35, 0),
		Color = Color3.fromRGB(127, 140, 141),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		Parent = tableModel,
	})

	local seatDistance = tableSize.Z / 2 + 1.5

	local seat1 = Instance.new("Seat")
	seat1.Name = "Seat1"
	seat1.Size = Vector3.new(2, 0.5, 2)
	seat1.Anchored = true
	seat1.Disabled = false
	seat1.Color = Color3.fromRGB(46, 125, 80)
	seat1.Material = Enum.Material.Fabric
	seat1.CFrame = tableCf * CFrame.new(0, -0.5, -seatDistance)
	seat1.Parent = tableModel
	orientSeatToward(seat1, center)

	if mode == "Versus" then
		local seat2 = Instance.new("Seat")
		seat2.Name = "Seat2"
		seat2.Size = Vector3.new(2, 0.5, 2)
		seat2.Anchored = true
		seat2.Disabled = false
		seat2.Color = Color3.fromRGB(212, 175, 55)
		seat2.Material = Enum.Material.Fabric
		seat2.CFrame = tableCf * CFrame.new(0, -0.5, seatDistance)
		seat2.Parent = tableModel
		orientSeatToward(seat2, center)
	end

	createStatusIndicator(tableModel, boardOrigin)

	tableModel.Parent = parent
	CollectionService:AddTag(tableModel, TAG)

	return tableModel
end

local function resolveAnchorPosition(anchorName: string, fallback: Vector3): Vector3
	local folder = Workspace:FindFirstChild(ANCHORS_FOLDER_NAME)
	if not folder then
		return PlazaConfig.getFloorPosition(fallback)
	end

	local anchor = folder:FindFirstChild(anchorName)
	if not anchor then
		return PlazaConfig.getFloorPosition(fallback)
	end

	if anchor:IsA("BasePart") then
		return Vector3.new(anchor.Position.X, PlazaConfig.BASE_Y, anchor.Position.Z)
	end
	if anchor:IsA("Attachment") then
		local world = anchor.WorldPosition
		return Vector3.new(world.X, PlazaConfig.BASE_Y, world.Z)
	end

	return PlazaConfig.getFloorPosition(fallback)
end

local function prepareDayLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(120, 120, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 145)
	Lighting.FogEnd = 100000
	Lighting.FogStart = 0
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = 0.2
		atmosphere.Haze = 0
		atmosphere.Glare = 0.1
	end

	-- Si algún script o plugin mueve el reloj, lo volvemos al mediodía.
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
		if math.abs(Lighting.ClockTime - 14) > 0.05 then
			Lighting.ClockTime = 14
		end
	end)
end

local function ensureSpawn()
	if not PlazaConfig.ENSURE_SPAWN then
		return
	end

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			return
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = PlazaConfig.getSpawnPosition()
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = Workspace
end

local function clearGeneratedTables()
	for _, tagged in CollectionService:GetTagged(TAG) do
		if tagged:IsA("Model") and tagged:GetAttribute("GeneratedByPlazaBuilder") == true then
			tagged:Destroy()
		end
	end

	local existing = Workspace:FindFirstChild("MemoryTables")
	if existing then
		existing:Destroy()
	end
end

local function buildTables()
	clearGeneratedTables()
	prepareDayLighting()
	ensureSpawn()

	local tablesFolder = Instance.new("Folder")
	tablesFolder.Name = "MemoryTables"
	tablesFolder.Parent = Workspace

	for index, offset in PlazaConfig.SOLO_OFFSETS do
		local floorPos = resolveAnchorPosition("Solo_" .. index, offset)
		local model = createMemoryTable(tablesFolder, "Table_Solo_" .. index, "Solo", floorPos)
		model:SetAttribute("GeneratedByPlazaBuilder", true)
	end

	for index, offset in PlazaConfig.VERSUS_OFFSETS do
		local floorPos = resolveAnchorPosition("Versus_" .. index, offset)
		local model = createMemoryTable(tablesFolder, "Table_Versus_" .. index, "Versus", floorPos)
		model:SetAttribute("GeneratedByPlazaBuilder", true)
	end

	warn(
		"[MemoryGame] Mesas generadas:",
		PlazaConfig.SOLO_COUNT,
		"solo +",
		PlazaConfig.VERSUS_COUNT,
		"versus @ Y =",
		PlazaConfig.BASE_Y
	)
end

function PlazaBuilder.init()
	buildTables()
end

return PlazaBuilder
