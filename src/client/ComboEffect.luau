local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ComboEffect = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local label: TextLabel? = nil
local pointsLabel: TextLabel? = nil

local function ensureGui()
	if screenGui and screenGui.Parent then
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ComboEffectGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	label = Instance.new("TextLabel")
	label.Name = "StreakLabel"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.28)
	label.Size = UDim2.fromOffset(420, 72)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 48
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = ""
	label.Visible = false
	label.Parent = screenGui

	pointsLabel = Instance.new("TextLabel")
	pointsLabel.Name = "PointsPopup"
	pointsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	pointsLabel.Position = UDim2.fromScale(0.5, 0.36)
	pointsLabel.Size = UDim2.fromOffset(280, 36)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Font = Enum.Font.GothamBold
	pointsLabel.TextSize = 22
	pointsLabel.TextColor3 = Color3.fromRGB(180, 255, 160)
	pointsLabel.TextStrokeTransparency = 0.5
	pointsLabel.Text = ""
	pointsLabel.Visible = false
	pointsLabel.Parent = screenGui
end

--[[
	Muestra "¡Racha xN!" cuando streak >= 1.
	pointsGained opcional para el popup de puntos.
]]
function ComboEffect.show(streak: number, multiplier: number?, pointsGained: number?)
	ensureGui()
	if not label or not pointsLabel then
		return
	end

	if streak <= 0 then
		label.Visible = false
		pointsLabel.Visible = false
		return
	end

	local mult = multiplier or 1
	label.Text = string.format("¡Racha x%d!", streak)
	if mult > 1 then
		label.Text = string.format("¡Racha x%d! (×%.1f)", streak, mult)
	end
	label.Visible = true
	label.TextTransparency = 0
	label.Size = UDim2.fromOffset(420, 72)

	local popIn = TweenService:Create(
		label,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(460, 80) }
	)
	local fadeOut = TweenService:Create(
		label,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	)

	popIn:Play()
	task.delay(0.9, function()
		fadeOut:Play()
		fadeOut.Completed:Once(function()
			if label then
				label.Visible = false
				label.TextTransparency = 0
			end
		end)
	end)

	if pointsGained and pointsGained > 0 and pointsLabel then
		pointsLabel.Text = string.format("+%d pts", pointsGained)
		pointsLabel.Visible = true
		pointsLabel.TextTransparency = 0
		pointsLabel.Position = UDim2.fromScale(0.5, 0.36)

		local rise = TweenService:Create(
			pointsLabel,
			TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.30), TextTransparency = 1 }
		)
		rise:Play()
		rise.Completed:Once(function()
			if pointsLabel then
				pointsLabel.Visible = false
			end
		end)
	end
end

function ComboEffect.init()
	ensureGui()
end

return ComboEffect
