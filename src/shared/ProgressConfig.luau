local ProgressConfig = {}

-- Puntos base por pareja encontrada
ProgressConfig.BASE_POINTS_PER_MATCH = 100

--[[
	Multiplicador de racha:
	  Racha 1 → x1.0
	  Racha 2 → x1.5
	  Racha 3 → x2.0
	  Racha N → 1 + (N - 1) * 0.5
]]
function ProgressConfig.getStreakMultiplier(streak: number): number
	local n = math.max(0, math.floor(streak))
	if n <= 0 then
		return 1
	end
	return 1 + (n - 1) * 0.5
end

function ProgressConfig.calculateMatchPoints(streak: number): number
	local multiplier = ProgressConfig.getStreakMultiplier(streak)
	return math.floor(ProgressConfig.BASE_POINTS_PER_MATCH * multiplier + 0.5)
end

return ProgressConfig
