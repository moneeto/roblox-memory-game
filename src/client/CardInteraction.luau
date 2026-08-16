local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared.CardData)
local Remotes = require(Shared.Remotes)

local CardAnimations3D = require(script.Parent.CardAnimations3D)
local SoundManager = require(script.Parent.SoundManager)
local TableHud = require(script.Parent.TableHud)
local TableCamera = require(script.Parent.TableCamera)
local TableUtils = require(script.Parent.TableUtils)
local JumpLock = require(script.Parent.JumpLock)
local FlipArmGesture = require(script.Parent.FlipArmGesture)

local CardInteraction = {}

local localPlayer = Players.LocalPlayer

local activeTableId: string? = nil
local isParticipant = false
local gameMode: string? = nil
local currentTurnUserId: number? = nil
local clickConnections: { RBXScriptConnection } = {}

local function clearClickConnections()
	for _, connection in clickConnections do
		connection:Disconnect()
	end
	table.clear(clickConnections)
end

local function getTableModel(tableId: string): Model?
	return TableUtils.getTableModel(tableId)
end

-- Radio en pantalla de la ficha (misma proyección que el cursor: WorldToViewportPoint).
local function getCardScreenRadius(camera: Camera, card: BasePart): (Vector2, number, boolean)
	local center3, onScreen = camera:WorldToViewportPoint(card.Position)
	local center = Vector2.new(center3.X, center3.Y)
	if center3.Z < 0 then
		return center, 0, false
	end

	local size = card.Size
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local radius = 0
	for _, localOffset in {
		Vector3.new(hx, hy, hz),
		Vector3.new(-hx, hy, hz),
		Vector3.new(hx, hy, -hz),
		Vector3.new(-hx, hy, -hz),
		Vector3.new(hx, -hy, hz),
		Vector3.new(-hx, -hy, -hz),
	} do
		local corner3 = camera:WorldToViewportPoint(card.CFrame:PointToWorldSpace(localOffset))
		local dx = corner3.X - center.X
		local dy = corner3.Y - center.Y
		radius = math.max(radius, math.sqrt(dx * dx + dy * dy))
	end

	return center, radius, onScreen or center3.Z > 0
end

local function findCardAtScreenPoint(board: Instance, camera: Camera, clickX: number, clickY: number): BasePart?
	local bestCard: BasePart? = nil
	local bestDist = math.huge

	for _, child in board:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		if child:GetAttribute("Matched") == true then
			continue
		end

		local center, radius, usable = getCardScreenRadius(camera, child)
		if not usable or radius < 4 then
			continue
		end

		local dx = clickX - center.X
		local dy = clickY - center.Y
		local dist = math.sqrt(dx * dx + dy * dy)
		-- Ligero margen para tap/click en el borde visual
		if dist <= radius * 1.08 and dist < bestDist then
			bestDist = dist
			bestCard = child
		end
	end

	return bestCard
end

local function tryFlipCardAtScreenPoint(tableId: string, clickX: number, clickY: number)
	if not isParticipant or activeTableId ~= tableId then
		return
	end
	if gameMode == CardData.MODES.Versus and currentTurnUserId ~= localPlayer.UserId then
		return
	end

	local tableModel = getTableModel(tableId)
	if not tableModel then
		return
	end
	local board = tableModel:FindFirstChild("Board")
	if not board then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local card = findCardAtScreenPoint(board, camera, clickX, clickY)
	if not card then
		return
	end

	local cardIndex = card:GetAttribute("CardIndex")
	if typeof(cardIndex) ~= "number" then
		return
	end

	FlipArmGesture.playLocal()
	Remotes.RequestFlip:FireServer(tableId, cardIndex)
end

local function bindCardClicks(tableId: string)
	clearClickConnections()

	local tableModel = getTableModel(tableId)
	if not tableModel then
		return
	end
	local board = tableModel:FindFirstChild("Board")
	if not board then
		return
	end

	for _, card in board:GetChildren() do
		if card:IsA("BasePart") then
			card.CanQuery = true
			local oldDetector = card:FindFirstChildOfClass("ClickDetector")
			if oldDetector then
				oldDetector:Destroy()
			end
		end
	end

	local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if activeTableId ~= tableId then
			return
		end

		-- GetMouseLocation comparte espacio con WorldToViewportPoint (sin GuiInset).
		-- En touch usamos input.Position (mismo espacio de viewport).
		local clickPos = if input.UserInputType == Enum.UserInputType.Touch
			then Vector2.new(input.Position.X, input.Position.Y)
			else UserInputService:GetMouseLocation()

		tryFlipCardAtScreenPoint(tableId, clickPos.X, clickPos.Y)
	end)

	table.insert(clickConnections, connection)
end

local function leaveGame()
	isParticipant = false
	activeTableId = nil
	gameMode = nil
	clearClickConnections()
	JumpLock.unlock()
	TableCamera.restore()
	TableHud.hide()
end

local function onGameStarted(tableId: string, payload: {
	mode: string,
	players: { number },
	currentTurnUserId: number,
	gridRows: number,
	gridCols: number,
})
	local inGame = false
	if typeof(payload) ~= "table" or typeof(payload.players) ~= "table" then
		warn("[MemoryGame] GameStarted con payload inválido")
		return
	end

	for _, userId in payload.players do
		local id = if typeof(userId) == "number" then userId else tonumber(userId)
		if id == localPlayer.UserId then
			inGame = true
			break
		end
	end

	if not inGame then
		warn("[MemoryGame] GameStarted ignorado (no soy participante) mesa=", tableId)
		return
	end

	warn("[MemoryGame] Cliente: partida iniciada en", tableId, "modo", payload.mode)

	isParticipant = true
	activeTableId = tableId
	gameMode = payload.mode
	currentTurnUserId = payload.currentTurnUserId

	JumpLock.lock()

	TableHud.show(tableId, payload.mode)
	TableHud.setStatus("Mezclando cartas...")

	task.spawn(function()
		local tableModel = TableUtils.waitForTableModel(tableId, 8)
		if not tableModel or activeTableId ~= tableId then
			return
		end

		local board = tableModel:WaitForChild("Board", 8)
		if board and activeTableId == tableId then
			CardAnimations3D.resetAllCards(tableId)
			CardAnimations3D.orientBoardForLocalPlayer(tableId)
			TableCamera.focusOnTable(tableId)
			bindCardClicks(tableId)
		end
	end)

	task.delay(CardData.SHUFFLE_DURATION, function()
		if activeTableId ~= tableId then
			return
		end
		CardAnimations3D.resetAllCards(tableId)
		CardAnimations3D.orientBoardForLocalPlayer(tableId)
		if gameMode == CardData.MODES.Solo then
			TableHud.setStatus("Modo solitario")
		elseif currentTurnUserId == localPlayer.UserId then
			TableHud.setStatus("Tu turno")
		else
			TableHud.setStatus("Turno del rival")
		end
	end)
end

function CardInteraction.init()
	Remotes.init()

	TableHud.init(function()
		if activeTableId then
			Remotes.RequestQuit:FireServer(activeTableId)
		else
			leaveGame()
		end
	end, function()
		if activeTableId then
			Remotes.RequestQuit:FireServer(activeTableId)
		end
		leaveGame()
	end)

	Remotes.GameStarted.OnClientEvent:Connect(onGameStarted)

	Remotes.CardRevealed.OnClientEvent:Connect(function(tableId, cardIndex, _iconId)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		-- El rival ve el gesto del brazo; el local ya lo reprodujo al clickear.
		if currentTurnUserId and currentTurnUserId ~= localPlayer.UserId then
			FlipArmGesture.playForPlayer(Players:GetPlayerByUserId(currentTurnUserId))
		end
		local tableModel = TableUtils.getTableModel(tableId)
		local card = nil
		if tableModel then
			local board = tableModel:FindFirstChild("Board")
			if board then
				card = board:FindFirstChild("Card_" .. tostring(cardIndex))
			end
		end
		SoundManager.playFlip(card)
		task.spawn(function()
			CardAnimations3D.playFlip(tableId, cardIndex)
		end)
	end)

	Remotes.CardHidden.OnClientEvent:Connect(function(tableId, cardIndex)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		local tableModel = TableUtils.getTableModel(tableId)
		local card = nil
		if tableModel then
			local board = tableModel:FindFirstChild("Board")
			if board then
				card = board:FindFirstChild("Card_" .. tostring(cardIndex))
			end
		end
		SoundManager.playFlip(card)
		task.spawn(function()
			CardAnimations3D.playFlip(tableId, cardIndex)
		end)
	end)

	Remotes.MatchFound.OnClientEvent:Connect(function(tableId, cardIndex1, cardIndex2, _scorerUserId)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		local tableModel = TableUtils.getTableModel(tableId)
		local at = if tableModel then TableUtils.getFocusPart(tableModel) else nil
		SoundManager.playMatch(at)
		task.spawn(function()
			CardAnimations3D.playMatch(tableId, cardIndex1, cardIndex2)
		end)
	end)

	Remotes.MismatchFound.OnClientEvent:Connect(function(tableId, cardIndex1, cardIndex2)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		local tableModel = TableUtils.getTableModel(tableId)
		local at = if tableModel then TableUtils.getFocusPart(tableModel) else nil
		SoundManager.playMismatch(at)
		task.spawn(function()
			CardAnimations3D.playMismatch(tableId, cardIndex1, cardIndex2)
			CardAnimations3D.resetAllCards(tableId)
			if gameMode == CardData.MODES.Solo then
				TableHud.setStatus("Modo solitario")
			elseif currentTurnUserId == localPlayer.UserId then
				TableHud.setStatus("Tu turno")
			else
				TableHud.setStatus("Turno del rival")
			end
		end)
	end)

	Remotes.TurnChanged.OnClientEvent:Connect(function(tableId, turnUserId)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		currentTurnUserId = turnUserId
		CardAnimations3D.resetAllCards(tableId)
		if turnUserId == localPlayer.UserId then
			TableHud.setStatus("Tu turno")
		else
			TableHud.setStatus("Turno del rival")
		end
	end)

	Remotes.GameEnded.OnClientEvent:Connect(function(tableId, result)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		local tableModel = TableUtils.getTableModel(tableId)
		local at = if tableModel then TableUtils.getFocusPart(tableModel) else nil
		SoundManager.playWin(at)

		JumpLock.unlock()
		TableCamera.restore()
		TableHud.showResults(result)
	end)

	Remotes.GameCancelled.OnClientEvent:Connect(function(tableId)
		if activeTableId ~= tableId and not isParticipant then
			return
		end
		leaveGame()
	end)
end

return CardInteraction
