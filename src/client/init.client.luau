local CardInteraction = require(script.CardInteraction)
local ShopUI = require(script.ShopUI)

local ok, err = pcall(function()
	CardInteraction.init()
	ShopUI.init()
end)

if ok then
	warn("[MemoryGame] Cliente iniciado correctamente")
else
	warn("[MemoryGame] Error al iniciar cliente:", err)
end
