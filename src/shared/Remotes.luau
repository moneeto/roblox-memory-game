local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"RequestFlip",
	"RequestRematch",
	"RequestQuit",
	"CardRevealed",
	"CardHidden",
	"MatchFound",
	"MismatchFound",
	"TurnChanged",
	"GameStarted",
	"GameEnded",
	"GamePaused",
	"GameResumed",
	"GameCancelled",
	-- Progresión / tienda
	"StreakUpdated",
	"PointsAwarded",
	"PlayerDataUpdated",
	"RequestPlayerData",
	"RequestPurchaseSkin",
	"RequestEquipSkin",
	"RequestPurchaseMemePack",
	"ShopResult",
}

local Remotes = {}

function Remotes.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if RunService:IsServer() then
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end

		for _, name in REMOTE_NAMES do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	end

	if not folder then
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end

	for _, name in REMOTE_NAMES do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
