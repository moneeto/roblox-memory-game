local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FlipArmGesture = {}

local REACH_OUT = 0.16
local REACH_HOLD = 0.05
local REACH_BACK = 0.22
local playingByCharacter: { [Model]: boolean } = {}

local function findMotor(character: Model, name: string): Motor6D?
	for _, inst in character:GetDescendants() do
		if inst:IsA("Motor6D") and inst.Name == name then
			return inst
		end
	end
	return nil
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
			alpha = alpha * alpha * (3 - 2 * alpha) -- smoothstep
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

local function playR15(character: Model): boolean
	local shoulder = findMotor(character, "RightShoulder")
	local elbow = findMotor(character, "RightElbow")
	if not (shoulder and elbow) then
		return false
	end

	playTransforms(character, {
		[shoulder] = CFrame.Angles(math.rad(-70), math.rad(15), math.rad(25)),
		[elbow] = CFrame.Angles(math.rad(-40), 0, math.rad(10)),
	})
	return true
end

local function playR6(character: Model): boolean
	local shoulder = findMotor(character, "Right Shoulder")
	if not shoulder then
		return false
	end

	playTransforms(character, {
		[shoulder] = CFrame.Angles(math.rad(-90), math.rad(20), math.rad(30)),
	})
	return true
end

function FlipArmGesture.playForPlayer(player: Player?)
	if not player then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	if playingByCharacter[character] then
		return
	end

	playingByCharacter[character] = true
	local ok = playR15(character) or playR6(character)
	task.delay(REACH_OUT + REACH_HOLD + REACH_BACK + 0.1, function()
		playingByCharacter[character] = nil
	end)

	if not ok and player == Players.LocalPlayer then
		warn("[MemoryGame] No se encontró motor del brazo para el gesto de volteo")
	end
end

function FlipArmGesture.playLocal()
	FlipArmGesture.playForPlayer(Players.LocalPlayer)
end

return FlipArmGesture
