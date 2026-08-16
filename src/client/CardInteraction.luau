local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared.CardData)
local Remotes = require(Shared.Remotes)

local CardAnimations3D = require(script.Parent.CardAnimations3D)
local SoundManager = require(script.Parent.SoundManager)
local TableHud = require(script.Parent.TableHud)
local TableCamera = require(script.Parent.TableCamera)
local TableUtils = require(script.Parent.TableUtils)

local CardInteraction = {}

local localPlayer = Players.LocalPlayer

local activeTableId: string? = nil
local isParticipant = false
local gameMode: string? = nil
local currentTurnUserId: number? = nil
local isAnimating = false
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
		if not card:IsA("BasePart") then
			continue
		end

		local cardIndex = card:GetAttribute("CardIndex")
		if typeof(cardIndex) ~= "number" then
			continue
		end

		local clickDetector = card:FindFirstChildOfClass("ClickDetector")
		if not clickDetector then
			continue
		end

		local connection = clickDetector.MouseClick:Connect(function(player)
			if player ~= localPlayer then
				return
			end
			if not isParticipant or isAnimating or activeTableId ~= tableId then
				return
			end
			if gameMode == CardData.MODES.Versus and currentTurnUserId ~= localPlayer.UserId then
				return
			end
			if card:GetAttribute("Matched") or card:GetAttribute("Revealed") then
				return
			end

			Remotes.RequestFlip:FireServer(tableId, cardIndex)
		end)

		table.insert(clickConnections, connection)
	end
end

local function leaveGame()
	isParticipant = false
	activeTableId = nil
	gameMode = nil
	isAnimating = false
	clearClickConnections()
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

	TableHud.show(tableId, payload.mode)
	TableHud.setStatus("Mezclando cartas...")

	task.spawn(function()
		local tableModel = TableUtils.waitForTableModel(tableId, 8)
		if not tableModel or activeTableId ~= tableId then
			return
		end

		local board = tableModel:WaitForChild("Board", 8)
		if board and activeTableId == tableId then
			CardAnimations3D.orientBoardForLocalPlayer(tableId)
			TableCamera.focusOnTable(tableId)
			bindCardClicks(tableId)
		end
	end)

	task.delay(CardData.SHUFFLE_DURATION, function()
		if activeTableId ~= tableId then
			return
		end
		isAnimating = false
		if gameMode == CardData.MODES.Solo then
			TableHud.setStatus("Modo solitario")
		elseif currentTurnUserId == localPlayer.UserId then
			TableHud.setStatus("Tu turno")
		else
			TableHud.setStatus("Turno del rival")
		end
	end)

	isAnimating = true
end

function CardInteraction.init()
	Remotes.init()

	TableHud.init(function()
		if activeTableId then
			Remotes.RequestQuit:FireServer(activeTableId)
		end
	end, function()
		if activeTableId then
			Remotes.RequestRematch:FireServer(activeTableId)
		end
	end)

	Remotes.GameStarted.OnClientEvent:Connect(onGameStarted)

	Remotes.CardRevealed.OnClientEvent:Connect(function(tableId, cardIndex, _iconId)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		local card = nil
		local tableModel = TableUtils.getTableModel(tableId)
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
		isAnimating = true
		local tableModel = TableUtils.getTableModel(tableId)
		local at = if tableModel then TableUtils.getFocusPart(tableModel) else nil
		SoundManager.playMismatch(at)
		task.spawn(function()
			CardAnimations3D.playMismatch(tableId, cardIndex1, cardIndex2)
			isAnimating = false
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
		TableHud.showResults(result)
	end)

	Remotes.GameCancelled.OnClientEvent:Connect(function(tableId)
		if not isParticipant or activeTableId ~= tableId then
			return
		end
		leaveGame()
	end)
end

return CardInteraction
