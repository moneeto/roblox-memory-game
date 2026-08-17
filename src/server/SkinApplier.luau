local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinCatalog = require(Shared.SkinCatalog)

local SkinApplier = {}

local function applyPartAppearance(part: BasePart, appearance: SkinCatalog.SkinAppearance)
	part.Color = appearance.Color
	part.Material = appearance.Material

	local existing = part:FindFirstChild("SkinTexture")
	if existing then
		existing:Destroy()
	end

	local textureId = appearance.TextureId
	if textureId and textureId ~= "" then
		local texture = Instance.new("Texture")
		texture.Name = "SkinTexture"
		texture.Texture = textureId
		texture.Face = Enum.NormalId.Top
		texture.StudsPerTileU = 2
		texture.StudsPerTileV = 2
		texture.Parent = part
	end
end

--[[
	Aplica skins equipadas a TableTop y sillas de la mesa.
	Las fichas se aplican en BoardBuilder.build vía cardAppearance.
]]
function SkinApplier.applyFurniture(tableModel: Model, equipped: { Cards: string, Seats: string, Tables: string })
	local tableAppearance = SkinCatalog.getAppearance(equipped.Tables)
	local seatAppearance = SkinCatalog.getAppearance(equipped.Seats)

	local tableTop = tableModel:FindFirstChild("TableTop")
	if tableTop and tableTop:IsA("BasePart") and tableAppearance then
		applyPartAppearance(tableTop, tableAppearance)
	end

	if seatAppearance then
		for _, childName in { "Seat1", "Seat2" } do
			local seat = tableModel:FindFirstChild(childName)
			if seat and seat:IsA("BasePart") then
				applyPartAppearance(seat, seatAppearance)
			end
		end
	end
end

function SkinApplier.getCardAppearance(equippedCardSkinId: string): SkinCatalog.SkinAppearance
	local appearance = SkinCatalog.getAppearance(equippedCardSkinId)
	if appearance then
		return appearance
	end
	return SkinCatalog.getAppearance(SkinCatalog.DEFAULT_EQUIPPED.Cards) :: SkinCatalog.SkinAppearance
end

return SkinApplier
