local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared.CardData)
local ProgressConfig = require(Shared.ProgressConfig)
local MemeCatalog = require(Shared.MemeCatalog)
local BoardBuilder = require(script.Parent.BoardBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)
local SkinApplier = require(script.Parent.SkinApplier)

export type GameMode = "Solo" | "Versus"
export type GameStatus = "waiting" | "playing" | "ended"

local GameInstance = {}
GameInstance.__index = GameInstance

type CardState = {
	id: number,
	matched: boolean,
}

export type GameInstance = typeof(setmetatable({} :: {
	tableModel: Model,
	tableId: string,
	mode: GameMode,
	remotes: any,
	cards: { CardState },
	cardParts: { BasePart },
	revealed: { number },
	currentTurn: Player?,
	players: { Player },
	scores: { [Player]: number },
	status: GameStatus,
	isEvaluating: boolean,
	attempts: number,
	startedAt: number,
	seatPlayers: { Player? },
	-- Racha (combo) por jugador dentro de la partida actual
	streaks: { [Player]: number },
	-- Cara visual por id de par (1..N) elegida al azar del pool de memes
	pairFaces: { [number]: MemeCatalog.PairFace },
}, GameInstance))

local function fisherYatesShuffle(values: { number }): { number }
	local shuffled = table.clone(values)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

local function unseatPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end

function GameInstance.new(tableModel: Model, mode: GameMode, remotes: any): GameInstance
	local self = setmetatable({}, GameInstance)
	self.tableModel = tableModel
	self.tableId = tableModel.Name
	self.mode = mode
	self.remotes = remotes
	self.cards = {}
	self.cardParts = {}
	self.revealed = {}
	self.currentTurn = nil
	self.players = {}
	self.scores = {}
	self.status = "waiting"
	self.isEvaluating = false
	self.attempts = 0
	self.startedAt = 0
	self.seatPlayers = {}
	self.streaks = {}
	self.pairFaces = {}
	return self
end

function GameInstance:isSolo(): boolean
	return self.mode == CardData.MODES.Solo
end

function GameInstance:getStatus(): GameStatus
	return self.status
end

function GameInstance:getPlayers(): { Player }
	return self.players
end

function GameInstance:setSeatPlayers(player1: Player?, player2: Player?)
	self.seatPlayers = { player1, player2 }
end

function GameInstance:findParticipant(player: Player): boolean
	for _, participant in self.players do
		if participant == player then
			return true
		end
	end
	return false
end

function GameInstance:fireToParticipants(remote: RemoteEvent, ...: any)
	for _, player in self.players do
		remote:FireClient(player, self.tableId, ...)
	end
end

function GameInstance:resolveUnlockedMemePacks(players: { Player }): { string }
	local seen = {}
	local packs = {}

	for _, defaultId in MemeCatalog.getDefaultUnlockedPackIds() do
		seen[defaultId] = true
		table.insert(packs, defaultId)
	end

	for _, player in players do
		for _, packId in PlayerDataService.getUnlockedMemePacks(player) do
			if not seen[packId] then
				seen[packId] = true
				table.insert(packs, packId)
			end
		end
	end

	return packs
end

function GameInstance:generateShuffledCards(): { CardState }
	local pairCount = CardData.getPairCount(self.mode)
	local unlockedPacks = self:resolveUnlockedMemePacks(self.players)
	local faces = MemeCatalog.pickRandomFaces(pairCount, unlockedPacks)

	self.pairFaces = {}
	for index, face in faces do
		self.pairFaces[index] = face
	end

	local ids: { number } = {}
	for id = 1, pairCount do
		table.insert(ids, id)
		table.insert(ids, id)
	end

	local shuffledIds = fisherYatesShuffle(ids)
	local cards: { CardState } = {}
	for _, id in shuffledIds do
		table.insert(cards, { id = id, matched = false })
	end
	return cards
end

function GameInstance:serializeScores(): { [number]: number }
	local serialized = {}
	for player, score in self.scores do
		serialized[player.UserId] = score
	end
	return serialized
end

function GameInstance:allCardsMatched(): boolean
	for _, card in self.cards do
		if not card.matched then
			return false
		end
	end
	return true
end

function GameInstance:getWinnerUserId(): number?
	if self:isSolo() then
		local solo = self.players[1]
		return if solo then solo.UserId else nil
	end

	local player1 = self.players[1]
	local player2 = self.players[2]
	if not player1 or not player2 then
		return nil
	end

	local score1 = self.scores[player1] or 0
	local score2 = self.scores[player2] or 0
	if score1 > score2 then
		return player1.UserId
	elseif score2 > score1 then
		return player2.UserId
	end
	return nil
end

function GameInstance:resetState()
	BoardBuilder.destroy(self.tableModel)
	self.cards = {}
	self.cardParts = {}
	self.revealed = {}
	self.currentTurn = nil
	self.players = {}
	self.scores = {}
	self.status = "waiting"
	self.isEvaluating = false
	self.attempts = 0
	self.startedAt = 0
	self.streaks = {}
	self.pairFaces = {}
end

function GameInstance:prepareForRestart()
	BoardBuilder.destroy(self.tableModel)
	self.cards = {}
	self.cardParts = {}
	self.revealed = {}
	self.status = "waiting"
	self.isEvaluating = false
	self.streaks = {}
	self.pairFaces = {}
end

function GameInstance:startGame(players: { Player })
	if self.status == "playing" then
		return
	end
	if #players == 0 then
		return
	end

	self.players = players
	self.cards = self:generateShuffledCards()
	self.revealed = {}
	self.scores = {}
	for _, player in players do
		self.scores[player] = 0
		self.streaks[player] = 0
	end
	self.currentTurn = players[1]
	self.isEvaluating = false
	self.attempts = 0
	self.startedAt = os.clock()

	-- Skins: en Solo el único jugador; en Versus Seat1 (quién inicia)
	local skinOwner = players[1]
	local equipped = PlayerDataService.getEquipped(skinOwner)
	SkinApplier.applyFurniture(self.tableModel, equipped)
	local cardAppearance = SkinApplier.getCardAppearance(equipped.Cards)

	self.cardParts = BoardBuilder.build(self.tableModel, self.mode, cardAppearance)
	if #self.cardParts == 0 then
		warn("[MemoryGame] No se pudieron crear cartas en", self.tableId)
		self.players = {}
		self.scores = {}
		self.streaks = {}
		self.status = "waiting"
		return
	end

	self.status = "playing"

	local rows, cols = CardData.getGridForMode(self.mode)
	local playerUserIds = {}
	for _, player in players do
		table.insert(playerUserIds, player.UserId)
	end

	local payload = {
		mode = self.mode,
		players = playerUserIds,
		currentTurnUserId = players[1].UserId,
		gridRows = rows,
		gridCols = cols,
	}

	local gameStarted = self.remotes and self.remotes.GameStarted
	if not gameStarted then
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		gameStarted = folder and folder:FindFirstChild("GameStarted")
	end

	if not gameStarted then
		warn("[MemoryGame] Remote GameStarted no existe — no se pudo avisar al cliente")
		return
	end

	for _, player in players do
		gameStarted:FireClient(player, self.tableId, payload)
		warn("[MemoryGame] GameStarted enviado a", player.Name, "mesa", self.tableId)
	end

	warn("[MemoryGame] Tablero listo en", self.tableId, #self.cardParts, "cartas")
end

function GameInstance:switchTurn()
	if self:isSolo() then
		return
	end

	local player1 = self.players[1]
	local player2 = self.players[2]
	if not player1 or not player2 then
		return
	end

	if self.currentTurn == player1 then
		self.currentTurn = player2
	else
		self.currentTurn = player1
	end

	self:fireToParticipants(self.remotes.TurnChanged, self.currentTurn.UserId)
end

function GameInstance:endGame()
	if self.status == "ended" then
		return
	end

	self.status = "ended"
	self.isEvaluating = false
	self.revealed = {}

	local elapsed = math.floor(os.clock() - self.startedAt)
	local result

	if self:isSolo() then
		result = {
			mode = self.mode,
			attempts = self.attempts,
			elapsedTime = elapsed,
			pairs = CardData.getPairCount(self.mode),
		}
	else
		result = {
			mode = self.mode,
			winnerUserId = self:getWinnerUserId(),
			scores = self:serializeScores(),
		}
	end

	self:fireToParticipants(self.remotes.GameEnded, result)
	BoardBuilder.removeBarrier(self.tableModel)
end

function GameInstance:cancelGame()
	if self.status == "waiting" then
		return
	end

	local participants = table.clone(self.players)
	self:resetState()

	for _, player in participants do
		self.remotes.GameCancelled:FireClient(player, self.tableId)
	end
end

function GameInstance:handleMatch()
	local currentPlayer = self.currentTurn
	if not currentPlayer then
		return
	end

	for _, cardIndex in self.revealed do
		self.cards[cardIndex].matched = true
		local cardPart = self.cardParts[cardIndex]
		if cardPart then
			cardPart:SetAttribute("Matched", true)
		end
	end

	self.scores[currentPlayer] = (self.scores[currentPlayer] or 0) + 1

	-- Racha + puntos persistentes
	local newStreak = (self.streaks[currentPlayer] or 0) + 1
	self.streaks[currentPlayer] = newStreak
	local pointsGained = ProgressConfig.calculateMatchPoints(newStreak)
	local totalPoints = PlayerDataService.addPoints(currentPlayer, pointsGained)

	self:fireToParticipants(
		self.remotes.MatchFound,
		self.revealed[1],
		self.revealed[2],
		currentPlayer.UserId
	)

	if self.remotes.StreakUpdated then
		self.remotes.StreakUpdated:FireClient(
			currentPlayer,
			self.tableId,
			newStreak,
			ProgressConfig.getStreakMultiplier(newStreak),
			pointsGained
		)
	end

	if self.remotes.PointsAwarded then
		self.remotes.PointsAwarded:FireClient(currentPlayer, pointsGained, totalPoints, newStreak)
	end

	self.revealed = {}
	self.isEvaluating = false

	if self:allCardsMatched() then
		self:endGame()
	end
end

function GameInstance:handleMismatch()
	local currentPlayer = self.currentTurn
	if currentPlayer then
		self.streaks[currentPlayer] = 0
		if self.remotes.StreakUpdated then
			self.remotes.StreakUpdated:FireClient(currentPlayer, self.tableId, 0, 1, 0)
		end
	end

	local revealedCopy = table.clone(self.revealed)
	self.isEvaluating = true

	self:fireToParticipants(self.remotes.MismatchFound, revealedCopy[1], revealedCopy[2])

	task.delay(CardData.MISMATCH_DELAY, function()
		if self.status ~= "playing" then
			return
		end

		for _, cardIndex in revealedCopy do
			local cardPart = self.cardParts[cardIndex]
			if cardPart then
				BoardBuilder.hideCard(cardPart)
			end
			self:fireToParticipants(self.remotes.CardHidden, cardIndex)
		end

		self.revealed = {}
		self:switchTurn()
		self.isEvaluating = false
	end)
end

function GameInstance:evaluateRevealed()
	if #self.revealed ~= 2 then
		return
	end

	self.attempts += 1
	self.isEvaluating = true

	local firstCard = self.cards[self.revealed[1]]
	local secondCard = self.cards[self.revealed[2]]

	if firstCard.id == secondCard.id then
		self:handleMatch()
	else
		self:handleMismatch()
	end
end

function GameInstance:requestFlip(player: Player, cardIndex: number)
	if self.status ~= "playing" or self.isEvaluating then
		return
	end

	if not self:findParticipant(player) then
		return
	end

	if not self:isSolo() and self.currentTurn ~= player then
		return
	end

	if typeof(cardIndex) ~= "number" then
		return
	end

	local totalCards = CardData.getTotalCards(self.mode)
	if cardIndex < 1 or cardIndex > totalCards then
		return
	end

	local card = self.cards[cardIndex]
	if not card or card.matched then
		return
	end

	for _, revealedIndex in self.revealed do
		if revealedIndex == cardIndex then
			return
		end
	end

	if #self.revealed >= 2 then
		return
	end

	table.insert(self.revealed, cardIndex)
	local cardPart = self.cardParts[cardIndex]
	if cardPart then
		BoardBuilder.revealCard(cardPart, card.id, self.pairFaces[card.id])
	end
	self:fireToParticipants(self.remotes.CardRevealed, cardIndex, card.id)

	if #self.revealed == 2 then
		self:evaluateRevealed()
	end
end

function GameInstance:requestRematch(player: Player)
	if self.status ~= "ended" then
		return
	end

	local seat1 = self.seatPlayers[1]
	local seat2 = self.seatPlayers[2]
	if player ~= seat1 and player ~= seat2 then
		return
	end

	local players: { Player } = {}
	if self:isSolo() then
		if seat1 then
			players = { seat1 }
		end
	elseif seat1 and seat2 and seat1 ~= seat2 then
		players = { seat1, seat2 }
	else
		return
	end

	if #players == 0 then
		return
	end

	self:resetState()
	self:startGame(players)
end

function GameInstance:requestQuit(player: Player)
	-- Permitir salir también si ya terminó la partida (botón Aceptar)
	if self.status ~= "playing" and self.status ~= "ended" then
		return
	end

	if self.status == "playing" and not self:findParticipant(player) then
		return
	end

	-- Si terminó, cualquiera de los que estaban sentados puede aceptar/limpiar
	if self.status == "ended" then
		local seat1 = self.seatPlayers[1]
		local seat2 = self.seatPlayers[2]
		if player ~= seat1 and player ~= seat2 and not self:findParticipant(player) then
			return
		end
	end

	unseatPlayer(player)
	self:cancelGame()
end

return GameInstance
