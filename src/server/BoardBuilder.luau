local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared.CardData)

local BoardBuilder = {}

local CARD_SIZE = Vector3.new(1.15, 0.18, 1.45)
-- Tras rotación -90° en Y, el ancho visual en columnas usa Size.Z y en filas Size.X
local GAP = 0.45
local SPACING_X = CARD_SIZE.Z + GAP -- horizontal (columnas)
local SPACING_Z = CARD_SIZE.X + GAP -- profundidad (filas)
local MARGIN = 1.25
-- Altura de la pared invisible sobre la mesa (solo durante la partida)
local BARRIER_HEIGHT = 10

local function getHorizontalDirection(from: Vector3, to: Vector3): Vector3
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if delta.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return delta.Unit
end

local function resolveBoardOrigin(tableModel: Model): BasePart?
	local tableTop = tableModel:FindFirstChild("TableTop")
	local seat1 = tableModel:FindFirstChild("Seat1")
	local seat2 = tableModel:FindFirstChild("Seat2")

	local existing = tableModel:FindFirstChild("BoardOrigin")
	if existing and existing:IsA("BasePart") then
		existing:Destroy()
	end

	if not (tableTop and tableTop:IsA("BasePart")) then
		return nil
	end

	local forward: Vector3
	if seat1 and seat1:IsA("BasePart") and seat2 and seat2:IsA("BasePart") then
		forward = getHorizontalDirection(seat1.Position, seat2.Position)
	elseif seat1 and seat1:IsA("BasePart") then
		forward = getHorizontalDirection(seat1.Position, tableTop.Position)
		if forward.Magnitude < 0.05 then
			local look = seat1.CFrame.LookVector
			forward = Vector3.new(look.X, 0, look.Z)
			if forward.Magnitude < 0.05 then
				forward = Vector3.new(0, 0, -1)
			else
				forward = forward.Unit
			end
		end
	else
		forward = Vector3.new(0, 0, -1)
	end

	local right = Vector3.new(-forward.Z, 0, forward.X)
	local center = tableTop.Position + Vector3.new(0, tableTop.Size.Y / 2 + 0.08, 0)

	local origin = Instance.new("Part")
	origin.Name = "BoardOrigin"
	origin.Size = Vector3.new(1, 0.05, 1)
	origin.Anchored = true
	origin.Transparency = 1
	origin.CanCollide = false
	origin.CanQuery = false
	origin.CFrame = CFrame.fromMatrix(center, right, Vector3.yAxis, -forward)
	origin.Parent = tableModel
	return origin
end

local function getBoardFolder(tableModel: Model): Model
	local existing = tableModel:FindFirstChild("Board")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Model")
	folder.Name = "Board"
	folder.Parent = tableModel
	return folder
end

local function storeRestCFrame(card: BasePart, rest: CFrame)
	local value = card:FindFirstChild("RestCFrame")
	if not (value and value:IsA("CFrameValue")) then
		value = Instance.new("CFrameValue")
		value.Name = "RestCFrame"
		value.Parent = card
	end
	(value :: CFrameValue).Value = rest
	card.CFrame = rest
end

local function getCardCFrame(boardOrigin: BasePart, row: number, col: number, rows: number, cols: number): CFrame
	local totalWidth = (cols - 1) * SPACING_X
	local totalDepth = (rows - 1) * SPACING_Z
	local offsetX = (col - 1) * SPACING_X - totalWidth / 2
	local offsetZ = (row - 1) * SPACING_Z - totalDepth / 2

	local lift = CARD_SIZE.Y / 2 + 0.02
	local position = boardOrigin.Position
		+ boardOrigin.CFrame.RightVector * offsetX
		+ boardOrigin.CFrame.LookVector * offsetZ
		+ Vector3.new(0, lift, 0)

	-- Plana sobre la mesa; SurfaceGui en Top queda pegado a la ficha
	local base = CFrame.fromMatrix(
		position,
		boardOrigin.CFrame.RightVector,
		Vector3.yAxis,
		-boardOrigin.CFrame.LookVector
	)
	-- Ajuste para que el texto de SurfaceGui se lea desde Seat1
	return base * CFrame.Angles(0, math.rad(-90), 0)
end

local function createSymbolSurface(name: string, enabled: boolean, text: string): SurfaceGui
	local surface = Instance.new("SurfaceGui")
	surface.Name = name
	surface.Face = Enum.NormalId.Top
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.LightInfluence = 0.2
	surface.MaxDistance = 40
	surface.Enabled = enabled

	local label = Instance.new("TextLabel")
	label.Name = if name == "FrontGui" then "Symbol" else "BackLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = surface

	return surface
end

local function destroyBoardBarrier(tableModel: Model)
	local existing = tableModel:FindFirstChild("BoardBarrier")
	if existing then
		existing:Destroy()
	end
end

local function ensureBoardBarrier(tableModel: Model)
	destroyBoardBarrier(tableModel)

	local tableTop = tableModel:FindFirstChild("TableTop")
	if not (tableTop and tableTop:IsA("BasePart")) then
		return
	end

	-- Caja invisible sobre la mesa: evita que caminen sobre el tablero.
	-- Altura editable arriba: BARRIER_HEIGHT
	local halfHeight = BARRIER_HEIGHT / 2
	local barrier = Instance.new("Part")
	barrier.Name = "BoardBarrier"
	barrier.Size = Vector3.new(tableTop.Size.X + 0.5, BARRIER_HEIGHT, tableTop.Size.Z + 0.5)
	barrier.CFrame = tableTop.CFrame * CFrame.new(0, tableTop.Size.Y / 2 + halfHeight, 0)
	barrier.Anchored = true
	barrier.CanCollide = true
	barrier.CanQuery = false
	barrier.CanTouch = false
	barrier.Transparency = 1
	barrier.CastShadow = false
	barrier.Parent = tableModel
end

function BoardBuilder.getRequiredTableSize(mode: string): Vector3
	local rows, cols = CardData.getGridForMode(mode)
	local width = (cols - 1) * SPACING_X + CARD_SIZE.X + MARGIN * 2
	local depth = (rows - 1) * SPACING_Z + CARD_SIZE.Z + MARGIN * 2
	return Vector3.new(math.max(width, 10), 0.5, math.max(depth, 12))
end

function BoardBuilder.build(tableModel: Model, mode: string): { BasePart }
	local boardOrigin = resolveBoardOrigin(tableModel)
	if not boardOrigin then
		warn("[MemoryGame] BoardOrigin no encontrado en", tableModel.Name)
		return {}
	end

	local rows, cols = CardData.getGridForMode(mode)
	local boardFolder = getBoardFolder(tableModel)
	local cardParts: { BasePart } = {}

	ensureBoardBarrier(tableModel)

	local index = 0
	for row = 1, rows do
		for col = 1, cols do
			index += 1

			local card = Instance.new("Part")
			card.Name = "Card_" .. index
			card.Size = CARD_SIZE
			card.Anchored = true
			card.CanCollide = false
			card.CanQuery = true
			card.Color = CardData.CARD_BACK_COLOR
			card.Material = Enum.Material.SmoothPlastic
			card.TopSurface = Enum.SurfaceType.Smooth
			card.BottomSurface = Enum.SurfaceType.Smooth
			card:SetAttribute("CardIndex", index)
			card:SetAttribute("Revealed", false)
			card:SetAttribute("Matched", false)
			card.Parent = boardFolder

			local rest = getCardCFrame(boardOrigin, row, col, rows, cols)
			storeRestCFrame(card, rest)

			-- Símbolos pegados a la cara superior (no flotan ni se ven a lo lejos como Billboard)
			local frontGui = createSymbolSurface("FrontGui", false, "")
			frontGui.Parent = card

			local backGui = createSymbolSurface("BackGui", true, "?")
			backGui.Parent = card

			table.insert(cardParts, card)
		end
	end

	warn("[MemoryGame] BoardBuilder creó", #cardParts, "cartas en", tableModel.Name)
	return cardParts
end

function BoardBuilder.destroy(tableModel: Model)
	local board = tableModel:FindFirstChild("Board")
	if board then
		board:Destroy()
	end
	destroyBoardBarrier(tableModel)
end

function BoardBuilder.removeBarrier(tableModel: Model)
	destroyBoardBarrier(tableModel)
end

function BoardBuilder.revealCard(cardPart: BasePart, iconId: number)
	local pair = CardData.getPairById(iconId)
	cardPart.Color = pair.color
	cardPart:SetAttribute("Revealed", true)

	local frontGui = cardPart:FindFirstChild("FrontGui")
	if frontGui and frontGui:IsA("SurfaceGui") then
		frontGui.Enabled = true
		local symbol = frontGui:FindFirstChild("Symbol")
		if symbol and symbol:IsA("TextLabel") then
			symbol.Text = pair.symbol
		end
	end

	local backGui = cardPart:FindFirstChild("BackGui")
	if backGui and backGui:IsA("SurfaceGui") then
		backGui.Enabled = false
	end
end

function BoardBuilder.hideCard(cardPart: BasePart)
	cardPart.Color = CardData.CARD_BACK_COLOR
	cardPart:SetAttribute("Revealed", false)

	local frontGui = cardPart:FindFirstChild("FrontGui")
	if frontGui and frontGui:IsA("SurfaceGui") then
		frontGui.Enabled = false
	end

	local backGui = cardPart:FindFirstChild("BackGui")
	if backGui and backGui:IsA("SurfaceGui") then
		backGui.Enabled = true
	end

	local rest = cardPart:FindFirstChild("RestCFrame")
	if rest and rest:IsA("CFrameValue") then
		cardPart.CFrame = rest.Value
	end
end

return BoardBuilder
