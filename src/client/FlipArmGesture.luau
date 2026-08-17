local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FlipArmGesture = {}

local REACH_OUT = 0.16
local REACH_HOLD = 0.05
local REACH_BACK = 0.22
local playingByCharacter: { [Model]: boolean } = {}
local warnedMissingMotor = false

local function motorNameMatches(motorName: string, keywords: { string }): boolean
	local lower = string.lower(motorName)
	for _, key in keywords do
		if not string.find(lower, key, 1, true) then
			return false
		end
	end
	return true
end

local function findMotor(character: Model, keywords: { string }): Motor6D?
	for _, inst in character:GetDescendants() do
		if inst:IsA("Motor6D") and motorNameMatches(inst.Name, keywords) then
			return inst
		end
	end
	return nil
end

local function findShoulderMotor(character: Model): Motor6D?
	-- Nombres clásicos R15 / R6
	local direct = findMotor(character, { "right", "shoulder" })
		or findMotor(character, { "left", "shoulder" })
	if direct then
		return direct
	end

	-- Por Part1 del brazo superior
	for _, partName in { "RightUpperArm", "Right Arm", "LeftUpperArm", "Left Arm" } do
		local arm = character:FindFirstChild(partName)
		if arm and arm:IsA("BasePart") then
			for _, inst in character:GetDescendants() do
				if inst:IsA("Motor6D") and inst.Part1 == arm then
					return inst
				end
			end
		end
	end

	return nil
end

local function findElbowMotor(character: Model): Motor6D?
	return findMotor(character, { "right", "elbow" })
		or findMotor(character, { "left", "elbow" })
end

-- Transform se aplica encima de la animación de sentado; hay que pisarlo cada frame.
local function playTransforms(character: Model, goals: { [Motor6D]: CFrame })
	local bindName = "MemoryFlipArm_" .. character.Name .. "_" .. tostring(os.clock())
	local elapsed = 0
	local total = REACH_OUT + REACH_HOLD + REACH_BACK

	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value, function(dt)
		if not character.Parent then
			pcall(function()
				RunService:UnbindFromRenderStep(bindName)
			end)
			return
		end

		elapsed += dt
		local alpha = 0
		if elapsed <= REACH_OUT then
			alpha = math.clamp(elapsed / REACH_OUT, 0, 1)
			alpha = alpha * alpha * (3 - 2 * alpha)
		elseif elapsed <= REACH_OUT + REACH_HOLD then
			alpha = 1
		else
			local t = math.clamp((elapsed - REACH_OUT - REACH_HOLD) / REACH_BACK, 0, 1)
			alpha = 1 - (t * t * (3 - 2 * t))
		end

		for motor, goal in goals do
			if motor.Parent then
				motor.Transform = CFrame.identity:Lerp(goal, alpha)
			end
		end

		if elapsed >= total then
			for motor, _ in goals do
				if motor.Parent then
					motor.Transform = CFrame.identity
				end
			end
			pcall(function()
				RunService:UnbindFromRenderStep(bindName)
			end)
		end
	end)

	task.delay(total + 0.05, function()
		pcall(function()
			RunService:UnbindFromRenderStep(bindName)
		end)
	end)
end

local function playWithMotors(character: Model): boolean
	local shoulder = findShoulderMotor(character)
	if not shoulder then
		return false
	end

	local goals: { [Motor6D]: CFrame } = {
		[shoulder] = CFrame.Angles(math.rad(-75), math.rad(15), math.rad(25)),
	}

	local elbow = findElbowMotor(character)
	if elbow then
		goals[elbow] = CFrame.Angles(math.rad(-40), 0, math.rad(10))
	end

	playTransforms(character, goals)
	return true
end

-- Fallback: IKControl (avatares nuevos / sin Motor6D clásico)
local function playWithIK(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local upper = character:FindFirstChild("RightUpperArm") :: BasePart?
		or character:FindFirstChild("Right Arm") :: BasePart?
	local hand = character:FindFirstChild("RightHand") :: BasePart?
		or character:FindFirstChild("Right Arm") :: BasePart?

	if not (humanoid and root and upper) then
		return false
	end

	local target = Instance.new("Part")
	target.Name = "MemoryFlipIKTarget"
	target.Anchored = true
	target.CanCollide = false
	target.Transparency = 1
	target.Size = Vector3.new(0.2, 0.2, 0.2)
	target.CFrame = root.CFrame * CFrame.new(1.1, 0.6, -1.4)
	target.Parent = character

	local ik = Instance.new("IKControl")
	ik.Name = "MemoryFlipIK"
	ik.Type = Enum.IKControlType.Transform
	ik.EndEffector = hand or upper
	ik.ChainRoot = upper
	ik.Target = target
	ik.Weight = 0
	ik.Parent = humanoid

	local bindName = "MemoryFlipIK_" .. character.Name .. "_" .. tostring(os.clock())
	local elapsed = 0
	local total = REACH_OUT + REACH_HOLD + REACH_BACK

	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value, function(dt)
		if not character.Parent then
			pcall(function()
				RunService:UnbindFromRenderStep(bindName)
			end)
			return
		end

		elapsed += dt
		local weight = 0
		if elapsed <= REACH_OUT then
			local a = math.clamp(elapsed / REACH_OUT, 0, 1)
			weight = a * a * (3 - 2 * a)
		elseif elapsed <= REACH_OUT + REACH_HOLD then
			weight = 1
		else
			local t = math.clamp((elapsed - REACH_OUT - REACH_HOLD) / REACH_BACK, 0, 1)
			weight = 1 - (t * t * (3 - 2 * t))
		end

		if ik.Parent then
			ik.Weight = weight
		end

		if elapsed >= total then
			pcall(function()
				RunService:UnbindFromRenderStep(bindName)
			end)
			ik:Destroy()
			target:Destroy()
		end
	end)

	task.delay(total + 0.1, function()
		pcall(function()
			RunService:UnbindFromRenderStep(bindName)
		end)
		if ik.Parent then
			ik:Destroy()
		end
		if target.Parent then
			target:Destroy()
		end
	end)

	return true
end

function FlipArmGesture.playForPlayer(player: Player?)
	if not player then
		return
	end

	local character = player.Character
	if not character or not character:FindFirstChildOfClass("Humanoid") then
		return
	end
	if playingByCharacter[character] then
		return
	end

	playingByCharacter[character] = true
	local ok = playWithMotors(character) or playWithIK(character)
	task.delay(REACH_OUT + REACH_HOLD + REACH_BACK + 0.15, function()
		playingByCharacter[character] = nil
	end)

	if not ok and player == Players.LocalPlayer and not warnedMissingMotor then
		warnedMissingMotor = true
		warn("[MemoryGame] No se encontró motor/IK del brazo para el gesto de volteo")
	end
end

function FlipArmGesture.playLocal()
	FlipArmGesture.playForPlayer(Players.LocalPlayer)
end

return FlipArmGesture
