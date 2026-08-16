local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local PlazaBuilder = require(script.PlazaBuilder)
local TableManager = require(script.TableManager)

local ok, err = pcall(function()
	Remotes.init()
	PlazaBuilder.init()
	TableManager.init(Remotes)
end)

if ok then
	warn("[MemoryGame] Servidor iniciado correctamente")
else
	warn("[MemoryGame] Error al iniciar servidor:", err)
end
