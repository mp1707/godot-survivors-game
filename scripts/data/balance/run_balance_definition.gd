extends Resource
class_name RunBalanceDefinition

@export var player_definition: PlayerDefinition
@export var level_progression: LevelProgression
@export var wave_definition: WaveDefinition
@export var spawn_pacing_definition: SpawnPacingDefinition
@export var progression_catalog: ProgressionCatalog

func is_valid() -> bool:
	return player_definition != null \
		and level_progression != null \
		and wave_definition != null \
		and spawn_pacing_definition != null \
		and progression_catalog != null
