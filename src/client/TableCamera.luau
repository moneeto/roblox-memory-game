local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local TableUtils = require(script.Parent.TableUtils)

local TableCamera = {}

local BIND_NAME = "MemoryTableCamera"
local localPlayer = Players.LocalPlayer
local savedCameraType: Enum.CameraType? = nil
local savedCameraMode: Enum.CameraMode? = nil
local activeTween: Tween? = nil
local targetCFrame: CFrame? = nil
local isBound = false

local function unbindCamera()
	if isBound then
		pcall(function()
			RunService:UnbindFromRenderStep(BIND_NAME)
		end)
		isBound = false
	end
	targetCFrame = nil
end

local function bindCamera(cframe: CFrame)
	unbindCamera()
	targetCFrame = cframe
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
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

	-- Detrás del jugador local, mirando al tablero (y al rival)
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

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	unbindCamera()

	if savedCameraType == nil then
		savedCameraType = camera.CameraType
		savedCameraMode = localPlayer.CameraMode
	end

	localPlayer.CameraMode = Enum.CameraMode.Classic
	camera.CameraType = Enum.CameraType.Scriptable

	activeTween = TweenService:Create(camera, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = desiredCFrame,
	})
	activeTween:Play()
	activeTween.Completed:Connect(function()
		bindCamera(desiredCFrame)
	end)
end

function TableCamera.restore()
	unbindCamera()

	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = savedCameraType or Enum.CameraType.Custom
	if savedCameraMode then
		localPlayer.CameraMode = savedCameraMode
	end

	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	savedCameraType = nil
	savedCameraMode = nil
end

return TableCamera
