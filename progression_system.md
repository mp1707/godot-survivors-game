# Progression System (nach Balancing Refactor)

## 1. Kernprinzip

Progression ist explizit datengetrieben:

- Abilities/Upgrades kommen aus `ProgressionCatalog`
- Level-Up Optionen kommen aus `AbilityProgressionModel` + `LevelUpOptionService`
- Upgrade-Wirkung kommt aus `UpgradeEffect` + Applier

Keine implizite Ordner-Discovery, keine doppelte Level-Up-Build-Logik.

## 2. Zentrale Bausteine

### 2.1 Data

- `scripts/data/progression/progression_catalog.gd`
- `resources/progression/catalogs/default_progression_catalog.tres`

enthaelt:

- `abilities: Array[AbilityDefinition]`
- `upgrades: Array[UpgradeDefinition]`

### 2.2 Model

- `scripts/player/ability_progression_model.gd`

Aufgaben:

- Weapon-Slots und Ability-States verwalten
- Utility-Upgrade-States verwalten
- Option-Pool fuer Level-Up bauen (`get_level_up_options(level)`)
- gewaehlte Option anwenden (`apply_option`)

### 2.3 Option-Auswahl

- `scripts/systems/level_up_option_service.gd`
- `scripts/systems/level_up_controller.gd`

Ablauf:

1. Controller bekommt `leveled_up(level)`.
2. Service liest Option-Pool aus Model.
3. Service waehlt finale Optionen (Standard: 3), inkl. Unlock-Milestone-Priorisierung.
4. Popup zeigt Optionen; Auswahl geht zurueck an `AbilityProgressionModel.apply_option`.

## 3. Upgrade-Effekte

### 3.1 Datenstruktur

- `scripts/data/progression/upgrade_effect.gd`
- `UpgradeDefinition.effects: Array[UpgradeEffect]`

`UpgradeEffect`-Felder:

- `target_domain` (`weapon_state` / `player`)
- `stat_key`
- `operation` (`add`, `clamp_add`, `set_true`, ...)
- `value`
- `min_value`, `max_value`

### 3.2 Runtime-Anwendung

- `scripts/progression/weapon_upgrade_applier.gd`
- `scripts/progression/utility_upgrade_applier.gd`

Regel:

- Wenn `effects` gesetzt sind: datengetriebene Anwendung.
- Wenn `effects` leer sind: Legacy-Fallback (`upgrade_type`/`numeric_value`).

Damit bleibt Migration robust, ohne Big-Bang.

## 4. Utility-Upgrades (Player)

Utility-Upgrades mutieren Player-Stats ueber klar benannte Methoden in `player.gd`:

- `adjust_dash_cooldown(...)`
- `adjust_dash_distance(...)`
- `unlock_dash_invulnerable()`
- `unlock_dash_phase()`
- `adjust_charge_ki_regen(...)`
- `adjust_ki_release_knockback(...)`
- `adjust_ki_release_aoe_damage(...)`

Kein ID-basierter Handler-Registrierungscode mehr im Model.

## 5. Weapon-Upgrades

Weapon-Upgrades mutieren `WeaponAbilityState` ueber `WeaponUpgradeApplier`.

Typische Stat-Keys in Effekten:

- `cost_upgrade_count`
- `damage_upgrade_count`
- `pierce_upgrade_count`
- `speed_upgrade_count`
- `bounce_upgrade_count`
- `size_upgrade_count`
- `barrier_absorb_upgrade_count`
- `barrier_lifetime_upgrade_count`
- `barrier_reflect_unlocked`
- `charge_speed_upgrade_count`

## 6. Integritaetsregeln

- `ProgressionCatalog` ist Pflicht fuer `AbilityProgressionModel.initialize(...)`.
- Fehlende oder doppelte IDs im Catalog werden als Fehler geloggt.
- Utility-States werden aus dem Upgrade-Katalog (Domain `utility`) aufgebaut.

## 7. Erweiterung

### Neue Ability

1. `AbilityDefinition`-Resource anlegen.
2. In `default_progression_catalog.tres` unter `abilities` eintragen.
3. Optional: `projectile_definition` referenzieren.

### Neues Upgrade

1. `UpgradeDefinition`-Resource anlegen.
2. `effects` definieren (`target_domain`, `stat_key`, `operation`, `value`).
3. In `default_progression_catalog.tres` unter `upgrades` eintragen.
4. Ability `upgrade_ids` (falls weapon-bound) erweitern.

### Neues Utility-Stat-Ziel

1. neuen `stat_key` in Utility-Upgrade-Resource verwenden.
2. genau einmal in `UtilityUpgradeApplier` auf Player-Methode mappen.
3. Player-Methode kapselt Seiteneffekte (z. B. Dash-Phasing waehrend aktiver Dash-Phase).
