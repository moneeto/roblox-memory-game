--[[
	Catálogo de memes para las CARAS de las fichas.

	CÓMO CARGAR MEMES:
	1) create.roblox.com → Creaciones → Adhesivos → subir JPG/PNG
	2) Copiá el ID numérico de cada adhesivo
	3) Pegalo en DEFAULT_IMAGE_IDS o VIP_IMAGE_IDS (abajo)

	1 adhesivo = 1 ID = 1 meme distinto.
	Ideal: 24 IDs en DEFAULT + 24 en VIP.
	Si un slot no tiene ID, esa ficha usa letra (A, B, C...) de fallback.
]]

export type MemeDef = {
	id: string,
	name: string,
	packId: string,
	-- rbxassetid://...  (dejar "" hasta que subas/pegues el asset)
	imageId: string,
	-- Color de fondo de la ficha al revelar (se ve alrededor / detrás de la imagen)
	color: Color3,
	-- Fallback si no hay imagen cargada
	symbol: string,
}

export type MemePackDef = {
	id: string,
	name: string,
	price: number,
	defaultUnlocked: boolean,
	description: string,
}

local MemeCatalog = {}

MemeCatalog.PACK_DEFAULT = "memes_default"
MemeCatalog.PACK_VIP = "memes_vip"

MemeCatalog.PACKS = {
	{
		id = "memes_default",
		name = "Memes Clásicos",
		price = 0,
		defaultUnlocked = true,
		description = "24 memes gratis. Cada partida elige al azar los que necesita el tablero.",
	},
	{
		id = "memes_vip",
		name = "Memes VIP",
		price = 2500,
		defaultUnlocked = false,
		description = "24 memes extra. Se suman al pool de rotación al canjearlos.",
	},
} :: { MemePackDef }

local FALLBACK_COLORS = {
	Color3.fromRGB(231, 76, 60),
	Color3.fromRGB(46, 204, 113),
	Color3.fromRGB(52, 152, 219),
	Color3.fromRGB(241, 196, 15),
	Color3.fromRGB(155, 89, 182),
	Color3.fromRGB(230, 126, 34),
	Color3.fromRGB(26, 188, 156),
	Color3.fromRGB(236, 72, 153),
	Color3.fromRGB(52, 73, 94),
	Color3.fromRGB(149, 165, 166),
	Color3.fromRGB(39, 174, 96),
	Color3.fromRGB(41, 128, 185),
}

--[[
	Lista de Asset IDs del pack DEFAULT (hasta 24).
	1 adhesivo subido = 1 ID = 1 meme distinto.

	Ejemplo con el tuyo (sixseven):
]]
local DEFAULT_IMAGE_IDS: { string } = {
	"rbxassetid://94967867578601", -- 01 ← tu primer meme
	-- "rbxassetid://OTRO_ID",    -- 02
	-- "rbxassetid://OTRO_ID",    -- 03
	-- ... hasta 24
}

--[[
	Lista de Asset IDs del pack VIP (hasta 24).
	Se desbloquean canjeando el pack en la tienda.
]]
local VIP_IMAGE_IDS: { string } = {
	-- "rbxassetid://...",
}

local function buildPackMemes(packId: string, prefix: string, count: number, imageIds: { string }): { MemeDef }
	local memes = {}
	for i = 1, count do
		local rawId = imageIds[i]
		local imageId = ""
		if typeof(rawId) == "string" and rawId ~= "" then
			-- Acepta "123" o "rbxassetid://123"
			if string.find(rawId, "rbxassetid://", 1, true) == 1 then
				imageId = rawId
			else
				imageId = "rbxassetid://" .. rawId
			end
		end

		table.insert(memes, {
			id = string.format("%s_%02d", packId, i),
			name = string.format("%s %02d", prefix, i),
			packId = packId,
			imageId = imageId,
			color = FALLBACK_COLORS[((i - 1) % #FALLBACK_COLORS) + 1],
			symbol = string.char(64 + ((i - 1) % 26) + 1), -- A..Z rotando
		})
	end
	return memes
end

local DEFAULT_MEMES = buildPackMemes(MemeCatalog.PACK_DEFAULT, "Meme", 24, DEFAULT_IMAGE_IDS)
local VIP_MEMES = buildPackMemes(MemeCatalog.PACK_VIP, "VIP", 24, VIP_IMAGE_IDS)

local ALL_MEMES: { MemeDef } = {}
for _, meme in DEFAULT_MEMES do
	table.insert(ALL_MEMES, meme)
end
for _, meme in VIP_MEMES do
	table.insert(ALL_MEMES, meme)
end

local byId: { [string]: MemeDef } = {}
for _, meme in ALL_MEMES do
	byId[meme.id] = meme
end

local packsById: { [string]: MemePackDef } = {}
for _, pack in MemeCatalog.PACKS do
	packsById[pack.id] = pack
end

function MemeCatalog.getPack(packId: string): MemePackDef?
	return packsById[packId]
end

function MemeCatalog.getAllPacks(): { MemePackDef }
	return MemeCatalog.PACKS
end

function MemeCatalog.getDefaultUnlockedPackIds(): { string }
	local ids = {}
	for _, pack in MemeCatalog.PACKS do
		if pack.defaultUnlocked then
			table.insert(ids, pack.id)
		end
	end
	return ids
end

function MemeCatalog.getMemesInPack(packId: string): { MemeDef }
	local list = {}
	for _, meme in ALL_MEMES do
		if meme.packId == packId then
			table.insert(list, meme)
		end
	end
	return list
end

function MemeCatalog.getMeme(memeId: string): MemeDef?
	return byId[memeId]
end

local function fisherYatesShuffle<T>(values: { T }): { T }
	local shuffled = table.clone(values)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

export type PairFace = {
	memeId: string,
	imageId: string,
	color: Color3,
	symbol: string,
	packId: string,
}

--[[
	Elige `count` memes al azar del pool de packs desbloqueados.
	Si el pool es menor que count, vuelve a barajar y reutiliza.
]]
function MemeCatalog.pickRandomFaces(count: number, unlockedPackIds: { string }): { PairFace }
	local allowed = {}
	for _, packId in unlockedPackIds do
		allowed[packId] = true
	end

	local pool: { MemeDef } = {}
	for _, meme in ALL_MEMES do
		if allowed[meme.packId] then
			table.insert(pool, meme)
		end
	end

	if #pool == 0 then
		pool = MemeCatalog.getMemesInPack(MemeCatalog.PACK_DEFAULT)
	end

	local faces: { PairFace } = {}
	local deck = fisherYatesShuffle(pool)
	local index = 1

	for _ = 1, count do
		if index > #deck then
			deck = fisherYatesShuffle(pool)
			index = 1
		end
		local meme = deck[index]
		index += 1
		table.insert(faces, {
			memeId = meme.id,
			imageId = meme.imageId,
			color = meme.color,
			symbol = meme.symbol,
			packId = meme.packId,
		})
	end

	return faces
end

return MemeCatalog
