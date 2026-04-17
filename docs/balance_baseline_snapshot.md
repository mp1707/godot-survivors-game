# Balance Baseline Snapshot (Pre-Refactor)

Datum: 2026-04-17
Quelle: `resources/**/*.tres` + Runtime-Defaults in `scripts/**/*.gd`.

## Player (PlayerDefinition)

- Resource: `res://resources/balance/player_default.tres`
- `max_health`: 100
- `max_mana`: 100
- `mana_regen_per_second`: 1.0
- `ki_charge_regen_per_second`: 20.0
- `speed`: 150.0
- `dash_distance`: 40.0
- `dash_speed`: 700.0
- `dash_cooldown`: 5.0
- `xp_magnet_radius`: 80.0

## Enemies (EnemyDefinition)

- `ghoul`: HP 1, DMG 10, speed 40.0, xp 1
- `ghoul_elite`: HP 3, DMG 12, speed 40.0, xp 2
- `crawler`: HP 2, DMG 10, speed 36.0, xp 1
- `crawler_elite`: HP 4, DMG 12, speed 36.0, xp 3
- `eye`: HP 3, DMG 12, speed 48.0, xp 2
- `eye_elite`: HP 6, DMG 14, speed 48.0, xp 4

## Spawn / Wave

- Resource: `res://resources/balance/waves/default_run.tres`
- Timer wait time in scene: `1.2s`
- Wave size curve: `1 -> 6` (max_waves_for_curve: 40)
- Stage counts: ghoul 220, crawler 280, eye 300
- Total enemies: 800
- Spawn ring: min 260.0, max 340.0

## Abilities (AbilityDefinition)

- `ki_blast`: starts unlocked, slot 0, cost 10, dmg 1-1, speed 360, size 0.7
- `charged_ki_blast`: unlock 5, charge, cost 30, dmg 2-5, charge_time 3.0, speed 320
- `barrier`: unlock 9, cost 30, absorb 30 (+10), lifetime 10 (+2)
- `energy_ball`: unlock 13, charge, cost 50, dmg 5-10, charge_time 5.0, speed 70, pierce -1
- `dash`: utility progression ability resource
- `charge_ki`: utility progression ability resource

## Upgrades (current payload model)

Weapon upgrade IDs:
- `cost`, `damage`, `pierce`, `speed`, `bounce`, `size`, `absorb`, `lifetime`, `reflect`, `charge_speed`

Utility upgrade IDs:
- `dash_cooldown` (`numeric_value=-1`, `min_clamp=1`, max_stacks 4)
- `dash_distance` (`numeric_value=5`)
- `dash_invulnerable` (flag, max_stacks 1)
- `dash_phase` (flag, max_stacks 1)
- `charge_ki_regen` (`numeric_value=2`)
- `charge_ki_knockback` (`numeric_value=10`)
- `charge_ki_aoe_damage` (`numeric_value=1`)

## Erwartete Level-Up Kandidaten (vor Random-Pick)

- Level 1: kein Unlock-Milestone; Pool = aktive Waffen-Upgrades + Utility-Upgrades
- Level 5: Unlock-Milestone `charged_ki_blast`; Unlock-Option priorisiert, auf bis zu 3 Optionen mit Upgrades aufgefuellt
- Level 9: Unlock-Milestone `barrier`; gleicher Mechanismus
- Level 13: Unlock-Milestone `energy_ball`; gleicher Mechanismus
