# Survivors Game – Architekturübersicht

## 1. Systemübersicht

```mermaid
graph TB
    subgraph CORE["Core"]
        MAIN["main.gd (Orchestrator)"]
    end

    subgraph PLAYER["Player Subsystem"]
        P["Player (player.gd)"]
        PWS["PlayerWeaponSystem"]
        PP["PlayerProgression"]
        WPM["WeaponProgressionModel"]
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
        G["Ghoul / Crawler / Eye"]
    end

    subgraph PROJECTILES["Projectiles"]
        PROJ["laser_projectile.gd"]
    end

    subgraph PICKUPS["Pickups"]
        XOM["XPOrbManager (Pool)"]
        XO["XPOrb"]
    end

    subgraph UI["UI"]
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
    DB -->|extends| G

    P --> PWS
    P --> PP
    P --> PUI
    PWS --> WPM
    PUI --> PHB
    PUI --> PMB
    P --> DAI

    WPM -.->|loads| AD
    WPM -.->|loads| UD
    G -.->|reads| ED
    MAIN -.->|reads| WD
    MAIN -.->|reads| LPROG
    P -.->|reads| PD

    PWS -->|instantiates| PROJ
    PROJ -->|apply_damage| G

    MAIN -->|spawn_orb| XOM
    XOM --> XO
    XO -->|collect_xp| P

    HR --> G
    HR --> P

    MAIN --> G
    MAIN --> XOM
    MAIN --> LUP
    MAIN --> ABB
    MAIN --> XPB
    MAIN --> FDN
    MAIN --> P
```

---

## 2. Signal-Verbindungen

```mermaid
flowchart LR
    P(["Player"])
    PWS(["PlayerWeaponSystem"])
    G(["Enemy"])
    XO(["XPOrb"])
    LUP(["LevelUpPopup"])
    MAIN(["main.gd"])
    PUI(["PlayerUIController"])
    PHB(["HealthBar"])
    PMB(["ManaBar"])
    ABB(["ActionButtonBar"])
    FDN(["FloatingDamageNumber"])
    XOM(["XPOrbManager"])

    P -->|"died()"| MAIN
    P -->|"health_changed(cur, max)"| PUI
    P -->|"mana_changed(cur, max)"| PUI
    P -->|"xp_changed(cur, req, lvl)"| MAIN
    P -->|"leveled_up(level)"| MAIN

    PUI --> PHB
    PUI --> PMB

    PWS -->|"weapon_slots_changed()"| MAIN
    PWS -->|"charging_state_changed(bool)"| PMB
    PWS -->|"shoot_animation_requested(dir)"| P

    G -->|"damage_taken(amount, pos)"| MAIN
    G -->|"died()"| MAIN

    XO -->|"collected(orb, value)"| XOM
    XOM -->|"collect_xp(amount)"| P

    LUP -->|"option_selected(option)"| MAIN

    MAIN -->|"spawn FloatingDamageNumber"| FDN
    MAIN -->|"refresh icons"| ABB
    MAIN -->|"show Game Over"| MAIN
```

---

## 3. Level-Up Datenfluss

```mermaid
sequenceDiagram
    participant XO as XPOrb
    participant XOM as XPOrbManager
    participant PL as PlayerProgression
    participant MAIN as main.gd
    participant LUP as LevelUpPopup
    participant WPM as WeaponProgressionModel
    participant PWS as PlayerWeaponSystem
    participant P as Player

    XO->>XOM: collected(orb, value)
    XOM->>PL: add_xp(value)
    PL-->>MAIN: leveled_up(level)
    MAIN->>WPM: get_unlockable_weapon_options()
    MAIN->>WPM: get_weapon_upgrade_options()
    MAIN->>P: get_utility_upgrade_options()
    MAIN->>LUP: present_options(3 options)
    LUP-->>MAIN: option_selected(option)

    alt TYPE_NEW_WEAPON
        MAIN->>PWS: unlock_weapon_in_next_free_slot(id)
    else TYPE_WEAPON_UPGRADE
        MAIN->>PWS: apply_weapon_upgrade(ability_id, upgrade_id)
    else TYPE_PLAYER_UPGRADE
        MAIN->>P: apply_utility_upgrade(upgrade_id)
    end

    PWS-->>MAIN: weapon_slots_changed()
    MAIN->>ABB: set_weapon_slot_icon(slot, icon)
```

---

## 4. Kampf- & Schadensfluss

```mermaid
sequenceDiagram
    participant IN as Input
    participant PWS as PlayerWeaponSystem
    participant P as Player
    participant PROJ as Projectile
    participant G as Ghoul
    participant MAIN as main.gd

    IN->>PWS: action_pressed (fire)
    PWS->>P: consume_mana(cost)
    PWS->>PROJ: instantiate + configure
    PWS-->>P: shoot_animation_requested(dir)

    PROJ->>G: body_entered → apply_damage(dmg, pos)
    G-->>MAIN: damage_taken(amount, pos)
    MAIN->>MAIN: spawn FloatingDamageNumber

    alt HP <= 0
        G-->>MAIN: died()
        MAIN->>XOM: spawn_orb(pos, xp_value)
        G->>G: queue_free()
    end
```

---

## 5. Vererbungs- & Kompositionshierarchie

```mermaid
classDiagram
    class DamageableBody2D {
        +apply_damage(amount, pos)
        +apply_knockback(dir, force)
    }

    class Player {
        -_health float
        -_mana float
        -_is_dashing bool
        -_is_ki_charging bool
        +collect_xp(amount)
        +apply_utility_upgrade(id)
        +get_power_level() int
    }

    class Ghoul {
        -_hp float
        -target Node2D
        +definition EnemyDefinition
    }

    class PlayerWeaponSystem {
        -_weapon_slots Array
        -_model WeaponProgressionModel
        +unlock_weapon_in_next_free_slot(id)
        +apply_weapon_upgrade(ability_id, upgrade_id)
        +is_charging() bool
    }

    class WeaponProgressionModel {
        -_ability_states Dict
        +get_ability_state(id) WeaponAbilityState
        +get_current_cost(id) float
        +get_charged_damage(id) float
    }

    class WeaponAbilityState {
        +ability_id String
        +is_unlocked bool
        +upgrade_counts Dict
    }

    class PlayerProgression {
        -_level int
        -_xp_in_level float
        +add_xp(amount)
        +get_level() int
    }

    class XPOrbManager {
        -_pool Array
        +spawn_orb(pos, value)
        +clear_orbs()
    }

    DamageableBody2D <|-- Player
    DamageableBody2D <|-- Ghoul
    Player *-- PlayerWeaponSystem
    Player *-- PlayerProgression
    PlayerWeaponSystem *-- WeaponProgressionModel
    WeaponProgressionModel *-- WeaponAbilityState
    XPOrbManager *-- XPOrb
```

---

## 6. Ressourcen-Hierarchie

```
res://resources/
├── balance/
│   ├── player/         → PlayerDefinition.tres   (HP, Mana, Dash-Stats)
│   ├── enemies/        → EnemyDefinition.tres     (HP, Damage, Speed)
│   ├── waves/          → WaveDefinition.tres      (Spawn-Regeln, Stages)
│   └── progression/    → LevelProgression.tres    (XP-Kurve)
└── progression/
    ├── abilities/      → AbilityDefinition.tres   (Damage, Cost, Pierce…)
    ├── upgrades/       → UpgradeDefinition.tres   (Wert, Max-Stacks)
    └── icons/          → Texture-Atlas .tres
```

---

## 7. Schnellreferenz – Signaltabelle

| Signal | Emittiert von | Empfangen von | Effekt |
|---|---|---|---|
| `health_changed(cur, max)` | Player | PlayerUIController | HealthBar aktualisieren |
| `mana_changed(cur, max)` | Player | PlayerUIController | ManaBar aktualisieren |
| `xp_changed(cur, req, lvl)` | PlayerProgression | main.gd | XPProgressBar + Label |
| `leveled_up(level)` | PlayerProgression | main.gd | Level-Up Popup öffnen |
| `died()` | Player | main.gd | Game Over zeigen |
| `weapon_slots_changed()` | PlayerWeaponSystem | main.gd | ActionButtonBar Icons refresh |
| `charging_state_changed(bool)` | PlayerWeaponSystem | PlayerUIController | ManaBar Vorschau |
| `shoot_animation_requested(dir)` | PlayerWeaponSystem | Player | Schussanimation abspielen |
| `damage_taken(amount, pos)` | Ghoul/Enemy | main.gd | FloatingDamageNumber spawnen |
| `died()` | Ghoul/Enemy | main.gd | XP Orb spawnen |
| `collected(orb, value)` | XPOrb | XPOrbManager | `player.collect_xp()` aufrufen |
| `option_selected(option)` | LevelUpPopup | main.gd | Upgrade anwenden |
