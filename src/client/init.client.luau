local CardInteraction = require(script.CardInteraction)

local ok, err = pcall(function()
	CardInteraction.init()
end)

if ok then
	warn("[MemoryGame] Cliente iniciado correctamente")
else
	warn("[MemoryGame] Error al iniciar cliente:", err)
end
