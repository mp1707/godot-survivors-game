# Survivors Game – Architekturübersicht (Post-Refactor)

## 1. Systemübersicht

```mermaid
graph TB
    subgraph CORE["Core Orchestration"]
        MAIN["main.gd"]
        ES["EnemySpawner"]
        LUC["LevelUpController"]
        HUD["GameHud"]
    end

    subgraph PLAYER["Player Subsystem"]
        P["Player (player.gd)"]
        PWS["PlayerWeaponSystem"]
        PP["PlayerProgression"]
        APM["AbilityProgressionModel"]
        PUI["PlayerUIController"]
        PHB["PlayerHealthBar"]
        PMB["PlayerManaBar"]
        DAI["DashAfterimageVfx"]
    end

    subgraph COMBAT["Combat"]
        DB["DamageableBody2D (abstract)"]
        HR["HitReaction2D"]
    end

    subgraph ENEMIES["Enemies"]
        E["Enemy (ghoul/crawler/eye scenes)"]
    end

    subgraph PROJECTILES["Projectiles"]
        PROJ["laser_projectile.gd"]
    end

    subgraph PICKUPS["Pickups"]
        XOM["XPOrbManager"]
        XO["XPOrb"]
    end

    subgraph UI["UI Components"]
        XPB["XPProgressBar"]
        LUP["LevelUpPopup"]
        ABB["ActionButtonBar"]
        FDN["FloatingDamageNumber"]
    end

    subgraph DATA["Data / Resources"]
        AD["AbilityDefinition (.tres)"]
        UD["UpgradeDefinition (.tres)"]
        ED["EnemyDefinition (.tres)"]
        WD["WaveDefinition (.tres)"]
        PD["PlayerDefinition (.tres)"]
        LPROG["LevelProgression (.tres)"]
    end

    DB -->|extends| P
    DB -->|extends| E

    MAIN --> ES
    MAIN --> LUC
    MAIN --> HUD
    MAIN --> XOM
    MAIN --> P

    P --> PWS
    P --> PP
    P --> PUI
    P --> DAI

    PWS --> APM
    LUC --> APM
    HUD --> APM

    PUI --> PHB
    PUI --> PMB

    ES -->|instantiates| E
    E -->|apply_damage| P
    PWS -->|instantiates| PROJ
    PROJ -->|apply_damage| E

    MAIN -->|spawn_orb| XOM
    XOM --> XO
    XO -->|collect_xp| P

    HR --> E
    HR --> P

    APM -.->|loads| AD
    APM -.->|loads| UD
    E -.->|reads| ED
    ES -.->|reads| WD
    P -.->|reads| PD
    PP -.->|reads| LPROG

    HUD --> XPB
    HUD --> ABB
    HUD --> FDN
    LUC --> LUP
```

---

## 2. Signal-Verbindungen

```mermaid
flowchart LR
    PP(["PlayerProgression"])
    P(["Player"])
    PWS(["PlayerWeaponSystem"])
    PUI(["PlayerUIController"])
    LUC(["LevelUpController"])
    LUP(["LevelUpPopup"])
    APM(["AbilityProgressionModel"])
    ES(["EnemySpawner"])
    HUD(["GameHud"])
    MAIN(["main.gd"])
    XO(["XPOrb"])
    XOM(["XPOrbManager"])

    PP -->|"xp_changed(cur, req, lvl)"| P
    PP -->|"leveled_up(level)"| P

    P -->|"health_changed(cur, max)"| PUI
    P -->|"mana_changed(cur, max)"| PUI
    P -->|"mana_preview_changed(active, preview_cost, max)"| PUI
    P -->|"xp_changed(cur, req, lvl)"| HUD
    P -->|"leveled_up(level)"| LUC
    P -->|"died()"| MAIN

    PWS -->|"charging_state_changed(bool)"| PUI
    PWS -->|"shoot_animation_requested(dir)"| P

    ES -->|"enemy_damage_taken(amount, pos)"| HUD
    ES -->|"enemy_died(enemy)"| HUD
    ES -->|"enemy_died(enemy)"| MAIN

    LUP -->|"option_selected(option)"| LUC
    LUC -->|"apply_option(option)"| APM

    APM -->|"weapon_unlocked(slot, ability)"| HUD
    APM -->|"weapon_upgraded(ability, upgrade)"| HUD

    XO -->|"collected(orb, amount)"| XOM
    XOM -->|"collect_xp(amount)"| P
```

---

## 3. Spawn-, Kampf- und XP-Datenfluss

```mermaid
sequenceDiagram
    participant T as WaveSpawnTimer
    participant MAIN as main.gd
    participant ES as EnemySpawner
    participant WD as WaveDefinition
    participant E as Enemy
    participant HUD as GameHud
    participant XOM as XPOrbManager
    participant XO as XPOrb
    participant P as Player
    participant PP as PlayerProgression

    T->>MAIN: timeout()
    MAIN->>ES: on_wave_tick()
    ES->>WD: get_total_enemy_count()
    ES->>WD: get_wave_size(wave_index)
    ES->>WD: pick_enemy_for_spawn(rng, spawned_count)
    ES->>E: instantiate + add_child + set target

    E-->>ES: damage_taken(amount, world_position)
    ES-->>HUD: enemy_damage_taken(amount, world_position)
    HUD->>HUD: spawn FloatingDamageNumber

    E-->>ES: died()
    ES-->>MAIN: enemy_died(enemy)
    ES-->>HUD: enemy_died(enemy)
    MAIN->>XOM: spawn_orb(enemy.global_position, enemy.xp_drop_value)

    XO-->>XOM: collected(orb, amount)
    XOM->>P: collect_xp(amount)
    P->>PP: add_xp(amount)
    PP-->>P: xp_changed / leveled_up
    P-->>HUD: xp_changed
```

---

## 4. Level-Up Datenfluss

```mermaid
sequenceDiagram
    participant PP as PlayerProgression
    participant P as Player
    participant LUC as LevelUpController
    participant APM as AbilityProgressionModel
    participant LUP as LevelUpPopup
    participant HUD as GameHud

    PP-->>P: leveled_up(level)
    P-->>LUC: leveled_up(level)
    LUC->>APM: get_unlockable_weapon_options(level)
    LUC->>APM: get_weapon_upgrade_options()
    LUC->>APM: get_utility_upgrade_options()
    LUC->>LUP: present_options(level, options)
    Note over LUC,LUP: Tree paused while popup is active

    LUP-->>LUC: option_selected(option)
    LUC->>APM: apply_option(option)

    alt new weapon
        APM-->>HUD: weapon_unlocked(slot_index, ability_id)
    else weapon upgrade
        APM-->>HUD: weapon_upgraded(ability_id, upgrade_id)
    else utility upgrade
        APM->>P: utility handler (Player) anwenden
    end

    HUD->>HUD: refresh action bar icons
    Note over LUC,LUP: Tree resumed after selection
```

---

## 5. Vererbungs- und Kompositionshierarchie

```mermaid
classDiagram
    class DamageableBody2D {
        +apply_damage(amount, pos)
        +apply_knockback(source_pos, distance)
    }

    class Player {
        +collect_xp(amount)
        +get_progression_model() AbilityProgressionModel
    }

    class Enemy {
        +definition EnemyDefinition
        +target DamageableBody2D
    }

    class PlayerWeaponSystem {
        +attach_progression_model(model)
        +physics_update(delta)
        +is_charging() bool
    }

    class AbilityProgressionModel {
        +get_slot_icon(slot) Texture2D
        +get_unlockable_weapon_options(level) Array
        +get_weapon_upgrade_options() Array
        +get_utility_upgrade_options() Array
        +apply_option(option) bool
    }

    class PlayerProgression {
        +add_xp(amount)
        +get_level() int
    }

    class EnemySpawner {
        +setup(player, wave, rng, enemies_parent)
        +on_wave_tick() bool
    }

    class LevelUpController {
        +setup(player, progression, popup, rng)
        +flush_and_resume()
    }

    class GameHud {
        +setup(player, progression, spawner, ...)
        +get_kill_count() int
    }

    class XPOrbManager {
        +setup(player)
        +spawn_orb(pos, xp)
        +clear_orbs()
    }

    DamageableBody2D <|-- Player
    DamageableBody2D <|-- Enemy
    Player *-- PlayerWeaponSystem
    Player *-- PlayerProgression
    PlayerWeaponSystem --> AbilityProgressionModel
    LevelUpController --> AbilityProgressionModel
    EnemySpawner --> Enemy
    GameHud --> EnemySpawner
    XPOrbManager *-- XPOrb
```

---

## 6. Ressourcen-Hierarchie

```text
res://resources/
├── balance/
│   ├── player_default.tres          -> PlayerDefinition (HP/Mana/Movement/Utility Upgrades)
│   ├── enemies/*.tres               -> EnemyDefinition (Combat/Movement/Rewards)
│   ├── waves/default_run.tres       -> WaveDefinition + WaveStage-Verteilung
│   └── level_progression_default.tres -> LevelProgression (XP-Kurve)
└── progression/
    ├── abilities/*.tres             -> AbilityDefinition (Weapon/Utility-Abilities)
    ├── upgrades/**/*.tres            -> UpgradeDefinition (Weapon + Utility)
    └── icons/*.tres                 -> Icon-Ressourcen
```

---

## 7. Schnellreferenz – Signaltabelle

| Signal | Emittiert von | Empfangen von | Effekt |
|---|---|---|---|
| `xp_changed(current, required, level)` | `PlayerProgression` | `Player` | Player spiegelt XP-Status nach außen |
| `leveled_up(new_level)` | `PlayerProgression` | `Player` | Player reicht Level-Up weiter |
| `health_changed(current, max)` | `Player` | `PlayerUIController` | HealthBar aktualisieren |
| `mana_changed(current, max)` | `Player` | `PlayerUIController` | ManaBar aktualisieren |
| `mana_preview_changed(active, preview_cost, max)` | `Player` | `PlayerUIController` | Mana-Vorschau aktualisieren |
| `xp_changed(current, required, level)` | `Player` | `GameHud` | XPProgressBar + Level-Label aktualisieren |
| `leveled_up(new_level)` | `Player` | `LevelUpController` | Level-Up Queue/Pause-Flow starten |
| `died()` | `Player` | `main.gd` | Spawn stoppen, Cleanup, Game Over anzeigen |
| `shoot_animation_requested(dir)` | `PlayerWeaponSystem` | `Player` | Schussanimation abspielen |
| `charging_state_changed(is_charging)` | `PlayerWeaponSystem` | `PlayerUIController` | ManaBar Charge-Preview anzeigen/verstecken |
| `enemy_damage_taken(amount, world_position)` | `EnemySpawner` | `GameHud` | FloatingDamageNumber erzeugen |
| `enemy_died(enemy)` | `EnemySpawner` | `GameHud`, `main.gd` | Kill-Counter + XP-Orb-Spawn |
| `option_selected(option)` | `LevelUpPopup` | `LevelUpController` | Option anwenden und Spiel fortsetzen |
| `weapon_unlocked(slot_index, ability_id)` | `AbilityProgressionModel` | `GameHud` | ActionBar-Icons aktualisieren |
| `weapon_upgraded(ability_id, upgrade_id)` | `AbilityProgressionModel` | `GameHud` | ActionBar-Icons aktualisieren |
| `utility_applied(upgrade_id)` | `AbilityProgressionModel` | *(aktuell kein Listener)* | Event für potenzielle zukünftige UI-Hooks |
| `collected(orb, amount)` | `XPOrb` | `XPOrbManager` | XP einsammeln + Orb recyceln |
