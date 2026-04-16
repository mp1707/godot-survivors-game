extends Resource
class_name WaveStage

@export var normal_enemy: EnemyDefinition
@export var elite_enemy: EnemyDefinition
@export var enemy_count: int = 100
@export_range(0.0, 1.0, 0.01) var elite_chance: float = 0.08

func pick_enemy(rng: RandomNumberGenerator) -> EnemyDefinition:
	if elite_enemy != null and rng.randf() < elite_chance:
		return elite_enemy
	return normal_enemy
