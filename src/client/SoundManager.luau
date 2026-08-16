local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundConfig = require(Shared.SoundConfig)

local SoundManager = {}

local soundFolder: Folder? = nil

local function getFolder(): Folder
	if soundFolder and soundFolder.Parent then
		return soundFolder
	end

	local existing = SoundService:FindFirstChild("MemoryGameSounds")
	if existing and existing:IsA("Folder") then
		existing:Destroy()
	end

	soundFolder = Instance.new("Folder")
	soundFolder.Name = "MemoryGameSounds"
	soundFolder.Parent = SoundService

	local definitions = {
		{ name = "Flip", id = SoundConfig.FLIP, volume = SoundConfig.VOLUMES.FLIP, speed = SoundConfig.PLAYBACK_SPEEDS.FLIP },
		{ name = "Match", id = SoundConfig.MATCH, volume = SoundConfig.VOLUMES.MATCH, speed = SoundConfig.PLAYBACK_SPEEDS.MATCH },
		{ name = "Mismatch", id = SoundConfig.MISMATCH, volume = SoundConfig.VOLUMES.MISMATCH, speed = SoundConfig.PLAYBACK_SPEEDS.MISMATCH },
		{ name = "Win", id = SoundConfig.WIN, volume = SoundConfig.VOLUMES.WIN, speed = SoundConfig.PLAYBACK_SPEEDS.WIN },
	}

	for _, definition in definitions do
		local sound = Instance.new("Sound")
		sound.Name = definition.name
		sound.SoundId = definition.id
		sound.Volume = definition.volume
		sound.PlaybackSpeed = definition.speed
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = soundFolder
	end

	return soundFolder
end

function SoundManager.play(soundName: string, parent: Instance?)
	local folder = getFolder()
	local template = folder:FindFirstChild(soundName) :: Sound?
	if not template then
		return
	end

	local sound = template:Clone()
	sound.Parent = parent or SoundService
	sound:Play()

	local conn: RBXScriptConnection?
	conn = sound.Ended:Connect(function()
		if conn then
			conn:Disconnect()
		end
		sound:Destroy()
	end)

	task.delay(3, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function SoundManager.playFlip(at: Instance?)
	SoundManager.play("Flip", at)
end

function SoundManager.playMatch(at: Instance?)
	SoundManager.play("Match", at)
end

function SoundManager.playMismatch(at: Instance?)
	SoundManager.play("Mismatch", at)
end

function SoundManager.playWin(at: Instance?)
	SoundManager.play("Win", at)
end

return SoundManager
