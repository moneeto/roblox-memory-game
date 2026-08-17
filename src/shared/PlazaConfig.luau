local PlazaConfig = {}

--[[
	Layout place (Documents/memory-game-roblox.rbxl):

	White izq:  center (-35.85, 2000.04, 21.30)  size ~60 × 118
	White der:  center ( 24.20, 2000.04, 21.30)  size ~60 × 118
	Pasillo:    X ≈ -5.8 entre ambas; franja bordó en Z ≈ 15..28
	Spawn:      (-5.82, 2000.14, -26.95)
	Dorado:     Z ≈ -52

	1 hilera centrada en cada blanca; 5 mesas equiespaciadas en Z.
]]

PlazaConfig.BASE_Y = 2001.04

PlazaConfig.BUILD_ENVIRONMENT = false
PlazaConfig.DESTROY_BASEPLATE = false
PlazaConfig.ENSURE_SPAWN = false

PlazaConfig.TABLE_YAW = math.rad(90)

PlazaConfig.SOLO_COUNT = 4
PlazaConfig.VERSUS_COUNT = 6

-- Centros X de cada plataforma blanca
local ROW_LEFT = -35.85
local ROW_RIGHT = 24.20

-- Z equiespaciado en el largo blanco (-37.8 .. 80.3), margen ~18
-- Orden: Solo · Solo · 1v1 · 1v1 · 1v1
local COL = { -20, 1, 22, 43, 64 }

PlazaConfig.SOLO_OFFSETS = {
	Vector3.new(ROW_LEFT, 0, COL[1]),
	Vector3.new(ROW_LEFT, 0, COL[2]),
	Vector3.new(ROW_RIGHT, 0, COL[1]),
	Vector3.new(ROW_RIGHT, 0, COL[2]),
}

PlazaConfig.VERSUS_OFFSETS = {
	Vector3.new(ROW_LEFT, 0, COL[3]),
	Vector3.new(ROW_LEFT, 0, COL[4]),
	Vector3.new(ROW_LEFT, 0, COL[5]),
	Vector3.new(ROW_RIGHT, 0, COL[3]),
	Vector3.new(ROW_RIGHT, 0, COL[4]),
	Vector3.new(ROW_RIGHT, 0, COL[5]),
}

function PlazaConfig.getSpawnPosition(): Vector3
	return Vector3.new(-5.82, PlazaConfig.BASE_Y + 0.5, -26.95)
end

function PlazaConfig.getFloorPosition(offset: Vector3): Vector3
	return Vector3.new(offset.X, PlazaConfig.BASE_Y, offset.Z)
end

return PlazaConfig
