local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local TableUtils = require(script.Parent.TableUtils)

local TableCamera = {}

local BIND_NAME = "MemoryTableCamera"
local localPlayer = Players.LocalPlayer
local activeTween: Tween? = nil
local targetCFrame: CFrame? = nil
local isBound = false
local focused = false
local focusToken = 0

local function unbindCamera()
	pcall(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
	isBound = false
	targetCFrame = nil
end

local function bindCamera(cframe: CFrame, token: number)
	if token ~= focusToken or not focused then
		return
	end
	unbindCamera()
	targetCFrame = cframe
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		if not focused or token ~= focusToken then
			return
		end
		local camera = workspace.CurrentCamera
		if camera and targetCFrame then
			camera.CFrame = targetCFrame
		end
	end)
	isBound = true
end

local function computeTableCameraCFrame(tableModel: Model): CFrame?
	local focusPart = TableUtils.getFocusPart(tableModel)
	if not focusPart then
		return nil
	end

	local boardFocus = focusPart.Position + Vector3.new(0, 0.4, 0)
	local mySeat = TableUtils.getLocalPlayerSeat(tableModel, localPlayer)

	local seatPos: Vector3
	if mySeat then
		seatPos = mySeat.Position
	else
		local seats = TableUtils.getSeatPositions(tableModel)
		if #seats == 0 then
			return CFrame.lookAt(boardFocus + Vector3.new(0, 8, 8), boardFocus)
		end
		seatPos = seats[1]
	end

	local away = Vector3.new(seatPos.X - boardFocus.X, 0, seatPos.Z - boardFocus.Z)
	if away.Magnitude < 0.05 then
		away = Vector3.new(0, 0, -1)
	else
		away = away.Unit
	end

	local cameraPosition = boardFocus + away * 5.5 + Vector3.new(0, 6.5, 0)
	local lookTarget = boardFocus

	local rivalSeat = if mySeat then TableUtils.getOppositeSeat(tableModel, mySeat) else nil
	if rivalSeat then
		lookTarget = boardFocus:Lerp(rivalSeat.Position + Vector3.new(0, 2, 0), 0.18)
	end

	return CFrame.lookAt(cameraPosition, lookTarget)
end

function TableCamera.focusOnTable(tableId: string)
	local tableModel = TableUtils.waitForTableModel(tableId, 6)
	if not tableModel then
		return
	end

	local desiredCFrame = computeTableCameraCFrame(tableModel)
	if not desiredCFrame then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	focusToken += 1
	local token = focusToken

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	unbindCamera()

	focused = true
	localPlayer.CameraMode = Enum.CameraMode.Classic
	camera.CameraType = Enum.CameraType.Scriptable

	activeTween = TweenService:Create(camera, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = desiredCFrame,
	})
	activeTween:Play()
	activeTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Cancelled then
			return
		end
		if focused and token == focusToken then
			bindCamera(desiredCFrame, token)
		end
	end)
end

function TableCamera.restore()
	focusToken += 1
	focused = false

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	unbindCamera()

	local function applyFreeCamera()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		camera.CameraType = Enum.CameraType.Custom
		localPlayer.CameraMode = Enum.CameraMode.Classic

		local character = localPlayer.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end

	applyFreeCamera()
	task.defer(applyFreeCamera)
	task.delay(0.05, function()
		if not focused then
			applyFreeCamera()
		end
	end)
	task.delay(0.2, function()
		if not focused then
			applyFreeCamera()
		end
	end)
end

function TableCamera.isFocused(): boolean
	return focused
end

return TableCamera
