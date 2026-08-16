local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlazaConfig = require(Shared.PlazaConfig)

local PlazaBuilder = {}

local TAG = "MemoryTable"
local plazaModel: Model? = nil

local function createPart(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material,
	Transparency: number?,
	Parent: Instance,
}): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Anchored = true
	part.Color = props.Color
	part.Material = props.Material
	part.Transparency = props.Transparency or 0
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
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	label.Text = "0/1"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
end

local function createMemoryTable(
	parent: Model,
	tableName: string,
	mode: "Solo" | "Versus",
	floorPosition: Vector3
): Model
	local tableModel = Instance.new("Model")
	tableModel.Name = tableName
	tableModel:SetAttribute("Mode", mode)

	local center = floorPosition + Vector3.new(0, 1.25, 0)

	-- Mesa grande: las fichas (hasta 4x4) caben con margen
	-- Eje largo en Z: Seat1 (usuario) <-> Seat2 (rival)
	local tableSize = if mode == "Solo" then Vector3.new(10, 0.5, 14) else Vector3.new(12, 0.5, 16)

	local tableTop = createPart({
		Name = "TableTop",
		Size = tableSize,
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(139, 90, 43),
		Material = Enum.Material.Wood,
		Parent = tableModel,
	})
	tableModel.PrimaryPart = tableTop

	local boardOrigin = createPart({
		Name = "BoardOrigin",
		Size = Vector3.new(1, 0.05, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 0.35, 0)),
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
	seat1.Color = Color3.fromRGB(192, 57, 43)
	seat1.Material = Enum.Material.Fabric
	seat1.CFrame = CFrame.new(center + Vector3.new(0, -0.5, -seatDistance))
	seat1.Parent = tableModel
	orientSeatToward(seat1, center)

	if mode == "Versus" then
		local seat2 = Instance.new("Seat")
		seat2.Name = "Seat2"
		seat2.Size = Vector3.new(2, 0.5, 2)
		seat2.Anchored = true
		seat2.Disabled = false
		seat2.Color = Color3.fromRGB(41, 128, 185)
		seat2.Material = Enum.Material.Fabric
		seat2.CFrame = CFrame.new(center + Vector3.new(0, -0.5, seatDistance))
		seat2.Parent = tableModel
		orientSeatToward(seat2, center)
	end

	createStatusIndicator(tableModel, boardOrigin)

	tableModel.Parent = parent
	CollectionService:AddTag(tableModel, TAG)

	return tableModel
end

local function buildEnvironment(parent: Model, baseY: number)
	createPart({
		Name = "MainFloor",
		Size = Vector3.new(160, 1, 100),
		CFrame = CFrame.new(0, baseY - 0.5, 0),
		Color = Color3.fromRGB(189, 195, 199),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})

	createPart({
		Name = "PlayArea",
		Size = Vector3.new(140, 0.2, 80),
		CFrame = CFrame.new(0, baseY + 0.05, 0),
		Color = Color3.fromRGB(76, 175, 80),
		Material = Enum.Material.Grass,
		Parent = parent,
	})

	local welcomeSign = createPart({
		Name = "WelcomeSign",
		Size = Vector3.new(14, 4, 0.4),
		CFrame = CFrame.new(0, baseY + 3, -45),
		Color = Color3.fromRGB(41, 128, 185),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local welcomeGui = Instance.new("SurfaceGui")
	welcomeGui.Face = Enum.NormalId.Front
	welcomeGui.Parent = welcomeSign

	local welcomeLabel = Instance.new("TextLabel")
	welcomeLabel.Size = UDim2.fromScale(1, 1)
	welcomeLabel.BackgroundTransparency = 1
	welcomeLabel.Text = "CENTRO RECREATIVO\nJuego de memoria"
	welcomeLabel.TextScaled = true
	welcomeLabel.Font = Enum.Font.GothamBold
	welcomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	welcomeLabel.Parent = welcomeGui
end

local function prepareWorld()
	if PlazaConfig.DESTROY_BASEPLATE then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end
	end

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
end

local function clearStalePlazas()
	for _, child in Workspace:GetChildren() do
		if child.Name == "MemoryPlaza" then
			child:Destroy()
		end
	end
end

local function buildPlaza()
	clearStalePlazas()
	plazaModel = nil

	prepareWorld()

	plazaModel = Instance.new("Model")
	plazaModel.Name = "MemoryPlaza"

	local baseY = PlazaConfig.BASE_Y

	if PlazaConfig.BUILD_ENVIRONMENT then
		buildEnvironment(plazaModel, baseY)
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
	spawn.Parent = plazaModel

	for index, offset in PlazaConfig.SOLO_OFFSETS do
		createMemoryTable(
			plazaModel,
			"Table_Solo_" .. index,
			"Solo",
			PlazaConfig.getFloorPosition(offset)
		)
	end

	for index, offset in PlazaConfig.VERSUS_OFFSETS do
		createMemoryTable(
			plazaModel,
			"Table_Versus_" .. index,
			"Versus",
			PlazaConfig.getFloorPosition(offset)
		)
	end

	plazaModel.Parent = Workspace
	warn(
		"[MemoryGame] Plaza creada:",
		PlazaConfig.SOLO_COUNT,
		"solo +",
		PlazaConfig.VERSUS_COUNT,
		"versus en Y =",
		baseY
	)
end

function PlazaBuilder.init()
	buildPlaza()
end

return PlazaBuilder
