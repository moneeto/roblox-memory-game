local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinCatalog = require(Shared.SkinCatalog)
local MemeCatalog = require(Shared.MemeCatalog)

export type PlayerProfile = {
	points: number,
	unlockedSkins: { string },
	unlockedMemePacks: { string },
	equipped: {
		Cards: string,
		Seats: string,
		Tables: string,
	},
}

local PlayerDataService = {}

local DATASTORE_NAME = "MemoryPlayerData_v1"
local KEY_PREFIX = "player_"

local store = if RunService:IsServer() then DataStoreService:GetDataStore(DATASTORE_NAME) else nil

local cache: { [number]: PlayerProfile } = {}
local saving: { [number]: boolean } = {}
local remotes: any = nil

local function deepCopyList(list: { string }): { string }
	local copy = {}
	for _, value in list do
		table.insert(copy, value)
	end
	return copy
end

local function createDefaultProfile(): PlayerProfile
	return {
		points = 0,
		unlockedSkins = SkinCatalog.getDefaultUnlockedIds(),
		unlockedMemePacks = MemeCatalog.getDefaultUnlockedPackIds(),
		equipped = {
			Cards = SkinCatalog.DEFAULT_EQUIPPED.Cards,
			Seats = SkinCatalog.DEFAULT_EQUIPPED.Seats,
			Tables = SkinCatalog.DEFAULT_EQUIPPED.Tables,
		},
	}
end

local function sanitizeProfile(raw: any): PlayerProfile
	local profile = createDefaultProfile()
	if typeof(raw) ~= "table" then
		return profile
	end

	if typeof(raw.points) == "number" then
		profile.points = math.max(0, math.floor(raw.points))
	end

	if typeof(raw.unlockedSkins) == "table" then
		local unlocked = {}
		local seen = {}
		for _, id in raw.unlockedSkins do
			if typeof(id) == "string" and SkinCatalog.getById(id) and not seen[id] then
				seen[id] = true
				table.insert(unlocked, id)
			end
		end
		-- Garantizar skins por defecto
		for _, defaultId in SkinCatalog.getDefaultUnlockedIds() do
			if not seen[defaultId] then
				table.insert(unlocked, defaultId)
			end
		end
		profile.unlockedSkins = unlocked
	end

	if typeof(raw.unlockedMemePacks) == "table" then
		local packs = {}
		local seenPacks = {}
		for _, id in raw.unlockedMemePacks do
			if typeof(id) == "string" and MemeCatalog.getPack(id) and not seenPacks[id] then
				seenPacks[id] = true
				table.insert(packs, id)
			end
		end
		for _, defaultId in MemeCatalog.getDefaultUnlockedPackIds() do
			if not seenPacks[defaultId] then
				table.insert(packs, defaultId)
			end
		end
		profile.unlockedMemePacks = packs
	end

	local function resolveEquipped(category: string, fallback: string): string
		local equippedTable = raw.equipped
		local id = if typeof(equippedTable) == "table" then equippedTable[category] else nil
		if typeof(id) ~= "string" then
			return fallback
		end
		local skin = SkinCatalog.getById(id)
		if not skin or skin.category ~= category then
			return fallback
		end
		-- Debe estar desbloqueada
		for _, unlockedId in profile.unlockedSkins do
			if unlockedId == id then
				return id
			end
		end
		return fallback
	end

	profile.equipped = {
		Cards = resolveEquipped("Cards", SkinCatalog.DEFAULT_EQUIPPED.Cards),
		Seats = resolveEquipped("Seats", SkinCatalog.DEFAULT_EQUIPPED.Seats),
		Tables = resolveEquipped("Tables", SkinCatalog.DEFAULT_EQUIPPED.Tables),
	}

	return profile
end

local function cloneProfile(profile: PlayerProfile): PlayerProfile
	return {
		points = profile.points,
		unlockedSkins = deepCopyList(profile.unlockedSkins),
		unlockedMemePacks = deepCopyList(profile.unlockedMemePacks),
		equipped = {
			Cards = profile.equipped.Cards,
			Seats = profile.equipped.Seats,
			Tables = profile.equipped.Tables,
		},
	}
end

local function ensureLeaderstats(player: Player, points: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local pointsValue = leaderstats:FindFirstChild("Puntos")
	if not pointsValue then
		pointsValue = Instance.new("IntValue")
		pointsValue.Name = "Puntos"
		pointsValue.Parent = leaderstats
	end
	if pointsValue:IsA("IntValue") then
		pointsValue.Value = points
	end
end

local function syncClient(player: Player, profile: PlayerProfile)
	if remotes and remotes.PlayerDataUpdated then
		remotes.PlayerDataUpdated:FireClient(player, cloneProfile(profile))
	end
end

local function getKey(userId: number): string
	return KEY_PREFIX .. tostring(userId)
end

local function loadFromStore(userId: number): PlayerProfile
	if not store then
		return createDefaultProfile()
	end

	local success, result = pcall(function()
		return store:GetAsync(getKey(userId))
	end)

	if success then
		return sanitizeProfile(result)
	end

	warn("[PlayerData] GetAsync falló para", userId, result)
	return createDefaultProfile()
end

local function saveToStore(userId: number, profile: PlayerProfile): boolean
	if not store then
		return true
	end
	if saving[userId] then
		return false
	end

	saving[userId] = true
	local payload = cloneProfile(profile)
	local success, err = pcall(function()
		store:UpdateAsync(getKey(userId), function(_old)
			return payload
		end)
	end)
	saving[userId] = false

	if not success then
		warn("[PlayerData] UpdateAsync falló para", userId, err)
	end
	return success
end

function PlayerDataService.getProfile(player: Player): PlayerProfile?
	return cache[player.UserId]
end

function PlayerDataService.getPoints(player: Player): number
	local profile = cache[player.UserId]
	return if profile then profile.points else 0
end

function PlayerDataService.addPoints(player: Player, amount: number): number
	local profile = cache[player.UserId]
	if not profile or amount <= 0 then
		return PlayerDataService.getPoints(player)
	end

	profile.points += math.floor(amount)
	ensureLeaderstats(player, profile.points)
	syncClient(player, profile)
	return profile.points
end

function PlayerDataService.hasSkin(player: Player, skinId: string): boolean
	local profile = cache[player.UserId]
	if not profile then
		return false
	end
	for _, id in profile.unlockedSkins do
		if id == skinId then
			return true
		end
	end
	return false
end

function PlayerDataService.getEquipped(player: Player): { Cards: string, Seats: string, Tables: string }
	local profile = cache[player.UserId]
	if not profile then
		return table.clone(SkinCatalog.DEFAULT_EQUIPPED)
	end
	return {
		Cards = profile.equipped.Cards,
		Seats = profile.equipped.Seats,
		Tables = profile.equipped.Tables,
	}
end

function PlayerDataService.getUnlockedMemePacks(player: Player): { string }
	local profile = cache[player.UserId]
	if not profile then
		return MemeCatalog.getDefaultUnlockedPackIds()
	end
	return deepCopyList(profile.unlockedMemePacks)
end

function PlayerDataService.hasMemePack(player: Player, packId: string): boolean
	local profile = cache[player.UserId]
	if not profile then
		return false
	end
	for _, id in profile.unlockedMemePacks do
		if id == packId then
			return true
		end
	end
	return false
end

function PlayerDataService.purchaseMemePack(player: Player, packId: string): (boolean, string)
	local profile = cache[player.UserId]
	if not profile then
		return false, "Datos no cargados"
	end

	local pack = MemeCatalog.getPack(packId)
	if not pack then
		return false, "Pack inválido"
	end

	if PlayerDataService.hasMemePack(player, packId) then
		return false, "Ya desbloqueado"
	end

	if profile.points < pack.price then
		return false, "Puntos insuficientes"
	end

	profile.points -= pack.price
	table.insert(profile.unlockedMemePacks, packId)
	ensureLeaderstats(player, profile.points)
	syncClient(player, profile)
	task.spawn(saveToStore, player.UserId, profile)

	return true, "Pack VIP desbloqueado"
end

--[[
	Compra una skin. Devuelve ok, mensaje.
]]
function PlayerDataService.purchaseSkin(player: Player, skinId: string): (boolean, string)
	local profile = cache[player.UserId]
	if not profile then
		return false, "Datos no cargados"
	end

	local skin = SkinCatalog.getById(skinId)
	if not skin then
		return false, "Skin inválida"
	end

	if PlayerDataService.hasSkin(player, skinId) then
		return false, "Ya desbloqueada"
	end

	if profile.points < skin.price then
		return false, "Puntos insuficientes"
	end

	profile.points -= skin.price
	table.insert(profile.unlockedSkins, skinId)
	ensureLeaderstats(player, profile.points)
	syncClient(player, profile)
	task.spawn(saveToStore, player.UserId, profile)

	return true, "Comprada"
end

--[[
	Equipa una skin ya desbloqueada.
]]
function PlayerDataService.equipSkin(player: Player, skinId: string): (boolean, string)
	local profile = cache[player.UserId]
	if not profile then
		return false, "Datos no cargados"
	end

	local skin = SkinCatalog.getById(skinId)
	if not skin then
		return false, "Skin inválida"
	end

	if not PlayerDataService.hasSkin(player, skinId) then
		return false, "Skin no desbloqueada"
	end

	profile.equipped[skin.category] = skinId
	syncClient(player, profile)
	task.spawn(saveToStore, player.UserId, profile)

	return true, "Equipada"
end

local function onPlayerAdded(player: Player)
	local profile = loadFromStore(player.UserId)
	cache[player.UserId] = profile
	ensureLeaderstats(player, profile.points)
	syncClient(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = cache[player.UserId]
	if profile then
		saveToStore(player.UserId, profile)
		cache[player.UserId] = nil
	end
end

function PlayerDataService.init(remoteFolder: any)
	remotes = remoteFolder

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	if remotes.RequestPurchaseSkin then
		remotes.RequestPurchaseSkin.OnServerEvent:Connect(function(player: Player, skinId: any)
			if typeof(skinId) ~= "string" then
				return
			end
			local ok, message = PlayerDataService.purchaseSkin(player, skinId)
			if remotes.ShopResult then
				remotes.ShopResult:FireClient(player, "purchase", ok, skinId, message)
			end
		end)
	end

	if remotes.RequestEquipSkin then
		remotes.RequestEquipSkin.OnServerEvent:Connect(function(player: Player, skinId: any)
			if typeof(skinId) ~= "string" then
				return
			end
			local ok, message = PlayerDataService.equipSkin(player, skinId)
			if remotes.ShopResult then
				remotes.ShopResult:FireClient(player, "equip", ok, skinId, message)
			end
		end)
	end

	if remotes.RequestPurchaseMemePack then
		remotes.RequestPurchaseMemePack.OnServerEvent:Connect(function(player: Player, packId: any)
			if typeof(packId) ~= "string" then
				return
			end
			local ok, message = PlayerDataService.purchaseMemePack(player, packId)
			if remotes.ShopResult then
				remotes.ShopResult:FireClient(player, "purchase_meme_pack", ok, packId, message)
			end
		end)
	end

	if remotes.RequestPlayerData then
		remotes.RequestPlayerData.OnServerEvent:Connect(function(player: Player)
			local profile = cache[player.UserId]
			if profile then
				syncClient(player, profile)
			end
		end)
	end

	game:BindToClose(function()
		for userId, profile in cache do
			task.spawn(saveToStore, userId, profile)
		end
		-- Dar tiempo a los saves en Studio / shutdown
		task.wait(3)
	end)

	warn("[PlayerData] Servicio iniciado (DataStore:", DATASTORE_NAME, ")")
end

return PlayerDataService
