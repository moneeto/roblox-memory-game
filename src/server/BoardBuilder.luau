local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared.CardData)

local BoardBuilder = {}

-- Fichas planas que caben en la mesa ampliada
local CARD_SIZE = Vector3.new(1.15, 0.18, 1.45)
local SPACING_X = 1.35
local SPACING_Z = 1.65
local MARGIN = 1.25

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

	-- Eje del tablero: desde Seat1 hacia Seat2 (o LookVector del Seat1 en Solo)
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
	-- Columnas izquierda→derecha desde Seat1; filas hacia el rival
	local offsetX = (col - 1) * SPACING_X - totalWidth / 2
	local offsetZ = (row - 1) * SPACING_Z - totalDepth / 2

	local lift = CARD_SIZE.Y / 2 + 0.02
	local position = boardOrigin.Position
		+ boardOrigin.CFrame.RightVector * offsetX
		+ boardOrigin.CFrame.LookVector * offsetZ
		+ Vector3.new(0, lift, 0)

	-- Rotación: Top arriba; eje del texto alineado al eje Seat1→Seat2 (no de costado)
	local base = CFrame.fromMatrix(
		position,
		boardOrigin.CFrame.RightVector,
		Vector3.yAxis,
		-boardOrigin.CFrame.LookVector
	)
	-- SurfaceGui en Top: el "arriba" del texto sigue el eje local -Z; giramos 90° para leer de frente
	return base * CFrame.Angles(0, math.rad(-90), 0)
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

	local index = 0
	for row = 1, rows do
		for col = 1, cols do
			index += 1

			local card = Instance.new("Part")
			card.Name = "Card_" .. index
			card.Size = CARD_SIZE
			card.Anchored = true
			card.CanCollide = false
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

			local clickDetector = Instance.new("ClickDetector")
			clickDetector.MaxActivationDistance = 64
			clickDetector.Parent = card

			local frontGui = Instance.new("SurfaceGui")
			frontGui.Name = "FrontGui"
			frontGui.Face = Enum.NormalId.Top
			frontGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			frontGui.PixelsPerStud = 50
			frontGui.Enabled = false
			frontGui.Parent = card

			local symbol = Instance.new("TextLabel")
			symbol.Name = "Symbol"
			symbol.Size = UDim2.fromScale(1, 1)
			symbol.BackgroundTransparency = 1
			symbol.TextScaled = true
			symbol.Font = Enum.Font.GothamBold
			symbol.TextColor3 = Color3.fromRGB(255, 255, 255)
			symbol.Parent = frontGui

			local backGui = Instance.new("SurfaceGui")
			backGui.Name = "BackGui"
			backGui.Face = Enum.NormalId.Top
			backGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			backGui.PixelsPerStud = 50
			backGui.Parent = card

			local backLabel = Instance.new("TextLabel")
			backLabel.Size = UDim2.fromScale(1, 1)
			backLabel.BackgroundTransparency = 1
			backLabel.Text = "?"
			backLabel.TextScaled = true
			backLabel.Font = Enum.Font.GothamBold
			backLabel.TextColor3 = Color3.fromRGB(236, 240, 241)
			backLabel.Parent = backGui

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
end

function BoardBuilder.revealCard(cardPart: BasePart, iconId: number)
	local pair = CardData.getPairById(iconId)
	cardPart.Color = pair.color
	cardPart:SetAttribute("Revealed", true)

	local frontGui = cardPart:FindFirstChild("FrontGui") :: SurfaceGui?
	if frontGui then
		frontGui.Enabled = true
		local symbol = frontGui:FindFirstChild("Symbol") :: TextLabel?
		if symbol then
			symbol.Text = pair.symbol
		end
	end

	local backGui = cardPart:FindFirstChild("BackGui") :: SurfaceGui?
	if backGui then
		backGui.Enabled = false
	end
end

function BoardBuilder.hideCard(cardPart: BasePart)
	cardPart.Color = CardData.CARD_BACK_COLOR
	cardPart:SetAttribute("Revealed", false)

	local frontGui = cardPart:FindFirstChild("FrontGui") :: SurfaceGui?
	if frontGui then
		frontGui.Enabled = false
	end

	local backGui = cardPart:FindFirstChild("BackGui") :: SurfaceGui?
	if backGui then
		backGui.Enabled = true
	end

	local rest = cardPart:FindFirstChild("RestCFrame")
	if rest and rest:IsA("CFrameValue") then
		cardPart.CFrame = rest.Value
	end
end

return BoardBuilder
