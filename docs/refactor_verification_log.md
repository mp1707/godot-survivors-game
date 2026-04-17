# Balancing Refactor Verification Log

## Phase 0

- Ergebnis: `docs/balance_baseline_snapshot.md` und `docs/manual_balance_regression_checklist.md` angelegt.
- Verifikation: Baseline-Werte aus aktuellen `.tres` und Runtime-Balancefeldern dokumentiert; Checkliste deckt Level-Up, Combat, Spawn und Data Integrity ab.

## Phase 1

- Ergebnis: `LevelUpController` enthaelt keine eigene Option-Build-/Random-Logik mehr.
- Verifikation:
  - neue Service-Klasse `scripts/systems/level_up_option_service.gd` eingebunden.
  - `LevelUpController` ruft nur noch Service + `AbilityProgressionModel.apply_option(...)` auf.
  - `AbilityProgressionModel.get_level_up_options(...)` liefert den zentralen Optionen-Pool fuer den Service.

## Phase 2

- Ergebnis: implizite Directory-Discovery durch expliziten `ProgressionCatalog` ersetzt.
- Verifikation:
  - neue Resource-/Script-Typen: `ProgressionCatalog` + `default_progression_catalog.tres`.
  - `AbilityProgressionModel` laedt Abilities/Upgrades ausschliesslich aus Catalog (inkl. Duplicate-/Missing-ID Checks).
  - `Player` initialisiert das Model mit Catalog (`scenes/player.tscn` referenziert den Default-Catalog).

## Phase 3

- Ergebnis: Spawn-Pacing ist in `SpawnPacingDefinition` zentralisiert.
- Verifikation:
  - `EnemySpawner` verarbeitet Intervall + Batch-Multiplikator datengetrieben.
  - `main.gd` setzt Timer-Wait-Time pro Tick aus Spawner/Pacing-Definition.
  - `scenes/main.tscn` nutzt `default_spawn_pacing.tres`; Timer-Autostart wurde entfernt (technischer Trigger, nicht Balancequelle).

## Phase 4

- Ergebnis: Projektil-Balancewerte sind in `ProjectileDefinition` zentralisiert.
- Verifikation:
  - neue Datenklasse `scripts/data/progression/projectile_definition.gd` + 3 Projektil-Resources.
  - `AbilityDefinition` referenziert jetzt `projectile_definition`; betroffene Ability-Resources migriert.
  - `PlayerWeaponSystem` uebergibt `projectile_definition` an Projektil-Instanzen.
  - `laser_projectile.gd` liest Lifetime/Rotation/Bounce/Contact-Hardwerte aus `ProjectileDefinition`.
  - Szenenwert `energy_ball_projectile.tscn:lifetime` entfernt (jetzt Datenquelle Resource).

## Phase 5

- Ergebnis: Upgrade-Effekte laufen ueber datengetriebene `UpgradeEffect`-Listen und dedizierte Applier.
- Verifikation:
  - neue Daten-/Runtime-Typen: `UpgradeEffect`, `WeaponUpgradeApplier`, `UtilityUpgradeApplier`.
  - `AbilityProgressionModel` delegiert Waffen-/Utility-Anwendung an Applier statt Handler-Registry.
  - `Player` enthaelt nur noch fachliche Utility-Stat-Operationen, keine Upgrade-ID-Matchlogik.
  - Upgrade-Resources unter `resources/progression/upgrades/**` auf `effects` migriert; Legacy-Felder bleiben als kompatibler Fallback bestehen.

## Phase 6

- Ergebnis: konkurrierende Runtime-Balance-Defaults bereinigt; Definitions sind verpflichtende Quelle.
- Verifikation:
  - `Player` und `Enemy` nutzen nur technische Initialwerte und brechen bei fehlender Definition fail-fast ab (`push_error`, Processing stop/cleanup).
  - `WeaponAbilityState` nutzt neutrale Initialwerte und markiert fehlende AbilityDefinition explizit.
  - Balancerelevante Startwerte liegen damit fachlich in `PlayerDefinition`/`EnemyDefinition`/`AbilityDefinition`.

## Phase 7

- Ergebnis: `RunBalanceDefinition` ist zentraler Run-Einstiegspunkt.
- Verifikation:
  - `main.gd` exportiert nur noch `run_balance` und verteilt Daten an Player/Progression/Spawner.
  - `scenes/main.tscn` referenziert nur `resources/balance/runs/default_run_balance.tres` fuer Balancing-Setup.
  - zentrale Run-Resource verknuepft PlayerDefinition, LevelProgression, WaveDefinition, SpawnPacingDefinition und ProgressionCatalog.
