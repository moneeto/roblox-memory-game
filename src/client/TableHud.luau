local Players = game:GetService("Players")

local TableHud = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local resultsPanel: Frame? = nil
local confirmOverlay: Frame? = nil

local onQuitConfirm: (() -> ())? = nil
local onRematch: (() -> ())? = nil

local function getScore(raw: { [any]: number }, userId: number): number
	return raw[userId] or raw[tostring(userId)] or 0
end

function TableHud.init(quitCallback: () -> (), rematchCallback: () -> ())
	onQuitConfirm = quitCallback
	onRematch = rematchCallback

	if screenGui then
		screenGui:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MemoryTableHud"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -120, 0, 36)
	statusLabel.Position = UDim2.new(0, 12, 0, 12)
	statusLabel.BackgroundTransparency = 0.2
	statusLabel.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 18
	statusLabel.TextColor3 = Color3.fromRGB(236, 240, 241)
	statusLabel.Text = ""
	statusLabel.Parent = screenGui

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 8)
	statusCorner.Parent = statusLabel

	local exitButton = Instance.new("TextButton")
	exitButton.Name = "ExitButton"
	exitButton.Size = UDim2.fromOffset(90, 34)
	exitButton.Position = UDim2.new(1, -100, 0, 12)
	exitButton.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
	exitButton.Font = Enum.Font.GothamBold
	exitButton.TextSize = 16
	exitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitButton.Text = "Salir"
	exitButton.Parent = screenGui

	local exitCorner = Instance.new("UICorner")
	exitCorner.CornerRadius = UDim.new(0, 8)
	exitCorner.Parent = exitButton

	exitButton.MouseButton1Click:Connect(function()
		TableHud.showQuitConfirm()
	end)

	confirmOverlay = Instance.new("Frame")
	confirmOverlay.Name = "QuitConfirm"
	confirmOverlay.Size = UDim2.fromScale(1, 1)
	confirmOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	confirmOverlay.BackgroundTransparency = 0.5
	confirmOverlay.Visible = false
	confirmOverlay.ZIndex = 10
	confirmOverlay.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(340, 180)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	panel.ZIndex = 11
	panel.Parent = confirmOverlay

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 60)
	title.Position = UDim2.fromOffset(12, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(236, 240, 241)
	title.Text = "¿Cancelar la partida?"
	title.TextWrapped = true
	title.ZIndex = 12
	title.Parent = panel

	local yesButton = Instance.new("TextButton")
	yesButton.Name = "YesButton"
	yesButton.Size = UDim2.fromOffset(120, 40)
	yesButton.Position = UDim2.new(0.5, -130, 1, -56)
	yesButton.BackgroundColor3 = Color3.fromRGB(192, 57, 43)
	yesButton.Font = Enum.Font.GothamBold
	yesButton.Text = "Sí, salir"
	yesButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	yesButton.ZIndex = 12
	yesButton.Parent = panel

	local noButton = Instance.new("TextButton")
	noButton.Name = "NoButton"
	noButton.Size = UDim2.fromOffset(120, 40)
	noButton.Position = UDim2.new(0.5, 10, 1, -56)
	noButton.BackgroundColor3 = Color3.fromRGB(127, 140, 141)
	noButton.Font = Enum.Font.GothamBold
	noButton.Text = "Cancelar"
	noButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	noButton.ZIndex = 12
	noButton.Parent = panel

	yesButton.MouseButton1Click:Connect(function()
		TableHud.hideQuitConfirm()
		if onQuitConfirm then
			onQuitConfirm()
		end
	end)

	noButton.MouseButton1Click:Connect(function()
		TableHud.hideQuitConfirm()
	end)

	resultsPanel = Instance.new("Frame")
	resultsPanel.Name = "Results"
	resultsPanel.Size = UDim2.fromOffset(360, 220)
	resultsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	resultsPanel.Position = UDim2.fromScale(0.5, 0.5)
	resultsPanel.BackgroundColor3 = Color3.fromRGB(44, 62, 80)
	resultsPanel.Visible = false
	resultsPanel.ZIndex = 20
	resultsPanel.Parent = screenGui

	local resultsCorner = Instance.new("UICorner")
	resultsCorner.CornerRadius = UDim.new(0, 12)
	resultsCorner.Parent = resultsPanel

	local resultsTitle = Instance.new("TextLabel")
	resultsTitle.Name = "Title"
	resultsTitle.Size = UDim2.new(1, -24, 0, 50)
	resultsTitle.Position = UDim2.fromOffset(12, 16)
	resultsTitle.BackgroundTransparency = 1
	resultsTitle.Font = Enum.Font.GothamBold
	resultsTitle.TextSize = 24
	resultsTitle.TextColor3 = Color3.fromRGB(236, 240, 241)
	resultsTitle.Text = "Fin del juego"
	resultsTitle.ZIndex = 21
	resultsTitle.Parent = resultsPanel

	local resultsBody = Instance.new("TextLabel")
	resultsBody.Name = "Body"
	resultsBody.Size = UDim2.new(1, -24, 0, 80)
	resultsBody.Position = UDim2.fromOffset(12, 72)
	resultsBody.BackgroundTransparency = 1
	resultsBody.Font = Enum.Font.Gotham
	resultsBody.TextSize = 18
	resultsBody.TextColor3 = Color3.fromRGB(189, 195, 199)
	resultsBody.TextWrapped = true
	resultsBody.Text = ""
	resultsBody.ZIndex = 21
	resultsBody.Parent = resultsPanel

	local rematchButton = Instance.new("TextButton")
	rematchButton.Name = "RematchButton"
	rematchButton.Size = UDim2.fromOffset(200, 44)
	rematchButton.AnchorPoint = Vector2.new(0.5, 1)
	rematchButton.Position = UDim2.new(0.5, 0, 1, -20)
	rematchButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	rematchButton.Font = Enum.Font.GothamBold
	rematchButton.TextSize = 18
	rematchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	rematchButton.Text = "Jugar de nuevo"
	rematchButton.ZIndex = 21
	rematchButton.Parent = resultsPanel

	local rematchCorner = Instance.new("UICorner")
	rematchCorner.CornerRadius = UDim.new(0, 8)
	rematchCorner.Parent = rematchButton

	rematchButton.MouseButton1Click:Connect(function()
		if resultsPanel then
			resultsPanel.Visible = false
		end
		if onRematch then
			onRematch()
		end
	end)
end

function TableHud.show(_tableId: string, mode: string)
	if screenGui then
		screenGui.Enabled = true
	end
	if statusLabel then
		statusLabel.Text = if mode == "Solo" then "Modo solitario" else "Partida 1v1"
	end
	if resultsPanel then
		resultsPanel.Visible = false
	end
	TableHud.hideQuitConfirm()
end

function TableHud.hide()
	if screenGui then
		screenGui.Enabled = false
	end
	if resultsPanel then
		resultsPanel.Visible = false
	end
	TableHud.hideQuitConfirm()
end

function TableHud.setStatus(text: string)
	if statusLabel then
		statusLabel.Text = text
	end
end

function TableHud.showQuitConfirm()
	if confirmOverlay then
		confirmOverlay.Visible = true
	end
end

function TableHud.hideQuitConfirm()
	if confirmOverlay then
		confirmOverlay.Visible = false
	end
end

function TableHud.showResults(result: {
	mode: string,
	attempts: number?,
	elapsedTime: number?,
	pairs: number?,
	winnerUserId: number?,
	scores: { [any]: number }?,
})
	if not resultsPanel then
		return
	end

	local title = resultsPanel:FindFirstChild("Title") :: TextLabel
	local body = resultsPanel:FindFirstChild("Body") :: TextLabel

	if result.mode == "Solo" then
		if title then
			title.Text = "¡Completaste el juego!"
		end
		if body then
			body.Text = string.format(
				"Intentos: %d\nTiempo: %ds\nPares: %d",
				result.attempts or 0,
				result.elapsedTime or 0,
				result.pairs or 0
			)
		end
	else
		if title then
			if result.winnerUserId then
				local winner = Players:GetPlayerByUserId(result.winnerUserId)
				local name = if winner then winner.DisplayName else "Jugador"
				title.Text = string.format("¡Ganó %s!", name)
			else
				title.Text = "¡Empate!"
			end
		end
		if body and result.scores then
			local lines = {}
			for userIdKey, score in result.scores do
				local userId = if typeof(userIdKey) == "number" then userIdKey else tonumber(userIdKey)
				if userId then
					local plr = Players:GetPlayerByUserId(userId)
					local name = if plr then plr.DisplayName else ("Jugador " .. userId)
					table.insert(lines, string.format("%s: %d pares", name, score))
				end
			end
			body.Text = table.concat(lines, "\n")
		end
	end

	resultsPanel.Visible = true
	TableHud.setStatus("Partida terminada")
end

return TableHud
