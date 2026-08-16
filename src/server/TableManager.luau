local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameInstance = require(script.Parent.GameInstance)

local TableManager = {}

local TAG = "MemoryTable"
local activeGames: { [string]: any } = {}
local connectedTables: { [Model]: boolean } = {}
local remotes = nil

local function getPlayerFromSeat(seat: Seat?): Player?
	if not seat then
		return nil
	end
	local occupant = seat.Occupant
	if not occupant then
		return nil
	end
	local character = occupant.Parent
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function getSeats(tableModel: Model): (Seat?, Seat?)
	local seat1 = tableModel:FindFirstChild("Seat1")
	local seat2 = tableModel:FindFirstChild("Seat2")
	local s1 = if seat1 and seat1:IsA("Seat") then seat1 else nil
	local s2 = if seat2 and seat2:IsA("Seat") then seat2 else nil
	return s1, s2
end

local function getCapacity(mode: string): number
	return if mode == "Solo" then 1 else 2
end

local function updateStatusIndicator(tableModel: Model, mode: string)
	local indicator = tableModel:FindFirstChild("StatusIndicator")
	if not indicator then
		return
	end

	local seat1, seat2 = getSeats(tableModel)
	local occupied = 0
	if getPlayerFromSeat(seat1) then
		occupied += 1
	end
	if getPlayerFromSeat(seat2) then
		occupied += 1
	end

	local capacity = getCapacity(mode)
	local label = indicator:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = string.format("%d/%d", occupied, capacity)
		if occupied >= capacity then
			label.TextColor3 = Color3.fromRGB(46, 204, 113)
		else
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end

local function buildPlayerList(mode: string, seat1: Seat?, seat2: Seat?): { Player }
	local player1 = getPlayerFromSeat(seat1)
	local player2 = getPlayerFromSeat(seat2)

	if mode == "Solo" then
		if player1 then
			return { player1 }
		end
		-- Fallback: a veces en Solo el jugador termina en Seat2 si el mapa está mal armado
		if player2 then
			return { player2 }
		end
		return {}
	end

	if player1 and player2 and player1 ~= player2 then
		return { player1, player2 }
	end
	return {}
end

local function tryStartGame(game: any)
	local tableModel = game.tableModel
	local seat1, seat2 = getSeats(tableModel)
	local players = buildPlayerList(game.mode, seat1, seat2)
	game:setSeatPlayers(getPlayerFromSeat(seat1), getPlayerFromSeat(seat2))
	updateStatusIndicator(tableModel, game.mode)

	local capacity = getCapacity(game.mode)
	if #players < capacity then
		return
	end

	local status = game:getStatus()
	if status == "playing" then
		return
	end

	if status == "ended" then
		game:prepareForRestart()
	end

	local ok, err = pcall(function()
		game:startGame(players)
	end)

	if not ok then
		warn("[MemoryGame] ERROR al iniciar partida en", game.tableId, ":", err)
		return
	end

	if game:getStatus() == "playing" then
		warn("[MemoryGame] Partida OK:", game.tableId, game.mode, "jugadores=", #players)
	else
		warn("[MemoryGame] startGame no dejó status=playing en", game.tableId)
	end
end

local function handleSeatChange(game: any)
	local tableModel = game.tableModel
	local seat1, seat2 = getSeats(tableModel)
	local player1 = getPlayerFromSeat(seat1)
	local player2 = getPlayerFromSeat(seat2)
	game:setSeatPlayers(player1, player2)
	updateStatusIndicator(tableModel, game.mode)

	local status = game:getStatus()
	if status == "playing" then
		local shouldCancel = false
		if game.mode == "Solo" then
			local solo = game:getPlayers()[1]
			if solo and player1 ~= solo and player2 ~= solo then
				shouldCancel = true
			end
		elseif not player1 or not player2 then
			shouldCancel = true
		end

		if shouldCancel then
			warn("[MemoryGame] Cancelando partida (jugador se levantó):", game.tableId)
			game:cancelGame()
		end
		return
	end

	-- Pequeño delay para que Occupant termine de resolverse en Studio multi-cliente
	task.delay(0.15, function()
		tryStartGame(game)
	end)
end

local function connectTable(tableModel: Model, game: any)
	if connectedTables[tableModel] then
		return
	end
	connectedTables[tableModel] = true

	local seat1, seat2 = getSeats(tableModel)
	if not seat1 then
		warn("[MemoryGame] Mesa sin Seat1:", tableModel.Name)
	end
	if game.mode == "Versus" and not seat2 then
		warn("[MemoryGame] Mesa Versus sin Seat2:", tableModel.Name)
	end

	local function onSeatChanged()
		handleSeatChange(game)
	end

	if seat1 then
		seat1:GetPropertyChangedSignal("Occupant"):Connect(onSeatChanged)
	end
	if seat2 then
		seat2:GetPropertyChangedSignal("Occupant"):Connect(onSeatChanged)
	end

	updateStatusIndicator(tableModel, game.mode)
	warn("[MemoryGame] Mesa conectada:", tableModel.Name, "mode=", game.mode)
end

local function registerTable(tableModel: Model)
	if activeGames[tableModel.Name] then
		return
	end

	local mode = tableModel:GetAttribute("Mode")
	if mode ~= "Solo" and mode ~= "Versus" then
		warn("[MemoryGame] Mesa sin Mode válido:", tableModel.Name, tostring(mode))
		return
	end

	local game = GameInstance.new(tableModel, mode, remotes)
	activeGames[tableModel.Name] = game
	connectTable(tableModel, game)
end

local function findGameByPlayer(player: Player): any?
	for _, game in activeGames do
		if game:findParticipant(player) then
			return game
		end
	end
	return nil
end

function TableManager.getGame(tableId: string)
	return activeGames[tableId]
end

function TableManager.init(remoteFolder)
	remotes = remoteFolder

	-- Asegurar remotes reales desde ReplicatedStorage por si el módulo no está hidratado
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder then
		for _, name in {
			"RequestFlip",
			"RequestRematch",
			"RequestQuit",
			"CardRevealed",
			"CardHidden",
			"MatchFound",
			"MismatchFound",
			"TurnChanged",
			"GameStarted",
			"GameEnded",
			"GameCancelled",
		} do
			local remote = folder:FindFirstChild(name)
			if remote then
				remotes[name] = remote
			end
		end
	end

	local function onTableAdded(instance: Instance)
		if not instance:IsA("Model") then
			return
		end
		for _, legacyName in { "Sign", "ModeTag" } do
			local legacy = instance:FindFirstChild(legacyName)
			if legacy then
				legacy:Destroy()
			end
		end
		registerTable(instance)
	end

	for _, tableModel in CollectionService:GetTagged(TAG) do
		onTableAdded(tableModel)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(onTableAdded)

	-- Backup: si el signal de Occupant falla en Studio, el poll arranca la partida igual
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 0.35 then
			return
		end
		accum = 0
		for _, game in activeGames do
			local status = game:getStatus()
			if status == "waiting" then
				local seat1, seat2 = getSeats(game.tableModel)
				local players = buildPlayerList(game.mode, seat1, seat2)
				if #players >= getCapacity(game.mode) then
					tryStartGame(game)
				else
					updateStatusIndicator(game.tableModel, game.mode)
				end
			else
				updateStatusIndicator(game.tableModel, game.mode)
			end
		end
	end)

	remotes.RequestFlip.OnServerEvent:Connect(function(player: Player, tableId: string, cardIndex: number)
		local game = activeGames[tableId]
		if game then
			game:requestFlip(player, cardIndex)
		end
	end)

	remotes.RequestRematch.OnServerEvent:Connect(function(player: Player, tableId: string)
		local game = activeGames[tableId]
		if game then
			game:requestRematch(player)
		end
	end)

	remotes.RequestQuit.OnServerEvent:Connect(function(player: Player, tableId: string?)
		local game = if tableId then activeGames[tableId] else findGameByPlayer(player)
		if game then
			game:requestQuit(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local game = findGameByPlayer(player)
		if game and game:getStatus() == "playing" then
			game:cancelGame()
		end
	end)

	local count = 0
	for _ in activeGames do
		count += 1
	end
	warn("[MemoryGame] TableManager listo. Mesas registradas:", count)
end

return TableManager
