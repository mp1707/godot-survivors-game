# Survivors Game – Architektur (Balancing Refactor)

## 1. Zielbild

Balancing ist datengetrieben und zentral orchestriert:

- Zentraler Einstieg pro Run: `RunBalanceDefinition`
- Expliziter Progression-Datenkatalog: `ProgressionCatalog`
- Spawn-Druck in eigener Datenquelle: `SpawnPacingDefinition`
- Projektil-Balance in eigener Datenquelle: `ProjectileDefinition`
- Upgrade-Anwendung ueber dedizierte Applier statt ID-basierter Handler
- Enemy-Targeting ueber zentrale Runtime-Registry statt globaler Group-Scans

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

Integrity-API:

- `validate() -> bool`
- `get_validation_errors() -> PackedStringArray`

Validiert u. a.:

- Null-/Duplicate-/Empty-ID-Faelle bei Abilities und Upgrades
- `ability.upgrade_ids` Cross-References
- Ability-Icons (`action_bar_icon`, `upgrade_icon`)

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
- fuehrt fruehes Fail-Fast fuer `ProgressionCatalog.validate()` aus (vor Runtime-Systemaufbau)
- erstellt Runtime-Systeme (`EnemySpawner`, `LevelUpController`, `GameHud`)
- steuert Wave-Timer technisch; Spawn-Tempo kommt aus `SpawnPacingDefinition`

### 3.2 Player / Progression

- `scripts/player/player.gd`
- `scripts/player/player_progression.gd`
- `scripts/player/ability_progression_model.gd`

Verantwortung:

- Player liest nur `PlayerDefinition` als Balance-Quelle
- `AbilityProgressionModel` baut Progression/Level-Up Daten aus `ProgressionCatalog`
- `AbilityProgressionModel` liefert zentrale Ability-Icons (inkl. Utility-Icons fuer UI)
- Utility-Upgrade-Anwendung via `UtilityUpgradeApplier`
- Weapon-Upgrade-Anwendung via `WeaponUpgradeApplier`

#### 3.2.1 Player-Komposition (Component-Pattern)

`Player` ist ein schlanker Orchestrator. Mechaniken leben in fokussierten Child-Node-Komponenten unter `scripts/player/components/`:

- `PlayerVitals` — Health, Mana, Invuln-Frames, XP-Magnet-Radius. Owner aller Vitals-Signals (`health_changed`, `mana_changed`, `mana_preview_changed`, `died`); Player re-emittiert sie als oeffentliche API.
- `BarrierController` — Lifetime/Absorption/Reflect + Barrier-Sprite. Wird von `Player.apply_damage` vor `Vitals.take_damage` konsultiert (`try_absorb`).
- `DashController` — Dash-State, Cooldown, Phase-Through-Collision-Mask, Afterimage-Spawn. Besitzt `move_and_slide` waehrend des Dashs.
- `KiChargeController` — Charge-State, Mana-Regen-Boost waehrend Charge, AOE-Release, Aura-Sprite + Audio-Loop. Emittiert `charge_state_changed`/`released`.
- `PlayerAnimationController` — Walk/Idle/Shoot/Charging-Animationen auf `AnimatedSprite2D`.

Player verteilt `PlayerDefinition` ueber `component.configure(definition)`, injiziert Cross-Refs ueber `component.setup(...)` und orchestriert `_physics_process` als sequenzielle Pipeline.

Neue Mechaniken werden als zusaetzliche Komponente angelegt; `_physics_process` bekommt einen Slot in der Pipeline. Neue Utility-Upgrades hooken via `UtilityUpgradeApplier._build_handler_registry()` direkt auf die Komponenten-Methoden (z. B. `Callable(player.get_dash(), "adjust_cooldown")`).

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
- Projektil-Script liest Balancewerte ausschliesslich aus `ProjectileDefinition`
- Projektil-Parent wird via `Player.attach_projectile_parent($Projectiles)` aus `main.gd` injiziert (analog `EnemySpawner._enemies_parent`); kein `get_tree().current_scene.add_child()` mehr

### 3.5 Enemy Registry

- Script: `scripts/systems/enemy_registry.gd`
- Autoload: `EnemyRegistry` (in `project.godot`)

Verantwortung:

- zentrale Registry aktiver Enemies
- Query-APIs fuer Combat-Targeting:
  - `find_nearest_enemy(...)`
  - `get_enemies_in_radius(...)`
- `Enemy` registriert/deregistriert sich lifecycle-sicher (`_ready`/`_exit_tree`)

## 4. Upgrade-System

### 4.1 Datenmodell

- `scripts/data/progression/upgrade_definition.gd`
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
- `effects` sind verpflichtend; Legacy-Felder wurden entfernt
- Anwendung ist atomar (Prevalidate + Apply), kein Teil-Apply bei Fehlern
- Utility-Applier nutzt stat-key-basierte Dispatcher-Registry statt harter Match-Kaskade
- Utility-Handler-Callables zeigen direkt auf die zustaendige Player-Komponente (z. B. `Callable(player.get_dash(), "adjust_cooldown")`); keine Proxy-Methoden auf `Player`

## 5. Verantwortlichkeitsgrenzen

- `main.gd`: Orchestrierung, kein Balancing-Hardcode
- `EnemySpawner`: Spawn-Komposition + Pacing-Auswertung
- `EnemyRegistry`: zentrale Enemy-Queries fuer Combat-Hotpaths
- `AbilityProgressionModel`: Progression-Read/Write + Option-Pool
- `GameHud` + `ActionButtonBar`: UI-Icons aus aktivem Progression-Modell statt harter Resource-Pfade
- `LevelUpOptionService`: Option-Selection-Regeln
- Applier: Upgrade-Effektanwendung pro Domain
- Resource-Definitions: Single Source of Truth fuer Balance
- `Player`: Orchestrator + oeffentliche Signal-/Methoden-API; keine Mechanik-Logik
- `PlayerVitals`: Health, Mana, Invuln, XP-Magnet; alleiniger Owner der Vitals-Signals
- `BarrierController`: Damage-Absorption + Reflect; vor `Vitals.take_damage` konsultiert
- `DashController`: Dash-State, Cooldown, Phase-Through-Mask, Afterimage-Spawn
- `KiChargeController`: Charge-State, AOE-Release, Aura + Charge-Audio-Loop
- `PlayerAnimationController`: alle `AnimatedSprite2D`-State-Transitions des Players

## 6. Fail-Fast / Integrity

- fehlendes `RunBalanceDefinition`-Setup -> `push_error`
- fehlende Definitionen in `Player`/`Enemy` -> `push_error` + Abbruch
- `ProgressionCatalog` wird vor Runtime-Systemaufbau validiert (`validate()` + Fehlerreport)
- ungeltige Catalog-/Cross-Reference-/Icon-Daten brechen den Run-Setup frueh ab
