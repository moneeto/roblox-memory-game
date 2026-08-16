local PlazaConfig = {}

-- Altura del piso de la plaza. Si tus árboles/terreno están en Y≈0 y no ves las mesas,
-- bajá este valor (ej. 0) o subí la cámara en Play.
PlazaConfig.BASE_Y = 20
PlazaConfig.BUILD_ENVIRONMENT = true
PlazaConfig.DESTROY_BASEPLATE = true

PlazaConfig.SOLO_COUNT = 3
PlazaConfig.VERSUS_COUNT = 6

-- Posiciones de mesas en la plaza (X, Z relativos al centro)
PlazaConfig.SOLO_OFFSETS = {
	Vector3.new(-48, 0, -32),
	Vector3.new(-48, 0, 0),
	Vector3.new(-48, 0, 32),
}

PlazaConfig.VERSUS_OFFSETS = {
	Vector3.new(-16, 0, -32),
	Vector3.new(16, 0, -32),
	Vector3.new(48, 0, -32),
	Vector3.new(-16, 0, 32),
	Vector3.new(16, 0, 32),
	Vector3.new(48, 0, 32),
}

function PlazaConfig.getSpawnPosition(): Vector3
	return Vector3.new(0, PlazaConfig.BASE_Y + 0.5, 0)
end

function PlazaConfig.getFloorPosition(offset: Vector3): Vector3
	return Vector3.new(offset.X, PlazaConfig.BASE_Y, offset.Z)
end

return PlazaConfig
