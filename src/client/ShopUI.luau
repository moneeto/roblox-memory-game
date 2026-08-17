local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SkinCatalog = require(Shared.SkinCatalog)
local MemeCatalog = require(Shared.MemeCatalog)

local ShopUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

type Profile = {
	points: number,
	unlockedSkins: { string },
	unlockedMemePacks: { string }?,
	equipped: { Cards: string, Seats: string, Tables: string },
}

local profile: Profile? = nil
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local pointsLabel: TextLabel? = nil
local listFrame: ScrollingFrame? = nil
local statusLabel: TextLabel? = nil

local function hasUnlocked(skinId: string): boolean
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

local function hasMemePack(packId: string): boolean
	if not profile then
		return false
	end
	local packs = profile.unlockedMemePacks or {}
	for _, id in packs do
		if id == packId then
			return true
		end
	end
	-- Packs free por defecto
	local pack = MemeCatalog.getPack(packId)
	return if pack then pack.defaultUnlocked == true else false
end

local function isEquipped(skinId: string): boolean
	if not profile then
		return false
	end
	local eq = profile.equipped
	return eq.Cards == skinId or eq.Seats == skinId or eq.Tables == skinId
end

local function addSectionHeader(text: string, layoutOrder: number)
	if not listFrame then
		return
	end
	local header = Instance.new("Frame")
	header.Name = "Header_" .. text
	header.Size = UDim2.new(1, -12, 0, 28)
	header.BackgroundTransparency = 1
	header.LayoutOrder = layoutOrder
	header.Parent = listFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(212, 175, 55)
	label.Text = text
	label.Parent = header
end

local function refreshList()
	if not listFrame or not pointsLabel then
		return
	end

	for _, child in listFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	pointsLabel.Text = string.format("Puntos: %d", if profile then profile.points else 0)

	local layoutOrder = 0

	layoutOrder += 1
	addSectionHeader("Packs de memes (caras de fichas)", layoutOrder)

	for _, pack in MemeCatalog.getAllPacks() do
		layoutOrder += 1

		local row = Instance.new("Frame")
		row.Name = pack.id
		row.Size = UDim2.new(1, -12, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(40, 48, 58)
		row.LayoutOrder = layoutOrder
		row.Parent = listFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -130, 0, 22)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 16
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(236, 240, 241)
		title.Text = pack.name
		title.Parent = row

		local meta = Instance.new("TextLabel")
		meta.BackgroundTransparency = 1
		meta.Position = UDim2.fromOffset(12, 32)
		meta.Size = UDim2.new(1, -130, 0, 24)
		meta.Font = Enum.Font.Gotham
		meta.TextSize = 12
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.TextColor3 = Color3.fromRGB(160, 170, 180)
		meta.TextWrapped = true
		if hasMemePack(pack.id) then
			meta.Text = "Desbloqueado · rota en cada partida"
			meta.TextColor3 = Color3.fromRGB(46, 204, 113)
		elseif pack.price <= 0 then
			meta.Text = pack.description
		else
			meta.Text = string.format("%d pts · %s", pack.price, pack.description)
		end
		meta.Parent = row

		local action = Instance.new("TextButton")
		action.Size = UDim2.fromOffset(96, 32)
		action.Position = UDim2.new(1, -108, 0.5, -16)
		action.Font = Enum.Font.GothamBold
		action.TextSize = 14
		action.TextColor3 = Color3.fromRGB(255, 255, 255)
		action.Parent = row

		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 6)
		actionCorner.Parent = action

		if hasMemePack(pack.id) then
			action.Text = "✓"
			action.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
			action.Active = false
		else
			action.Text = "Canjear"
			action.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
			action.MouseButton1Click:Connect(function()
				Remotes.RequestPurchaseMemePack:FireServer(pack.id)
			end)
		end
	end

	layoutOrder += 1
	addSectionHeader("Skins (mesa / sillas / dorso)", layoutOrder)

	for _, skin in SkinCatalog.getAll() do
		layoutOrder += 1

		local row = Instance.new("Frame")
		row.Name = skin.id
		row.Size = UDim2.new(1, -12, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(40, 48, 58)
		row.LayoutOrder = layoutOrder
		row.Parent = listFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(36, 36)
		swatch.Position = UDim2.fromOffset(10, 10)
		swatch.BackgroundColor3 = skin.appearance.Color
		swatch.Parent = row

		local swatchCorner = Instance.new("UICorner")
		swatchCorner.CornerRadius = UDim.new(0, 6)
		swatchCorner.Parent = swatch

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(56, 6)
		title.Size = UDim2.new(1, -170, 0, 22)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 16
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(236, 240, 241)
		title.Text = string.format("%s · %s", skin.name, skin.category)
		title.Parent = row

		local meta = Instance.new("TextLabel")
		meta.BackgroundTransparency = 1
		meta.Position = UDim2.fromOffset(56, 28)
		meta.Size = UDim2.new(1, -170, 0, 18)
		meta.Font = Enum.Font.Gotham
		meta.TextSize = 13
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.TextColor3 = Color3.fromRGB(160, 170, 180)
		if isEquipped(skin.id) then
			meta.Text = "Equipada"
			meta.TextColor3 = Color3.fromRGB(46, 204, 113)
		elseif hasUnlocked(skin.id) then
			meta.Text = "Desbloqueada"
		elseif skin.price <= 0 then
			meta.Text = "Gratis"
		else
			meta.Text = string.format("%d pts", skin.price)
		end
		meta.Parent = row

		local action = Instance.new("TextButton")
		action.Size = UDim2.fromOffset(96, 32)
		action.Position = UDim2.new(1, -108, 0.5, -16)
		action.Font = Enum.Font.GothamBold
		action.TextSize = 14
		action.TextColor3 = Color3.fromRGB(255, 255, 255)
		action.AutoButtonColor = true
		action.Parent = row

		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 6)
		actionCorner.Parent = action

		if isEquipped(skin.id) then
			action.Text = "✓"
			action.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
			action.Active = false
		elseif hasUnlocked(skin.id) then
			action.Text = "Equipar"
			action.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
			action.MouseButton1Click:Connect(function()
				Remotes.RequestEquipSkin:FireServer(skin.id)
			end)
		else
			action.Text = "Comprar"
			action.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
			action.MouseButton1Click:Connect(function()
				Remotes.RequestPurchaseSkin:FireServer(skin.id)
			end)
		end
	end
end

local function buildUi()
	if screenGui then
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkinShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 40
	screenGui.Parent = playerGui

	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenShop"
	openButton.Size = UDim2.fromOffset(110, 36)
	openButton.Position = UDim2.new(1, -122, 1, -50)
	openButton.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	openButton.Font = Enum.Font.GothamBold
	openButton.TextSize = 16
	openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	openButton.Text = "Tienda"
	openButton.Parent = screenGui

	local openCorner = Instance.new("UICorner")
	openCorner.CornerRadius = UDim.new(0, 8)
	openCorner.Parent = openButton

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "ShopPanel"
	mainFrame.Size = UDim2.fromOffset(420, 460)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(28, 34, 42)
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 36)
	title.Position = UDim2.fromOffset(16, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 241)
	title.Text = "Tienda"
	title.Parent = mainFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(36, 36)
	closeButton.Position = UDim2.new(1, -44, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Text = "X"
	closeButton.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	pointsLabel = Instance.new("TextLabel")
	pointsLabel.Size = UDim2.new(1, -32, 0, 24)
	pointsLabel.Position = UDim2.fromOffset(16, 48)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Font = Enum.Font.Gotham
	pointsLabel.TextSize = 16
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.TextColor3 = Color3.fromRGB(212, 175, 55)
	pointsLabel.Text = "Puntos: 0"
	pointsLabel.Parent = mainFrame

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "SkinList"
	listFrame.Size = UDim2.new(1, -24, 1, -120)
	listFrame.Position = UDim2.fromOffset(12, 80)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.CanvasSize = UDim2.fromOffset(0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = mainFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listFrame

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -32, 0, 22)
	statusLabel.Position = UDim2.new(0, 16, 1, -30)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 14
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(160, 170, 180)
	statusLabel.Text = ""
	statusLabel.Parent = mainFrame

	openButton.MouseButton1Click:Connect(function()
		if mainFrame then
			mainFrame.Visible = not mainFrame.Visible
			if mainFrame.Visible then
				Remotes.RequestPlayerData:FireServer()
				refreshList()
			end
		end
	end)

	closeButton.MouseButton1Click:Connect(function()
		if mainFrame then
			mainFrame.Visible = false
		end
	end)
end

function ShopUI.setProfile(data: Profile)
	profile = data
	refreshList()
end

function ShopUI.init()
	Remotes.init()
	buildUi()

	Remotes.PlayerDataUpdated.OnClientEvent:Connect(function(data)
		if typeof(data) == "table" then
			ShopUI.setProfile(data)
		end
	end)

	Remotes.ShopResult.OnClientEvent:Connect(function(_action, ok, _skinId, message)
		if statusLabel then
			statusLabel.Text = tostring(message or "")
			statusLabel.TextColor3 = if ok then Color3.fromRGB(46, 204, 113) else Color3.fromRGB(231, 76, 60)
		end
	end)

	Remotes.RequestPlayerData:FireServer()
end

return ShopUI
