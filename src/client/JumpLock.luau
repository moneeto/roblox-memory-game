local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local JumpLock = {}

local ACTION_NAME = "MemoryBlockJump"
local localPlayer = Players.LocalPlayer
local savedJumpHeight: number? = nil
local savedJumpPower: number? = nil
local locked = false

local function applyHumanoidLock(humanoid: Humanoid, enableLock: boolean)
	if enableLock then
		if savedJumpHeight == nil then
			savedJumpHeight = humanoid.JumpHeight
			savedJumpPower = humanoid.JumpPower
		end
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
		humanoid.Jump = false
	else
		humanoid.JumpHeight = savedJumpHeight or 7.2
		humanoid.JumpPower = savedJumpPower or 50
		savedJumpHeight = nil
		savedJumpPower = nil
	end
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") and locked then
		applyHumanoidLock(humanoid, true)
	end
end

function JumpLock.lock()
	if locked then
		return
	end
	locked = true

	ContextActionService:BindAction(ACTION_NAME, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.PlayerActions.CharacterJump)

	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			applyHumanoidLock(humanoid, true)
		end
	end
end

function JumpLock.unlock()
	if not locked then
		return
	end
	locked = false

	ContextActionService:UnbindAction(ACTION_NAME)

	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			applyHumanoidLock(humanoid, false)
		end
	end
end

function JumpLock.isLocked(): boolean
	return locked
end

localPlayer.CharacterAdded:Connect(onCharacter)

return JumpLock
