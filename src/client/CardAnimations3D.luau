local TableUtils = require(script.Parent.TableUtils)

local CardAnimations3D = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardData = require(Shared.CardData)

local animToken: { [BasePart]: number } = {}

local function getCardPart(tableId: string, cardIndex: number): BasePart?
	local tableModel = TableUtils.getTableModel(tableId)
	if not tableModel then
		return nil
	end
	local board = tableModel:FindFirstChild("Board")
	if not board then
		return nil
	end
	return board:FindFirstChild("Card_" .. cardIndex) :: BasePart?
end

local function getRestCFrame(card: BasePart): CFrame
	local rest = card:FindFirstChild("RestCFrame")
	if rest and rest:IsA("CFrameValue") then
		return rest.Value
	end
	return card.CFrame
end

local function snapToRest(card: BasePart)
	local rest = getRestCFrame(card)
	card.CFrame = rest
end

local function beginAnim(card: BasePart): number
	local token = (animToken[card] or 0) + 1
	animToken[card] = token
	return token
end

local function isAnimCurrent(card: BasePart, token: number): boolean
	return animToken[card] == token
end

local function tweenCFrame(card: BasePart, goal: CFrame, duration: number)
	local tween = TweenService:Create(card, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = goal,
	})
	tween:Play()
	tween.Completed:Wait()
end

-- Volteo suave sin dejar la ficha de canto: sube → vuelve plana
function CardAnimations3D.playFlip(tableId: string, cardIndex: number)
	local card = getCardPart(tableId, cardIndex)
	if not card then
		return
	end

	local token = beginAnim(card)
	local rest = getRestCFrame(card)
	snapToRest(card)

	local up = rest + Vector3.new(0, 0.4, 0)
	local half = CardData.FLIP_DURATION / 2

	tweenCFrame(card, up, half)
	if not isAnimCurrent(card, token) then
		snapToRest(card)
		return
	end

	tweenCFrame(card, rest, half)
	snapToRest(card)
end

function CardAnimations3D.playMatch(tableId: string, cardIndex1: number, cardIndex2: number)
	for _, index in { cardIndex1, cardIndex2 } do
		local card = getCardPart(tableId, index)
		if not card then
			continue
		end

		local token = beginAnim(card)
		local rest = getRestCFrame(card)
		snapToRest(card)

		local existing = card:FindFirstChildOfClass("Highlight")
		if existing then
			existing:Destroy()
		end

		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(46, 204, 113)
		highlight.OutlineColor = Color3.fromRGB(39, 174, 96)
		highlight.FillTransparency = 0.4
		highlight.Parent = card

		local up = rest + Vector3.new(0, 0.35, 0)
		tweenCFrame(card, up, 0.12)
		if not isAnimCurrent(card, token) then
			snapToRest(card)
			continue
		end
		tweenCFrame(card, rest, 0.12)
		snapToRest(card)
	end
end

function CardAnimations3D.playMismatch(tableId: string, cardIndex1: number, cardIndex2: number)
	for _, index in { cardIndex1, cardIndex2 } do
		local card = getCardPart(tableId, index)
		if not card then
			continue
		end

		local token = beginAnim(card)
		local rest = getRestCFrame(card)
		snapToRest(card)

		local right = rest.RightVector * 0.12
		tweenCFrame(card, rest + right, 0.05)
		if not isAnimCurrent(card, token) then
			snapToRest(card)
			continue
		end
		tweenCFrame(card, rest - right, 0.05)
		if not isAnimCurrent(card, token) then
			snapToRest(card)
			continue
		end
		tweenCFrame(card, rest, 0.05)
		snapToRest(card)
	end
end

function CardAnimations3D.resetAllCards(tableId: string)
	local tableModel = TableUtils.getTableModel(tableId)
	if not tableModel then
		return
	end
	local board = tableModel:FindFirstChild("Board")
	if not board then
		return
	end
	for _, child in board:GetChildren() do
		if child:IsA("BasePart") then
			snapToRest(child)
		end
	end
end

-- Texto pegado a la ficha (SurfaceGui): rota solo el label para legibilidad local.
-- No mueve las fichas: misma posición para todos los jugadores.
function CardAnimations3D.orientBoardForLocalPlayer(tableId: string)
	local tableModel = TableUtils.getTableModel(tableId)
	if not tableModel then
		return
	end

	local board = tableModel:FindFirstChild("Board")
	if not board then
		return
	end

	local Players = game:GetService("Players")
	local mySeat = TableUtils.getLocalPlayerSeat(tableModel, Players.LocalPlayer)
	local textRotation = if mySeat and mySeat.Name == "Seat2" then 180 else 0

	for _, child in board:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		for _, guiName in { "FrontGui", "BackGui" } do
			local gui = child:FindFirstChild(guiName)
			if not (gui and gui:IsA("SurfaceGui")) then
				continue
			end
			for _, label in gui:GetChildren() do
				if label:IsA("TextLabel") then
					label.Rotation = textRotation
				end
			end
		end
	end
end

return CardAnimations3D
