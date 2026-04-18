# Survivors Game Architekturuebersicht

Diese Datei beschreibt den **aktuellen Implementierungsstand** der Architektur. Fokus: Systemgrenzen, Datenfluss, Signalfluss, Runtime-Pipelines und Erweiterungspunkte.

## 1. Gesamtbild
Das Spiel wird zentral durch `main.gd` orchestriert. Balancing und Progression sind datengetrieben, Gameplay-Logik ist in spezialisierte Runtime-Systeme aufgeteilt.

```mermaid
flowchart TB
    subgraph Data
        RB["RunBalanceDefinition"]
        PD["PlayerDefinition"]
        LP["LevelProgression"]
        WD["WaveDefinition"]
        SP["SpawnPacingDefinition"]
        PC["ProgressionCatalog"]
        AD["AbilityDefinition"]
        UD["UpgradeDefinition"]
        PDE["ProjectileDefinition"]
    end

    subgraph Runtime
        MAIN["main.gd"]
        PLAYER["Player"]
        CD["AbilityCooldownRuntime"]
        SPW["EnemySpawner"]
        LUC["LevelUpController"]
        HUD["GameHud"]
        ORB["XPOrbManager"]
        REG["EnemyRegistry Autoload"]
    end

    RB --> PD
    RB --> LP
    RB --> WD
    RB --> SP
    RB --> PC
    PC --> AD
    PC --> UD
    AD --> PDE

    RB --> MAIN
    MAIN --> PLAYER
    PLAYER --> CD
    MAIN --> SPW
    MAIN --> LUC
    MAIN --> HUD
    MAIN --> ORB
    REG --> SPW
    REG --> PLAYER
```

## 2. Boot- und Setup-Flow
`main.gd` schreibt die Run-Daten bereits in `_enter_tree` in die Szenenknoten. Danach validiert `_ready` den Catalog erneut und startet Runtime-Systeme.

```mermaid
sequenceDiagram
    participant Main as main.gd
    participant RB as RunBalanceDefinition
    participant Player as Player
    participant Catalog as ProgressionCatalog
    participant Spawner as EnemySpawner
    participant LUC as LevelUpController
    participant Hud as GameHud

    Main->>RB: read run_balance
    Main->>Player: set definition + progression_catalog
    Main->>Catalog: validate
    Main->>Player: get_progression_model
    Main->>Spawner: setup(player, wave, pacing, rng, enemies_parent)
    Main->>LUC: setup(player, progression_model, popup, rng)
    Main->>Hud: setup(player, progression_model, spawner, ui_refs)
    Main->>Player: attach_projectile_parent(projectiles)
```

## 3. Szenen- und Komponentenstruktur
Der Player ist ein Orchestrator; Mechanik liegt in Komponenten.

- `PlayerVitals`: HP, Mana, Invuln, XP-Magnetradius.
- `AbilityCooldownRuntime`: Global Cooldown (GCD) + ability-spezifische Cooldowns.
- `DashController`: Dash-Status, Kollision/Phase, Afterimages; Cooldown-Gating ueber Runtime.
- `KiChargeController`: Charge-Status, Regen-Boost, Release-AOE/Knockback.
- `BarrierController`: Absorb/Lifetime/Reflect vor Vitals-Schaden.
- `PlayerWeaponSystem`: Weapon-Slot-Input, Charge-Flow, Projektilspawns.
- `PlayerAnimationController`: Animationszustandslogik.

```mermaid
flowchart LR
    Input["InputMap Actions"] --> Player["Player"]
    Player --> Vitals["PlayerVitals"]
    Player --> Cooldowns["AbilityCooldownRuntime"]
    Player --> Dash["DashController"]
    Player --> Charge["KiChargeController"]
    Player --> Barrier["BarrierController"]
    Player --> Weapon["PlayerWeaponSystem"]
    Player --> Anim["PlayerAnimationController"]
    Cooldowns --> Dash
    Cooldowns --> Charge
    Cooldowns --> Weapon
    Weapon --> ProjectileParent["Projectiles Node"]
    Dash --> Move["CharacterBody2D move_and_slide"]
    Player --> Move
```

## 4. Player Runtime-Pipeline
Die Player-Loop ist explizit sequenziell. Prioritaeten:
1) Death/Invuln/Hit-Reaction,
2) Dash + Ki-Charge Gate,
3) Weapon-Update,
4) Movement + Animation.

```mermaid
flowchart TD
    A["Player physics tick"] --> B["Vitals invuln tick"]
    B --> C["AbilityCooldownRuntime tick (GCD + local)"]
    C --> D["Barrier lifetime tick"]
    D --> E["HitReaction physics step"]
    E --> F{"Dash start"}
    F --> G{"Ki Charge active"}
    G -->|yes| H["lock movement and weapon"]
    G -->|no| I["Mana regen + WeaponSystem physics_update"]
    I --> J{"Weapon charging"}
    J -->|yes| K["charging animation + no movement"]
    J -->|no| L{"Dash active"}
    L -->|yes| M["Dash update and move"]
    L -->|no| N["Normal movement + animation"]
```

## 5. Ability- und Upgrade-Architektur
Abilities (Weapon + Utility) laufen im selben Model (`AbilityProgressionModel`) ueber `AbilityState`.

- Weapon-Channel: Slots `action1..3`, Unlocks im Run moeglich.
- Utility-Channel: feste Utility-Slots mit `input_action` und `utility_slot_index`.
- Basis-Cooldown ist datengetrieben pro Ability (`AbilityDefinition.base_cooldown_seconds`).
- Aktivierung ist einheitlich: `can_activate(ability_id)` vor Cast und `commit_activation(ability_id)` bei erfolgreicher Aktivierung.
- Upgrades sind ability-gebunden (`UpgradeDefinition.ability_id`).

```mermaid
classDiagram
    class ProgressionCatalog {
      abilities
      upgrades
      validate()
    }
    class AbilityDefinition {
      id
      activation_channel
      input_action
      utility_slot_index
      base_cooldown_seconds
      upgrade_ids
    }
    class AbilityState {
      ability_id
      activation_channel
      slot_index
      utility_slot_index
      stat_fields
      upgrade_counters
    }
    class UpgradeDefinition {
      id
      ability_id
      max_stacks
      effects
      get_domain()
    }
    class UpgradeEffect {
      target_domain
      stat_key
      operation
      value
    }
    class AbilityProgressionModel {
      weapon_slots
      utility_slots
      get_ability_base_cooldown()
      adjust_ability_base_cooldown()
      get_level_up_options()
      apply_option()
      apply_weapon_upgrade()
      apply_utility_upgrade()
    }
    class AbilityCooldownRuntime {
      tick()
      can_activate()
      commit_activation()
      get_effective_remaining()
      get_effective_ratio()
    }

    ProgressionCatalog --> AbilityDefinition
    ProgressionCatalog --> UpgradeDefinition
    AbilityDefinition --> AbilityState
    UpgradeDefinition --> UpgradeEffect
    AbilityProgressionModel --> AbilityState
    AbilityProgressionModel --> UpgradeDefinition
    AbilityProgressionModel --> AbilityCooldownRuntime
```

## 6. Level-Up Pipeline
Optionen kommen zentral aus dem ProgressionModel; Auswahl und Pause-Handling liegen im Controller.

```mermaid
sequenceDiagram
    participant XP as PlayerProgression
    participant Player as Player
    participant LUC as LevelUpController
    participant Service as LevelUpOptionService
    participant Model as AbilityProgressionModel
    participant Popup as LevelUpPopup

    XP-->>Player: leveled_up(level)
    Player-->>LUC: leveled_up(level)
    LUC->>Service: build_options(level)
    Service->>Model: get_level_up_options(level)
    Model-->>Service: option_pool
    Service-->>LUC: 3 final options
    LUC->>Popup: present_options
    Popup-->>LUC: option_selected
    LUC->>Model: apply_option(option)
```

## 7. Combat- und Enemy-Flow
Enemies werden durch Timer-Ticks ueber `EnemySpawner` erzeugt. Projektile treffen `DamageableBody2D`-Subklassen (Enemy, Player).

```mermaid
flowchart LR
    Timer["WaveSpawnTimer timeout"] --> Spawner["EnemySpawner on_wave_tick"]
    Spawner --> Enemy["Enemy instance"]
    Enemy --> Registry["EnemyRegistry register"]

    Weapon["PlayerWeaponSystem"] --> Projectile["LaserProjectile"]
    Projectile --> Enemy
    Enemy -->|damage_taken| Spawner
    Spawner -->|enemy_damage_taken| Hud["GameHud floating damage"]

    Enemy -->|died| Spawner
    Spawner -->|enemy_died| Main["main.gd"]
    Main --> Orbs["XPOrbManager spawn_orb"]
    Orbs --> Orb["XPOrb"]
    Orb -->|collected| Orbs
    Orbs --> Player["collect_xp"]
```

## 8. Signalmatrix (Emitter -> Consumer)
Die wichtigsten Laufzeit-Signale und ihre Konsumenten:

| Emitter | Signal | Consumer | Zweck |
|---|---|---|---|
| `PlayerVitals` | `health_changed` | `Player` -> `PlayerUIController` | HP-UI aktualisieren |
| `PlayerVitals` | `mana_changed` | `Player` -> `PlayerUIController` | Mana-UI aktualisieren |
| `PlayerVitals` | `mana_preview_changed` | `Player` -> `PlayerUIController` | Charge-Mana-Preview |
| `PlayerVitals` | `died` | `Player` | Player-Tod propagieren |
| `PlayerProgression` | `xp_changed` | `Player` -> `GameHud` | XP-Bar + Leveltext |
| `PlayerProgression` | `leveled_up` | `Player` -> `LevelUpController` | Level-Up Queue |
| `PlayerWeaponSystem` | `shoot_animation_requested` | `PlayerAnimationController` | Shoot-Anim triggern |
| `PlayerWeaponSystem` | `charging_state_changed` | `PlayerUIController` | Mana-Preview on/off |
| `KiChargeController` | `charge_state_changed` | `Player` | Aura-Animation steuern |
| `Enemy` | `damage_taken` | `EnemySpawner` -> `GameHud` | Floating Damage Number |
| `Enemy` | `died` | `EnemySpawner` -> `main` + `GameHud` | XP-Orbs + Kills |
| `XPOrb` | `collected` | `XPOrbManager` -> `Player` | XP gutschreiben |
| `AbilityProgressionModel` | `weapon_unlocked` | `GameHud` | Weapon-Icons refresh |
| `AbilityProgressionModel` | `weapon_upgraded` | `GameHud` | Weapon-Icons refresh |
| `AbilityProgressionModel` | `utility_applied` | `GameHud` | Utility-Icons refresh |
| `LevelUpPopup` | `option_selected` | `LevelUpController` | Upgrade anwenden |

```mermaid
flowchart LR
    Vitals["PlayerVitals"] -->|health_changed mana_changed mana_preview_changed died| Player["Player"]
    Player -->|health_changed mana_changed mana_preview_changed| PUI["PlayerUIController"]
    Progress["PlayerProgression"] -->|xp_changed leveled_up| Player
    Player -->|xp_changed leveled_up| LUC["LevelUpController"]
    Weapon["PlayerWeaponSystem"] -->|shoot_animation_requested| Anim["PlayerAnimationController"]
    Weapon -->|charging_state_changed| PUI
    Ki["KiChargeController"] -->|charge_state_changed| Player
    Enemy["Enemy"] -->|damage_taken died| Spawner["EnemySpawner"]
    Spawner -->|enemy_damage_taken enemy_died| Hud["GameHud"]
    Model["AbilityProgressionModel"] -->|weapon_unlocked weapon_upgraded utility_applied| Hud
    Popup["LevelUpPopup"] -->|option_selected| LUC
    Orb["XPOrb"] -->|collected| OrbMgr["XPOrbManager"]
    OrbMgr -->|collect_xp call| Player
```

## 9. UI-Systeme
Zwei getrennte UI-Flows laufen parallel:

- `PlayerUIController`: Health/Mana/ManaPreview direkt am Player.
- `GameHud`: Kills, XP, PowerLevel, ActionButtonBar (inkl. Cooldown-Overlay), FloatingDamageNumbers.
- `ActionButtonBar`: Overlay-Fuellung laeuft pro Slot von oben nach unten und zeigt `AbilityCooldownRuntime.get_effective_ratio(ability_id)`.

```mermaid
flowchart TB
    Player["Player signals"] --> PUI["PlayerUIController"]
    Weapon["PlayerWeaponSystem signals"] --> PUI

    Player --> Hud["GameHud"]
    Player --> Cooldowns["AbilityCooldownRuntime"]
    Progression["AbilityProgressionModel signals"] --> Hud
    Spawner["EnemySpawner signals"] --> Hud

    Hud --> ActionBar["ActionButtonBar"]
    Cooldowns --> ActionBar
    Hud --> XPBar["XPProgressBar"]
    Hud --> Score["ScoreLabel"]
    Hud --> Damage["FloatingDamageNumber instances"]
```

## 10. Validierungs- und Fail-Fast-Regeln
Die wichtigste Integritaet wird vor Run-Start abgesichert:

- `RunBalanceDefinition.is_valid()` muss alle Referenzen enthalten.
- `ProgressionCatalog.validate()` prueft u. a.:
  - doppelte/ungueltige Ability- und Upgrade-IDs,
  - gueltige Ability-Icons,
  - Utility-Aktivierungsdaten (`input_action`, `utility_slot_index`, eindeutige Utility-Slots),
  - nicht-negative Ability-Cooldowns (`base_cooldown_seconds >= 0`),
  - Ability-Upgrade-Links inkl. Domain-Konsistenz,
  - ability-gebundene Utility-Upgrades.

Wenn Validierung fehlschlaegt, stoppt `main.gd` den Aufbau frueh.

## 11. Erweiterungspunkte
Die Architektur ist auf neue Inhalte ausgelegt:

- Neue Ability: `AbilityDefinition` + optional `ProjectileDefinition` + Catalog-Eintrag.
- Cooldown-Balancing: `base_cooldown_seconds` direkt in der Ability-Ressource.
- Neues Upgrade: `UpgradeDefinition.effects` + Catalog-Eintrag + `upgrade_ids` an Ability.
- Neues Utility-Statziel: neuer `stat_key` + Mapping in `UtilityUpgradeApplier`.
- Neue Enemy-Variante: `EnemyDefinition` + `WaveStage`-Eintrag.
- Neues Spawnverhalten: Kurven in `SpawnPacingDefinition`.

Die Orchestrierung bleibt dabei stabil, weil `main.gd`, `AbilityProgressionModel` und `EnemySpawner` als feste Integrationspunkte dienen.
