# Survivors Game – Architektur (Balancing Refactor)

## 1. Zielbild

Balancing ist datengetrieben und zentral orchestriert:

- Zentraler Einstieg pro Run: `RunBalanceDefinition`
- Expliziter Progression-Datenkatalog: `ProgressionCatalog`
- Spawn-Druck in eigener Datenquelle: `SpawnPacingDefinition`
- Projektil-Balance in eigener Datenquelle: `ProjectileDefinition`
- Upgrade-Anwendung ueber dedizierte Applier statt ID-basierter Handler

## 2. Zentrale Balance-Resources

### 2.1 Run-Einstieg

- `resources/balance/runs/default_run_balance.tres`
- Script: `scripts/data/balance/run_balance_definition.gd`

Enthaelt Referenzen auf:

- `player_definition` (`PlayerDefinition`)
- `level_progression` (`LevelProgression`)
- `wave_definition` (`WaveDefinition`)
- `spawn_pacing_definition` (`SpawnPacingDefinition`)
- `progression_catalog` (`ProgressionCatalog`)

### 2.2 Progression-Daten

- `scripts/data/progression/progression_catalog.gd`
- `resources/progression/catalogs/default_progression_catalog.tres`

Explizite Listen:

- `abilities: Array[AbilityDefinition]`
- `upgrades: Array[UpgradeDefinition]`

Wichtig: Keine implizite Ordner-Discovery mehr.

### 2.3 Spawn-Pacing

- `scripts/data/balance/spawn_pacing_definition.gd`
- `resources/balance/spawn/default_spawn_pacing.tres`

Steuert:

- Spawn-Intervall ueber Zeit/Wave
- optionalen Spawn-Batch-Multiplikator

### 2.4 Projektil-Balance

- `scripts/data/progression/projectile_definition.gd`
- `resources/progression/projectiles/*.tres`

Steuert u. a.:

- Lifetime
- CollisionShape-Scale
- Rotation-Mode
- Bounce-Targeting und Bounce-Step
- Kontaktverhalten bei Nicht-Enemy-Kollision

## 3. Runtime-Orchestrierung

### 3.1 Main

- Script: `scripts/main.gd`
- Scene: `scenes/main.tscn`

Verantwortung:

- liest genau eine `run_balance`-Resource
- versorgt Player/Progression vor `Player._ready()` mit Run-Daten (`_enter_tree`)
- erstellt Runtime-Systeme (`EnemySpawner`, `LevelUpController`, `GameHud`)
- steuert Wave-Timer technisch; Spawn-Tempo kommt aus `SpawnPacingDefinition`

### 3.2 Player / Progression

- `scripts/player/player.gd`
- `scripts/player/player_progression.gd`
- `scripts/player/ability_progression_model.gd`

Verantwortung:

- Player liest nur `PlayerDefinition` als Balance-Quelle
- `AbilityProgressionModel` baut Progression/Level-Up Daten aus `ProgressionCatalog`
- Utility-Upgrade-Anwendung via `UtilityUpgradeApplier`
- Weapon-Upgrade-Anwendung via `WeaponUpgradeApplier`

### 3.3 Level-Up Pipeline

- `scripts/systems/level_up_controller.gd`
- `scripts/systems/level_up_option_service.gd`

Verantwortung:

- `LevelUpController`: Queue + Popup-Flow
- `LevelUpOptionService`: finaler 3er-Option-Satz inkl. Milestone-Priorisierung
- Option-Pool kommt zentral aus `AbilityProgressionModel.get_level_up_options(level)`

### 3.4 Combat / Projectiles

- `scripts/player/player_weapon_system.gd`
- `scripts/abilities/laser_projectile.gd`

Verantwortung:

- WeaponSystem instanziert Projektil und uebergibt Ability-Stats + `ProjectileDefinition`
- Projektil-Script enthaelt nur technische Fallbacks; Balancewerte kommen aus Daten

## 4. Upgrade-System

### 4.1 Datenmodell

- `scripts/data/progression/upgrade_definition.gd.gd`
- `scripts/data/progression/upgrade_effect.gd`

`UpgradeDefinition` kann jetzt strukturierte `effects` enthalten:

- `target_domain`
- `stat_key`
- `operation`
- `value`
- optionale Clamps (`min_value`, `max_value`)

### 4.2 Anwendung

- `scripts/progression/weapon_upgrade_applier.gd`
- `scripts/progression/utility_upgrade_applier.gd`

Prinzip:

- neue Upgrades werden primaer als Daten (`effects`) angelegt
- Legacy-Felder (`upgrade_type`, `numeric_value`) bleiben als kompatibler Fallback

## 5. Verantwortlichkeitsgrenzen

- `main.gd`: Orchestrierung, kein Balancing-Hardcode
- `EnemySpawner`: Spawn-Komposition + Pacing-Auswertung
- `AbilityProgressionModel`: Progression-Read/Write + Option-Pool
- `LevelUpOptionService`: Option-Selection-Regeln
- Applier: Upgrade-Effektanwendung pro Domain
- Resource-Definitions: Single Source of Truth fuer Balance

## 6. Fail-Fast / Integrity

- fehlendes `RunBalanceDefinition`-Setup -> `push_error`
- fehlende Definitionen in `Player`/`Enemy` -> `push_error` + Abbruch
- `ProgressionCatalog` validiert fehlende/duplizierte IDs beim Laden
