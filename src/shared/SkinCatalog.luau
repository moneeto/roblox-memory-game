export type SkinCategory = "Cards" | "Seats" | "Tables"

export type SkinAppearance = {
	Color: Color3,
	Material: Enum.Material,
	-- TextureId opcional (Decal/Texture); vacío = sin textura
	TextureId: string?,
}

export type SkinDef = {
	id: string,
	name: string,
	category: SkinCategory,
	price: number,
	-- true = desbloqueada al crear cuenta
	defaultUnlocked: boolean?,
	appearance: SkinAppearance,
}

local SkinCatalog = {}

SkinCatalog.CATEGORIES = {
	Cards = "Cards",
	Seats = "Seats",
	Tables = "Tables",
} :: { [string]: SkinCategory }

-- IDs por defecto (siempre desbloqueados y equipados al inicio)
SkinCatalog.DEFAULT_EQUIPPED = {
	Cards = "cards_classic",
	Seats = "seats_classic",
	Tables = "tables_classic",
}

local SKINS: { SkinDef } = {
	-- Fichas (dorso)
	{
		id = "cards_classic",
		name = "Clásico",
		category = "Cards",
		price = 0,
		defaultUnlocked = true,
		appearance = {
			Color = Color3.fromRGB(52, 73, 94),
			Material = Enum.Material.SmoothPlastic,
		},
	},
	{
		id = "cards_gold",
		name = "Dorado",
		category = "Cards",
		price = 500,
		appearance = {
			Color = Color3.fromRGB(212, 175, 55),
			Material = Enum.Material.Metal,
		},
	},
	{
		id = "cards_neon",
		name = "Neón",
		category = "Cards",
		price = 800,
		appearance = {
			Color = Color3.fromRGB(0, 255, 170),
			Material = Enum.Material.Neon,
		},
	},
	{
		id = "cards_obsidian",
		name = "Obsidiana",
		category = "Cards",
		price = 1200,
		appearance = {
			Color = Color3.fromRGB(20, 20, 28),
			Material = Enum.Material.Slate,
		},
	},

	-- Sillas
	{
		id = "seats_classic",
		name = "Clásico",
		category = "Seats",
		price = 0,
		defaultUnlocked = true,
		appearance = {
			Color = Color3.fromRGB(46, 125, 80),
			Material = Enum.Material.Fabric,
		},
	},
	{
		id = "seats_royal",
		name = "Real",
		category = "Seats",
		price = 600,
		appearance = {
			Color = Color3.fromRGB(120, 40, 160),
			Material = Enum.Material.Fabric,
		},
	},
	{
		id = "seats_crimson",
		name = "Carmesí",
		category = "Seats",
		price = 900,
		appearance = {
			Color = Color3.fromRGB(160, 30, 45),
			Material = Enum.Material.Leather,
		},
	},

	-- Mesas
	{
		id = "tables_classic",
		name = "Clásico",
		category = "Tables",
		price = 0,
		defaultUnlocked = true,
		appearance = {
			Color = Color3.fromRGB(110, 24, 45),
			Material = Enum.Material.SmoothPlastic,
		},
	},
	{
		id = "tables_oak",
		name = "Roble",
		category = "Tables",
		price = 700,
		appearance = {
			Color = Color3.fromRGB(139, 90, 43),
			Material = Enum.Material.Wood,
		},
	},
	{
		id = "tables_marble",
		name = "Mármol",
		category = "Tables",
		price = 1500,
		appearance = {
			Color = Color3.fromRGB(230, 230, 235),
			Material = Enum.Material.Marble,
		},
	},
}

local byId: { [string]: SkinDef } = {}
for _, skin in SKINS do
	byId[skin.id] = skin
end

function SkinCatalog.getAll(): { SkinDef }
	return SKINS
end

function SkinCatalog.getById(id: string): SkinDef?
	return byId[id]
end

function SkinCatalog.getByCategory(category: SkinCategory): { SkinDef }
	local result = {}
	for _, skin in SKINS do
		if skin.category == category then
			table.insert(result, skin)
		end
	end
	return result
end

function SkinCatalog.getDefaultUnlockedIds(): { string }
	local ids = {}
	for _, skin in SKINS do
		if skin.defaultUnlocked then
			table.insert(ids, skin.id)
		end
	end
	return ids
end

function SkinCatalog.getAppearance(id: string): SkinAppearance?
	local skin = byId[id]
	return if skin then skin.appearance else nil
end

return SkinCatalog
