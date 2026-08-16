local CardData = {}

CardData.MODES = {
	Solo = "Solo",
	Versus = "Versus",
}

CardData.GRID = {
	Solo = { rows = 4, cols = 3 },
	Versus = { rows = 4, cols = 4 },
}

CardData.MISMATCH_DELAY = 1.15
CardData.FLIP_DURATION = 0.35
CardData.SHUFFLE_DURATION = 1.2

CardData.CARD_BACK_COLOR = Color3.fromRGB(52, 73, 94)

CardData.PAIRS = {
	{ id = 1, color = Color3.fromRGB(231, 76, 60), symbol = "A" },
	{ id = 2, color = Color3.fromRGB(46, 204, 113), symbol = "B" },
	{ id = 3, color = Color3.fromRGB(52, 152, 219), symbol = "C" },
	{ id = 4, color = Color3.fromRGB(241, 196, 15), symbol = "D" },
	{ id = 5, color = Color3.fromRGB(155, 89, 182), symbol = "E" },
	{ id = 6, color = Color3.fromRGB(230, 126, 34), symbol = "F" },
	{ id = 7, color = Color3.fromRGB(26, 188, 156), symbol = "G" },
	{ id = 8, color = Color3.fromRGB(236, 72, 153), symbol = "H" },
}

function CardData.getGridForMode(mode: string): (number, number)
	local grid = CardData.GRID[mode] or CardData.GRID.Versus
	return grid.rows, grid.cols
end

function CardData.getTotalCards(mode: string): number
	local rows, cols = CardData.getGridForMode(mode)
	return rows * cols
end

function CardData.getPairCount(mode: string): number
	return CardData.getTotalCards(mode) / 2
end

function CardData.getPairById(id: number)
	for _, pair in CardData.PAIRS do
		if pair.id == id then
			return pair
		end
	end
	return CardData.PAIRS[1]
end

return CardData
