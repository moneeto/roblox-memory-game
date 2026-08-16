local SoundConfig = {}

-- Sonidos minimalistas (cortos / suaves)
SoundConfig.FLIP = "rbxasset://sounds/switch.wav"
SoundConfig.MATCH = "rbxasset://sounds/electronicpingshort.wav"
SoundConfig.MISMATCH = "rbxasset://sounds/switch.wav"
SoundConfig.WIN = "rbxasset://sounds/electronicpingshort.wav"

SoundConfig.VOLUMES = {
	FLIP = 0.22,
	MATCH = 0.28,
	MISMATCH = 0.18,
	WIN = 0.32,
}

-- Velocidad de reproducción para un feel más limpio
SoundConfig.PLAYBACK_SPEEDS = {
	FLIP = 1.35,
	MATCH = 1.15,
	MISMATCH = 0.75,
	WIN = 0.9,
}

return SoundConfig
